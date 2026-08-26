import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/modifier_option_image_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/product_image_service.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ModifierOptionSaveInput = ({
  int supplyId,
  double quantityDeducted,
  double priceExtra,
  String? imageUrl,
  List<int>? newImageBytes,
  String? newImageMimeType,
});

typedef ModifierGroupSaveInput = ({
  String name,
  int minSelection,
  int maxSelection,
  List<ModifierOptionSaveInput> options,
});

/// Product editor: recipes, modifiers, image — Drift on device, Supabase on web.
abstract class ProductEditorRepository {
  Stream<List<Supply>> watchSupplies();

  Future<List<Supply>> getSupplies();

  Future<Product?> getProduct(int id);

  Future<List<({Recipe recipe, Supply supply})>> getRecipesForProduct(int productId);

  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(int productId);

  Future<int> saveProduct({
    required int? productId,
    required String name,
    required double price,
    double? employeePrice,
    int? categoryId,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<ModifierGroupSaveInput> modifierGroups,
  });
}

class DriftProductEditorRepository implements ProductEditorRepository {
  DriftProductEditorRepository(this._pos);

  final PosRepository _pos;

  @override
  Stream<List<Supply>> watchSupplies() => _pos.watchSupplies();

  @override
  Future<List<Supply>> getSupplies() => _pos.getSupplies();

  @override
  Future<Product?> getProduct(int id) => _pos.getProduct(id);

  @override
  Future<List<({Recipe recipe, Supply supply})>> getRecipesForProduct(int productId) =>
      _pos.getRecipesForProduct(productId);

  @override
  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(int productId) =>
      _pos.getModifierGroupsForProduct(productId);

  @override
  Future<int> saveProduct({
    required int? productId,
    required String name,
    required double price,
    double? employeePrice,
    int? categoryId,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<ModifierGroupSaveInput> modifierGroups,
  }) =>
      _pos.saveProduct(
        productId: productId,
        name: name,
        price: price,
        employeePrice: employeePrice,
        categoryId: categoryId,
        imageUrl: imageUrl,
        newImageBytes: newImageBytes,
        newImageMimeType: newImageMimeType,
        recipeItems: recipeItems,
        modifierGroups: modifierGroups,
      );
}

class SupabaseProductEditorRepository implements ProductEditorRepository {
  SupabaseProductEditorRepository(this._client);

  final SupabaseClient _client;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Supply _supplyFromRow(Map<String, dynamic> row) {
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
  Stream<List<Supply>> watchSupplies() {
    return _client.from('supplies').stream(primaryKey: ['id']).map(
          (rows) => rows.map((e) => _supplyFromRow(Map<String, dynamic>.from(e))).toList(),
        );
  }

  @override
  Future<List<Supply>> getSupplies() async {
    final res = await _client.from('supplies').select().order('name');
    return (res as List<dynamic>)
        .map((e) => _supplyFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<Product?> getProduct(int id) async {
    final row = await _client.from('products').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row as Map);
    return Product(
      id: _asInt(m['id'])!,
      name: m['name'] as String,
      price: (m['price'] as num).toDouble(),
      employeePrice: m['employee_price'] == null
          ? null
          : (m['employee_price'] as num).toDouble(),
      imageUrl: m['image_url'] as String?,
      isActive: m['is_active'] as bool? ?? true,
      categoryId: m['category_id'] == null ? null : _asInt(m['category_id']),
    );
  }

  @override
  Future<List<({Recipe recipe, Supply supply})>> getRecipesForProduct(int productId) async {
    final res = await _client.from('recipes').select().eq('product_id', productId);
    final out = <({Recipe recipe, Supply supply})>[];
    for (final r in res as List<dynamic>) {
      final rm = Map<String, dynamic>.from(r as Map);
      final recipeId = _asInt(rm['id'])!;
      final supplyId = _asInt(rm['supply_id'])!;
      final srow = await _client.from('supplies').select().eq('id', supplyId).single();
      final supply = _supplyFromRow(Map<String, dynamic>.from(srow as Map));
      final recipe = Recipe(
        id: recipeId,
        productId: productId,
        supplyId: supplyId,
        quantityRequired: (rm['quantity_required'] as num).toDouble(),
      );
      out.add((recipe: recipe, supply: supply));
    }
    return out;
  }

  @override
  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(int productId) async {
    final pmRes = await _client.from('product_modifiers').select('modifier_group_id').eq('product_id', productId);
    final groupIds = <int>{};
    for (final e in pmRes as List<dynamic>) {
      final gid = _asInt((e as Map)['modifier_group_id']);
      if (gid != null) {
        groupIds.add(gid);
      }
    }
    final result = <ModifierGroupWithOptions>[];
    for (final gid in groupIds) {
      final grow = await _client.from('modifier_groups').select().eq('id', gid).maybeSingle();
      if (grow == null) continue;
      final gm = Map<String, dynamic>.from(grow as Map);
      final group = ModifierGroup(
        id: gid,
        name: gm['name'] as String,
        minSelection: _asInt(gm['min_selection']) ?? 0,
        maxSelection: _asInt(gm['max_selection']) ?? 1,
      );
      final optRes = await _client.from('modifier_options').select().eq('modifier_group_id', gid);
      final options = <ModifierOptionWithSupply>[];
      for (final o in optRes as List<dynamic>) {
        final om = Map<String, dynamic>.from(o as Map);
        final sid = _asInt(om['supply_id'])!;
        final srow = await _client.from('supplies').select('name, unit').eq('id', sid).single();
        final sm = Map<String, dynamic>.from(srow as Map);
        final option = ModifierOption(
          id: _asInt(om['id'])!,
          modifierGroupId: gid,
          supplyId: sid,
          quantityDeducted: (om['quantity_deducted'] as num).toDouble(),
          priceExtra: (om['price_extra'] as num?)?.toDouble() ?? 0,
          imageUrl: om['image_url'] as String?,
        );
        options.add(
          ModifierOptionWithSupply(
            option: option,
            supplyName: sm['name'] as String? ?? '',
            supplyUnit: sm['unit'] as String?,
          ),
        );
      }
      result.add(ModifierGroupWithOptions(group: group, options: options));
    }
    return result;
  }

  @override
  Future<int> saveProduct({
    required int? productId,
    required String name,
    required double price,
    double? employeePrice,
    int? categoryId,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<ModifierGroupSaveInput> modifierGroups,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();

    late int id;
    if (productId == null) {
      final insert = <String, dynamic>{
        'name': name,
        'price': price,
        'employee_price': employeePrice,
        'is_active': true,
        'category_id': categoryId,
        if (newImageBytes == null) 'image_url': imageUrl,
      };
      final row = await _client.from('products').insert(insert).select('id').single();
      id = _asInt(row['id'])!;
    } else {
      id = productId;
      final upd = <String, dynamic>{
        'name': name,
        'price': price,
        'employee_price': employeePrice,
        'category_id': categoryId,
      };
      if (newImageBytes == null) {
        upd['image_url'] = imageUrl;
      }
      await _client.from('products').update(upd).eq('id', id);
    }

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await ProductImageService.uploadProductImage(
        productId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await _client.from('products').update({'image_url': url}).eq('id', id);
      }
    }

    var err = await CloudSyncService.deleteRecipesForProductFromCloud(id);
    if (err != null) {
      throw StateError(err);
    }
    for (final item in recipeItems) {
      err = await CloudSyncService.insertRecipeToCloud(
        productId: id,
        supplyId: item.supplyId,
        quantityRequired: item.quantityRequired,
      );
      if (err != null) {
        throw StateError(err);
      }
    }

    err = await CloudSyncService.deleteModifiersForProductFromCloud(id);
    if (err != null) {
      throw StateError(err);
    }

    for (final group in modifierGroups) {
      final gRow = await _client
          .from('modifier_groups')
          .insert({
            'name': group.name,
            'min_selection': group.minSelection,
            'max_selection': group.maxSelection,
          })
          .select('id')
          .single();
      final groupId = _asInt(gRow['id'])!;
      err = await CloudSyncService.insertProductModifierToCloud(productId: id, modifierGroupId: groupId);
      if (err != null) {
        throw StateError(err);
      }
      for (final opt in group.options) {
        final hasNewBytes =
            opt.newImageBytes != null && opt.newImageBytes!.isNotEmpty;
        final insert = <String, dynamic>{
          'modifier_group_id': groupId,
          'supply_id': opt.supplyId,
          'quantity_deducted': opt.quantityDeducted,
          'price_extra': opt.priceExtra,
          if (!hasNewBytes) 'image_url': opt.imageUrl,
        };
        final oRow =
            await _client.from('modifier_options').insert(insert).select('id').single();
        final optionId = _asInt(oRow['id'])!;
        if (hasNewBytes) {
          final url = await ModifierOptionImageService.uploadModifierOptionImage(
            optionId: optionId,
            bytes: Uint8List.fromList(opt.newImageBytes!),
            mimeType: opt.newImageMimeType ?? 'image/jpeg',
          );
          if (url != null) {
            await _client
                .from('modifier_options')
                .update({'image_url': url}).eq('id', optionId);
          }
        }
      }
    }

    final p = await getProduct(id);
    if (p != null) {
      err = await CloudSyncService.upsertProductToCloud(
        id: p.id,
        name: p.name,
        price: p.price,
        categoryId: p.categoryId,
        isActive: p.isActive,
        imageUrl: p.imageUrl,
      );
      if (err != null) {
        throw StateError(err);
      }
    }

    return id;
  }
}

final productEditorRepositoryProvider = Provider<ProductEditorRepository>((ref) {
  if (isSupabaseOnlyBackend) {
    return SupabaseProductEditorRepository(Supabase.instance.client);
  }
  return DriftProductEditorRepository(ref.watch(posRepositoryProvider)!);
});
