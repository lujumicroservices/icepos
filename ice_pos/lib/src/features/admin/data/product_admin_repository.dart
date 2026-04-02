import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Product list / toggle / delete for admin (Drift vs Supabase web).
abstract class ProductAdminRepository {
  Stream<List<Product>> watchAllProducts();

  Future<void> setProductActive(int productId, bool active);

  Future<void> deleteProduct(int productId);
}

class DriftProductAdminRepository implements ProductAdminRepository {
  DriftProductAdminRepository(this._pos);

  final PosRepository _pos;

  @override
  Stream<List<Product>> watchAllProducts() => _pos.watchAllProducts();

  @override
  Future<void> setProductActive(int productId, bool active) =>
      _pos.setProductActive(productId, active);

  @override
  Future<void> deleteProduct(int productId) => _pos.deleteProduct(productId);
}

class SupabaseProductAdminRepository implements ProductAdminRepository {
  SupabaseProductAdminRepository(this._client);

  final SupabaseClient _client;

  Product _rowToProduct(Map<String, dynamic> row) {
    final id = row['id'];
    return Product(
      id: id is int ? id : (id as num).toInt(),
      name: row['name'] as String,
      price: (row['price'] as num).toDouble(),
      imageUrl: row['image_url'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      categoryId: row['category_id'] == null
          ? null
          : (row['category_id'] is int
              ? row['category_id'] as int
              : (row['category_id'] as num).toInt()),
    );
  }

  @override
  Stream<List<Product>> watchAllProducts() {
    return _client.from('products').stream(primaryKey: ['id']).map(
          (rows) => rows.map((e) => _rowToProduct(Map<String, dynamic>.from(e))).toList(),
        );
  }

  @override
  Future<void> setProductActive(int productId, bool active) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await _client.from('products').update({'is_active': active}).eq('id', productId);
    final row = await _client.from('products').select().eq('id', productId).single();
    final m = Map<String, dynamic>.from(row as Map);
    final err = await CloudSyncService.upsertProductToCloud(
      id: productId,
      name: m['name'] as String,
      price: (m['price'] as num).toDouble(),
      categoryId: m['category_id'] == null
          ? null
          : (m['category_id'] is int
              ? m['category_id'] as int
              : (m['category_id'] as num).toInt()),
      isActive: m['is_active'] as bool? ?? true,
      imageUrl: m['image_url'] as String?,
    );
    if (err != null) {
      throw StateError(err);
    }
  }

  @override
  Future<void> deleteProduct(int productId) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final items = await _client.from('sale_items').select('id').eq('product_id', productId);
    if ((items as List<dynamic>).isNotEmpty) {
      throw StateError(
        'No se puede eliminar: el producto tiene ventas asociadas. Desactívalo en su lugar.',
      );
    }
    var err = await CloudSyncService.deleteRecipesForProductFromCloud(productId);
    if (err != null) {
      throw StateError(err);
    }
    err = await CloudSyncService.deleteModifiersForProductFromCloud(productId);
    if (err != null) {
      throw StateError(err);
    }
    err = await CloudSyncService.deleteProductFromCloud(productId);
    if (err != null) {
      throw StateError(err);
    }
  }
}

final productAdminRepositoryProvider = Provider<ProductAdminRepository>((ref) {
  if (isSupabaseOnlyBackend) {
    return SupabaseProductAdminRepository(Supabase.instance.client);
  }
  return DriftProductAdminRepository(ref.watch(posRepositoryProvider)!);
});
