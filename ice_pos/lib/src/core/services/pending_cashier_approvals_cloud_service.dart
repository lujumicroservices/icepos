import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef PendingCloudResolutionHandler = Future<void> Function({
  required String cloudId,
  required String status,
  String? kind,
  Map<String, dynamic>? payload,
});

/// Fila en Supabase `pending_cashier_approvals` (web admin + sync con caja).
class CloudPendingCashierApprovalRow {
  const CloudPendingCashierApprovalRow({
    required this.id,
    required this.storeId,
    required this.deviceId,
    required this.kind,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final int storeId;
  final String deviceId;
  final String kind;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

/// Inserta en nube, aprueba/rechaza desde web, y escucha resoluciones para la caja física.
class PendingCashierApprovalsCloudService {
  PendingCashierApprovalsCloudService._();

  static RealtimeChannel? _deviceChannel;
  static AppDatabase? _db;
  static PendingCloudResolutionHandler? _onResolution;
  static void Function()? _onSyncDone;

  static List<Map<String, dynamic>> _list(dynamic res) {
    if (res == null) return [];
    if (res is List) return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  static int _int(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseTs(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// Sube una fila local recién insertada y devuelve el uuid de Supabase.
  static Future<String?> pushLocalPendingRow({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return null;
    if (!ConnectivityService.instance.isConnected) return null;
    try {
      final storeId = await StoreScope.getActiveStoreId();
      final dev = await DeviceIdService.getDeviceInfo();
      final client = SupabaseService.instance.client;
      final res = await client
          .from('pending_cashier_approvals')
          .insert({
            'store_id': storeId,
            'device_id': dev.deviceId,
            'kind': kind,
            'payload': payload,
          })
          .select('id')
          .maybeSingle();
      final cloudId = res?['id'] as String?;
      if (cloudId != null) {
        unawaited(_notifyPushForPendingApproval(
          cloudId: cloudId,
          storeId: storeId,
          kind: kind,
        ));
      }
      return cloudId;
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService.pushLocalPendingRow: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<void> _notifyPushForPendingApproval({
    required String cloudId,
    required int storeId,
    required String kind,
  }) async {
    if (!SupabaseService.isInitialized) return;
    try {
      await SupabaseService.instance.client.functions.invoke(
        'notify-pending-approval',
        body: {
          'pending_id': cloudId,
          'store_id': storeId,
          'kind': kind,
        },
      );
    } catch (e) {
      debugPrint('PendingCashierApprovalsCloudService._notifyPushForPendingApproval: $e');
    }
  }

  static Future<void> markResolvedOnCloud(String cloudId, String status) async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    if (!ConnectivityService.instance.isConnected) return;
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      await SupabaseService.instance.client.from('pending_cashier_approvals').update({
        'status': status,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', cloudId);
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService.markResolvedOnCloud: $e');
      debugPrint('$st');
    }
  }

  static Future<List<CloudPendingCashierApprovalRow>> fetchPendingForActiveStore() async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return [];
    try {
      final storeId = await StoreScope.getActiveStoreId();
      final res = await SupabaseService.instance.client
          .from('pending_cashier_approvals')
          .select('id, store_id, device_id, kind, payload, status, created_at, resolved_at')
          .eq('store_id', storeId)
          .eq('status', 'pending')
          .order('created_at');
      return _list(res).map(_rowFromMap).where((r) => r.status == 'pending').toList();
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService.fetchPendingForActiveStore: $e');
      debugPrint('$st');
      return [];
    }
  }

  static CloudPendingCashierApprovalRow _rowFromMap(Map<String, dynamic> m) {
    final payloadRaw = m['payload'];
    final Map<String, dynamic> payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};
    return CloudPendingCashierApprovalRow(
      id: m['id'] as String,
      storeId: _int(m['store_id']),
      deviceId: m['device_id'] as String? ?? '',
      kind: m['kind'] as String? ?? '',
      payload: payload,
      status: m['status'] as String? ?? 'pending',
      createdAt: _parseTs(m['created_at']) ?? DateTime.now(),
      resolvedAt: _parseTs(m['resolved_at']),
    );
  }

  /// Polling para web (sin Drift).
  static Stream<List<CloudPendingCashierApprovalRow>> watchPendingForActiveStore() async* {
    if (!CloudSyncService.isEnabled) return;
    while (true) {
      if (!ConnectivityService.instance.isConnected) {
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      try {
        yield await fetchPendingForActiveStore();
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  /// Admin web (o nativo): aplica en nube y marca aprobada. El cierre de caja lo ejecuta la caja al recibir Realtime.
  static Future<String?> approveFromWeb(String cloudId) async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) {
      return 'Supabase no disponible';
    }
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      final row = await client
          .from('pending_cashier_approvals')
          .select('id, kind, payload, status')
          .eq('id', cloudId)
          .maybeSingle();
      if (row == null) return 'Solicitud no encontrada';
      final map = Map<String, dynamic>.from(row);
      if ((map['status'] as String?) != 'pending') return 'Ya fue resuelta';
      final kind = map['kind'] as String? ?? '';
      final payloadRaw = map['payload'];
      final Map<String, dynamic> payload = payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : <String, dynamic>{};

      switch (kind) {
        case 'movement':
          final type = payload['type'] as String? ?? '';
          final account = payload['account'] as String? ?? '';
          final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
          final reason = payload['reason'] as String? ?? '';
          final shiftKey = (payload['cloudShiftId'] as num?)?.toInt() ??
              (payload['shiftId'] as num?)?.toInt();
          final (err, _) = await CloudSyncService.insertMovementToCloud(
            type: type,
            account: account,
            amount: amount,
            reason: reason,
            shiftId: shiftKey,
          );
          if (err != null) return err;
          break;
        case 'sale_cancel':
          final saleId = (payload['saleId'] as num?)?.toInt();
          if (saleId == null) return 'saleId inválido';
          await client.from('sales').update({
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', saleId);
          break;
        case 'shift_close':
          break;
        default:
          return 'Tipo desconocido';
      }

      await client.from('pending_cashier_approvals').update({
        'status': 'approved',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', cloudId).eq('status', 'pending');
      return null;
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService.approveFromWeb: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static Future<String?> rejectFromWeb(String cloudId) async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) {
      return 'Supabase no disponible';
    }
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      await client.from('pending_cashier_approvals').update({
        'status': 'rejected',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', cloudId).eq('status', 'pending');
      return null;
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService.rejectFromWeb: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Suscripción: cuando la nube marca aprobada/rechazada, la caja actualiza Drift y sync.
  static void startDeviceListener({
    required AppDatabase db,
    required PendingCloudResolutionHandler onResolution,
    void Function()? onSyncDone,
  }) {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    if (_deviceChannel != null) return;
    _db = db;
    _onResolution = onResolution;
    _onSyncDone = onSyncDone;

    unawaited(_subscribeDevice());
  }

  static Future<void> _subscribeDevice() async {
    final db = _db;
    if (db == null || _onResolution == null) return;
    final dev = await DeviceIdService.getDeviceInfo();
    try {
      final myId = dev.deviceId;
      _deviceChannel = SupabaseService.instance.client
          .channel('pending-approvals-$myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'pending_cashier_approvals',
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec['device_id'] != myId) return;
              unawaited(_onDevicePendingUpdate(payload, db));
            },
          )
          .subscribe();
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService._subscribeDevice: $e');
      debugPrint('$st');
    }
  }

  static Future<void> _onDevicePendingUpdate(
    PostgresChangePayload event,
    AppDatabase db,
  ) async {
    try {
      final rec = event.newRecord;
      final status = rec['status'] as String?;
      if (status != 'approved' && status != 'rejected') return;
      final cloudId = rec['id'] as String?;
      if (cloudId == null) return;
      final kind = rec['kind'] as String?;
      final payloadRaw = rec['payload'];
      final Map<String, dynamic>? resolutionPayload = payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : null;
      await _onResolution!(
        cloudId: cloudId,
        status: status!,
        kind: kind,
        payload: resolutionPayload,
      );
      _onSyncDone?.call();
    } catch (e, st) {
      debugPrint('PendingCashierApprovalsCloudService._onDevicePendingUpdate: $e');
      debugPrint('$st');
    }
  }

  static Future<void> stopDeviceListener() async {
    if (_deviceChannel != null) {
      await SupabaseService.instance.client.removeChannel(_deviceChannel!);
      _deviceChannel = null;
    }
    _db = null;
    _onResolution = null;
    _onSyncDone = null;
  }
}
