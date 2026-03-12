import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

const _kCloudProductIdMap = 'cloud_product_id_map';
const _kCloudSupplyIdMap = 'cloud_supply_id_map';
const _kStartupSyncErrorKey = 'startup_sync_error';

/// When Supabase is the source of truth:
/// - syncFromCloud: replace local master data (categories, products, supplies, recipes, modifiers, bundles) from cloud.
/// - writeSaleToCloud: write sale + inventory to Supabase; call before local processSale.
class CloudSyncService {
  CloudSyncService._();

  static bool get isEnabled => SupabaseService.isInitialized;

  /// Último error de sincronización (fallo o "nube vacía"). La UI puede mostrarlo en el drawer.
  static String? lastSyncError;

  /// Call when sync fails at startup so the UI can show the error once.
  static Future<void> setStartupSyncError(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStartupSyncErrorKey, message);
    } catch (_) {}
  }

  /// Reads and clears the startup sync error (for showing in UI once).
  static Future<String?> takeStartupSyncError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final msg = prefs.getString(_kStartupSyncErrorKey);
      if (msg != null) await prefs.remove(_kStartupSyncErrorKey);
      return msg;
    } catch (_) {
      return null;
    }
  }

  /// True if cloud has no categories (empty master data). Use to allow "Cargar desde JSON" only when cloud is empty.
  static Future<bool> isCloudEmpty() async {
    if (!SupabaseService.isInitialized) return true;
    try {
      final res = await SupabaseService.instance.client
          .from('categories')
          .select('id')
          .limit(1);
      return _list(res).isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Replaces local master data with Supabase data. Does not sync sales (those are write-through).
  /// Fetches all data from cloud first; only clears local DB after a successful fetch so a failed
  /// sync (network, RLS, etc.) never wipes local data.
  static Future<String?> syncFromCloud(AppDatabase db) async {
    if (!SupabaseService.isInitialized) return null;
    final client = SupabaseService.instance.client;

    // 1. Fetch everything from cloud first (no local writes). On any failure we return without touching local DB.
    List<Map<String, dynamic>> catRows;
    List<Map<String, dynamic>> supRows;
    List<Map<String, dynamic>> prodRows;
    List<Map<String, dynamic>> recRows;
    List<Map<String, dynamic>> mgRows;
    List<Map<String, dynamic>> pmRows;
    List<Map<String, dynamic>> moRows;
    List<Map<String, dynamic>> bundleRows;
    List<Map<String, dynamic>> biRows;
    try {
      final catRaw = await client.from('categories').select('*').order('id');
      catRows = _list(catRaw).map((r) => _map(r)).toList();
      // If cloud has no categories, do not wipe local — leave data as is.
      if (catRows.isEmpty) {
        lastSyncError = 'La nube no tiene categorías. Sube datos desde otro dispositivo (Cargar desde JSON y enviar a la nube).';
        return lastSyncError;
      }
      supRows = _list(await client.from('supplies').select('*').order('id')).map((r) => _map(r)).toList();
      prodRows = _list(await client.from('products').select('*').order('id')).map((r) => _map(r)).toList();
      recRows = _list(await client.from('recipes').select('*').order('id')).map((r) => _map(r)).toList();
      mgRows = _list(await client.from('modifier_groups').select('*').order('id')).map((r) => _map(r)).toList();
      pmRows = _list(await client.from('product_modifiers').select('*')).map((r) => _map(r)).toList();
      moRows = _list(await client.from('modifier_options').select('*')).map((r) => _map(r)).toList();
      bundleRows = _list(await client.from('bundles').select('*').order('id')).map((r) => _map(r)).toList();
      biRows = _list(await client.from('bundle_items').select('*')).map((r) => _map(r)).toList();
    } catch (e, st) {
      debugPrint('CloudSyncService.syncFromCloud fetch failed: $e');
      debugPrint('$st');
      lastSyncError = e.toString();
      return lastSyncError;
    }

    try {
      // 2. Now replace local master data (FK order: delete dependents first)
      await (db.delete(db.modifierOptions)).go();
      await (db.delete(db.productModifiers)).go();
      await (db.delete(db.modifierGroups)).go();
      await (db.delete(db.recipes)).go();
      await (db.delete(db.bundleItems)).go();
      await (db.delete(db.bundles)).go();
      await (db.delete(db.products)).go();
      await (db.delete(db.supplies)).go();
      await (db.delete(db.categories)).go();

      for (final row in catRows) {
        final cloudId = _int(row['id'])!;
        final cloudParentId = _int(row['parent_id']);
        await db.into(db.categories).insert(CategoriesCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          parentId: Value(cloudParentId),
          color: Value(row['color'] as String?),
        ));
      }
      for (final row in supRows) {
        final cloudId = _int(row['id'])!;
        await db.into(db.supplies).insert(SuppliesCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          unit: Value(row['unit'] as String),
          currentStock: Value(_double(row['current_stock'])),
          costPerUnit: Value(_double(row['cost_per_unit'])),
          reorderPoint: Value(_double(row['reorder_point'])),
          category: Value(row['category'] as String?),
        ));
      }
      for (final row in prodRows) {
        final cloudId = _int(row['id'])!;
        final cloudCatId = _int(row['category_id']);
        await db.into(db.products).insert(ProductsCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          price: Value(_double(row['price'])),
          imageUrl: Value(row['image_url'] as String?),
          isActive: Value(_bool(row['is_active'])),
          categoryId: Value(cloudCatId),
        ));
      }
      for (final row in recRows) {
        await db.into(db.recipes).insert(RecipesCompanion.insert(
          productId: _int(row['product_id'])!,
          supplyId: _int(row['supply_id'])!,
          quantityRequired: _double(row['quantity_required']),
        ));
      }
      for (final row in mgRows) {
        final cloudId = _int(row['id'])!;
        await db.into(db.modifierGroups).insert(ModifierGroupsCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          minSelection: Value(_int(row['min_selection']) ?? 0),
          maxSelection: Value(_int(row['max_selection'])!),
        ));
      }
      for (final row in pmRows) {
        await db.into(db.productModifiers).insert(ProductModifiersCompanion.insert(
          productId: _int(row['product_id'])!,
          modifierGroupId: _int(row['modifier_group_id'])!,
        ));
      }
      for (final row in moRows) {
        await db.into(db.modifierOptions).insert(ModifierOptionsCompanion.insert(
          modifierGroupId: _int(row['modifier_group_id'])!,
          supplyId: _int(row['supply_id'])!,
          quantityDeducted: _double(row['quantity_deducted']),
          priceExtra: Value(_double(row['price_extra'])),
        ));
      }
      for (final row in bundleRows) {
        final cloudId = _int(row['id'])!;
        await db.into(db.bundles).insert(BundlesCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          price: Value(_double(row['price'])),
          isActive: Value(_bool(row['is_active'])),
          categoryId: Value(_int(row['category_id'])),
        ));
      }
      for (final row in biRows) {
        await db.into(db.bundleItems).insert(BundleItemsCompanion.insert(
          bundleId: _int(row['bundle_id'])!,
          productId: _int(row['product_id'])!,
          quantityRequired: Value(_double(row['quantity'])),
        ));
      }

      final allProducts = await (db.select(db.products)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
      final allSupplies = await (db.select(db.supplies)..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
      final localToCloudProduct = {for (final p in allProducts) p.id: p.id};
      final localToCloudSupply = {for (final s in allSupplies) s.id: s.id};
      if (localToCloudProduct.isNotEmpty) {
        await _saveIdMaps(localToCloudProduct, localToCloudSupply);
      }
      lastSyncError = null;
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.syncFromCloud write failed: $e');
      debugPrint('$st');
      lastSyncError = e.toString();
      return lastSyncError;
    }
  }

  /// Writes sale + sale_items + supply deductions + inventory_logs to Supabase.
  /// Returns (error, cloudSaleId): on success (null, id), on failure (message, null). When cloud disabled, (null, null).
  static Future<(String? error, int? cloudSaleId)> writeSaleToCloud(
    List<CartItem> items, {
    required double totalAmount,
    required String paymentMethod,
    double amountTendered = 0,
    double changeGiven = 0,
  }) async {
    if (!SupabaseService.isInitialized || items.isEmpty) return (null, null);
    try {
      final client = SupabaseService.instance.client;
      final (productMap, supplyMap) = await _loadIdMaps();
      if (productMap.isEmpty) {
        return ('Falta el mapa de productos con la nube. Abre el menú (≡) y pulsa "Sincronizar" si la nube ya tiene datos, o "Enviar datos a la nube" si este dispositivo tiene el menú.', null);
      }

      for (final cartItem in items) {
        final cloudProductId = productMap[cartItem.productId];
        if (cloudProductId == null) {
          return ('Producto (id ${cartItem.productId}) no está en la nube. En este dispositivo abre el menú (≡) y pulsa Sincronizar para alinear IDs con la nube.', null);
        }
        final recipeRows = await client.from('recipes').select('*').eq('product_id', cloudProductId);
        for (final r in _list(recipeRows)) {
          final row = _map(r);
          final supplyId = _int(row['supply_id'])!;
          final qty = _double(row['quantity_required']) * cartItem.quantity;
          final res = await client.from('supplies').select('current_stock').eq('id', supplyId).maybeSingle();
          final cur = res == null ? 0.0 : _double(_map(res)['current_stock']);
          await client.from('supplies').update({'current_stock': cur - qty}).eq('id', supplyId);
          await client.from('inventory_logs').insert({'supply_id': supplyId, 'change_amount': -qty, 'reason': 'SALE'});
        }
        for (final mod in cartItem.selectedModifiers) {
          final amount = mod.quantityDeducted * cartItem.quantity;
          final cloudSupplyId = supplyMap[mod.supplyId];
          if (cloudSupplyId == null) {
            return ('Insumo (id ${mod.supplyId}) no está en la nube. Sincroniza desde la nube.', null);
          }
          final res = await client.from('supplies').select('current_stock').eq('id', cloudSupplyId).maybeSingle();
          final cur = res == null ? 0.0 : _double(_map(res)['current_stock']);
          await client.from('supplies').update({'current_stock': cur - amount}).eq('id', cloudSupplyId);
          await client.from('inventory_logs').insert({'supply_id': cloudSupplyId, 'change_amount': -amount, 'reason': 'SALE'});
        }
      }

      final device = await DeviceIdService.getDeviceInfo();
      Map<String, dynamic> saleRow = {
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'amount_tendered': amountTendered,
        'change_given': changeGiven,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
      };
      dynamic saleRes;
      try {
        saleRes = await client.from('sales').insert(saleRow).select('id').single();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('device_id') || msg.contains('device_name') || msg.contains('does not exist')) {
          saleRow = {
            'total_amount': totalAmount,
            'payment_method': paymentMethod,
            'amount_tendered': amountTendered,
            'change_given': changeGiven,
          };
          saleRes = await client.from('sales').insert(saleRow).select('id').single();
        } else {
          rethrow;
        }
      }
      final saleId = _int(_map(saleRes)['id']);
      if (saleId == null) return ('Error al crear venta', null);

      for (final item in items) {
        final cloudProductId = productMap[item.productId];
        if (cloudProductId == null) {
          return ('Producto (id ${item.productId}) no está en la nube. En este dispositivo pulsa Sincronizar (≡) para alinear IDs con la nube.', null);
        }
        await client.from('sale_items').insert({
          'sale_id': saleId,
          'product_id': cloudProductId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
        });
      }
      return (null, saleId);
    } catch (e, st) {
      debugPrint('CloudSyncService.writeSaleToCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
    }
  }

  /// Marca la venta como cancelada en Supabase (borrado lógico). No borra sale_items.
  static Future<String?> softCancelSaleInCloud(int cloudSaleId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      await client.from('sales').update({'cancelled_at': DateTime.now().toUtc().toIso8601String()}).eq('id', cloudSaleId);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.softCancelSaleInCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Envía el turno a la nube (al iniciar turno). Upsert por id para alinear con local.
  static Future<String?> writeShiftToCloud(Shift shift) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      await client.from('shifts').upsert({
        'id': shift.id,
        'start_time': shift.startTime.toUtc().toIso8601String(),
        'end_time': shift.endTime?.toUtc().toIso8601String(),
        'starting_fund': shift.startingFund,
      }, onConflict: 'id');
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.writeShiftToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Envía el cierre de caja a la nube (al cerrar turno). Actualiza shift con end_time e inserta shift_closures.
  static Future<String?> writeShiftClosureToCloud(Shift shiftWithEndTime, ShiftClosure closure) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      await client.from('shifts').upsert({
        'id': shiftWithEndTime.id,
        'start_time': shiftWithEndTime.startTime.toUtc().toIso8601String(),
        'end_time': shiftWithEndTime.endTime?.toUtc().toIso8601String(),
        'starting_fund': shiftWithEndTime.startingFund,
      }, onConflict: 'id');
      await client.from('shift_closures').insert({
        'shift_id': closure.shiftId,
        'closing_time': closure.closingTime.toUtc().toIso8601String(),
        'system_expected_cash': closure.systemExpectedCash,
        'declared_cash': closure.declaredCash,
        'difference': closure.difference,
        'notes': closure.notes,
      });
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.writeShiftClosureToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static List<dynamic> _list(dynamic v) {
    if (v == null) return [];
    return v is List ? v : [];
  }

  static Map<String, dynamic> _map(dynamic r) {
    return r is Map<String, dynamic> ? r : Map<String, dynamic>.from(r as Map<dynamic, dynamic>);
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _double(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    return v == 1 || v == 'true';
  }

  /// Pushes local master data to Supabase (use once to make cloud the source of truth).
  /// Overwrites cloud tables: categories, supplies, products, recipes, modifiers, bundles.
  static Future<String?> pushToCloud(AppDatabase db) async {
    if (!SupabaseService.isInitialized) return 'Supabase no configurado';
    try {
      final client = SupabaseService.instance.client;

      final categories = await (db.select(db.categories)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
      if (categories.isEmpty) return 'No hay categorías locales';

      // Truncate in FK order: dependents first (modifier_options, product_modifiers), then modifier_groups, then rest. Do not truncate products/supplies/categories (sale_items reference products).
      await _truncateCloud(client, ['bundle_items', 'bundles', 'modifier_options', 'product_modifiers', 'modifier_groups', 'recipes']);

      // Upsert categories, supplies, products (update prices/names in place; no delete so sale_items FK is not violated)
      final categoryRows = categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'parent_id': c.parentId,
        'color': c.color,
      }).toList();
      if (categoryRows.isNotEmpty) {
        await client.from('categories').upsert(categoryRows, onConflict: 'id');
      }

      final supplies = await (db.select(db.supplies)..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
      final supplyRows = supplies.map((s) => {
        'id': s.id,
        'name': s.name,
        'unit': s.unit,
        'current_stock': s.currentStock,
        'cost_per_unit': s.costPerUnit,
        'reorder_point': s.reorderPoint,
        'category': s.category,
      }).toList();
      if (supplyRows.isNotEmpty) {
        await client.from('supplies').upsert(supplyRows, onConflict: 'id');
      }

      final products = await (db.select(db.products)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
      final productRows = products.map((p) => {
        'id': p.id,
        'name': p.name,
        'price': p.price,
        'image_url': p.imageUrl,
        'is_active': p.isActive,
        'category_id': p.categoryId,
      }).toList();
      if (productRows.isNotEmpty) {
        await client.from('products').upsert(productRows, onConflict: 'id');
      }

      final recipes = await db.select(db.recipes).get();
      for (final r in recipes) {
        await client.from('recipes').insert({
          'product_id': r.productId,
          'supply_id': r.supplyId,
          'quantity_required': r.quantityRequired,
        });
      }

      // Insert modifier_groups with explicit id (replaced by truncate above)
      final groups = await (db.select(db.modifierGroups)..orderBy([(g) => OrderingTerm.asc(g.id)])).get();
      if (groups.isNotEmpty) {
        final mgRows = groups.map((g) => {
          'id': g.id,
          'name': g.name,
          'min_selection': g.minSelection,
          'max_selection': g.maxSelection,
        }).toList();
        await client.from('modifier_groups').insert(mgRows);
      }

      // Insert product_modifiers and modifier_options in batch so sync is consistent
      final pms = await db.select(db.productModifiers).get();
      if (pms.isNotEmpty) {
        final pmRows = pms.map((pm) => {
          'product_id': pm.productId,
          'modifier_group_id': pm.modifierGroupId,
        }).toList();
        await client.from('product_modifiers').insert(pmRows);
      }

      final opts = await db.select(db.modifierOptions).get();
      if (opts.isNotEmpty) {
        final moRows = opts.map((o) => {
          'modifier_group_id': o.modifierGroupId,
          'supply_id': o.supplyId,
          'quantity_deducted': o.quantityDeducted,
          'price_extra': o.priceExtra,
        }).toList();
        await client.from('modifier_options').insert(moRows);
      }

      final bundles = await (db.select(db.bundles)..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
      for (final b in bundles) {
        await client.from('bundles').insert({
          'id': b.id,
          'name': b.name,
          'price': b.price,
          'is_active': b.isActive,
          'category_id': b.categoryId,
        });
      }
      final bis = await db.select(db.bundleItems).get();
      for (final bi in bis) {
        await client.from('bundle_items').insert({
          'bundle_id': bi.bundleId,
          'product_id': bi.productId,
          'quantity': bi.quantityRequired,
        });
      }

      await client.rpc('sync_sequences');
      // IDs are aligned: local id = cloud id. Save identity maps.
      final productMap = {for (final p in products) p.id: p.id};
      final supplyMap = {for (final s in supplies) s.id: s.id};
      await _saveIdMaps(productMap, supplyMap);

      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.pushToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static Future<void> _truncateCloud(dynamic client, List<String> tables) async {
    for (final t in tables) {
      await client.from(t).delete().gte('id', 0);
    }
  }

  static Future<void> _saveIdMaps(Map<int, int> localToCloudProduct, Map<int, int> supplyMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCloudProductIdMap, jsonEncode(localToCloudProduct.map((k, v) => MapEntry(k.toString(), v))));
      await prefs.setString(_kCloudSupplyIdMap, jsonEncode(supplyMap.map((k, v) => MapEntry(k.toString(), v))));
    } catch (_) {}
  }

  static Future<(Map<int, int>, Map<int, int>)> _loadIdMaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productJson = prefs.getString(_kCloudProductIdMap);
      final supplyJson = prefs.getString(_kCloudSupplyIdMap);
      final productMap = <int, int>{};
      final supplyMap = <int, int>{};
      if (productJson != null) {
        final decoded = jsonDecode(productJson) as Map<String, dynamic>?;
        if (decoded != null) {
          for (final e in decoded.entries) {
            final k = int.tryParse(e.key);
            final v = e.value is int ? e.value as int : (e.value is num ? (e.value as num).toInt() : null);
            if (k != null && v != null) productMap[k] = v;
          }
        }
      }
      if (supplyJson != null) {
        final decoded = jsonDecode(supplyJson) as Map<String, dynamic>?;
        if (decoded != null) {
          for (final e in decoded.entries) {
            final k = int.tryParse(e.key);
            final v = e.value is int ? e.value as int : (e.value is num ? (e.value as num).toInt() : null);
            if (k != null && v != null) supplyMap[k] = v;
          }
        }
      }
      return (productMap, supplyMap);
    } catch (_) {
      return (<int, int>{}, <int, int>{});
    }
  }
}
