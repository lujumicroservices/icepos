import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
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

  static const int _syncMaxAttempts = 3;
  static const Duration _syncRetryDelay = Duration(seconds: 2);

  /// Solo una sincronización a la vez. Si [syncFromCloud] se llama en paralelo (Realtime + Insumos + refresh),
  /// todas esperan el mismo [Future]; sin esto dos corridas intercalan DELETE/INSERT y rompen UNIQUE (p. ej. bundles.id).
  static Future<String?>? _syncFromCloudMutex;

  static bool _isRetryableNetworkError(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('No address associated') ||
        s.contains('connection abort') ||
        s.contains('Connection refused') ||
        s.contains('TimeoutException') ||
        s.contains('ClientException');
  }

  /// Replaces local master data with Supabase data. Does not sync sales (those are write-through).
  /// Fetches all data from cloud first; only clears local DB after a successful fetch so a failed
  /// sync (network, RLS, etc.) never wipes local data. Retries up to [_syncMaxAttempts] on network errors.
  ///
  /// Llamadas concurrentes comparten una sola ejecución (mutex) para evitar condiciones de carrera en SQLite.
  static Future<String?> syncFromCloud(AppDatabase? db) {
    if (db == null) return Future.value(null);
    final pending = _syncFromCloudMutex;
    if (pending != null) return pending;

    final future = _syncFromCloudImpl(db);
    _syncFromCloudMutex = future;
    future.whenComplete(() {
      if (identical(_syncFromCloudMutex, future)) {
        _syncFromCloudMutex = null;
      }
    });
    return future;
  }

  static Future<String?> _syncFromCloudImpl(AppDatabase db) async {
    if (!SupabaseService.isInitialized) return null;
    final client = SupabaseService.instance.client;

    // 1. Fetch everything from cloud first (no local writes). Retry on network errors.
    List<Map<String, dynamic>> catRows = [];
    List<Map<String, dynamic>> supRows = [];
    List<Map<String, dynamic>> prodRows = [];
    List<Map<String, dynamic>> recRows = [];
    List<Map<String, dynamic>> mgRows = [];
    List<Map<String, dynamic>> pmRows = [];
    List<Map<String, dynamic>> moRows = [];
    List<Map<String, dynamic>> bundleRows = [];
    List<Map<String, dynamic>> biRows = [];

    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= _syncMaxAttempts; attempt++) {
      try {
        final catRaw = await client.from('categories').select('*').order('id');
        catRows = _list(catRaw).map((r) => _map(r)).toList();
        if (catRows.isEmpty) {
          lastSyncError = 'La nube no tiene categorías. En el primer dispositivo usa Cargar menú desde JSON en el menú (≡); los datos se enviarán a la nube al guardar.';
          return lastSyncError;
        }
        final rest = await Future.wait([
          client.from('supplies').select('*').order('id'),
          client.from('products').select('*').order('id'),
          client.from('recipes').select('*').order('id'),
          client.from('modifier_groups').select('*').order('id'),
          client.from('product_modifiers').select('*'),
          client.from('modifier_options').select('*'),
          client.from('bundles').select('*').order('id'),
          client.from('bundle_items').select('*'),
        ]);
        supRows = _list(rest[0]).map((r) => _map(r)).toList();
        prodRows = _list(rest[1]).map((r) => _map(r)).toList();
        recRows = _list(rest[2]).map((r) => _map(r)).toList();
        mgRows = _list(rest[3]).map((r) => _map(r)).toList();
        pmRows = _list(rest[4]).map((r) => _map(r)).toList();
        moRows = _list(rest[5]).map((r) => _map(r)).toList();
        bundleRows = _list(rest[6]).map((r) => _map(r)).toList();
        biRows = _list(rest[7]).map((r) => _map(r)).toList();
        lastError = null;
        break;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        debugPrint('CloudSyncService.syncFromCloud fetch failed (intento $attempt/$_syncMaxAttempts): $e');
        if (_isRetryableNetworkError(e) && attempt < _syncMaxAttempts) {
          debugPrint('CloudSyncService.syncFromCloud: reintento en ${_syncRetryDelay.inSeconds}s...');
          await Future<void>.delayed(_syncRetryDelay);
        } else {
          debugPrint('$st');
          lastSyncError = e.toString();
          return lastSyncError;
        }
      }
    }
    if (lastError != null) {
      if (lastStack != null) debugPrint('$lastStack');
      lastSyncError = lastError.toString();
      return lastSyncError;
    }
    if (catRows.isEmpty) {
      lastSyncError = 'No se pudo cargar datos de la nube.';
      return lastSyncError;
    }

    // PostgREST puede devolver filas duplicadas por id → UNIQUE al insertar (ej. modifier_groups.id).
    catRows = _dedupeByIdKey(catRows, 'id');
    supRows = _dedupeByIdKey(supRows, 'id');
    prodRows = _dedupeByIdKey(prodRows, 'id');
    recRows = _dedupeRecipeRows(recRows);
    mgRows = _dedupeByIdKey(mgRows, 'id');
    pmRows = _dedupeProductModifierRows(pmRows);
    moRows = _dedupeModifierOptionRows(moRows);
    bundleRows = _dedupeByIdKey(bundleRows, 'id');
    biRows = _dedupeBundleItemRows(biRows);

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
          imageUrl: Value(row['image_url'] as String?),
        ));
      }
      for (final row in supRows) {
        final cloudId = _int(row['id'])!;
        final stockModeRaw = row['stock_count_mode'];
        final stockMode = stockModeRaw is String && stockModeRaw.isNotEmpty
            ? stockModeRaw
            : 'quantity';
        final qualRaw = row['qualitative_level'];
        final qualLevel = qualRaw is String && qualRaw.isNotEmpty ? qualRaw : null;
        await db.into(db.supplies).insert(SuppliesCompanion(
          id: Value(cloudId),
          name: Value(row['name'] as String),
          unit: Value(row['unit'] as String),
          currentStock: Value(_double(row['current_stock'])),
          costPerUnit: Value(_double(row['cost_per_unit'])),
          reorderPoint: Value(_double(row['reorder_point'])),
          category: Value(row['category'] as String?),
          stockCountMode: Value(stockMode),
          qualitativeLevel: Value(qualLevel),
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
        return ('Falta el mapa de productos con la nube. Comprueba la conexión; los datos se sincronizan automáticamente. Si este es el primer dispositivo, carga el menú desde JSON en el menú (≡).', null);
      }

      for (final cartItem in items) {
        final cloudProductId = productMap[cartItem.productId];
        if (cloudProductId == null) {
          return ('Producto (id ${cartItem.productId}) no está en la nube. Espera a que la sincronización automática actualice los datos o comprueba la conexión.', null);
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
            return ('Insumo (id ${mod.supplyId}) no está en la nube. Espera a que la sincronización automática actualice los datos.', null);
          }
          final res = await client.from('supplies').select('current_stock').eq('id', cloudSupplyId).maybeSingle();
          final cur = res == null ? 0.0 : _double(_map(res)['current_stock']);
          await client.from('supplies').update({'current_stock': cur - amount}).eq('id', cloudSupplyId);
          await client.from('inventory_logs').insert({'supply_id': cloudSupplyId, 'change_amount': -amount, 'reason': 'SALE'});
        }
      }

      final device = await DeviceIdService.getDeviceInfo();
      final storeId = await StoreScope.getActiveStoreId();
      Map<String, dynamic> saleRow = {
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'amount_tendered': amountTendered,
        'change_given': changeGiven,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
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
            'store_id': storeId,
          };
          try {
            saleRes = await client.from('sales').insert(saleRow).select('id').single();
          } catch (e2) {
            final m2 = e2.toString();
            if (m2.contains('store_id') || m2.contains('does not exist')) {
              saleRow.remove('store_id');
              saleRes = await client.from('sales').insert(saleRow).select('id').single();
            } else {
              rethrow;
            }
          }
        } else if (msg.contains('store_id') || msg.contains('does not exist')) {
          saleRow.remove('store_id');
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
          return ('Producto (id ${item.productId}) no está en la nube. Espera a que la sincronización automática actualice los datos o comprueba la conexión.', null);
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
      final device = await DeviceIdService.getDeviceInfo();
      final storeId = await StoreScope.getActiveStoreId();
      await client.from('shifts').upsert({
        'id': shift.id,
        'start_time': shift.startTime.toUtc().toIso8601String(),
        'end_time': shift.endTime?.toUtc().toIso8601String(),
        'starting_fund': shift.startingFund,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
      }, onConflict: 'id');
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.writeShiftToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Upsert en [pos_devices] (nombre, versión, plataforma). Devuelve mensaje de error o null.
  static Future<String?> registerPosDeviceInCloud() async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      final client = SupabaseService.instance.client;
      final device = await DeviceIdService.getDeviceInfo();
      final pkg = await PackageInfo.fromPlatform();
      final storeId = await StoreScope.getActiveStoreId();
      await client.from('pos_devices').upsert({
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': '${pkg.version}+${pkg.buildNumber}',
        'platform': _platformLabel(),
        'store_id': storeId,
      }, onConflict: 'device_id');
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.registerPosDeviceInCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Registra el terminal y reenvía el turno abierto local (si existe) para asociar device_id en la nube.
  static Future<String?> registerDeviceAndSyncOpenShift(AppDatabase? db) async {
    final err = await registerPosDeviceInCloud();
    if (err != null) return err;
    if (db != null) {
      final open = await (db.select(db.shifts)
            ..where((s) => s.endTime.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
            ..limit(1))
          .getSingleOrNull();
      if (open != null) {
        return await writeShiftToCloud(open);
      }
    }
    return null;
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static Future<List<CloudPosDeviceRecord>> fetchPosDevicesFromCloud() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client
          .from('pos_devices')
          .select()
          .order('last_seen_at', ascending: false);
      final out = <CloudPosDeviceRecord>[];
      for (final e in _list(res)) {
        final m = _map(e);
        final id = m['device_id'] as String? ?? '';
        if (id.isEmpty) continue;
        out.add(CloudPosDeviceRecord(
          deviceId: id,
          deviceName: m['device_name'] as String? ?? id,
          lastSeenAt: _parseTs(m['last_seen_at']) ?? DateTime.now(),
          appVersion: m['app_version'] as String?,
          platform: m['platform'] as String?,
          storeId: _int(m['store_id']) ?? kDefaultStoreId,
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchPosDevicesFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Turno abierto en nube para ese terminal (si existe).
  static Future<CloudShiftSummary?> fetchOpenShiftForDeviceCloud(
    String deviceId, {
    int? storeId,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      var q = SupabaseService.instance.client
          .from('shifts')
          .select()
          .eq('device_id', deviceId)
          .isFilter('end_time', null);
      if (storeId != null) {
        q = q.eq('store_id', storeId);
      }
      final row = await q.order('start_time', ascending: false).limit(1).maybeSingle();
      if (row == null) return null;
      final m = _map(row);
      final sid = _int(m['id']);
      if (sid == null) return null;
      return CloudShiftSummary(
        id: sid,
        startTime: _parseTs(m['start_time']) ?? DateTime.now(),
        endTime: null,
        startingFund: _double(m['starting_fund']),
        deviceId: m['device_id'] as String?,
        deviceName: m['device_name'] as String?,
        storeId: _int(m['store_id']) ?? kDefaultStoreId,
      );
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchOpenShiftForDeviceCloud: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<List<CloudShiftSummary>> fetchShiftsForDeviceFromCloud(
    String deviceId, {
    int? storeId,
    int limit = 40,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      var q = SupabaseService.instance.client
          .from('shifts')
          .select('*, shift_closures(*)')
          .eq('device_id', deviceId);
      if (storeId != null) {
        q = q.eq('store_id', storeId);
      }
      final res = await q.order('start_time', ascending: false).limit(limit);
      final out = <CloudShiftSummary>[];
      for (final e in _list(res)) {
        final m = _map(e);
        final sid = _int(m['id']);
        if (sid == null) continue;
        final closuresRaw = m['shift_closures'];
        final closures = <CloudShiftClosureBrief>[];
        if (closuresRaw is List) {
          for (final c in closuresRaw) {
            if (c is! Map) continue;
            final cm = _map(c);
            closures.add(CloudShiftClosureBrief(
              closingTime: _parseTs(cm['closing_time']) ?? DateTime.now(),
              systemExpectedCash: _double(cm['system_expected_cash']),
              declaredCash: _double(cm['declared_cash']),
              difference: _double(cm['difference']),
              notes: cm['notes'] as String?,
              closureKind: cm['closure_kind'] as String? ?? 'device',
            ));
          }
        } else if (closuresRaw is Map) {
          final cm = _map(closuresRaw);
          closures.add(CloudShiftClosureBrief(
            closingTime: _parseTs(cm['closing_time']) ?? DateTime.now(),
            systemExpectedCash: _double(cm['system_expected_cash']),
            declaredCash: _double(cm['declared_cash']),
            difference: _double(cm['difference']),
            notes: cm['notes'] as String?,
            closureKind: cm['closure_kind'] as String? ?? 'device',
          ));
        }
        out.add(CloudShiftSummary(
          id: sid,
          startTime: _parseTs(m['start_time']) ?? DateTime.now(),
          endTime: _parseTs(m['end_time']),
          startingFund: _double(m['starting_fund']),
          deviceId: m['device_id'] as String?,
          deviceName: m['device_name'] as String?,
          storeId: _int(m['store_id']) ?? kDefaultStoreId,
          closures: closures,
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchShiftsForDeviceFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  static Future<List<CloudSaleBrief>> fetchSalesForDeviceFromCloud(
    String deviceId, {
    int? storeId,
    int limit = 100,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      var q = SupabaseService.instance.client
          .from('sales')
          .select('id, date, total_amount, payment_method')
          .eq('device_id', deviceId)
          .isFilter('cancelled_at', null);
      if (storeId != null) {
        q = q.eq('store_id', storeId);
      }
      final res = await q.order('date', ascending: false).limit(limit);
      final out = <CloudSaleBrief>[];
      for (final e in _list(res)) {
        final m = _map(e);
        final id = _int(m['id']);
        if (id == null) continue;
        out.add(CloudSaleBrief(
          id: id,
          date: _parseTs(m['date']) ?? DateTime.now(),
          totalAmount: _double(m['total_amount']),
          paymentMethod: m['payment_method'] as String? ?? 'CASH',
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchSalesForDeviceFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Cierra el turno solo en Supabase (corte remoto). Requiere [shifts.device_id] para sumar ventas.
  static Future<String?> adminRemoteCloseShiftInCloud({
    required int shiftId,
    required double declaredCash,
    String? notes,
  }) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      final shiftRow = await client.from('shifts').select().eq('id', shiftId).maybeSingle();
      if (shiftRow == null) return 'Turno no encontrado';
      final sm = _map(shiftRow);
      if (sm['end_time'] != null) return 'El turno ya está cerrado';
      final deviceId = sm['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        return 'El turno no tiene dispositivo en la nube. En la caja use el botón Registrar en la nube con el turno abierto.';
      }
      final start = _parseTs(sm['start_time']) ?? DateTime.now();
      final startStr = start.toUtc().toIso8601String();
      final end = DateTime.now();
      final endStr = end.toUtc().toIso8601String();
      final shiftStoreId = _int(sm['store_id']) ?? kDefaultStoreId;
      final salesRes = await client
          .from('sales')
          .select('total_amount, payment_method')
          .gte('date', startStr)
          .lte('date', endStr)
          .eq('device_id', deviceId)
          .eq('store_id', shiftStoreId)
          .isFilter('cancelled_at', null);
      var cashSales = 0.0;
      for (final row in _list(salesRes)) {
        final r = _map(row);
        if ((r['payment_method'] as String?) == 'CASH') {
          cashSales += _double(r['total_amount']);
        }
      }
      final movRes =
          await client.from('movements').select('type, amount').eq('shift_id', shiftId).eq('account', 'CAJA');
      var movNet = 0.0;
      for (final row in _list(movRes)) {
        final r = _map(row);
        final t = r['type'] as String? ?? '';
        final amt = _double(r['amount']);
        if (t == 'ENTRADA') movNet += amt;
        if (t == 'SALIDA') movNet -= amt;
      }
      final startingFund = _double(sm['starting_fund']);
      final systemExpected = startingFund + cashSales + movNet;
      final difference = declaredCash - systemExpected;
      final adminDev = await DeviceIdService.getDeviceInfo();
      await client.from('shifts').update({'end_time': endStr}).eq('id', shiftId);
      await client.from('shift_closures').insert({
        'shift_id': shiftId,
        'closing_time': endStr,
        'system_expected_cash': systemExpected,
        'declared_cash': declaredCash,
        'difference': difference,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'closure_kind': 'admin_remote',
        'closed_by_device_id': adminDev.deviceId,
      });
      await logShiftCloseDiagnostic(
        event: 'shift_close_admin_remote',
        shiftId: shiftId,
        context: {
          'declaredCash': declaredCash,
          'systemExpectedCash': systemExpected,
          'targetDeviceId': deviceId,
          'adminDeviceId': adminDev.deviceId,
          'storeId': shiftStoreId,
        },
      );
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.adminRemoteCloseShiftInCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Descarga movimientos del turno desde la nube y los inserta en local si no existen (para incluir movimientos de otros dispositivos antes de cerrar turno).
  static Future<String?> pullMovementsForShift(AppDatabase db, int shiftId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final res = await client
          .from('movements')
          .select('id, date, type, account, amount, reason, shift_id')
          .eq('shift_id', shiftId)
          .order('id');
      final rows = _list(res).map((r) => _map(r)).toList();
      var insertedLocally = 0;
      for (final row in rows) {
        final cloudId = _int(row['id'])!;
        final existing = await (db.select(db.movements)..where((m) => m.id.equals(cloudId))).getSingleOrNull();
        if (existing != null) continue;
        final dateStr = row['date'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        await db.into(db.movements).insert(MovementsCompanion.insert(
              type: row['type'] as String,
              account: row['account'] as String,
              amount: _double(row['amount']),
              reason: row['reason'] as String,
              id: Value(cloudId),
              date: Value(date ?? DateTime.now()),
              shiftId: Value(_int(row['shift_id'])),
            ));
        insertedLocally++;
      }
      await logShiftCloseDiagnostic(
        event: 'pull_movements_for_shift',
        shiftId: shiftId,
        context: {
          'ok': true,
          'cloudRowCount': rows.length,
          'insertedLocally': insertedLocally,
        },
      );
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.pullMovementsForShift: $e');
      debugPrint('$st');
      await logShiftCloseDiagnostic(
        event: 'pull_movements_for_shift',
        shiftId: shiftId,
        context: {'ok': false, 'error': e.toString()},
      );
      return e.toString();
    }
  }

  /// Registro en Supabase para ver en web qué hizo cada dispositivo alrededor del cierre de caja. No lanza.
  static Future<void> logShiftCloseDiagnostic({
    required String event,
    int? shiftId,
    Map<String, Object?>? context,
  }) async {
    if (!SupabaseService.isInitialized) return;
    try {
      final device = await DeviceIdService.getDeviceInfo();
      final storeId = await StoreScope.getActiveStoreId();
      final payload = <String, dynamic>{
        'event': event,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
        if (shiftId != null) 'shift_id': shiftId,
        if (context != null && context.isNotEmpty) 'context': context,
      };
      await SupabaseService.instance.client.from('shift_close_events').insert(payload);
    } catch (e, st) {
      debugPrint('CloudSyncService.logShiftCloseDiagnostic: $e');
      debugPrint('$st');
    }
  }

  /// Envía un movimiento a la nube (para que otros dispositivos lo vean al hacer pull antes de cerrar turno).
  static Future<String?> writeMovementToCloud(Movement movement) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final storeId = await StoreScope.getActiveStoreId();
      await client.from('movements').upsert({
        'id': movement.id,
        'date': movement.date.toUtc().toIso8601String(),
        'type': movement.type,
        'account': movement.account,
        'amount': movement.amount,
        'reason': movement.reason,
        'shift_id': movement.shiftId,
        'store_id': storeId,
      }, onConflict: 'id');
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.writeMovementToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Movimientos desde Supabase (p. ej. web sin Drift).
  static Future<List<Movement>> fetchMovementsFromCloud({String? account, int limit = 200}) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      var query = client.from('movements').select();
      if (account != null) {
        query = query.eq('account', account);
      }
      final res = await query.order('date', ascending: false).limit(limit);
      final list = _list(res);
      return list.map((e) {
        final m = _map(e);
        final id = _int(m['id']) ?? 0;
        final date = DateTime.tryParse(m['date'].toString()) ?? DateTime.now();
        final shiftRaw = m['shift_id'];
        return Movement(
          id: id,
          date: date,
          type: m['type'] as String? ?? '',
          account: m['account'] as String? ?? '',
          amount: _double(m['amount']),
          reason: m['reason'] as String? ?? '',
          shiftId: shiftRaw == null ? null : _int(shiftRaw),
        );
      }).toList();
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchMovementsFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Inserta un movimiento solo en Supabase (sin fila local).
  static Future<String?> insertMovementToCloud({
    required String type,
    required String account,
    required double amount,
    required String reason,
    int? shiftId,
  }) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      final storeId = await StoreScope.getActiveStoreId();
      final payload = <String, dynamic>{
        'date': DateTime.now().toUtc().toIso8601String(),
        'type': type,
        'account': account,
        'amount': amount,
        'reason': reason,
        'store_id': storeId,
      };
      if (shiftId != null) {
        payload['shift_id'] = shiftId;
      }
      await client.from('movements').insert(payload);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.insertMovementToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Conciliación física directamente en Supabase (sin SQLite local).
  static Future<String?> reconcileSupplyInCloudOnly({
    required int supplyId,
    double? newQuantity,
    String? qualitativeLevel,
    String? newUnit,
    required bool useQualitativeEntry,
  }) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      final row = await client.from('supplies').select().eq('id', supplyId).maybeSingle();
      if (row == null) {
        throw StateError('Supply id=$supplyId not found');
      }
      final m = _map(row);
      final name = m['name'] as String? ?? '';
      final currentStock = _double(m['current_stock']);
      final costPerUnit = _double(m['cost_per_unit']);
      final reorderPoint = _double(m['reorder_point']);
      var unit = (m['unit'] as String?) ?? 'pcs';
      final category = m['category'] as String?;
      var stockMode = (m['stock_count_mode'] as String?) ?? StockCountMode.quantity;
      String? qual = m['qualitative_level'] as String?;

      final trimmedUnit = newUnit?.trim();
      final unitToSet = (trimmedUnit != null && trimmedUnit.isNotEmpty)
          ? (trimmedUnit.length > 10 ? trimmedUnit.substring(0, 10) : trimmedUnit)
          : null;
      if (unitToSet != null) {
        unit = unitToSet;
      }

      late final double newStock;
      late final double delta;

      if (useQualitativeEntry) {
        final level = qualitativeLevel?.trim();
        if (level == null || !QualitativeLevel.isValid(level)) {
          throw ArgumentError('Nivel cualitativo inválido');
        }
        newStock = stockFromQualitativeLevel(level);
        qual = level;
        stockMode = StockCountMode.qualitative;
        delta = newStock - currentStock;
      } else {
        final qty = newQuantity;
        if (qty == null || qty < 0) {
          throw ArgumentError('Cantidad inválida');
        }
        newStock = qty;
        qual = null;
        stockMode = StockCountMode.quantity;
        delta = qty - currentStock;
      }

      final err = await upsertSupplyToCloud(
        id: supplyId,
        name: name,
        unit: unit,
        currentStock: newStock,
        costPerUnit: costPerUnit,
        reorderPoint: reorderPoint,
        category: category,
        stockCountMode: stockMode,
        qualitativeLevel: qual,
      );
      if (err != null) return err;

      if (delta != 0) {
        await client.from('inventory_logs').insert({
          'supply_id': supplyId,
          'change_amount': delta,
          'reason': 'RECONCILIATION',
        });
      }
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.reconcileSupplyInCloudOnly: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static Future<List<({Bundle bundle, List<BundleItem> bundleItems})>> fetchBundlesWithItemsFromCloud() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final bundlesRes = await client.from('bundles').select('*').order('id');
      final itemsRes = await client.from('bundle_items').select('*');
      final bList = _list(bundlesRes);
      final iList = _list(itemsRes);
      final itemsByBundle = <int, List<BundleItem>>{};
      for (final e in iList) {
        final m = _map(e);
        final bi = BundleItem(
          id: _int(m['id']) ?? 0,
          bundleId: _int(m['bundle_id']) ?? 0,
          productId: _int(m['product_id']) ?? 0,
          quantityRequired: _double(m['quantity']),
        );
        itemsByBundle.putIfAbsent(bi.bundleId, () => []).add(bi);
      }
      final out = <({Bundle bundle, List<BundleItem> bundleItems})>[];
      for (final e in bList) {
        final m = _map(e);
        final id = _int(m['id']) ?? 0;
        final bundle = Bundle(
          id: id,
          name: m['name'] as String? ?? '',
          price: _double(m['price']),
          isActive: _bool(m['is_active']),
          categoryId: _int(m['category_id']),
        );
        out.add((bundle: bundle, bundleItems: itemsByBundle[id] ?? const []));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchBundlesWithItemsFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Guarda bundle + ítems solo en Supabase (sin SQLite local).
  static Future<({int bundleId, String? error})> saveBundleToCloudOnly({
    int? id,
    required String name,
    required double price,
    int? categoryId,
    required List<({int productId, double quantity})> productItems,
  }) async {
    if (!SupabaseService.isInitialized) {
      return (bundleId: -1, error: 'Supabase no inicializado');
    }
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final client = SupabaseService.instance.client;
      if (id == null) {
        final row = await client.from('bundles').insert({
          'name': name,
          'price': price,
          'is_active': true,
          'category_id': categoryId,
        }).select('id').single();
        final bundleId = _int(row['id']) ?? 0;
        if (bundleId == 0) {
          return (bundleId: 0, error: 'No se obtuvo id del bundle');
        }
        for (final item in productItems) {
          await client.from('bundle_items').insert({
            'bundle_id': bundleId,
            'product_id': item.productId,
            'quantity': item.quantity,
          });
        }
        return (bundleId: bundleId, error: null);
      }
      final err = await upsertBundleToCloud(
        id: id,
        name: name,
        price: price,
        categoryId: categoryId,
      );
      if (err != null) return (bundleId: id, error: err);
      final delErr = await deleteBundleItemsFromCloud(id);
      if (delErr != null) return (bundleId: id, error: delErr);
      for (final item in productItems) {
        final e2 = await insertBundleItemToCloud(
          bundleId: id,
          productId: item.productId,
          quantity: item.quantity,
        );
        if (e2 != null) return (bundleId: id, error: e2);
      }
      return (bundleId: id, error: null);
    } catch (e, st) {
      debugPrint('CloudSyncService.saveBundleToCloudOnly: $e');
      debugPrint('$st');
      return (bundleId: id ?? -1, error: e.toString());
    }
  }

  /// Envía el cierre de caja a la nube (al cerrar turno). Actualiza shift con end_time e inserta shift_closures.
  static Future<String?> writeShiftClosureToCloud(Shift shiftWithEndTime, ShiftClosure closure) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final device = await DeviceIdService.getDeviceInfo();
      final storeId = await StoreScope.getActiveStoreId();
      await client.from('shifts').upsert({
        'id': shiftWithEndTime.id,
        'start_time': shiftWithEndTime.startTime.toUtc().toIso8601String(),
        'end_time': shiftWithEndTime.endTime?.toUtc().toIso8601String(),
        'starting_fund': shiftWithEndTime.startingFund,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
      }, onConflict: 'id');
      await client.from('shift_closures').insert({
        'shift_id': closure.shiftId,
        'closing_time': closure.closingTime.toUtc().toIso8601String(),
        'system_expected_cash': closure.systemExpectedCash,
        'declared_cash': closure.declaredCash,
        'difference': closure.difference,
        'notes': closure.notes,
        'closure_kind': 'device',
        'closed_by_device_id': device.deviceId,
      });
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.writeShiftClosureToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Una fila por id (la última gana). Evita SqliteException UNIQUE al sincronizar.
  static List<Map<String, dynamic>> _dedupeByIdKey(
    List<Map<String, dynamic>> rows,
    String idKey,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = _int(row[idKey]);
      if (id == null) continue;
      byId[id] = row;
    }
    final keys = byId.keys.toList()..sort();
    return [for (final k in keys) byId[k]!];
  }

  static List<Map<String, dynamic>> _dedupeRecipeRows(List<Map<String, dynamic>> rows) {
    final key = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final pid = _int(row['product_id']);
      final sid = _int(row['supply_id']);
      if (pid == null || sid == null) continue;
      key['$pid:$sid'] = row;
    }
    return key.values.toList();
  }

  static List<Map<String, dynamic>> _dedupeProductModifierRows(
    List<Map<String, dynamic>> rows,
  ) {
    final key = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final pid = _int(row['product_id']);
      final mgid = _int(row['modifier_group_id']);
      if (pid == null || mgid == null) continue;
      key['$pid:$mgid'] = row;
    }
    return key.values.toList();
  }

  static List<Map<String, dynamic>> _dedupeModifierOptionRows(
    List<Map<String, dynamic>> rows,
  ) {
    final key = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final mg = _int(row['modifier_group_id']);
      final sid = _int(row['supply_id']);
      if (mg == null || sid == null) continue;
      key['$mg:$sid'] = row;
    }
    return key.values.toList();
  }

  static List<Map<String, dynamic>> _dedupeBundleItemRows(
    List<Map<String, dynamic>> rows,
  ) {
    final key = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final bid = _int(row['bundle_id']);
      final pid = _int(row['product_id']);
      if (bid == null || pid == null) continue;
      key['$bid:$pid'] = row;
    }
    return key.values.toList();
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

  // ----- Write-through: sync single entities to cloud so other devices get changes via Realtime -----

  static Future<String?> upsertCategoryToCloud({
    required int id,
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('categories').upsert({
        'id': id,
        'name': name,
        'parent_id': parentId,
        'color': color,
        'image_url': imageUrl,
      }, onConflict: 'id');
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.upsertCategoryToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteCategoryFromCloud(int id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('categories').delete().match({'id': id});
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteCategoryFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> upsertProductToCloud({
    required int id,
    required String name,
    required double price,
    int? categoryId,
    bool isActive = true,
    String? imageUrl,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('products').upsert({
        'id': id,
        'name': name,
        'price': price,
        'category_id': categoryId,
        'is_active': isActive,
        'image_url': imageUrl,
      }, onConflict: 'id');
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.upsertProductToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteProductFromCloud(int id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('products').delete().match({'id': id});
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteProductFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> upsertSupplyToCloud({
    required int id,
    required String name,
    required String unit,
    required double currentStock,
    double costPerUnit = 0,
    double reorderPoint = 0,
    String? category,
    String stockCountMode = 'quantity',
    String? qualitativeLevel,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('supplies').upsert({
        'id': id,
        'name': name,
        'unit': unit,
        'current_stock': currentStock,
        'cost_per_unit': costPerUnit,
        'reorder_point': reorderPoint,
        'category': category,
        'stock_count_mode': stockCountMode,
        'qualitative_level': qualitativeLevel,
      }, onConflict: 'id');
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.upsertSupplyToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteSupplyFromCloud(int id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('supplies').delete().match({'id': id});
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteSupplyFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> upsertBundleToCloud({
    required int id,
    required String name,
    required double price,
    bool isActive = true,
    int? categoryId,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('bundles').upsert({
        'id': id,
        'name': name,
        'price': price,
        'is_active': isActive,
        'category_id': categoryId,
      }, onConflict: 'id');
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.upsertBundleToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> insertBundleItemToCloud({
    required int bundleId,
    required int productId,
    required double quantity,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('bundle_items').insert({
        'bundle_id': bundleId,
        'product_id': productId,
        'quantity': quantity,
      });
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.insertBundleItemToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteBundleItemsFromCloud(int bundleId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('bundle_items').delete().eq('bundle_id', bundleId);
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteBundleItemsFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteBundleFromCloud(int id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('bundle_items').delete().eq('bundle_id', id);
      await SupabaseService.instance.client.from('bundles').delete().match({'id': id});
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteBundleFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteRecipesForProductFromCloud(int productId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('recipes').delete().eq('product_id', productId);
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteRecipesForProductFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> insertRecipeToCloud({
    required int productId,
    required int supplyId,
    required double quantityRequired,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('recipes').insert({
        'product_id': productId,
        'supply_id': supplyId,
        'quantity_required': quantityRequired,
      });
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.insertRecipeToCloud: $e');
      return e.toString();
    }
  }

  /// Deletes modifier_options, product_modifiers, and modifier_groups for groups that are linked to this product.
  static Future<String?> deleteModifiersForProductFromCloud(int productId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final pmRows = await client.from('product_modifiers').select('modifier_group_id').eq('product_id', productId);
      final groupIds = _list(pmRows).map((r) => _int(_map(r)['modifier_group_id'])).whereType<int>().toSet();
      for (final gid in groupIds) {
        await client.from('modifier_options').delete().eq('modifier_group_id', gid);
      }
      await client.from('product_modifiers').delete().eq('product_id', productId);
      for (final gid in groupIds) {
        await client.from('modifier_groups').delete().match({'id': gid});
      }
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteModifiersForProductFromCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> insertModifierGroupToCloud({
    required int id,
    required String name,
    int minSelection = 0,
    required int maxSelection,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('modifier_groups').insert({
        'id': id,
        'name': name,
        'min_selection': minSelection,
        'max_selection': maxSelection,
      });
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.insertModifierGroupToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> insertProductModifierToCloud({
    required int productId,
    required int modifierGroupId,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('product_modifiers').insert({
        'product_id': productId,
        'modifier_group_id': modifierGroupId,
      });
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.insertProductModifierToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> insertModifierOptionToCloud({
    required int modifierGroupId,
    required int supplyId,
    required double quantityDeducted,
    double priceExtra = 0,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('modifier_options').insert({
        'modifier_group_id': modifierGroupId,
        'supply_id': supplyId,
        'quantity_deducted': quantityDeducted,
        'price_extra': priceExtra,
      });
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.insertModifierOptionToCloud: $e');
      return e.toString();
    }
  }

  /// Write-through: sync product + its recipes + modifier groups/options from local DB to cloud.
  static Future<String?> syncProductToCloudFull(AppDatabase db, int productId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final product = await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingleOrNull();
      if (product == null) return null;
      var err = await upsertProductToCloud(
        id: product.id,
        name: product.name,
        price: product.price,
        categoryId: product.categoryId,
        isActive: product.isActive,
        imageUrl: product.imageUrl,
      );
      if (err != null) return err;

      err = await deleteRecipesForProductFromCloud(productId);
      if (err != null) return err;
      final recipes = await (db.select(db.recipes)..where((r) => r.productId.equals(productId))).get();
      for (final r in recipes) {
        err = await insertRecipeToCloud(productId: r.productId, supplyId: r.supplyId, quantityRequired: r.quantityRequired);
        if (err != null) return err;
      }

      err = await deleteModifiersForProductFromCloud(productId);
      if (err != null) return err;
      final pms = await (db.select(db.productModifiers)..where((pm) => pm.productId.equals(productId))).get();
      for (final pm in pms) {
        final group = await (db.select(db.modifierGroups)..where((g) => g.id.equals(pm.modifierGroupId))).getSingleOrNull();
        if (group == null) continue;
        err = await insertModifierGroupToCloud(id: group.id, name: group.name, minSelection: group.minSelection, maxSelection: group.maxSelection);
        if (err != null) return err;
        err = await insertProductModifierToCloud(productId: productId, modifierGroupId: group.id);
        if (err != null) return err;
        final opts = await (db.select(db.modifierOptions)..where((o) => o.modifierGroupId.equals(group.id))).get();
        for (final o in opts) {
          err = await insertModifierOptionToCloud(
            modifierGroupId: o.modifierGroupId,
            supplyId: o.supplyId,
            quantityDeducted: o.quantityDeducted,
            priceExtra: o.priceExtra,
          );
          if (err != null) return err;
        }
      }
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.syncProductToCloudFull: $e');
      return e.toString();
    }
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
        'image_url': c.imageUrl,
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
        'stock_count_mode': s.stockCountMode,
        'qualitative_level': s.qualitativeLevel,
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

/// Fila de [pos_devices] en Supabase.
class CloudPosDeviceRecord {
  const CloudPosDeviceRecord({
    required this.deviceId,
    required this.deviceName,
    required this.lastSeenAt,
    required this.storeId,
    this.appVersion,
    this.platform,
  });

  final String deviceId;
  final String deviceName;
  final DateTime lastSeenAt;
  /// [stores.id] en Supabase.
  final int storeId;
  final String? appVersion;
  final String? platform;
}

class CloudShiftClosureBrief {
  const CloudShiftClosureBrief({
    required this.closingTime,
    required this.systemExpectedCash,
    required this.declaredCash,
    required this.difference,
    this.notes,
    required this.closureKind,
  });

  final DateTime closingTime;
  final double systemExpectedCash;
  final double declaredCash;
  final double difference;
  final String? notes;
  final String closureKind;
}

class CloudShiftSummary {
  const CloudShiftSummary({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.startingFund,
    required this.storeId,
    this.deviceId,
    this.deviceName,
    this.closures = const [],
  });

  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingFund;
  final int storeId;
  final String? deviceId;
  final String? deviceName;
  final List<CloudShiftClosureBrief> closures;

  bool get isOpen => endTime == null;
}

class CloudSaleBrief {
  const CloudSaleBrief({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
  });

  final int id;
  final DateTime date;
  final double totalAmount;
  final String paymentMethod;
}
