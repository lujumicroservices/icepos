import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ice_pos/src/core/config/register_scope.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/shift/shift_linkage.dart';
import 'package:ice_pos/src/core/services/catalog_sync_progress.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/sync_coordinator.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart' show CartItem;

const _kShiftSelectWithRegister =
    'id, start_time, end_time, starting_fund, store_id, device_id, device_name, register_id, pos_registers ( label )';

const _kCloudProductIdMap = 'cloud_product_id_map';
const _kCloudSupplyIdMap = 'cloud_supply_id_map';
const _kStartupSyncErrorKey = 'startup_sync_error';
const _kLastCatalogSyncMsKey = 'last_successful_catalog_sync_ms';

/// When Supabase is the source of truth:
/// - syncFromCloud: replace local master data (categories, products, supplies, recipes, modifiers, bundles, discounts) from cloud.
/// - writeSaleToCloud: write sale + inventory to Supabase; call before local processSale.
class CloudSyncService {
  CloudSyncService._();

  static bool get isEnabled => SupabaseService.isInitialized;

  /// `public` tables loaded by [syncFromCloud]. Realtime should only trigger a
  /// catalog pull for these — not `sales`, `shifts`, `pending_cashier_approvals`, etc.
  static const Set<String> supabaseCatalogTableNames = {
    'categories',
    'supplies',
    'products',
    'recipes',
    'modifier_groups',
    'product_modifiers',
    'modifier_options',
    'bundles',
    'bundle_items',
    'discounts',
  };

  /// [Shift.id] en SQLite vs `shifts.id` en Supabase (columna local [Shift.cloudShiftId]).
  ///
  /// Siempre asigna [Shift.cloudShiftId] al abrir turno. El fallback a [Shift.id] es solo
  /// compatibilidad con filas legacy; no usar para enlazar movimientos entre dispositivos.
  static int supabaseShiftId(Shift s) => s.cloudShiftId ?? s.id;

  /// Cierra en SQLite turnos abiertos localmente que ya tienen [end_time] en Supabase.
  static Future<void> reconcileLocalOpenShiftsWithCloud(AppDatabase db) async {
    if (!SupabaseService.isInitialized || !ConnectivityService.instance.isConnected) return;
    try {
      final openRows = await (db.select(db.shifts)..where((s) => s.endTime.isNull())).get();
      if (openRows.isEmpty) return;
      final cloudIds = openRows.map(supabaseShiftId).toSet().toList();
      final client = SupabaseService.instance.client;
      final res = await client.from('shifts').select('id, end_time').inFilter('id', cloudIds);
      final endByCloudId = <int, DateTime>{};
      for (final e in _list(res)) {
        final m = _map(e);
        final cid = _int(m['id']);
        final end = _parseTs(m['end_time']);
        if (cid != null && end != null) {
          endByCloudId[cid] = end;
        }
      }
      for (final local in openRows) {
        final cid = supabaseShiftId(local);
        final end = endByCloudId[cid];
        if (end == null) continue;
        await (db.update(db.shifts)..where((s) => s.id.equals(local.id))).write(
          ShiftsCompanion(endTime: Value(end)),
        );
      }
    } catch (e, st) {
      debugPrint('CloudSyncService.reconcileLocalOpenShiftsWithCloud: $e');
      debugPrint('$st');
    }
  }

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
  static const Duration _syncOverallTimeout = Duration(seconds: 90);

  static bool _isRetryableNetworkError(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('HandshakeException') ||
        s.contains('Failed host lookup') ||
        s.contains('No address associated') ||
        s.contains('connection abort') ||
        s.contains('Connection aborted') ||
        s.contains('Connection reset') ||
        s.contains('Connection refused') ||
        s.contains('TimeoutException') ||
        s.contains('ClientException') ||
        s.contains('network is unreachable') ||
        s.contains(' 502') ||
        s.contains(' 503') ||
        s.contains(' 504');
  }

  /// Replaces local master data with Supabase data. Does not sync sales (those are write-through).
  /// Fetches all data from cloud first; only clears local DB after a successful fetch so a failed
  /// sync (network, RLS, etc.) never wipes local data. Retries up to [_syncMaxAttempts] on network errors.
  ///
  /// Concurrent calls serialize via [SyncCoordinator] (shared with outbox replay).
  /// [onProgress] reports UI-friendly stages (manual sync dialog).
  static Future<String?> syncFromCloud(
    AppDatabase? db, {
    void Function(CatalogSyncProgress progress)? onProgress,
  }) {
    if (db == null) return Future.value(null);
    return SyncCoordinator.synchronized(() async {
      try {
        return await _syncFromCloudImpl(db, onProgress: onProgress).timeout(
          _syncOverallTimeout,
          onTimeout: () {
            const msg = 'Tiempo de espera agotado al sincronizar desde la nube.';
            lastSyncError = msg;
            return msg;
          },
        );
      } catch (e, st) {
        debugPrint('CloudSyncService.syncFromCloud: $e');
        debugPrint('$st');
        lastSyncError = e.toString();
        return lastSyncError;
      }
    });
  }

  /// Cloud-first: pull catalog from Supabase into local Drift cache (alias of [syncFromCloud]).
  static Future<String?> applyCloudCatalogToLocalCache(AppDatabase? db) =>
      syncFromCloud(db);

  /// If the catalog cache is older than [maxAge], triggers a background [syncFromCloud].
  static Future<void> refreshCatalogCacheIfStale(
    AppDatabase db, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    if (!isEnabled || !ConnectivityService.instance.isConnected) return;
    final last = await getLastSuccessfulCatalogSyncTime();
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    unawaited(syncFromCloud(db));
  }

  /// When the local catalog cache last matched a successful cloud pull (persisted).
  static Future<DateTime?> getLastSuccessfulCatalogSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_kLastCatalogSyncMsKey);
      if (v == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setLastCatalogSyncNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCatalogSyncMsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<String?> _syncFromCloudImpl(
    AppDatabase db, {
    void Function(CatalogSyncProgress progress)? onProgress,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    final client = SupabaseService.instance.client;
    const totalSteps = 9;

    void report(int step, String stageKey, [String? detail]) {
      onProgress?.call(CatalogSyncProgress(
        step: step,
        totalSteps: totalSteps,
        stageKey: stageKey,
        detail: detail,
      ));
    }

    report(1, 'syncStepStarting');

    // 1. Fetch from cloud first (no local writes). Retry on network errors.
    List<Map<String, dynamic>> catRows = [];
    List<Map<String, dynamic>> supRows = [];
    List<Map<String, dynamic>> prodRows = [];
    List<Map<String, dynamic>> recRows = [];
    List<Map<String, dynamic>> mgRows = [];
    List<Map<String, dynamic>> pmRows = [];
    List<Map<String, dynamic>> moRows = [];
    List<Map<String, dynamic>> bundleRows = [];
    List<Map<String, dynamic>> biRows = [];
    List<Map<String, dynamic>> discRows = [];

    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= _syncMaxAttempts; attempt++) {
      try {
        report(
          2,
          'syncStepDownloadingCategories',
          attempt > 1 ? 'Reintento $attempt/$_syncMaxAttempts' : null,
        );
        final catRaw = await client.from('categories').select('*').order('id');
        catRows = _list(catRaw).map((r) => _map(r)).toList();
        if (catRows.isEmpty) {
          lastSyncError = 'La nube no tiene categorías. En el primer dispositivo usa Cargar menú desde JSON en el menú (≡); los datos se enviarán a la nube al guardar.';
          return lastSyncError;
        }

        report(3, 'syncStepDownloadingProducts');
        final productsBatch = await Future.wait([
          client.from('supplies').select('*').order('id'),
          client.from('products').select('*').order('id'),
        ]);
        supRows = _list(productsBatch[0]).map((r) => _map(r)).toList();
        prodRows = _list(productsBatch[1]).map((r) => _map(r)).toList();

        report(4, 'syncStepDownloadingRecipes');
        final recipesBatch = await Future.wait([
          client.from('recipes').select('*').order('id'),
          client.from('modifier_groups').select('*').order('id'),
          client.from('product_modifiers').select('*'),
          client.from('modifier_options').select('*'),
        ]);
        recRows = _list(recipesBatch[0]).map((r) => _map(r)).toList();
        mgRows = _list(recipesBatch[1]).map((r) => _map(r)).toList();
        pmRows = _list(recipesBatch[2]).map((r) => _map(r)).toList();
        moRows = _list(recipesBatch[3]).map((r) => _map(r)).toList();

        report(5, 'syncStepDownloadingBundles');
        final bundlesBatch = await Future.wait([
          client.from('bundles').select('*').order('id'),
          client.from('bundle_items').select('*'),
          client.from('discounts').select('*').order('id'),
        ]);
        bundleRows = _list(bundlesBatch[0]).map((r) => _map(r)).toList();
        biRows = _list(bundlesBatch[1]).map((r) => _map(r)).toList();
        discRows = _list(bundlesBatch[2]).map((r) => _map(r)).toList();

        lastError = null;
        break;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        debugPrint('CloudSyncService.syncFromCloud fetch failed (intento $attempt/$_syncMaxAttempts): $e');
        if (_isRetryableNetworkError(e) && attempt < _syncMaxAttempts) {
          debugPrint('CloudSyncService.syncFromCloud: reintento en ${_syncRetryDelay.inSeconds}s...');
          report(2, 'syncStepDownloadingCategories', 'Reintento $attempt/$_syncMaxAttempts…');
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
    discRows = _dedupeByIdKey(discRows, 'id');

    try {
      report(
        6,
        'syncStepSavingLocal',
        '${prodRows.length} productos · ${bundleRows.length} bundles',
      );
      // 2. Replace local master data atomically so readers don't see half-synced tables.
      await db.transaction(() async {
        // FK order: delete dependents first.
        await (db.delete(db.modifierOptions)).go();
        await (db.delete(db.productModifiers)).go();
        await (db.delete(db.modifierGroups)).go();
        await (db.delete(db.recipes)).go();
        await (db.delete(db.bundleItems)).go();
        await (db.delete(db.bundles)).go();
        await (db.delete(db.products)).go();
        await (db.delete(db.supplies)).go();
        await (db.delete(db.categories)).go();

        report(6, 'syncStepSavingCategories', '${catRows.length} categorías');
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
        report(7, 'syncStepSavingProducts', '${prodRows.length} productos · ${supRows.length} insumos');
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
            employeePrice: Value(_doubleOrNull(row['employee_price'])),
            imageUrl: Value(row['image_url'] as String?),
            isActive: Value(_bool(row['is_active'])),
            categoryId: Value(cloudCatId),
          ));
        }
        report(8, 'syncStepSavingRecipes', '${recRows.length} recetas · ${moRows.length} opciones');
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
            imageUrl: Value(row['image_url'] as String?),
          ));
        }
        report(8, 'syncStepSavingBundles', '${bundleRows.length} bundles · ${discRows.length} descuentos');
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
        if (discRows.isNotEmpty) {
          await (db.delete(db.discounts)).go();
          for (final row in discRows) {
            final cloudId = _int(row['id'])!;
            final rawDesc = row['description'];
            final desc = rawDesc is String ? rawDesc.trim() : '';
            final typeRaw = row['type'];
            final type = typeRaw is String && typeRaw.isNotEmpty
                ? typeRaw
                : 'percentage';
            await db.into(db.discounts).insert(DiscountsCompanion(
              id: Value(cloudId),
              code: Value(row['code'] as String),
              type: Value(type),
              percentage: Value(_double(row['percentage'])),
              description: Value(desc.isEmpty ? 'Discount' : desc),
              isActive: Value(_bool(row['is_active'])),
            ));
          }
        }
      });


      report(9, 'syncStepFinishing');
      final allProducts = await (db.select(db.products)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
      final allSupplies = await (db.select(db.supplies)..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
      final localToCloudProduct = {for (final p in allProducts) p.id: p.id};
      final localToCloudSupply = {for (final s in allSupplies) s.id: s.id};
      if (localToCloudProduct.isNotEmpty) {
        await _saveIdMaps(localToCloudProduct, localToCloudSupply);
      }
      lastSyncError = null;
      await _setLastCatalogSyncNow();
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
  ///
  /// Order: validate maps → insert [sales] → batch insert [sale_items] → cloud inventory.
  /// Previously inventory ran before sale_items; if line inserts failed, a header-only sale
  /// could remain in the cloud. Sale is deleted if sale_items insert fails.
  static Future<(String? error, int? cloudSaleId)> writeSaleToCloud(
    List<CartItem> items, {
    required double totalAmount,
    required String paymentMethod,
    double amountTendered = 0,
    double changeGiven = 0,
    String? paymentsJson,
    /// `shifts.id` en Supabase (opcional; agrega ventas al corte por turno).
    int? cloudShiftId,
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
        for (final mod in cartItem.selectedModifiers) {
          if (supplyMap[mod.supplyId] == null) {
            return ('Insumo (id ${mod.supplyId}) no está en la nube. Espera a que la sincronización automática actualice los datos.', null);
          }
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
        if (cloudShiftId != null) 'shift_id': cloudShiftId,
      };
      if (paymentsJson != null) {
        try {
          saleRow['payments_json'] = jsonDecode(paymentsJson);
        } catch (_) {}
      }
      dynamic saleRes;
      try {
        saleRes = await client.from('sales').insert(saleRow).select('id').single();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('shift_id')) {
          saleRow.remove('shift_id');
          try {
            saleRes = await client.from('sales').insert(saleRow).select('id').single();
          } catch (e2) {
            rethrow;
          }
        } else if (msg.contains('device_id') || msg.contains('device_name') || msg.contains('does not exist')) {
          saleRow = {
            'total_amount': totalAmount,
            'payment_method': paymentMethod,
            'amount_tendered': amountTendered,
            'change_given': changeGiven,
            'store_id': storeId,
            if (cloudShiftId != null && !msg.contains('shift_id')) 'shift_id': cloudShiftId,
          };
          try {
            saleRes = await client.from('sales').insert(saleRow).select('id').single();
          } catch (e2) {
            final m2 = e2.toString();
            if (m2.contains('shift_id')) {
              saleRow.remove('shift_id');
              saleRes = await client.from('sales').insert(saleRow).select('id').single();
            } else if (m2.contains('store_id') || m2.contains('does not exist')) {
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

      final itemRows = <Map<String, dynamic>>[];
      for (final item in items) {
        final cloudProductId = productMap[item.productId]!;
        itemRows.add({
          'sale_id': saleId,
          'product_id': cloudProductId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
        });
      }
      try {
        await client.from('sale_items').insert(itemRows);
      } catch (e) {
        try {
          await client.from('sales').delete().eq('id', saleId);
        } catch (_) {}
        rethrow;
      }
      // Guardrail: verify sale_items actually persisted for this sale.
      // If mismatch, fail hard so PosRepository logs a visible critical error.
      try {
        final rows = await client
            .from('sale_items')
            .select('id')
            .eq('sale_id', saleId);
        final insertedCount = _list(rows).length;
        if (insertedCount != itemRows.length) {
          try {
            await client.from('sales').delete().eq('id', saleId);
          } catch (_) {}
          return (
            'Venta nube inconsistente: sale_items esperados=${itemRows.length}, insertados=$insertedCount (sale_id=$saleId).',
            null,
          );
        }
      } catch (e) {
        try {
          await client.from('sales').delete().eq('id', saleId);
        } catch (_) {}
        return ('No se pudo verificar sale_items en nube para sale_id=$saleId: $e', null);
      }

      // Batch inventory deduction: aggregate quantities first to minimize roundtrips.
      final soldQtyByCloudProductId = <int, double>{};
      for (final item in items) {
        final cloudProductId = productMap[item.productId]!;
        soldQtyByCloudProductId.update(
          cloudProductId,
          (current) => current + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final deductionBySupplyId = <int, double>{};
      if (soldQtyByCloudProductId.isNotEmpty) {
        final cloudProductIds = soldQtyByCloudProductId.keys.toList(growable: false);
        final recipeRows = await client
            .from('recipes')
            .select('product_id,supply_id,quantity_required')
            .inFilter('product_id', cloudProductIds);
        for (final r in _list(recipeRows)) {
          final row = _map(r);
          final cloudProductId = _int(row['product_id']);
          final supplyId = _int(row['supply_id']);
          if (cloudProductId == null || supplyId == null) continue;
          final soldQty = soldQtyByCloudProductId[cloudProductId];
          if (soldQty == null || soldQty <= 0) continue;
          final qtyRequired = _double(row['quantity_required']);
          final deduction = qtyRequired * soldQty;
          if (deduction == 0) continue;
          deductionBySupplyId.update(
            supplyId,
            (current) => current + deduction,
            ifAbsent: () => deduction,
          );
        }
      }

      for (final item in items) {
        for (final mod in item.selectedModifiers) {
          final cloudSupplyId = supplyMap[mod.supplyId]!;
          final deduction = mod.quantityDeducted * item.quantity;
          if (deduction == 0) continue;
          deductionBySupplyId.update(
            cloudSupplyId,
            (current) => current + deduction,
            ifAbsent: () => deduction,
          );
        }
      }

      if (deductionBySupplyId.isNotEmpty) {
        final supplyIds = deductionBySupplyId.keys.toList(growable: false);
        final supplyRows = await client
            .from('supplies')
            .select('id,current_stock')
            .inFilter('id', supplyIds);
        final currentStockBySupplyId = <int, double>{};
        for (final row in _list(supplyRows)) {
          final mapped = _map(row);
          final id = _int(mapped['id']);
          if (id == null) continue;
          currentStockBySupplyId[id] = _double(mapped['current_stock']);
        }

        for (final entry in deductionBySupplyId.entries) {
          final supplyId = entry.key;
          final currentStock = currentStockBySupplyId[supplyId] ?? 0.0;
          await client
              .from('supplies')
              .update({'current_stock': currentStock - entry.value})
              .eq('id', supplyId);
        }

        final inventoryLogsRows = deductionBySupplyId.entries
            .map(
              (entry) => <String, dynamic>{
                'supply_id': entry.key,
                'change_amount': -entry.value,
                'reason': 'SALE',
              },
            )
            .toList(growable: false);
        await client.from('inventory_logs').insert(inventoryLogsRows);
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

  /// Envía el turno a la nube usando [supabaseShiftId] como `shifts.id`.
  ///
  /// Si el turno está abierto localmente pero en Supabase ya tiene `end_time`, **no** reabre
  /// en la nube: alinea SQLite con la nube y devuelve error.
  /// [payloadStoreId]: si no es null, se usa en el upsert en lugar de [StoreScope]
  /// (p. ej. al cerrar un turno local tras cambiar de tienda en el mismo flujo).
  static Future<String?> writeShiftToCloud(
    Shift shift,
    AppDatabase db, {
    int? payloadStoreId,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final cloudId = supabaseShiftId(shift);
      if (ConnectivityService.instance.isConnected && shift.endTime == null) {
        final existing =
            await client.from('shifts').select('end_time').eq('id', cloudId).maybeSingle();
        if (existing != null) {
          final end = _parseTs(_map(existing)['end_time']);
          if (end != null) {
            await (db.update(db.shifts)..where((s) => s.id.equals(shift.id))).write(
              ShiftsCompanion(endTime: Value(end)),
            );
            return 'Turno $cloudId ya cerrado en la nube; no se puede reabrir ahí. '
                'SQLite alineado con la fecha de cierre de Supabase.';
          }
        }
      }
      final device = await DeviceIdService.getDeviceInfo();
      final storeId = payloadStoreId ?? await StoreScope.getActiveStoreId();
      final regId = shift.cloudRegisterId;
      final payload = <String, dynamic>{
        'id': cloudId,
        'start_time': shift.startTime.toUtc().toIso8601String(),
        'end_time': shift.endTime?.toUtc().toIso8601String(),
        'starting_fund': shift.startingFund,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
        if (regId != null) 'register_id': regId,
      };
      try {
        await client.from('shifts').upsert(payload, onConflict: 'id');
      } catch (e, st) {
        if (e.toString().contains('register_id')) {
          payload.remove('register_id');
          await client.from('shifts').upsert(payload, onConflict: 'id');
        } else {
          debugPrint('CloudSyncService.writeShiftToCloud: $e');
          debugPrint('$st');
          rethrow;
        }
      }
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
      final registerId = await RegisterScope.getActiveRegisterId();
      final payload = <String, dynamic>{
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': '${pkg.version}+${pkg.buildNumber}',
        'platform': _platformLabel(),
        'store_id': storeId,
        'register_id': registerId,
      };
      try {
        await client.from('pos_devices').upsert(payload, onConflict: 'device_id');
      } catch (e) {
        if (e.toString().contains('register_id')) {
          payload.remove('register_id');
          await client.from('pos_devices').upsert(payload, onConflict: 'device_id');
        } else {
          rethrow;
        }
      }
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
      await reconcileLocalOpenShiftsWithCloud(db);
      final open = await (db.select(db.shifts)
            ..where((s) => s.endTime.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.id)])
            ..limit(1))
          .getSingleOrNull();
      if (open != null) {
        return await writeShiftToCloud(open, db);
      }
    }
    return null;
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// Señal de actualización remota para este terminal (fila en pos_devices).
  static Future<({DateTime at, String? message})?> fetchRemoteUpdateRequestForCurrentDevice() async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final row = await SupabaseService.instance.client
          .from('pos_devices')
          .select('remote_update_requested_at, remote_update_message')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (row == null) return null;
      final m = _map(row);
      final at = _parseTs(m['remote_update_requested_at']);
      if (at == null) return null;
      final msg = m['remote_update_message'] as String?;
      return (at: at, message: msg?.trim().isEmpty == true ? null : msg?.trim());
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchRemoteUpdateRequestForCurrentDevice: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Admin: marcar que esta caja debe mostrar aviso y comprobar actualización.
  static Future<String?> setRemoteUpdateRequestForDevice({
    required String deviceId,
    String? message,
  }) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final payload = <String, dynamic>{
        'remote_update_requested_at': DateTime.now().toUtc().toIso8601String(),
        'remote_update_message': message?.trim().isEmpty == true ? null : message?.trim(),
      };
      await SupabaseService.instance.client.from('pos_devices').update(payload).eq('device_id', deviceId);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.setRemoteUpdateRequestForDevice: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Admin: quitar la señal de actualización para un terminal.
  static Future<String?> clearRemoteUpdateRequestForDevice(String deviceId) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      await SupabaseService.instance.client.from('pos_devices').update({
        'remote_update_requested_at': null,
        'remote_update_message': null,
      }).eq('device_id', deviceId);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.clearRemoteUpdateRequestForDevice: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Aplica [store_id] y [register_id] de la fila en [pos_devices] a [StoreScope] / [RegisterScope].
  /// Solo con red; la nube manda cuando el terminal ya está provisionado.
  static Future<void> applyDeviceStoreRegisterFromCloudPrefs() async {
    if (!SupabaseService.isInitialized) return;
    if (!ConnectivityService.instance.isConnected) return;
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final row = await fetchPosDeviceFromCloud(deviceId);
      if (row == null) return;
      if (row.storeId >= 1) {
        await StoreScope.setActiveStoreId(row.storeId);
      }
      if (row.registerId != null && row.registerId! >= 1) {
        await RegisterScope.setActiveRegisterId(row.registerId!);
      }
    } catch (e, st) {
      debugPrint('CloudSyncService.applyDeviceStoreRegisterFromCloudPrefs: $e');
      debugPrint('$st');
    }
  }

  /// Turno abierto en nube para la tienda y cajón indicados (mismo [register_id]).
  static Future<CloudShiftSummary?> fetchOpenShiftForRegisterCloud({
    required int storeId,
    required int registerId,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      dynamic row;
      try {
        row = await SupabaseService.instance.client
            .from('shifts')
            .select(_kShiftSelectWithRegister)
            .eq('store_id', storeId)
            .eq('register_id', registerId)
            .isFilter('end_time', null)
            .order('start_time', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        row = await SupabaseService.instance.client
            .from('shifts')
            .select()
            .eq('store_id', storeId)
            .eq('register_id', registerId)
            .isFilter('end_time', null)
            .order('start_time', ascending: false)
            .limit(1)
            .maybeSingle();
      }
      if (row == null) return null;
      return _cloudShiftSummaryFromRow(_map(row));
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchOpenShiftForRegisterCloud: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Una fila de [pos_devices] por [deviceId], o null.
  static Future<CloudPosDeviceRecord?> fetchPosDeviceFromCloud(String deviceId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final row = await SupabaseService.instance.client
          .from('pos_devices')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();
      if (row == null) return null;
      final m = _map(row);
      final id = m['device_id'] as String? ?? '';
      if (id.isEmpty) return null;
      return CloudPosDeviceRecord(
        deviceId: id,
        deviceName: m['device_name'] as String? ?? id,
        lastSeenAt: _parseTs(m['last_seen_at']) ?? DateTime.now(),
        appVersion: m['app_version'] as String?,
        platform: m['platform'] as String?,
        storeId: _int(m['store_id']) ?? kDefaultStoreId,
        registerId: _int(m['register_id']),
        remoteUpdateRequestedAt: _parseTs(m['remote_update_requested_at']),
        remoteUpdateMessage: m['remote_update_message'] as String?,
      );
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchPosDeviceFromCloud: $e');
      debugPrint('$st');
      return null;
    }
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
          registerId: _int(m['register_id']),
          remoteUpdateRequestedAt: _parseTs(m['remote_update_requested_at']),
          remoteUpdateMessage: m['remote_update_message'] as String?,
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchPosDevicesFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Mayor [id] en `public.shifts` (todas las filas). Vacío → 0. Error/red → null.
  static Future<int?> fetchMaxShiftIdFromCloud() async {
    if (!SupabaseService.isInitialized) return null;
    if (!ConnectivityService.instance.isConnected) return null;
    try {
      final row = await SupabaseService.instance.client
          .from('shifts')
          .select('id')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return 0;
      return _int(_map(row)['id']) ?? 0;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchMaxShiftIdFromCloud: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Fila en [shifts] por id en **Supabase** (usa [supabaseShiftId] de la fila local).
  static Future<CloudShiftSummary?> fetchShiftByIdFromCloud(int supabaseShiftId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      Map<String, dynamic>? m;
      try {
        final row = await SupabaseService.instance.client
            .from('shifts')
            .select(_kShiftSelectWithRegister)
            .eq('id', supabaseShiftId)
            .maybeSingle();
        if (row != null) m = _map(row);
      } catch (_) {
        final row = await SupabaseService.instance.client
            .from('shifts')
            .select()
            .eq('id', supabaseShiftId)
            .maybeSingle();
        if (row != null) m = _map(row);
      }
      if (m == null) return null;
      return _cloudShiftSummaryFromRow(m);
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchShiftByIdFromCloud: $e');
      debugPrint('$st');
      return null;
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
          .select(_kShiftSelectWithRegister)
          .eq('device_id', deviceId)
          .isFilter('end_time', null);
      if (storeId != null) {
        q = q.eq('store_id', storeId);
      }
      dynamic row;
      try {
        row = await q.order('start_time', ascending: false).limit(1).maybeSingle();
      } catch (_) {
        var q2 = SupabaseService.instance.client
            .from('shifts')
            .select()
            .eq('device_id', deviceId)
            .isFilter('end_time', null);
        if (storeId != null) {
          q2 = q2.eq('store_id', storeId);
        }
        row = await q2.order('start_time', ascending: false).limit(1).maybeSingle();
      }
      if (row == null) return null;
      return _cloudShiftSummaryFromRow(_map(row));
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
          .select(
            'id, start_time, end_time, starting_fund, store_id, device_id, device_name, register_id, pos_registers ( label ), shift_closures (*)',
          )
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
        final summary = _cloudShiftSummaryFromRow(m, closures: closures);
        if (summary != null) out.add(summary);
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

  /// Ventas en nube con `sales.shift_id` = [cloudShiftId], excluyendo ids que ya están en SQLite (`cloud_sale_id`).
  /// Usado en cierre de caja: total local + estas = turno completo sin duplicar.
  static Future<({double cash, double debit, double credit, double transfer})>
      fetchCloudOnlySalesTotalsForShift({
    required int cloudShiftId,
    required Set<int> excludeCloudSaleIds,
  }) async {
    if (!SupabaseService.isInitialized) {
      return (cash: 0.0, debit: 0.0, credit: 0.0, transfer: 0.0);
    }
    try {
      final res = await SupabaseService.instance.client
          .from('sales')
          .select('id, total_amount, payment_method')
          .eq('shift_id', cloudShiftId)
          .isFilter('cancelled_at', null);
      var cash = 0.0;
      var debit = 0.0;
      var credit = 0.0;
      var transfer = 0.0;
      for (final e in _list(res)) {
        final m = _map(e);
        final id = _int(m['id']);
        if (id == null || excludeCloudSaleIds.contains(id)) continue;
        final amt = _double(m['total_amount']);
        switch (m['payment_method'] as String? ?? 'CASH') {
          case 'CARD_DEBIT':
            debit += amt;
            break;
          case 'CARD_CREDIT':
            credit += amt;
            break;
          case 'TRANSFER':
            transfer += amt;
            break;
          default:
            cash += amt;
        }
      }
      return (cash: cash, debit: debit, credit: credit, transfer: transfer);
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchCloudOnlySalesTotalsForShift: $e');
      debugPrint('$st');
      return (cash: 0.0, debit: 0.0, credit: 0.0, transfer: 0.0);
    }
  }

  /// IDs de ventas canceladas en nube para un turno (`sales.shift_id`).
  static Future<Set<int>> fetchCancelledSaleIdsForShift(int cloudShiftId) async {
    if (!SupabaseService.isInitialized) return <int>{};
    try {
      final res = await SupabaseService.instance.client
          .from('sales')
          .select('id')
          .eq('shift_id', cloudShiftId)
          .not('cancelled_at', 'is', null);
      final out = <int>{};
      for (final e in _list(res)) {
        final id = _int(_map(e)['id']);
        if (id != null) out.add(id);
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchCancelledSaleIdsForShift: $e');
      debugPrint('$st');
      return <int>{};
    }
  }

  /// Neto movimientos CAJA en nube para el turno, excluyendo ids ya presentes en SQLite (mismo id que nube).
  static Future<double> fetchCloudOnlyCajaMovementNetForShift({
    required int cloudShiftId,
    required Set<int> excludeCloudMovementIds,
  }) async {
    if (!SupabaseService.isInitialized) return 0;
    try {
      final res = await SupabaseService.instance.client
          .from('movements')
          .select('id, type, amount')
          .eq('shift_id', cloudShiftId)
          .eq('account', 'CAJA')
          .isFilter('cancelled_at', null);
      var net = 0.0;
      for (final e in _list(res)) {
        final m = _map(e);
        final id = _int(m['id']);
        if (id == null || excludeCloudMovementIds.contains(id)) continue;
        final t = m['type'] as String? ?? '';
        final amt = _double(m['amount']);
        if (t == 'ENTRADA') {
          net += amt;
        } else if (t == 'SALIDA') {
          net -= amt;
        }
      }
      return net;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchCloudOnlyCajaMovementNetForShift: $e');
      debugPrint('$st');
      return 0;
    }
  }

  /// Cierra el turno solo en Supabase (corte remoto). Suma ventas por [sales.shift_id] y,
  /// en datos antiguos, por dispositivo y rango de fechas del turno.
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
      final start = _parseTs(sm['start_time']) ?? DateTime.now();
      final startStr = start.toUtc().toIso8601String();
      final end = DateTime.now();
      final endStr = end.toUtc().toIso8601String();
      final shiftStoreId = _int(sm['store_id']) ?? kDefaultStoreId;
      var cashSales = 0.0;
      void addCashSalesFrom(List<dynamic> rows) {
        for (final row in _list(rows)) {
          final r = _map(row);
          if ((r['payment_method'] as String?) == 'CASH') {
            cashSales += _double(r['total_amount']);
          }
        }
      }

      try {
        final byShift = await client
            .from('sales')
            .select('total_amount, payment_method')
            .eq('shift_id', shiftId)
            .isFilter('cancelled_at', null);
        addCashSalesFrom(byShift);
      } catch (_) {}

      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          final legacy = await client
              .from('sales')
              .select('total_amount, payment_method')
              .isFilter('shift_id', null)
              .gte('date', startStr)
              .lte('date', endStr)
              .eq('device_id', deviceId)
              .eq('store_id', shiftStoreId)
              .isFilter('cancelled_at', null);
          addCashSalesFrom(legacy);
        } catch (_) {}
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

  /// Descarga movimientos del turno desde la nube; asocia filas locales al turno **local** [shift.id].
  static Future<String?> pullMovementsForShift(AppDatabase db, Shift shift) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final cloudShiftKey = supabaseShiftId(shift);
      final res = await client
          .from('movements')
          .select('id, date, type, account, amount, reason, shift_id, cancelled_at')
          .eq('shift_id', cloudShiftKey)
          .isFilter('cancelled_at', null)
          .order('id');
      final rowsRaw = _list(res).map((r) => _map(r)).toList();
      // PostgREST / proxies en redes inestables pueden devolver filas repetidas por id.
      final rows = _dedupeByIdKey(rowsRaw, 'id');
      var insertedLocally = 0;
      var skippedOutsideWindow = 0;
      for (final row in rows) {
        final cloudId = _int(row['id'])!;
        final dateStr = row['date'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        final movementDate = date ?? DateTime.now();
        final inWindow = isMovementInShiftWindow(movementDate: movementDate, shift: shift);
        final existing = await (db.select(db.movements)..where((m) => m.id.equals(cloudId))).getSingleOrNull();
        if (existing != null) {
          if (existing.cancelledAt == null && row['cancelled_at'] != null) {
            final cancelled = DateTime.tryParse(row['cancelled_at'].toString());
            if (cancelled != null) {
              await (db.update(db.movements)..where((m) => m.id.equals(cloudId))).write(
                    MovementsCompanion(cancelledAt: Value(cancelled.toLocal())),
                  );
            }
          }
          if (!inWindow && existing.shiftId == shift.id) {
            await (db.update(db.movements)..where((m) => m.id.equals(cloudId))).write(
                  const MovementsCompanion(shiftId: Value(null)),
                );
          }
          continue;
        }
        if (!inWindow) {
          skippedOutsideWindow++;
          continue;
        }
        await db.into(db.movements).insert(MovementsCompanion.insert(
              type: row['type'] as String,
              account: row['account'] as String,
              amount: _double(row['amount']),
              reason: row['reason'] as String,
              id: Value(cloudId),
              date: Value(movementDate),
              shiftId: Value(shift.id),
            ));
        insertedLocally++;
      }
      await logShiftCloseDiagnostic(
        event: 'pull_movements_for_shift',
        shiftId: cloudShiftKey,
        context: {
          'ok': true,
          'localShiftId': shift.id,
          'cloudRowCount': rows.length,
          'insertedLocally': insertedLocally,
          'skippedOutsideWindow': skippedOutsideWindow,
        },
      );
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.pullMovementsForShift: $e');
      debugPrint('$st');
      await logShiftCloseDiagnostic(
        event: 'pull_movements_for_shift',
        shiftId: supabaseShiftId(shift),
        context: {'ok': false, 'error': e.toString(), 'localShiftId': shift.id},
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

  /// Envía un movimiento a la nube (`shift_id` = id Supabase del turno).
  /// Reintenta en errores de red típicos (conexión inestable) para evitar fila local sin upsert en nube.
  static Future<String?> writeMovementToCloud(
    Movement movement,
    AppDatabase db, {
    int? cloudShiftIdOverride,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    const maxAttempts = 4;
    Object? lastErr;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final client = SupabaseService.instance.client;
        final storeId = await StoreScope.getActiveStoreId();
        int? cloudSid = cloudShiftIdOverride;
        if (cloudSid == null && movement.shiftId != null) {
          final sh = await (db.select(db.shifts)..where((s) => s.id.equals(movement.shiftId!)))
              .getSingleOrNull();
          cloudSid = sh != null ? supabaseShiftId(sh) : movement.shiftId;
        }
        await client.from('movements').upsert({
          'id': movement.id,
          'date': movement.date.toUtc().toIso8601String(),
          'type': movement.type,
          'account': movement.account,
          'amount': movement.amount,
          'reason': movement.reason,
          'shift_id': cloudSid,
          'store_id': storeId,
        }, onConflict: 'id');
        return null;
      } catch (e, st) {
        lastErr = e;
        debugPrint('CloudSyncService.writeMovementToCloud (intento $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts && _isRetryableNetworkError(e)) {
          await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
          continue;
        }
        debugPrint('$st');
        return e.toString();
      }
    }
    return lastErr?.toString();
  }

  static Movement _movementFromSupabaseRow(Map<String, dynamic> m) {
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
      needsCloudSync: false,
      cancelledAt: m['cancelled_at'] == null
          ? null
          : DateTime.tryParse(m['cancelled_at'].toString())?.toLocal(),
    );
  }

  /// Marca un movimiento como cancelado en Supabase (admin).
  static Future<String?> cancelMovementInCloud(int movementId) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      await SupabaseService.instance.client.from('movements').update({
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', movementId);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.cancelMovementInCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Movimientos desde Supabase (p. ej. web sin Drift), filtrados por tienda activa.
  static Future<List<Movement>> fetchMovementsFromCloud({String? account, int limit = 200}) async {
    if (!SupabaseService.isInitialized) return [];
    final client = SupabaseService.instance.client;
    final storeId = await StoreScope.getActiveStoreId();
    var query = client
        .from('movements')
        .select()
        .eq('store_id', storeId)
        .isFilter('cancelled_at', null);
    if (account != null) {
      query = query.eq('account', account);
    }
    final res = await query.order('date', ascending: false).limit(limit);
    final list = _list(res);
    return list.map((e) => _movementFromSupabaseRow(_map(e))).toList();
  }

  /// Ids cancelados recientes (para alinear SQLite tras sync).
  static Future<Set<int>> fetchCancelledMovementIdsFromCloud({
    String? account,
    int limit = 200,
  }) async {
    if (!SupabaseService.isInitialized) return {};
    try {
      final client = SupabaseService.instance.client;
      final storeId = await StoreScope.getActiveStoreId();
      var query = client
          .from('movements')
          .select('id')
          .eq('store_id', storeId)
          .not('cancelled_at', 'is', null);
      if (account != null) {
        query = query.eq('account', account);
      }
      final res = await query.order('date', ascending: false).limit(limit);
      final ids = <int>{};
      for (final e in _list(res)) {
        final id = _int(_map(e)['id']);
        if (id != null) ids.add(id);
      }
      return ids;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchCancelledMovementIdsFromCloud: $e');
      debugPrint('$st');
      return {};
    }
  }

  /// Turnos abiertos en la tienda activa (para asociar movimientos de caja).
  static Future<List<CloudShiftSummary>> fetchOpenShiftsForActiveStore() async {
    final storeId = await StoreScope.getActiveStoreId();
    final all = await fetchAllOpenShiftsForAdmin();
    return all.where((s) => s.storeId == storeId && s.isOpen).toList();
  }

  /// Inserta un movimiento solo en Supabase (sin fila local).
  /// [shiftId] es el id del turno en Supabase (`shifts.id`).
  static Future<(String?, Movement?)> insertMovementToCloud({
    required String type,
    required String account,
    required double amount,
    required String reason,
    int? shiftId,
  }) async {
    if (!SupabaseService.isInitialized) return ('Supabase no inicializado', null);
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
      final row = await client.from('movements').insert(payload).select().single();
      return (null, _movementFromSupabaseRow(_map(row)));
    } catch (e, st) {
      debugPrint('CloudSyncService.insertMovementToCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
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
      final cloudSid = supabaseShiftId(shiftWithEndTime);
      final regId = shiftWithEndTime.cloudRegisterId;
      final closurePayload = <String, dynamic>{
        'id': cloudSid,
        'start_time': shiftWithEndTime.startTime.toUtc().toIso8601String(),
        'end_time': shiftWithEndTime.endTime?.toUtc().toIso8601String(),
        'starting_fund': shiftWithEndTime.startingFund,
        'device_id': device.deviceId,
        'device_name': device.deviceName,
        'store_id': storeId,
        if (regId != null) 'register_id': regId,
      };
      try {
        await client.from('shifts').upsert(closurePayload, onConflict: 'id');
      } catch (e) {
        if (e.toString().contains('register_id')) {
          closurePayload.remove('register_id');
          await client.from('shifts').upsert(closurePayload, onConflict: 'id');
        } else {
          rethrow;
        }
      }
      await client.from('shift_closures').insert({
        'shift_id': cloudSid,
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

  static double? _doubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    return v == 1 || v == 'true';
  }

  static CloudShiftSummary? _cloudShiftSummaryFromRow(
    Map<String, dynamic> m, {
    List<CloudShiftClosureBrief> closures = const [],
  }) {
    final sid = _int(m['id']);
    if (sid == null) return null;
    final reg = m['pos_registers'];
    String? registerLabel;
    if (reg is Map) {
      registerLabel = reg['label'] as String?;
    }
    String? storeName;
    final st = m['stores'];
    if (st is Map) {
      storeName = st['name'] as String?;
    }
    return CloudShiftSummary(
      id: sid,
      startTime: _parseTs(m['start_time']) ?? DateTime.now(),
      endTime: _parseTs(m['end_time']),
      startingFund: _double(m['starting_fund']),
      deviceId: m['device_id'] as String?,
      deviceName: m['device_name'] as String?,
      storeId: _int(m['store_id']) ?? kDefaultStoreId,
      storeName: storeName,
      registerId: _int(m['register_id']),
      registerLabel: registerLabel,
      closures: closures,
    );
  }

  /// Cajones de una tienda (orden [display_order], luego etiqueta).
  /// [activeOnly]: false incluye cajones desactivados (pantalla admin).
  static Future<List<CloudPosRegisterRecord>> fetchRegistersForStore(
    int storeId, {
    bool activeOnly = true,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      var q = SupabaseService.instance.client
          .from('pos_registers')
          .select()
          .eq('store_id', storeId);
      if (activeOnly) {
        q = q.eq('active', true);
      }
      final res = await q.order('display_order').order('label');
      final out = <CloudPosRegisterRecord>[];
      for (final e in _list(res)) {
        final m = _map(e);
        final id = _int(m['id']);
        if (id == null) continue;
        out.add(CloudPosRegisterRecord(
          id: id,
          storeId: _int(m['store_id']) ?? kDefaultStoreId,
          label: m['label'] as String? ?? 'Caja $id',
          displayOrder: _int(m['display_order']) ?? 0,
          active: _bool(m['active']),
        ));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchRegistersForStore: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Turnos abiertos en nube para un cajón concreto (misma tienda).
  static Future<List<CloudShiftSummary>> fetchOpenShiftsForRegisterCloud({
    required int storeId,
    required int registerId,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client
          .from('shifts')
          .select(_kShiftSelectWithRegister)
          .eq('store_id', storeId)
          .eq('register_id', registerId)
          .isFilter('end_time', null)
          .order('start_time', ascending: false);
      final out = <CloudShiftSummary>[];
      for (final e in _list(res)) {
        final s = _cloudShiftSummaryFromRow(_map(e));
        if (s != null) out.add(s);
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchOpenShiftsForRegisterCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Turnos abiertos en toda la nube (admin: enlazar terminal a otra caja/tienda).
  static Future<List<CloudShiftSummary>> fetchAllOpenShiftsForAdmin() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client
          .from('shifts')
          .select(
            'id, start_time, end_time, starting_fund, store_id, device_id, device_name, register_id, stores ( name ), pos_registers ( label )',
          )
          .isFilter('end_time', null)
          .order('start_time', ascending: false);
      final out = <CloudShiftSummary>[];
      for (final e in _list(res)) {
        final s = _cloudShiftSummaryFromRow(_map(e));
        if (s != null) out.add(s);
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchAllOpenShiftsForAdmin: $e');
      debugPrint('$st');
      return [];
    }
  }

  static Future<List<CloudStoreRecord>> fetchStoresFromCloud() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client
          .from('stores')
          .select('id, name')
          .order('id');
      final out = <CloudStoreRecord>[];
      for (final e in _list(res)) {
        final m = _map(e);
        final id = _int(m['id']);
        if (id == null) continue;
        out.add(CloudStoreRecord(id: id, name: m['name'] as String? ?? 'Store $id'));
      }
      return out;
    } catch (e, st) {
      debugPrint('CloudSyncService.fetchStoresFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }

  static Future<(String? error, int? newId)> insertStoreToCloud(String name) async {
    if (!SupabaseService.isInitialized) return ('Supabase no inicializado', null);
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final trimmed = name.trim();
      if (trimmed.isEmpty) return ('El nombre no puede estar vacío', null);
      final row = await SupabaseService.instance.client
          .from('stores')
          .insert({'name': trimmed})
          .select('id')
          .single();
      return (null, _int(_map(row)['id']));
    } catch (e, st) {
      debugPrint('CloudSyncService.insertStoreToCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
    }
  }

  static Future<String?> updateStoreToCloud({required int id, required String name}) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final trimmed = name.trim();
      if (trimmed.isEmpty) return 'El nombre no puede estar vacío';
      await SupabaseService.instance.client.from('stores').update({'name': trimmed}).eq('id', id);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.updateStoreToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  static Future<(String? error, int? newId)> insertRegisterToCloud({
    required int storeId,
    required String label,
    int displayOrder = 0,
  }) async {
    if (!SupabaseService.isInitialized) return ('Supabase no inicializado', null);
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final trimmed = label.trim();
      if (trimmed.isEmpty) return ('La etiqueta no puede estar vacía', null);
      final row = await SupabaseService.instance.client
          .from('pos_registers')
          .insert({
            'store_id': storeId,
            'label': trimmed,
            'display_order': displayOrder,
            'active': true,
          })
          .select('id')
          .single();
      return (null, _int(_map(row)['id']));
    } catch (e, st) {
      debugPrint('CloudSyncService.insertRegisterToCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
    }
  }

  static Future<String?> updateRegisterToCloud({
    required int id,
    String? label,
    int? displayOrder,
    bool? active,
  }) async {
    if (!SupabaseService.isInitialized) return 'Supabase no inicializado';
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final payload = <String, dynamic>{};
      if (label != null) {
        final t = label.trim();
        if (t.isEmpty) return 'La etiqueta no puede estar vacía';
        payload['label'] = t;
      }
      if (displayOrder != null) payload['display_order'] = displayOrder;
      if (active != null) payload['active'] = active;
      if (payload.isEmpty) return null;
      await SupabaseService.instance.client.from('pos_registers').update(payload).eq('id', id);
      return null;
    } catch (e, st) {
      debugPrint('CloudSyncService.updateRegisterToCloud: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  // ----- Write-through: sync single entities to cloud so other devices get changes via Realtime -----

  /// Inserts a new category row in Supabase and returns its id (cloud-first create).
  static Future<(String? error, int? id)> insertCategoryRowInCloud({
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
  }) async {
    if (!SupabaseService.isInitialized) {
      return ('Supabase no inicializado', null);
    }
    try {
      final res = await SupabaseService.instance.client
          .from('categories')
          .insert(<String, dynamic>{
            'name': name.trim(),
            'parent_id': parentId,
            'color': color,
            'image_url': imageUrl,
          })
          .select('id')
          .single();
      final m = _map(res);
      final id = _int(m['id']);
      if (id == null) return ('Respuesta sin id', null);
      return (null, id);
    } catch (e, st) {
      debugPrint('CloudSyncService.insertCategoryRowInCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
    }
  }

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
    double? employeePrice,
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
        'employee_price': employeePrice,
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

  static Future<String?> upsertDiscountToCloud({
    required int id,
    required String code,
    required double percentage,
    required String description,
    required bool isActive,
    String type = 'percentage',
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('discounts').upsert({
        'id': id,
        'code': code,
        'type': type,
        'percentage': percentage,
        'description': description,
        'is_active': isActive,
      }, onConflict: 'id');
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.upsertDiscountToCloud: $e');
      return e.toString();
    }
  }

  static Future<String?> deleteDiscountFromCloud(int id) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('discounts').delete().match({'id': id});
      return null;
    } catch (e) {
      debugPrint('CloudSyncService.deleteDiscountFromCloud: $e');
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

  /// Inserts a new supply row in Supabase and returns its id (cloud-first create).
  static Future<(String? error, int? id)> insertSupplyRowInCloud({
    required String name,
    required String unit,
    required double currentStock,
    double costPerUnit = 0,
    double reorderPoint = 0,
    String? category,
    String stockCountMode = 'quantity',
    String? qualitativeLevel,
  }) async {
    if (!SupabaseService.isInitialized) {
      return ('Supabase no inicializado', null);
    }
    try {
      final res = await SupabaseService.instance.client
          .from('supplies')
          .insert(<String, dynamic>{
            'name': name,
            'unit': unit,
            'current_stock': currentStock,
            'cost_per_unit': costPerUnit,
            'reorder_point': reorderPoint,
            'category': category,
            'stock_count_mode': stockCountMode,
            'qualitative_level': qualitativeLevel,
          })
          .select('id')
          .single();
      final m = _map(res);
      final id = _int(m['id']);
      if (id == null) return ('Respuesta sin id', null);
      return (null, id);
    } catch (e, st) {
      debugPrint('CloudSyncService.insertSupplyRowInCloud: $e');
      debugPrint('$st');
      return (e.toString(), null);
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
    String? imageUrl,
  }) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      await SupabaseService.instance.client.from('modifier_options').insert({
        'modifier_group_id': modifierGroupId,
        'supply_id': supplyId,
        'quantity_deducted': quantityDeducted,
        'price_extra': priceExtra,
        'image_url': imageUrl,
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
        employeePrice: product.employeePrice,
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
            imageUrl: o.imageUrl,
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

  /// **Migration / recovery only.** Pushes local master data to Supabase and overwrites
  /// cloud tables: categories, supplies, products, recipes, modifiers, bundles.
  /// Not used in normal cloud-first operation (catalog is pulled via [syncFromCloud]).
  @Deprecated('Use syncFromCloud / admin cloud-first writes; keep for one-off data migration only.')
  static Future<String?> pushToCloud(AppDatabase db) async {
    if (!SupabaseService.isInitialized) return 'Supabase no configurado';
    try {
      final client = SupabaseService.instance.client;

      final categories = await (db.select(db.categories)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
      if (categories.isEmpty) return 'No hay categorías locales';

      // Truncate in FK order: dependents first (modifier_options, product_modifiers), then modifier_groups, then rest. Do not truncate products/supplies/categories (sale_items reference products).
      await _truncateCloud(client, [
        'discounts',
        'bundle_items',
        'bundles',
        'modifier_options',
        'product_modifiers',
        'modifier_groups',
        'recipes',
      ]);

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
        'employee_price': p.employeePrice,
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
          'image_url': o.imageUrl,
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

      final discList = await (db.select(db.discounts)..orderBy([(d) => OrderingTerm.asc(d.id)])).get();
      for (final d in discList) {
        await client.from('discounts').insert({
          'id': d.id,
          'code': d.code,
          'type': d.type,
          'percentage': d.percentage,
          'description': d.description,
          'is_active': d.isActive,
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

  /// Maps a Supabase `discounts` row to Drift [Discount].
  static Discount discountFromSupabaseRow(Map<String, dynamic> row) {
    final rawDesc = row['description'];
    final desc = rawDesc is String ? rawDesc.trim() : '';
    final typeRaw = row['type'];
    final type = typeRaw is String && typeRaw.isNotEmpty ? typeRaw : 'percentage';
    return Discount(
      id: _int(row['id'])!,
      code: row['code'] as String,
      type: type,
      percentage: _double(row['percentage']),
      description: desc.isEmpty ? 'Discount' : desc,
      isActive: _bool(row['is_active']),
    );
  }

  /// Loads all discount rows from Supabase (empty if offline / not configured).
  static Future<List<Discount>> fetchDiscountsFromCloud() async {
    if (!isEnabled) return [];
    try {
      final raw = await SupabaseService.instance.client.from('discounts').select('*').order('id');
      return _list(raw).map((r) => discountFromSupabaseRow(_map(r))).toList();
    } catch (e) {
      debugPrint('CloudSyncService.fetchDiscountsFromCloud: $e');
      return [];
    }
  }

  /// Active discounts only, ordered for display.
  static Future<List<Discount>> fetchActiveDiscountsFromCloud() async {
    final all = await fetchDiscountsFromCloud();
    all.sort((a, b) {
      final c = a.description.toLowerCase().compareTo(b.description.toLowerCase());
      if (c != 0) return c;
      return a.code.compareTo(b.code);
    });
    return all.where((d) => d.isActive).toList();
  }

  /// Inserts a new discount in Supabase (cloud id returned). For web admin without Drift.
  static Future<(String?, Discount?)> insertDiscountToCloud({
    required String code,
    required double percentage,
    required String description,
    required bool isActive,
    String type = 'percentage',
  }) async {
    if (!isEnabled) return ('Supabase no configurado', null);
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return ('Código vacío', null);
    final normalizedType = type.trim().isEmpty ? 'percentage' : type;
    final pct = normalizedType == 'employee' ? 0.0 : percentage;
    try {
      final row = await SupabaseService.instance.client
          .from('discounts')
          .insert({
            'code': trimmed,
            'type': normalizedType,
            'percentage': pct,
            'description': description.trim().isEmpty ? null : description.trim(),
            'is_active': isActive,
          })
          .select('*')
          .single();
      return (null, discountFromSupabaseRow(_map(row)));
    } catch (e) {
      return (e.toString(), null);
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

/// Fila de [pos_registers] en Supabase.
/// Fila de [stores] en Supabase.
class CloudStoreRecord {
  const CloudStoreRecord({required this.id, required this.name});

  final int id;
  final String name;
}

class CloudPosRegisterRecord {
  const CloudPosRegisterRecord({
    required this.id,
    required this.storeId,
    required this.label,
    required this.displayOrder,
    required this.active,
  });

  final int id;
  final int storeId;
  final String label;
  final int displayOrder;
  final bool active;
}

/// Fila de [pos_devices] en Supabase.
class CloudPosDeviceRecord {
  const CloudPosDeviceRecord({
    required this.deviceId,
    required this.deviceName,
    required this.lastSeenAt,
    required this.storeId,
    this.registerId,
    this.appVersion,
    this.platform,
    this.remoteUpdateRequestedAt,
    this.remoteUpdateMessage,
  });

  final String deviceId;
  final String deviceName;
  final DateTime lastSeenAt;
  /// [stores.id] en Supabase.
  final int storeId;
  /// [pos_registers.id] si el terminal está asignado a un cajón.
  final int? registerId;
  final String? appVersion;
  final String? platform;
  final DateTime? remoteUpdateRequestedAt;
  final String? remoteUpdateMessage;
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
    this.storeName,
    this.deviceId,
    this.deviceName,
    this.registerId,
    this.registerLabel,
    this.closures = const [],
  });

  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingFund;
  final int storeId;
  /// From join `stores(name)` when listing shifts for admin.
  final String? storeName;
  final String? deviceId;
  final String? deviceName;
  /// [pos_registers.id] en Supabase (cajón lógico).
  final int? registerId;
  final String? registerLabel;
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
