import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supply CRUD for admin: Drift on device, Supabase on web without SQLite.
abstract class SupplyAdminRepository {
  Future<List<({String name, List<Supply> supplies})>> getSuppliesGroupedByCategory();

  Future<List<String>> getSupplyCategoryNames();

  Future<int> saveSupply({
    int? id,
    required String name,
    required String unit,
    required double costPerUnit,
    double reorderPoint = 0,
    String? category,
    String stockCountMode = StockCountMode.quantity,
    String? qualitativeLevel,
  });

  Future<void> deleteSupply(int id);
}

class DriftSupplyAdminRepository implements SupplyAdminRepository {
  DriftSupplyAdminRepository(this._pos);

  final PosRepository _pos;

  @override
  Future<List<({String name, List<Supply> supplies})>> getSuppliesGroupedByCategory() =>
      _pos.getSuppliesGroupedByCategory();

  @override
  Future<List<String>> getSupplyCategoryNames() => _pos.getSupplyCategoryNames();

  @override
  Future<int> saveSupply({
    int? id,
    required String name,
    required String unit,
    required double costPerUnit,
    double reorderPoint = 0,
    String? category,
    String stockCountMode = StockCountMode.quantity,
    String? qualitativeLevel,
  }) =>
      _pos.saveSupply(
        id: id,
        name: name,
        unit: unit,
        costPerUnit: costPerUnit,
        reorderPoint: reorderPoint,
        category: category,
        stockCountMode: stockCountMode,
        qualitativeLevel: qualitativeLevel,
      );

  @override
  Future<void> deleteSupply(int id) => _pos.deleteSupply(id);
}

class SupabaseSupplyAdminRepository implements SupplyAdminRepository {
  SupabaseSupplyAdminRepository(this._client);

  final SupabaseClient _client;

  Supply _rowToSupply(Map<String, dynamic> row) {
    final id = row['id'];
    return Supply(
      id: id is int ? id : (id as num).toInt(),
      name: row['name'] as String,
      currentStock: (row['current_stock'] as num).toDouble(),
      unit: row['unit'] as String,
      costPerUnit: (row['cost_per_unit'] as num?)?.toDouble() ?? 0,
      reorderPoint: (row['reorder_point'] as num?)?.toDouble() ?? 0,
      category: row['category'] as String?,
      stockCountMode: (row['stock_count_mode'] as String?) ?? StockCountMode.quantity,
      qualitativeLevel: row['qualitative_level'] as String?,
    );
  }

  @override
  Future<List<({String name, List<Supply> supplies})>> getSuppliesGroupedByCategory() async {
    final res = await _client.from('supplies').select().order('name');
    final all = (res as List<dynamic>).map((e) => _rowToSupply(Map<String, dynamic>.from(e as Map))).toList();
    final byCategory = <String?, List<Supply>>{};
    for (final s in all) {
      final key = s.category?.trim().isEmpty == true ? null : s.category;
      byCategory.putIfAbsent(key, () => []).add(s);
    }
    final result = <({String name, List<Supply> supplies})>[];
    final sortedCategories = byCategory.keys.whereType<String>().toList()..sort();
    for (final name in sortedCategories) {
      final list = byCategory[name]!;
      list.sort((a, b) => a.name.compareTo(b.name));
      result.add((name: name, supplies: list));
    }
    final uncategorized = byCategory[null];
    if (uncategorized != null && uncategorized.isNotEmpty) {
      uncategorized.sort((a, b) => a.name.compareTo(b.name));
      result.add((name: 'Sin categoría', supplies: uncategorized));
    }
    return result;
  }

  @override
  Future<List<String>> getSupplyCategoryNames() async {
    final rows = await _client.from('supplies').select('category');
    final names = <String>{};
    for (final e in rows as List<dynamic>) {
      final c = (e as Map)['category'] as String?;
      if (c != null && c.trim().isNotEmpty) {
        names.add(c.trim());
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  @override
  Future<int> saveSupply({
    int? id,
    required String name,
    required String unit,
    required double costPerUnit,
    double reorderPoint = 0,
    String? category,
    String stockCountMode = StockCountMode.quantity,
    String? qualitativeLevel,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final cat = category?.trim().isEmpty == true ? null : category?.trim();
    final mode = stockCountMode == StockCountMode.qualitative
        ? StockCountMode.qualitative
        : StockCountMode.quantity;
    final qLevel = mode == StockCountMode.qualitative &&
            qualitativeLevel != null &&
            QualitativeLevel.isValid(qualitativeLevel)
        ? qualitativeLevel
        : null;
    final qualStock = qLevel != null ? stockFromQualitativeLevel(qLevel) : null;

    if (id == null) {
      final insert = <String, dynamic>{
        'name': name,
        'unit': unit,
        'cost_per_unit': costPerUnit,
        'reorder_point': reorderPoint,
        'category': cat,
        'stock_count_mode': mode,
        'qualitative_level': qLevel,
      };
      if (mode == StockCountMode.qualitative && qualStock != null) {
        insert['current_stock'] = qualStock;
      } else {
        insert['current_stock'] = 0.0;
      }
      final row = await _client.from('supplies').insert(insert).select('id').single();
      return row['id'] is int ? row['id'] as int : (row['id'] as num).toInt();
    }

    await _client.from('supplies').update({
      'name': name,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'reorder_point': reorderPoint,
      'category': cat,
      'stock_count_mode': mode,
      'qualitative_level': mode == StockCountMode.qualitative ? qLevel : null,
      if (mode == StockCountMode.qualitative && qualStock != null) 'current_stock': qualStock,
    }).eq('id', id);

    return id;
  }

  @override
  Future<void> deleteSupply(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final err = await CloudSyncService.deleteSupplyFromCloud(id);
    if (err != null) {
      throw StateError(err);
    }
  }
}

final supplyAdminRepositoryProvider = Provider<SupplyAdminRepository>((ref) {
  if (isSupabaseOnlyBackend) {
    return SupabaseSupplyAdminRepository(Supabase.instance.client);
  }
  return DriftSupplyAdminRepository(ref.watch(posRepositoryProvider)!);
});
