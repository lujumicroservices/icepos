import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

/// One row from [platform_orders] (Uber Eats, etc.).
class PlatformOrderRow {
  const PlatformOrderRow({
    required this.id,
    required this.platform,
    required this.externalOrderId,
    required this.status,
    required this.orderedAt,
    required this.totalAmount,
    this.currency,
    this.displaySummary,
  });

  final int id;
  final String platform;
  final String externalOrderId;
  final String status;
  final DateTime orderedAt;
  final double totalAmount;
  final String? currency;
  final String? displaySummary;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static PlatformOrderRow? fromMap(Map<String, dynamic> m) {
    final id = _asInt(m['id']);
    if (id == null) return null;
    final platform = m['platform'] as String?;
    final ext = m['external_order_id'] as String?;
    if (platform == null || ext == null) return null;
    final orderedRaw = m['ordered_at'] as String?;
    final orderedAt = orderedRaw != null ? DateTime.tryParse(orderedRaw) : null;
    if (orderedAt == null) return null;
    return PlatformOrderRow(
      id: id,
      platform: platform,
      externalOrderId: ext,
      status: m['status'] as String? ?? 'UNKNOWN',
      orderedAt: orderedAt,
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
      currency: m['currency'] as String?,
      displaySummary: m['display_summary'] as String?,
    );
  }
}

/// Loads [platform_orders] from Supabase for the active store.
class PlatformOrdersService {
  PlatformOrdersService._();

  static bool get isAvailable => SupabaseService.isInitialized;

  /// Uber Eats orders whose [ordered_at] falls on [day] in the device local calendar.
  static Future<List<PlatformOrderRow>> fetchUberEatsForDay(DateTime day) async {
    if (!isAvailable) return [];
    try {
      final storeId = await StoreScope.getActiveStoreId();
      final startLocal = DateTime(day.year, day.month, day.day);
      final endLocal = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      final client = SupabaseService.instance.client;
      final res = await client
          .from('platform_orders')
          .select(
            'id, store_id, platform, external_order_id, status, ordered_at, total_amount, currency, display_summary',
          )
          .eq('store_id', storeId)
          .eq('platform', 'uber_eats')
          .gte('ordered_at', startLocal.toUtc().toIso8601String())
          .lte('ordered_at', endLocal.toUtc().toIso8601String())
          .order('ordered_at', ascending: false);

      final list = res as List<dynamic>? ?? [];
      final out = <PlatformOrderRow>[];
      for (final row in list) {
        final m = Map<String, dynamic>.from(row as Map);
        final parsed = PlatformOrderRow.fromMap(m);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (e, st) {
      debugPrint('PlatformOrdersService.fetchUberEatsForDay: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
