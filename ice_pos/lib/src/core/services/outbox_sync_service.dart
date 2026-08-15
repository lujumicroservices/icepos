import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/services/sync_coordinator.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart' show CartItem;
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';

/// Replays local sales and movements that were created offline or failed to reach Supabase.
class OutboxSyncService {
  OutboxSyncService._();

  /// Call when connectivity returns or on app resume. Serialized with [CloudSyncService.syncFromCloud].
  static Future<void> drain(AppDatabase db) async {
    if (!SupabaseService.isInitialized || !CloudSyncService.isEnabled) return;
    if (!ConnectivityService.instance.isConnected) return;

    await SyncCoordinator.synchronized(() async {
      await _replayMovements(db);
      await _replaySales(db);
    });
  }

  static Future<void> _replayMovements(AppDatabase db) async {
    final pending = await (db.select(db.movements)
          ..where((m) => m.needsCloudSync.equals(true)))
        .get();
    for (final m in pending) {
      final err = await CloudSyncService.writeMovementToCloud(m, db);
      if (err == null) {
        await (db.update(db.movements)..where((x) => x.id.equals(m.id))).write(
              const MovementsCompanion(needsCloudSync: Value(false)),
            );
      } else {
        debugPrint('OutboxSyncService: movement ${m.id} still pending: $err');
      }
    }
  }

  static Future<void> _replaySales(AppDatabase db) async {
    final pending = await (db.select(db.sales)..where((s) => s.cloudSaleId.isNull())).get();
    for (final sale in pending) {
      if (sale.cancelledAt != null) continue;
      final shift = await (db.select(db.shifts)..where((s) => s.id.equals(sale.shiftId)))
          .getSingleOrNull();
      if (shift == null) continue;

      final cartItems = await _cartItemsForSale(db, sale.id);
      if (cartItems.isEmpty) continue;

      final cloudSid = CloudSyncService.supabaseShiftId(shift);
      final (err, cloudId) = await CloudSyncService.writeSaleToCloud(
        cartItems,
        totalAmount: sale.totalAmount,
        paymentMethod: sale.paymentMethod,
        amountTendered: sale.amountTendered,
        changeGiven: sale.changeGiven,
        paymentsJson: sale.paymentsJson,
        cloudShiftId: cloudSid,
      );
      if (err != null) {
        debugPrint('OutboxSyncService: sale ${sale.id} replay failed: $err');
        continue;
      }
      if (cloudId != null) {
        await (db.update(db.sales)..where((s) => s.id.equals(sale.id))).write(
              SalesCompanion(cloudSaleId: Value(cloudId)),
            );
      }
    }
  }

  static Future<List<CartItem>> _cartItemsForSale(AppDatabase db, int saleId) async {
    final rows = await db.customSelect(
      '''
SELECT si.product_id, si.quantity, si.unit_price, si.modifiers_json, p.name AS product_name
FROM sale_items si
INNER JOIN products p ON p.id = si.product_id
WHERE si.sale_id = ?
''',
      variables: [Variable.withInt(saleId)],
      readsFrom: {db.saleItems, db.products},
    ).get();

    final out = <CartItem>[];
    for (final row in rows) {
      final productId = row.read<int>('product_id');
      final quantity = row.read<double>('quantity');
      final unitPrice = row.read<double>('unit_price');
      final productName = row.read<String>('product_name');
      final modsRaw = row.read<String?>('modifiers_json');
      var mods = <ModifierOption>[];
      if (modsRaw != null && modsRaw.isNotEmpty) {
        try {
          final list = jsonDecode(modsRaw) as List<dynamic>;
          mods = list
              .map((e) => ModifierOptionDto.fromJson(e as Map<String, dynamic>).toModifierOption())
              .toList();
        } catch (_) {}
      }
      out.add(
        CartItem(
          productId: productId,
          quantity: quantity,
          unitPrice: unitPrice,
          productName: productName,
          selectedModifiers: mods,
        ),
      );
    }
    return out;
  }
}
