import 'dart:typed_data';

import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/services/category_image_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Category CRUD for admin: mobile uses [PosRepository] (Drift); web uses Supabase only.
abstract class CatalogRepository {
  Future<List<domain_cat.Category>> getAllCategories();

  Future<int> insertCategory({
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  });

  Future<void> updateCategory(
    int id, {
    String? name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  });

  Future<void> deleteCategory(int id);

  Future<int> countProductsInCategory(int categoryId);
}

class DriftCatalogRepository implements CatalogRepository {
  DriftCatalogRepository(this._pos);

  final PosRepository _pos;

  @override
  Future<List<domain_cat.Category>> getAllCategories() => _pos.getAllCategories();

  @override
  Future<int> insertCategory({
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  }) =>
      _pos.insertCategory(
        name: name,
        parentId: parentId,
        color: color,
        imageUrl: imageUrl,
        newImageBytes: newImageBytes,
        newImageMimeType: newImageMimeType,
      );

  @override
  Future<void> updateCategory(
    int id, {
    String? name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  }) =>
      _pos.updateCategory(
        id,
        name: name,
        parentId: parentId,
        color: color,
        imageUrl: imageUrl,
        newImageBytes: newImageBytes,
        newImageMimeType: newImageMimeType,
      );

  @override
  Future<void> deleteCategory(int id) => _pos.deleteCategory(id);

  @override
  Future<int> countProductsInCategory(int categoryId) =>
      _pos.countProductsInCategory(categoryId);
}

/// Remote catalog for web admin (no local Drift).
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  domain_cat.Category _rowToCategory(Map<String, dynamic> row) {
    final id = row['id'];
    final pid = row['parent_id'];
    return domain_cat.Category(
      id: id is int ? id : (id as num).toInt(),
      name: row['name'] as String,
      parentId: pid == null ? null : (pid is int ? pid : (pid as num).toInt()),
      color: row['color'] as String?,
      imageUrl: row['image_url'] as String?,
    );
  }

  @override
  Future<List<domain_cat.Category>> getAllCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, parent_id, color, image_url')
        .order('name');
    final list = (rows as List<dynamic>)
        .map((e) => _rowToCategory(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) {
      final ar = a.parentId == null ? 0 : 1;
      final br = b.parentId == null ? 0 : 1;
      final c = ar.compareTo(br);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<int> insertCategory({
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final row = await _client.from('categories').insert(<String, dynamic>{
      'name': name.trim(),
      'parent_id': parentId,
      'color': color,
      'image_url': newImageBytes != null ? null : imageUrl,
    }).select('id').single();
    final idRaw = row['id'];
    final id = idRaw is int ? idRaw : (idRaw as num).toInt();

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await CategoryImageService.uploadCategoryImage(
        categoryId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await _client.from('categories').update({'image_url': url}).eq('id', id);
      }
    }
    return id;
  }

  @override
  Future<void> updateCategory(
    int id, {
    String? name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final base = <String, dynamic>{};
    if (name != null) base['name'] = name.trim();
    if (parentId != null) base['parent_id'] = parentId;
    if (color != null) base['color'] = color;

    if (newImageBytes == null) {
      await _client.from('categories').update({
        ...base,
        'image_url': imageUrl,
      }).eq('id', id);
    } else {
      if (base.isNotEmpty) {
        await _client.from('categories').update(base).eq('id', id);
      }
    }

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await CategoryImageService.uploadCategoryImage(
        categoryId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await _client.from('categories').update({'image_url': url}).eq('id', id);
      }
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final products = await _client.from('products').select('id').eq('category_id', id);
    final pList = products as List<dynamic>;
    if (pList.isNotEmpty) {
      throw StateError(
        'Cannot delete category: ${pList.length} product(s) belong to it. '
        'Reassign or remove products first.',
      );
    }
    final children = await _client.from('categories').select('id').eq('parent_id', id);
    final cList = children as List<dynamic>;
    if (cList.isNotEmpty) {
      throw StateError(
        'Cannot delete category: it has ${cList.length} subcategory(ies). '
        'Delete or move them first.',
      );
    }
    await _client.from('categories').delete().eq('id', id);
  }

  @override
  Future<int> countProductsInCategory(int categoryId) async {
    final rows = await _client.from('products').select('id').eq('category_id', categoryId);
    return (rows as List<dynamic>).length;
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (isSupabaseOnlyBackend) {
    return SupabaseCatalogRepository(Supabase.instance.client);
  }
  final pos = ref.watch(posRepositoryProvider);
  if (pos == null) {
    throw StateError('CatalogRepository (Drift) requires a local database.');
  }
  return DriftCatalogRepository(pos);
});
