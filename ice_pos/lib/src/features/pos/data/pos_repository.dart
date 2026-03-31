import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/category_image_service.dart';
import 'package:ice_pos/src/core/services/product_image_service.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart' as domain;
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pos_repository.g.dart';

/// Item in the cart for a sale.
class CartItem {
  const CartItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productName,
    this.selectedModifiers = const [],
  });

  final int productId;
  final double quantity;
  final double unitPrice;
  /// Optional product name for debug logging.
  final String? productName;
  /// Selected modifier options (for inventory deduction).
  final List<ModifierOption> selectedModifiers;

  double get subtotal => quantity * unitPrice;
}

/// Sale item DTO for display (product name, quantity, price at sale).
class SaleItemDto {
  const SaleItemDto({
    required this.productName,
    required this.quantity,
    required this.priceAtSale,
  });

  final String productName;
  final double quantity;
  final double priceAtSale;
}

/// Sale with its line items for history/reporting.
class SaleWithItems {
  const SaleWithItems({
    required this.sale,
    required this.items,
  });

  final Sale sale;
  final List<SaleItemDto> items;
}

/// Modifier option with supply name for display.
class ModifierOptionWithSupply {
  const ModifierOptionWithSupply({
    required this.option,
    required this.supplyName,
    this.supplyUnit,
  });

  final ModifierOption option;
  final String supplyName;
  final String? supplyUnit;
}

/// Result of closing a shift - closure record + breakdown for Z-Report.
class ShiftClosureResult {
  const ShiftClosureResult({
    required this.closure,
    required this.startingFund,
    required this.cashSales,
    required this.cardSales,
    required this.transferSales,
    this.movementsCajaNet = 0,
  });

  final ShiftClosure closure;
  final double startingFund;
  final double cashSales;
  final double cardSales;
  final double transferSales;
  /// Neto de movimientos (entradas - salidas) de caja en el turno cerrado.
  final double movementsCajaNet;

  /// Total ventas del turno (efectivo + tarjeta + transferencia).
  double get totalSales => cashSales + cardSales + transferSales;
}

/// Totals for the current shift (for closure form). Does not close the shift.
class ShiftTotalsForClosure {
  const ShiftTotalsForClosure({
    required this.startingFund,
    required this.cashSales,
    required this.debitSales,
    required this.creditSales,
    required this.transferSales,
    this.movementsCajaNet = 0,
  });

  final double startingFund;
  final double cashSales;
  final double debitSales;
  final double creditSales;
  final double transferSales;
  /// Neto de movimientos (entradas - salidas) de caja en este turno. Afecta el esperado en caja.
  final double movementsCajaNet;

  double get cardSales => debitSales + creditSales;
  double get totalSales => cashSales + cardSales + transferSales;

  /// Lo que debería haber en caja: fondo inicial + ventas efectivo + movimientos (entradas - salidas).
  double get expectedCashInDrawer =>
      startingFund + cashSales + movementsCajaNet;
}

/// Modifier group with its options for the modifier dialog.
class ModifierGroupWithOptions {
  const ModifierGroupWithOptions({
    required this.group,
    required this.options,
  });

  final ModifierGroup group;
  final List<ModifierOptionWithSupply> options;
}

/// POS: only groups with at least one option should open the modifier sheet.
/// If every [ModifierOption] row fails the supply join, options are empty and the sheet would be useless.
List<ModifierGroupWithOptions> filterModifierGroupsForPos(
  List<ModifierGroupWithOptions> groups,
) =>
    groups.where((g) => g.options.isNotEmpty).toList();

/// Repository for POS (Point of Sale) operations.
class PosRepository {
  PosRepository(this._db);

  final AppDatabase _db;

  /// Persists a diagnostic row (sale failures, cloud sync issues). Never throws.
  Future<void> logOperationEvent({
    required String level,
    required String operation,
    required String message,
    Map<String, Object?>? context,
    StackTrace? stackTrace,
  }) async {
    try {
      String? ctxJson;
      if (context != null && context.isNotEmpty) {
        try {
          ctxJson = jsonEncode(context);
        } catch (_) {
          ctxJson = context.toString();
        }
      }
      await _db.into(_db.operationLogs).insert(
            OperationLogsCompanion.insert(
              level: level,
              operation: operation,
              message: message,
              contextJson: Value(ctxJson),
              stackTrace: Value(stackTrace?.toString()),
            ),
          );
    } catch (e, st) {
      debugPrint('logOperationEvent insert failed: $e\n$st');
    }
  }

  /// Latest entries first (for diagnostics screen).
  Future<List<OperationLog>> getOperationLogs({int limit = 500}) {
    return (_db.select(_db.operationLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
  }

  Future<void> clearOperationLogs() async {
    await _db.delete(_db.operationLogs).go();
  }

  /// Fetches categories. If [parentId] is null, returns root categories.
  Future<List<domain_cat.Category>> getCategories({int? parentId}) async {
    final query = parentId == null
        ? 'SELECT id, name, parent_id, color, image_url FROM categories WHERE parent_id IS NULL'
        : 'SELECT id, name, parent_id, color, image_url FROM categories WHERE parent_id = ?';
    final rows = await _db.customSelect(
      query,
      variables: parentId != null
          ? [Variable.withInt(parentId)]
          : [],
    ).get();
    return rows
        .map(
          (row) => domain_cat.Category(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            parentId: row.read<int?>('parent_id'),
            color: row.read<String?>('color'),
            imageUrl: row.read<String?>('image_url'),
          ),
        )
        .toList();
  }

  /// Returns all categories (root and subcategories) for admin/grouping.
  /// Order: root first (parent_id IS NULL), then by name.
  Future<List<domain_cat.Category>> getAllCategories() async {
    const query = '''
      SELECT id, name, parent_id, color, image_url FROM categories
      ORDER BY CASE WHEN parent_id IS NULL THEN 0 ELSE 1 END, name
    ''';
    final rows = await _db.customSelect(query).get();
    return rows
        .map(
          (row) => domain_cat.Category(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            parentId: row.read<int?>('parent_id'),
            color: row.read<String?>('color'),
            imageUrl: row.read<String?>('image_url'),
          ),
        )
        .toList();
  }

  /// Gets a single category by id.
  Future<domain_cat.Category?> getCategory(int id) async {
    final row = await (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return domain_cat.Category(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      color: row.color,
      imageUrl: row.imageUrl,
    );
  }

  /// Inserts a new category. Returns the new id.
  Future<int> insertCategory({
    required String name,
    int? parentId,
    String? color,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final id = await _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        name: name.trim(),
        parentId: Value(parentId),
        color: Value(color),
        imageUrl: newImageBytes != null ? const Value.absent() : Value(imageUrl),
      ),
    );

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await CategoryImageService.uploadCategoryImage(
        categoryId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(CategoriesCompanion(imageUrl: Value(url)));
      }
    }

    if (CloudSyncService.isEnabled) {
      final cat = await getCategory(id);
      if (cat != null) {
        CloudSyncService.upsertCategoryToCloud(
          id: cat.id,
          name: cat.name,
          parentId: cat.parentId,
          color: cat.color,
          imageUrl: cat.imageUrl,
        ).catchError((e) => null);
      }
    }
    return id;
  }

  /// Updates an existing category.
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
    final companion = CategoriesCompanion(
      name: name != null ? Value(name.trim()) : const Value.absent(),
      parentId:
          parentId != null ? Value<int?>(parentId) : const Value.absent(),
      color: color != null ? Value<String?>(color) : const Value.absent(),
    );

    if (newImageBytes == null) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        companion.copyWith(imageUrl: Value(imageUrl)),
      );
    } else {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(companion);
    }

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await CategoryImageService.uploadCategoryImage(
        categoryId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(CategoriesCompanion(imageUrl: Value(url)));
      }
    }
    if (CloudSyncService.isEnabled) {
      final cat = await getCategory(id);
      if (cat != null) {
        CloudSyncService.upsertCategoryToCloud(
          id: cat.id,
          name: cat.name,
          parentId: cat.parentId,
          color: cat.color,
          imageUrl: cat.imageUrl,
        ).catchError((e) => null);
      }
    }
  }

  /// Deletes a category. Fails if it has products or child categories.
  /// Use [reassignProductCategoryId] first if needed.
  Future<void> deleteCategory(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final products = await (_db.select(_db.products)
          ..where((p) => p.categoryId.equals(id)))
        .get();
    if (products.isNotEmpty) {
      throw StateError(
        'Cannot delete category: ${products.length} product(s) belong to it. '
        'Reassign or remove products first.',
      );
    }
    final children = await (_db.select(_db.categories)
          ..where((c) => c.parentId.equals(id)))
        .get();
    if (children.isNotEmpty) {
      throw StateError(
        'Cannot delete category: it has ${children.length} subcategory(ies). '
        'Delete or move them first.',
      );
    }
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    if (CloudSyncService.isEnabled) {
      CloudSyncService.deleteCategoryFromCloud(id).catchError((e) => null);
    }
  }

  /// Counts products in a category.
  Future<int> countProductsInCategory(int categoryId) async {
    final list = await (_db.select(_db.products)
          ..where((p) => p.categoryId.equals(categoryId)))
        .get();
    return list.length;
  }

  /// Gets active products that belong to the given category.
  /// Requires schema v9 (categories table, products.category_id). Run build_runner after schema change.
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    return (_db.select(_db.products)
          ..where((p) =>
              p.isActive.equals(true) & p.categoryId.equals(categoryId)))
        .get();
  }

  /// Gets all active products (e.g. when at root with no categories).
  Future<List<Product>> getProducts() async {
    return (_db.select(_db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
  }

  /// Observes active products (isActive == true).
  Stream<List<Product>> watchProducts() {
    return (_db.select(_db.products)
          ..where((p) => p.isActive.equals(true)))
        .watch();
  }

  /// Observes all products (including inactive) for admin.
  Stream<List<Product>> watchAllProducts() {
    return _db.select(_db.products).watch();
  }

  /// Gets a single product by id.
  Future<Product?> getProduct(int id) async {
    return await (_db.select(_db.products)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  /// Sets product active flag. Inactive products are hidden from POS.
  Future<void> setProductActive(int productId, bool active) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(isActive: Value(active)));
    if (CloudSyncService.isEnabled) {
      final p = await getProduct(productId);
      if (p != null) {
        CloudSyncService.upsertProductToCloud(
          id: p.id,
          name: p.name,
          price: p.price,
          categoryId: p.categoryId,
          isActive: active,
          imageUrl: p.imageUrl,
        ).catchError((e) => null);
      }
    }
  }

  /// Deletes a product and its recipes and product_modifiers.
  /// Throws StateError if the product has any sales (sale_items).
  Future<void> deleteProduct(int productId) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await _db.transaction(() async {
      final saleCount = await (_db.selectOnly(_db.saleItems)
            ..addColumns([_db.saleItems.id.count()])
            ..where(_db.saleItems.productId.equals(productId)))
          .getSingle();
      if ((saleCount.read(_db.saleItems.id.count()) ?? 0) > 0) {
        throw StateError(
          'No se puede eliminar: el producto tiene ventas asociadas. Desactívalo en su lugar.',
        );
      }
      await (_db.delete(_db.recipes)..where((r) => r.productId.equals(productId)))
          .go();
      await (_db.delete(_db.productModifiers)
            ..where((pm) => pm.productId.equals(productId)))
          .go();
      await (_db.delete(_db.products)..where((p) => p.id.equals(productId)))
          .go();
    });
    if (CloudSyncService.isEnabled) {
      CloudSyncService.deleteModifiersForProductFromCloud(productId).catchError((e) => null);
      CloudSyncService.deleteRecipesForProductFromCloud(productId).catchError((e) => null);
      CloudSyncService.deleteProductFromCloud(productId).catchError((e) => null);
    }
  }

  /// Gets recipes for a product with supply names.
  Future<List<({Recipe recipe, Supply supply})>> getRecipesForProduct(
    int productId,
  ) async {
    final rows = await (_db.select(_db.recipes)
          ..where((r) => r.productId.equals(productId)))
        .join([
      innerJoin(
        _db.supplies,
        _db.supplies.id.equalsExp(_db.recipes.supplyId),
      ),
    ]).get();
    return rows
        .map(
          (r) => (
            recipe: r.readTable(_db.recipes),
            supply: r.readTable(_db.supplies),
          ),
        )
        .toList();
  }

  /// Saves product with recipes and modifiers in a single transaction.
  /// [imageUrl]: URL final si no hay [newImageBytes] (puede ser null para quitar imagen).
  /// [newImageBytes]: si no es null, tras guardar se sube y se actualiza [image_url].
  /// Devuelve el id del producto guardado.
  Future<int> saveProduct({
    required int? productId,
    required String name,
    required double price,
    int? categoryId,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<({
      String name,
      int minSelection,
      int maxSelection,
      List<({int supplyId, double quantityDeducted, double priceExtra})> options,
    })> modifierGroups,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final savedProductId = await _db.transaction(() async {
      int id;
      if (productId == null) {
        id = await _db.into(_db.products).insert(
              ProductsCompanion.insert(
                name: name,
                price: price,
                categoryId: Value(categoryId),
                imageUrl: newImageBytes != null
                    ? const Value.absent()
                    : Value(imageUrl),
              ),
            );
      } else {
        id = productId;
        final companion = ProductsCompanion(
          name: Value(name),
          price: Value(price),
          categoryId: Value(categoryId),
        );
        if (newImageBytes == null) {
          await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
            companion.copyWith(imageUrl: Value(imageUrl)),
          );
        } else {
          await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(companion);
        }
      }

      // Replace recipes
      await (_db.delete(_db.recipes)..where((r) => r.productId.equals(id)))
          .go();
      for (final item in recipeItems) {
        await _db.into(_db.recipes).insert(
              RecipesCompanion.insert(
                productId: id,
                supplyId: item.supplyId,
                quantityRequired: item.quantityRequired,
              ),
            );
      }

      // Replace modifier groups: delete old, insert new
      final oldPms =
          await (_db.select(_db.productModifiers)
                ..where((pm) => pm.productId.equals(id)))
              .get();
      final oldGroupIds = oldPms.map((pm) => pm.modifierGroupId).toSet();
      for (final gid in oldGroupIds) {
        await (_db.delete(_db.modifierOptions)
              ..where((o) => o.modifierGroupId.equals(gid)))
            .go();
      }
      await (_db.delete(_db.productModifiers)
            ..where((pm) => pm.productId.equals(id)))
          .go();
      for (final gid in oldGroupIds) {
        await (_db.delete(_db.modifierGroups)..where((g) => g.id.equals(gid)))
            .go();
      }

      for (final group in modifierGroups) {
        final groupId = await _db.into(_db.modifierGroups).insert(
              ModifierGroupsCompanion.insert(
                name: group.name,
                minSelection: Value(group.minSelection),
                maxSelection: group.maxSelection,
              ),
            );
        await _db.into(_db.productModifiers).insert(
              ProductModifiersCompanion.insert(
                productId: id,
                modifierGroupId: groupId,
              ),
            );
        for (final opt in group.options) {
          await _db.into(_db.modifierOptions).insert(
                ModifierOptionsCompanion.insert(
                  modifierGroupId: groupId,
                  supplyId: opt.supplyId,
                  quantityDeducted: opt.quantityDeducted,
                  priceExtra: Value(opt.priceExtra),
                ),
              );
        }
      }
      return id;
    });

    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      final url = await ProductImageService.uploadProductImage(
        productId: savedProductId,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
      if (url != null) {
        await (_db.update(_db.products)..where((p) => p.id.equals(savedProductId)))
            .write(ProductsCompanion(imageUrl: Value(url)));
      }
    }

    if (CloudSyncService.isEnabled) {
      CloudSyncService.syncProductToCloudFull(_db, savedProductId).catchError((e) => null);
    }
    return savedProductId;
  }

  /// Observes all supplies for real-time inventory updates.
  Stream<List<Supply>> watchSupplies() {
    return _db.select(_db.supplies).watch();
  }

  /// Gets all supplies (one-time fetch).
  Future<List<Supply>> getSupplies() async {
    return _db.select(_db.supplies).get();
  }

  /// Distinct category names from supplies (for dropdowns / grouping).
  Future<List<String>> getSupplyCategoryNames() async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT category FROM supplies WHERE category IS NOT NULL AND category != \'\' ORDER BY category',
    ).get();
    return rows.map((r) => r.read<String>('category')).toList();
  }

  /// All supplies grouped by category for management screen: (category name, supplies).
  Future<List<({String name, List<Supply> supplies})>> getSuppliesGroupedByCategory() async {
    final all = await _db.select(_db.supplies).get();
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

  /// Lista plana de insumos en el mismo orden que la pantalla de administración (por categoría y nombre).
  Future<List<Supply>> getSuppliesOrderedForReconciliation() async {
    final grouped = await getSuppliesGroupedByCategory();
    final out = <Supply>[];
    for (final g in grouped) {
      out.addAll(g.supplies);
    }
    return out;
  }

  /// Gets active bundles with their product requirements.
  Future<List<({Bundle bundle, List<BundleItem> bundleItems})>> getBundlesWithItems() async {
    final bundles = await (_db.select(_db.bundles)
          ..where((b) => b.isActive.equals(true)))
        .get();
    final result = <({Bundle bundle, List<BundleItem> bundleItems})>[];
    for (final b in bundles) {
      final items = await (_db.select(_db.bundleItems)
            ..where((bi) => bi.bundleId.equals(b.id)))
          .get();
      result.add((bundle: b, bundleItems: items));
    }
    return result;
  }

  /// Saves a bundle (insert or update) with its items. Returns the bundle id.
  Future<int> saveBundle({
    int? id,
    required String name,
    required double price,
    int? categoryId,
    required List<({int productId, double quantity})> productItems,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final bundleId = await _db.transaction(() async {
      if (id == null) {
        final newId = await _db.into(_db.bundles).insert(
          BundlesCompanion.insert(
            name: name,
            price: price,
            categoryId: Value(categoryId),
          ),
        );
        for (final item in productItems) {
          await _db.into(_db.bundleItems).insert(
            BundleItemsCompanion.insert(
              bundleId: newId,
              productId: item.productId,
              quantityRequired: Value(item.quantity),
            ),
          );
        }
        return newId;
      } else {
        await (_db.update(_db.bundles)..where((b) => b.id.equals(id))).write(
          BundlesCompanion(
            name: Value(name),
            price: Value(price),
            categoryId: Value(categoryId),
          ),
        );
        await (_db.delete(_db.bundleItems)
              ..where((bi) => bi.bundleId.equals(id)))
            .go();
        for (final item in productItems) {
          await _db.into(_db.bundleItems).insert(
            BundleItemsCompanion.insert(
              bundleId: id,
              productId: item.productId,
              quantityRequired: Value(item.quantity),
            ),
          );
        }
        return id;
      }
    });
    if (CloudSyncService.isEnabled) {
      CloudSyncService.upsertBundleToCloud(
        id: bundleId,
        name: name,
        price: price,
        isActive: true,
        categoryId: categoryId,
      ).catchError((e) => null);
      CloudSyncService.deleteBundleItemsFromCloud(bundleId).catchError((e) => null);
      for (final item in productItems) {
        CloudSyncService.insertBundleItemToCloud(
          bundleId: bundleId,
          productId: item.productId,
          quantity: item.quantity,
        ).catchError((e) => null);
      }
    }
    return bundleId;
  }

  /// Deletes a bundle and its items.
  Future<void> deleteBundle(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await (_db.delete(_db.bundleItems)
          ..where((bi) => bi.bundleId.equals(id)))
        .go();
    await (_db.delete(_db.bundles)..where((b) => b.id.equals(id))).go();
    if (CloudSyncService.isEnabled) {
      CloudSyncService.deleteBundleFromCloud(id).catchError((e) => null);
    }
  }

  /// Finds an active discount by code (case-insensitive).
  Future<Discount?> findDiscountByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final all = await (_db.select(_db.discounts)
          ..where((d) => d.isActive.equals(true)))
        .get();
    for (final d in all) {
      if (d.code.toUpperCase() == normalized) return d;
    }
    return null;
  }

  /// Saves a supply (insert if id is null, update otherwise). Returns the supply id.
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
      final newId = await _db.into(_db.supplies).insert(
        SuppliesCompanion.insert(
          name: name,
          unit: unit,
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
          category: Value(cat),
          stockCountMode: Value(mode),
          qualitativeLevel: Value(qLevel),
          currentStock: mode == StockCountMode.qualitative && qualStock != null
              ? Value(qualStock)
              : const Value.absent(),
        ),
      );
      if (CloudSyncService.isEnabled) {
        final s = await (_db.select(_db.supplies)..where((s) => s.id.equals(newId))).getSingleOrNull();
        if (s != null) {
          CloudSyncService.upsertSupplyToCloud(
            id: s.id,
            name: s.name,
            unit: s.unit,
            currentStock: s.currentStock,
            costPerUnit: s.costPerUnit,
            reorderPoint: s.reorderPoint,
            category: s.category,
            stockCountMode: s.stockCountMode,
            qualitativeLevel: s.qualitativeLevel,
          ).catchError((e) => null);
        }
      }
      return newId;
    } else {
      await (_db.update(_db.supplies)..where((s) => s.id.equals(id))).write(
        SuppliesCompanion(
          name: Value(name),
          unit: Value(unit),
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
          category: Value(cat),
          stockCountMode: Value(mode),
          qualitativeLevel: mode == StockCountMode.qualitative
              ? Value(qLevel)
              : const Value(null),
          currentStock: mode == StockCountMode.qualitative && qualStock != null
              ? Value(qualStock)
              : const Value.absent(),
        ),
      );
      if (CloudSyncService.isEnabled) {
        final s = await (_db.select(_db.supplies)..where((s) => s.id.equals(id))).getSingleOrNull();
        if (s != null) {
          CloudSyncService.upsertSupplyToCloud(
            id: s.id,
            name: s.name,
            unit: s.unit,
            currentStock: s.currentStock,
            costPerUnit: s.costPerUnit,
            reorderPoint: s.reorderPoint,
            category: s.category,
            stockCountMode: s.stockCountMode,
            qualitativeLevel: s.qualitativeLevel,
          ).catchError((e) => null);
        }
      }
      return id;
    }
  }

  /// Ajuste de inventario por conciliación física (cantidad o nivel cualitativo).
  /// [useQualitativeEntry] debe coincidir con la UI: chips (nivel) vs cantidad numérica.
  /// Unidad `qual` implica conteo por nivel; otras unidades, por cantidad.
  /// Retorna mensaje de error de nube si el guardado local fue OK pero falló el upsert
  /// (la sync periódica podría sobrescribir datos locales si la nube queda desactualizada).
  Future<String?> reconcileSupply({
    required int supplyId,
    double? newQuantity,
    String? qualitativeLevel,
    String? newUnit,
    required bool useQualitativeEntry,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await _db.transaction(() async {
      final supply = await (_db.select(_db.supplies)
            ..where((s) => s.id.equals(supplyId)))
          .getSingleOrNull();
      if (supply == null) {
        throw StateError('Supply id=$supplyId not found');
      }

      final trimmedUnit = newUnit?.trim();
      final unitToSet = (trimmedUnit != null && trimmedUnit.isNotEmpty)
          ? (trimmedUnit.length > 10
              ? trimmedUnit.substring(0, 10)
              : trimmedUnit)
          : null;

      if (useQualitativeEntry) {
        final level = qualitativeLevel?.trim();
        if (level == null || !QualitativeLevel.isValid(level)) {
          throw ArgumentError('Nivel cualitativo inválido');
        }
        final newStock = stockFromQualitativeLevel(level);
        final delta = newStock - supply.currentStock;
        await (_db.update(_db.supplies)..where((s) => s.id.equals(supplyId)))
            .write(
          SuppliesCompanion(
            currentStock: Value(newStock),
            qualitativeLevel: Value(level),
            stockCountMode: Value(StockCountMode.qualitative),
            unit: unitToSet != null ? Value(unitToSet) : const Value.absent(),
          ),
        );
        if (delta != 0) {
          await _db.into(_db.inventoryLogs).insert(
                InventoryLogsCompanion.insert(
                  supplyId: supplyId,
                  changeAmount: delta,
                  reason: 'RECONCILIATION',
                ),
              );
        }
      } else {
        final qty = newQuantity;
        if (qty == null || qty < 0) {
          throw ArgumentError('Cantidad inválida');
        }
        final delta = qty - supply.currentStock;
        await (_db.update(_db.supplies)..where((s) => s.id.equals(supplyId)))
            .write(
          SuppliesCompanion(
            currentStock: Value(qty),
            stockCountMode: Value(StockCountMode.quantity),
            qualitativeLevel: const Value(null),
            unit: unitToSet != null ? Value(unitToSet) : const Value.absent(),
          ),
        );
        if (delta != 0) {
          await _db.into(_db.inventoryLogs).insert(
                InventoryLogsCompanion.insert(
                  supplyId: supplyId,
                  changeAmount: delta,
                  reason: 'RECONCILIATION',
                ),
              );
        }
      }
    });

    if (!CloudSyncService.isEnabled) return null;

    final s = await (_db.select(_db.supplies)
          ..where((s) => s.id.equals(supplyId)))
        .getSingleOrNull();
    if (s == null) return null;

    return CloudSyncService.upsertSupplyToCloud(
      id: s.id,
      name: s.name,
      unit: s.unit,
      currentStock: s.currentStock,
      costPerUnit: s.costPerUnit,
      reorderPoint: s.reorderPoint,
      category: s.category,
      stockCountMode: s.stockCountMode,
      qualitativeLevel: s.qualitativeLevel,
    );
  }

  /// Deletes a supply by id.
  Future<void> deleteSupply(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await (_db.delete(_db.supplies)..where((s) => s.id.equals(id))).go();
    if (CloudSyncService.isEnabled) {
      CloudSyncService.deleteSupplyFromCloud(id).catchError((e) => null);
    }
  }

  /// Parks the current order (saves to DB for later restore).
  Future<void> parkOrder(String? customerName, List<domain.CartItem> items) async {
    if (items.isEmpty) return;
    final total = items.fold(0.0, (sum, i) => sum + i.subtotal);
    final itemsJson = jsonEncode(items.map((i) => i.toJson()).toList());
    await _db.into(_db.parkedOrders).insert(
      ParkedOrdersCompanion.insert(
        customerName: Value(customerName),
        itemsJson: itemsJson,
        totalAmount: total,
      ),
    );
  }

  /// Observes all parked orders.
  Stream<List<ParkedOrder>> watchParkedOrders() {
    return _db.select(_db.parkedOrders).watch();
  }

  /// Removes a parked order from the table.
  Future<void> deleteParkedOrder(int id) async {
    await (_db.delete(_db.parkedOrders)..where((p) => p.id.equals(id))).go();
  }

  /// Gets modifier groups for a product (with options and supply names).
  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(
    int productId,
  ) async {
    return _getModifierGroupsForProductId(productId);
  }

  /// When [getModifierGroupsForProduct] returns empty, use this to find a product
  /// with the same name that has modifiers (e.g. avoid duplicate "Boli" without modifiers).
  /// Returns the product that has modifiers and its groups, or null if none.
  /// Tries first with [categoryId], then without category so modifiers are found even if category differs.
  Future<({Product product, List<ModifierGroupWithOptions> groups})?>
      getProductWithModifiersByName(String productName, {int? categoryId}) async {
    final name = productName.trim();
    if (name.isEmpty) return null;
    final query = _db.select(_db.products)..where((p) => p.name.equals(name));
    final products = await query.get();
    // Prefer same category, then any product with that name that has modifiers
    for (final product in products) {
      if (categoryId != null && product.categoryId != categoryId) continue;
      final groups = filterModifierGroupsForPos(
        await _getModifierGroupsForProductId(product.id),
      );
      if (groups.isNotEmpty) {
        return (product: product, groups: groups);
      }
    }
    for (final product in products) {
      final groups = filterModifierGroupsForPos(
        await _getModifierGroupsForProductId(product.id),
      );
      if (groups.isNotEmpty) {
        return (product: product, groups: groups);
      }
    }
    return null;
  }

  Future<List<ModifierGroupWithOptions>> _getModifierGroupsForProductId(
    int productId,
  ) async {
    final productModifiers = await (_db.select(_db.productModifiers)
          ..where((pm) => pm.productId.equals(productId)))
        .get();

    if (productModifiers.isEmpty) return [];

    final result = <ModifierGroupWithOptions>[];
    for (final pm in productModifiers) {
      final group = await (_db.select(_db.modifierGroups)
            ..where((g) => g.id.equals(pm.modifierGroupId)))
          .getSingleOrNull();
      if (group == null) continue;

      final optionRows = await (_db.select(_db.modifierOptions)
            ..where((o) => o.modifierGroupId.equals(group.id)))
          .join([
        innerJoin(
          _db.supplies,
          _db.supplies.id.equalsExp(_db.modifierOptions.supplyId),
        ),
      ]).get();

      final options = optionRows
          .map(
            (row) {
              final supply = row.readTable(_db.supplies);
              return ModifierOptionWithSupply(
                option: row.readTable(_db.modifierOptions),
                supplyName: supply.name,
                supplyUnit: supply.unit,
              );
            },
          )
          .toList();

      result.add(ModifierGroupWithOptions(group: group, options: options));
    }
    return result;
  }

  /// Deletes all sales and sale items from the local database (e.g. to match cloud after clearing cloud sales).
  Future<void> deleteAllLocalSales() async {
    await _db.delete(_db.saleItems).go();
    await _db.delete(_db.sales).go();
  }

  /// Cancels a sale (borrado lógico: marca cancelled_at). No borra ítems ni revierte inventario. Admin only.
  Future<void> deleteSale(int saleId) async {
    final sale = await (_db.select(_db.sales)..where((t) => t.id.equals(saleId))).getSingleOrNull();
    if (sale == null) return;
    if (sale.cloudSaleId != null &&
        CloudSyncService.isEnabled &&
        ConnectivityService.instance.isConnected) {
      await CloudSyncService.softCancelSaleInCloud(sale.cloudSaleId!);
    }
    await (_db.update(_db.sales)..where((t) => t.id.equals(saleId)))
        .write(SalesCompanion(cancelledAt: Value(DateTime.now())));
  }

  /// Deletes ALL local data in FK order. Use before "Sincronizar desde la nube" for a full reload from cloud.
  Future<void> deleteAllLocalData() async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await _db.delete(_db.saleItems).go();
    await _db.delete(_db.sales).go();
    await _db.delete(_db.inventoryLogs).go();
    await _db.delete(_db.modifierOptions).go();
    await _db.delete(_db.productModifiers).go();
    await _db.delete(_db.modifierGroups).go();
    await _db.delete(_db.recipes).go();
    await _db.delete(_db.bundleItems).go();
    await _db.delete(_db.bundles).go();
    await _db.delete(_db.products).go();
    await _db.delete(_db.supplies).go();
    await _db.delete(_db.categories).go();
    await _db.delete(_db.movements).go();
    await _db.delete(_db.cashMovements).go();
    await _db.delete(_db.shiftClosures).go();
    await _db.delete(_db.shifts).go();
    await _db.delete(_db.parkedOrders).go();
    await _db.delete(_db.discounts).go();
  }

  /// Observes sales history with items, ordered by date descending. Excludes cancelled sales.
  Stream<List<SaleWithItems>> watchSalesHistory() {
    final query = _db.select(_db.sales).join([
      innerJoin(
        _db.saleItems,
        _db.saleItems.saleId.equalsExp(_db.sales.id),
      ),
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])
      ..where(_db.sales.cancelledAt.isNull())
      ..orderBy([OrderingTerm.desc(_db.sales.date)]);

    return query.watch().map((rows) {
      final grouped = <int, ({Sale sale, List<SaleItemDto> items})>{};
      for (final row in rows) {
        final sale = row.readTable(_db.sales);
        final saleItem = row.readTable(_db.saleItems);
        final product = row.readTable(_db.products);

        final dto = SaleItemDto(
          productName: product.name,
          quantity: saleItem.quantity,
          priceAtSale: saleItem.unitPrice,
        );

        if (grouped.containsKey(sale.id)) {
          grouped[sale.id]!.items.add(dto);
        } else {
          grouped[sale.id] = (sale: sale, items: [dto]);
        }
      }
      return grouped.values
          .map((e) => SaleWithItems(sale: e.sale, items: e.items))
          .toList();
    });
  }

  /// Restocks a supply: adds quantity, updates cost (weighted average), logs.
  Future<void> restockSupply({
    required int supplyId,
    required double quantity,
    required double cost,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    await _db.transaction(() async {
      final supply = await (_db.select(_db.supplies)
            ..where((s) => s.id.equals(supplyId)))
          .getSingleOrNull();

      if (supply == null) {
        throw StateError('Supply id=$supplyId not found');
      }

      final newStock = supply.currentStock + quantity;
      final newCostPerUnit = supply.currentStock > 0
          ? (supply.currentStock * supply.costPerUnit + quantity * cost) /
              newStock
          : cost;

      await (_db.update(_db.supplies)
            ..where((s) => s.id.equals(supplyId)))
          .write(
        SuppliesCompanion(
          currentStock: Value(newStock),
          costPerUnit: Value(newCostPerUnit),
        ),
      );

      await _db.into(_db.inventoryLogs).insert(
            InventoryLogsCompanion.insert(
              supplyId: supplyId,
              changeAmount: quantity,
              reason: 'PURCHASE',
            ),
          );
    });
  }

  /// Processes a sale in a single Drift transaction.
  /// Creates sale record (with payment method, amount tendered, change), sale items, deducts inventory.
  /// Returns a [SaleSyncPayload] for syncing to Supabase (cloud); null if sync not needed.
  /// [paymentMethod] should be CASH, CARD_DEBIT, CARD_CREDIT, or TRANSFER.
  /// [amountTendered] and [changeGiven] are stored on the sale record.
  Future<SaleSyncPayload?> processSale(
    List<CartItem> items, {
    Discount? discount,
    double? totalAmount,
    String paymentMethod = 'CASH',
    double amountTendered = 0.0,
    double changeGiven = 0.0,
  }) async {
    if (items.isEmpty) return null;

    var amount = totalAmount ?? items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    if (totalAmount == null && discount != null) {
      amount = amount * (1 - discount.percentage);
    }

    final itemsContext = items
        .map(
          (i) => <String, Object?>{
            'productId': i.productId,
            'quantity': i.quantity,
            'unitPrice': i.unitPrice,
            if (i.productName != null) 'name': i.productName,
          },
        )
        .toList();

    String? cloudWriteError;
    var cloudSyncExceptionLogged = false;
    late int localSaleId;

    SaleSyncPayload? payload;
    try {
    await _db.transaction(() async {

      // 1. Loop through each CartItem and deduct inventory (with debug)
      for (final cartItem in items) {
        final productLabel =
            cartItem.productName ?? 'Product #${cartItem.productId}';

        // CRITICAL DEBUGGING: Find recipe items for this product
        final recipeItems = await (_db.select(_db.recipes)
              ..where((tbl) => tbl.productId.equals(cartItem.productId)))
            .get();

        debugPrint(
          '🔍 DEBUG: Found ${recipeItems.length} ingredients for Product $productLabel',
        );

        if (recipeItems.isEmpty) {
          debugPrint(
            '⚠️ No recipe for $productLabel (productId=${cartItem.productId}); skipping inventory deduction.',
          );
          // Still deduct modifier supplies and continue so the sale is recorded.
        } else {
          // Loop through recipeItems and deduct from supplies
          for (final recipe in recipeItems) {
            final amount =
                recipe.quantityRequired * cartItem.quantity;

            final supply = await (_db.select(_db.supplies)
                  ..where((s) => s.id.equals(recipe.supplyId)))
                .getSingleOrNull();

            if (supply == null) {
              throw StateError(
                'Supply id=${recipe.supplyId} not found for product ${cartItem.productId}',
              );
            }

            // Permitir venta aunque no haya stock suficiente (stock puede quedar negativo).
            final newStock = supply.currentStock - amount;

            await (_db.update(_db.supplies)
                  ..where((tbl) => tbl.id.equals(recipe.supplyId)))
                .write(
              SuppliesCompanion(currentStock: Value(newStock)),
            );

            debugPrint(
              '✅ DEDUCTING: $amount from Supply ${recipe.supplyId}. '
              'New Stock: $newStock',
            );

            await _db.into(_db.inventoryLogs).insert(
                  InventoryLogsCompanion.insert(
                    supplyId: recipe.supplyId,
                    changeAmount: -amount,
                    reason: 'SALE',
                  ),
                );
          }
        }

        // Deduct inventory for selected modifiers
        for (final modifier in cartItem.selectedModifiers) {
          final amount = modifier.quantityDeducted * cartItem.quantity;

          final supply = await (_db.select(_db.supplies)
                ..where((s) => s.id.equals(modifier.supplyId)))
              .getSingleOrNull();

          if (supply == null) {
            throw StateError(
              'Supply id=${modifier.supplyId} not found for modifier ${modifier.id}',
            );
          }

          // Permitir venta aunque no haya stock suficiente (stock puede quedar negativo).
          final newStock = supply.currentStock - amount;

          await (_db.update(_db.supplies)
                ..where((tbl) => tbl.id.equals(modifier.supplyId)))
              .write(
            SuppliesCompanion(currentStock: Value(newStock)),
          );

          await _db.into(_db.inventoryLogs).insert(
                InventoryLogsCompanion.insert(
                  supplyId: modifier.supplyId,
                  changeAmount: -amount,
                  reason: 'SALE',
                ),
              );
        }
      }

      // 2. Insert sale + items locally first (cloud sync after transaction if online).
      localSaleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              totalAmount: amount,
              paymentMethod: Value(paymentMethod),
              amountTendered: Value(amountTendered),
              changeGiven: Value(changeGiven),
              cloudSaleId: const Value.absent(),
            ),
          );

      for (final item in items) {
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: localSaleId,
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            );
      }

      final now = DateTime.now();
      payload = SaleSyncPayload(
        date: now,
        totalAmount: amount,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        changeGiven: changeGiven,
        items: items
            .map(
              (i) => SaleSyncItem(
                productName: i.productName ?? 'Producto',
                quantity: i.quantity,
                unitPrice: i.unitPrice,
              ),
            )
            .toList(),
      );
    });
    } catch (e, st) {
      await logOperationEvent(
        level: 'error',
        operation: 'sale_transaction',
        message: e.toString(),
        context: {
          'phase': 'local_db_transaction',
          'totalAmount': amount,
          'paymentMethod': paymentMethod,
          'items': itemsContext,
        },
        stackTrace: st,
      );
      rethrow;
    }

    try {
      if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
        final (err, cloudId) = await CloudSyncService.writeSaleToCloud(
          items,
          totalAmount: amount,
          paymentMethod: paymentMethod,
          amountTendered: amountTendered,
          changeGiven: changeGiven,
        );
        if (err != null) {
          cloudWriteError = err;
        }
        if (cloudId != null) {
          await (_db.update(_db.sales)..where((s) => s.id.equals(localSaleId))).write(
                SalesCompanion(cloudSaleId: Value(cloudId)),
              );
        }
      } else if (CloudSyncService.isEnabled && !ConnectivityService.instance.isConnected) {
        cloudWriteError =
            'Sin conexión; la venta quedó registrada solo en este dispositivo.';
      }
    } catch (e, st) {
      cloudSyncExceptionLogged = true;
      cloudWriteError = e.toString();
      await logOperationEvent(
        level: 'error',
        operation: 'sale_cloud_sync',
        message: e.toString(),
        context: {
          'localSaleId': localSaleId,
          'phase': 'writeSaleToCloud_exception',
          'totalAmount': amount,
          'paymentMethod': paymentMethod,
          'items': itemsContext,
        },
        stackTrace: st,
      );
    }

    if (cloudWriteError != null) {
      debugPrint('CloudSyncService.writeSaleToCloud (non-blocking): $cloudWriteError');
      if (!cloudSyncExceptionLogged) {
        final err = cloudWriteError;
        final isOfflineOnly = err.contains('Sin conexión') ||
            err.contains('solo en este dispositivo');
        await logOperationEvent(
          level: isOfflineOnly ? 'info' : 'warning',
          operation: 'sale_cloud_sync',
          message: err,
          context: {
            'localSaleId': localSaleId,
            'totalAmount': amount,
            'paymentMethod': paymentMethod,
            'items': itemsContext,
            if (isOfflineOnly) 'kind': 'offline_local_only',
          },
        );
      }
    }
    return payload;
  }

  /// Registra un movimiento (entrada o salida) que afecta caja o banco. No es una venta.
  /// Si account es CAJA y hay turno abierto, se asocia al turno (shiftId).
  /// Si Supabase está activo, envía el movimiento a la nube para que otros dispositivos lo vean al cerrar turno.
  Future<int> insertMovement({
    required String type,
    required String account,
    required double amount,
    required String reason,
    int? shiftId,
  }) async {
    final id = await _db.into(_db.movements).insert(
          MovementsCompanion.insert(
            type: type,
            account: account,
            amount: amount,
            reason: reason,
            shiftId: shiftId != null ? Value(shiftId) : const Value.absent(),
          ),
        );
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final movement = await (_db.select(_db.movements)..where((m) => m.id.equals(id))).getSingle();
      final err = await CloudSyncService.writeMovementToCloud(movement);
      if (err != null) debugPrint('Cloud write movement: $err');
    }
    return id;
  }

  /// Lista de movimientos ordenados por fecha descendente.
  Stream<List<Movement>> watchMovements({String? account, int limit = 200}) {
    if (account != null) {
      return (_db.select(_db.movements)
            ..where((m) => m.account.equals(account))
            ..orderBy([(m) => OrderingTerm.desc(m.date)])
            ..limit(limit))
          .watch();
    }
    return (_db.select(_db.movements)
          ..orderBy([(m) => OrderingTerm.desc(m.date)])
          ..limit(limit))
        .watch();
  }

  /// Ventas del turno por forma de pago (rango [rangeStart, rangeEnd]) y neto de movimientos de caja.
  Future<({double cashSales, double debitSales, double creditSales, double transferSales, double movementsCajaNet})>
      _getShiftSalesByPaymentType(int shiftId, DateTime rangeStart, DateTime rangeEnd) async {
    final dateInRange = _db.sales.date.isBiggerOrEqualValue(rangeStart) &
        _db.sales.date.isSmallerOrEqualValue(rangeEnd);
    final notCancelled = _db.sales.cancelledAt.isNull();
    final cashR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CASH') & dateInRange & notCancelled))
        .getSingle();
    final debitR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CARD_DEBIT') & dateInRange & notCancelled))
        .getSingle();
    final creditR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CARD_CREDIT') & dateInRange & notCancelled))
        .getSingle();
    final transferR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('TRANSFER') & dateInRange & notCancelled))
        .getSingle();
    final movementsCajaNet = await getMovementsCajaNetForShift(shiftId);
    return (
      cashSales: cashR.read(_db.sales.totalAmount.sum()) ?? 0.0,
      debitSales: debitR.read(_db.sales.totalAmount.sum()) ?? 0.0,
      creditSales: creditR.read(_db.sales.totalAmount.sum()) ?? 0.0,
      transferSales: transferR.read(_db.sales.totalAmount.sum()) ?? 0.0,
      movementsCajaNet: movementsCajaNet,
    );
  }

  /// Neto de movimientos de caja para un turno: sum(ENTRADA) - sum(SALIDA). Afecta el esperado en caja.
  Future<double> getMovementsCajaNetForShift(int shiftId) async {
    final rows = await (_db.select(_db.movements)
          ..where((m) => m.account.equals('CAJA') & m.shiftId.equals(shiftId)))
        .get();
    double net = 0;
    for (final r in rows) {
      if (r.type == 'ENTRADA') {
        net += r.amount;
      } else if (r.type == 'SALIDA') {
        net -= r.amount;
      }
    }
    return net;
  }

  /// Gets the current (open) shift, or null if none.
  Future<Shift?> getCurrentShift() async {
    final list = await (_db.select(_db.shifts)
          ..where((s) => s.endTime.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
          ..limit(1))
        .get();
    return list.isEmpty ? null : list.first;
  }

  /// Starts a new shift with the given starting fund.
  /// Envía el turno a la nube automáticamente si Supabase está configurado.
  Future<Shift> startShift(double startingFund) async {
    final id = await _db.into(_db.shifts).insert(
          ShiftsCompanion.insert(startingFund: Value(startingFund)),
        );
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(id)))
        .getSingle();
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final err = await CloudSyncService.writeShiftToCloud(shift);
      if (err != null) debugPrint('Cloud write shift: $err');
    }
    return shift;
  }

  /// Actualiza el fondo inicial del turno (hotfix: tras reinstalar la app el turno puede tener 0).
  /// Así puedes hacer el corte con el efectivo real en caja.
  Future<void> updateShiftStartingFund(int shiftId, double startingFund) async {
    await (_db.update(_db.shifts)..where((s) => s.id.equals(shiftId)))
        .write(ShiftsCompanion(startingFund: Value(startingFund)));
  }

  /// Closes a shift with blind count reconciliation.
  /// Returns the ShiftClosureResult (Z-Report) for display.
  Future<ShiftClosureResult> performCloseShift({
    required int shiftId,
    required double declaredCash,
    String? notes,
  }) async {
    final tx = await _db.transaction(() async {
      final shift = await (_db.select(_db.shifts)
            ..where((s) => s.id.equals(shiftId)))
          .getSingleOrNull();
      if (shift == null) {
        throw StateError('Shift $shiftId not found');
      }
      if (shift.endTime != null) {
        throw StateError('Shift $shiftId is already closed');
      }

      final now = DateTime.now();
      final sales = await _getShiftSalesByPaymentType(shiftId, shift.startTime, now);
      final cashSalesTotal = sales.cashSales;
      final cardSalesTotal = sales.debitSales + sales.creditSales;
      final transferSalesTotal = sales.transferSales;
      final movementsCajaNet = sales.movementsCajaNet;

      // systemExpectedCash = startingFund + cashSales + movimientos (entradas - salidas)
      final systemExpectedCash =
          shift.startingFund + cashSalesTotal + movementsCajaNet;

      final difference = declaredCash - systemExpectedCash;

      final closureId = await _db.into(_db.shiftClosures).insert(
            ShiftClosuresCompanion.insert(
              shiftId: shiftId,
              systemExpectedCash: systemExpectedCash,
              declaredCash: declaredCash,
              difference: difference,
              notes: notes != null ? Value(notes) : const Value.absent(),
            ),
          );

      await (_db.update(_db.shifts)..where((s) => s.id.equals(shiftId)))
          .write(ShiftsCompanion(endTime: Value(now)));

      final closure = await (_db.select(_db.shiftClosures)
            ..where((c) => c.id.equals(closureId)))
          .getSingle();
      final result = ShiftClosureResult(
        closure: closure,
        startingFund: shift.startingFund,
        cashSales: cashSalesTotal,
        cardSales: cardSalesTotal,
        transferSales: transferSalesTotal,
        movementsCajaNet: movementsCajaNet,
      );
      final shiftWithEndTime = shift.copyWith(endTime: Value(now));
      return (result: result, shiftForCloud: shiftWithEndTime);
    });
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final err = await CloudSyncService.writeShiftClosureToCloud(
        tx.shiftForCloud,
        tx.result.closure,
      );
      if (err != null) debugPrint('Cloud write shift closure: $err');
    }
    return tx.result;
  }

  /// Totals for closure form (expected in drawer, sales by payment type). Does not close the shift.
  Future<ShiftTotalsForClosure?> getShiftTotalsForClosure(int shiftId) async {
    final shift = await (_db.select(_db.shifts)
          ..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shift == null) return null;
    final now = DateTime.now();
    final sales = await _getShiftSalesByPaymentType(shiftId, shift.startTime, now);
    return ShiftTotalsForClosure(
      startingFund: shift.startingFund,
      cashSales: sales.cashSales,
      debitSales: sales.debitSales,
      creditSales: sales.creditSales,
      transferSales: sales.transferSales,
      movementsCajaNet: sales.movementsCajaNet,
    );
  }

  // ----- Reportes -----

  /// Cortes (cierres de turno) cuyo cierre ocurrió en el día indicado (fecha en hora local).
  /// Incluye desglose de ventas por forma de pago y datos de caja.
  Future<List<ClosureDayRow>> getClosuresForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);

    final closuresWithShifts = await (_db.select(_db.shiftClosures)
          ..orderBy([(c) => OrderingTerm.asc(c.closingTime)]))
        .join([
      innerJoin(
        _db.shifts,
        _db.shifts.id.equalsExp(_db.shiftClosures.shiftId),
      ),
    ]).get();

    final result = <ClosureDayRow>[];
    for (final row in closuresWithShifts) {
      final closure = row.readTable(_db.shiftClosures);
      final shift = row.readTable(_db.shifts);
      final closingLocal = closure.closingTime.toLocal();
      final closingDate = DateTime(closingLocal.year, closingLocal.month, closingLocal.day);
      if (closingDate != dayStart) continue;
      final endTime = shift.endTime ?? closure.closingTime;
      final dateInRange = _db.sales.date.isBiggerOrEqualValue(shift.startTime) &
          _db.sales.date.isSmallerOrEqualValue(endTime);
      final notCancelled = _db.sales.cancelledAt.isNull();

      final cashRes = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('CASH') & dateInRange & notCancelled))
          .getSingle();
      final cashSales = cashRes.read(_db.sales.totalAmount.sum()) ?? 0.0;

      final debitRes = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('CARD_DEBIT') & dateInRange & notCancelled))
          .getSingle();
      final cardDebit = debitRes.read(_db.sales.totalAmount.sum()) ?? 0.0;

      final creditRes = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('CARD_CREDIT') & dateInRange & notCancelled))
          .getSingle();
      final cardCredit = creditRes.read(_db.sales.totalAmount.sum()) ?? 0.0;

      final transferRes = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('TRANSFER') & dateInRange & notCancelled))
          .getSingle();
      final transferSales = transferRes.read(_db.sales.totalAmount.sum()) ?? 0.0;

      final movementsCajaNet = await getMovementsCajaNetForShift(shift.id);

      result.add(ClosureDayRow(
        shiftId: shift.id,
        startTime: shift.startTime,
        endTime: endTime,
        closingTime: closure.closingTime,
        startingFund: shift.startingFund,
        cashSales: cashSales,
        cardDebit: cardDebit,
        cardCredit: cardCredit,
        transferSales: transferSales,
        movementsCajaNet: movementsCajaNet,
        systemExpectedCash: closure.systemExpectedCash,
        declaredCash: closure.declaredCash,
        difference: closure.difference,
        notes: closure.notes,
      ));
    }
    return result;
  }

  /// Ventas en un rango de fechas: total, cantidad de ventas, desglose por método de pago.
  Future<SalesReportSummary> getSalesReportSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final salesInRange = await (_db.select(_db.sales)
          ..where((s) =>
              s.cancelledAt.isNull() &
              s.date.isBiggerOrEqualValue(start) &
              s.date.isSmallerOrEqualValue(endOfDay)))
        .get();

    double total = 0;
    int count = 0;
    double cash = 0, cardDebit = 0, cardCredit = 0, transfer = 0;
    for (final s in salesInRange) {
      total += s.totalAmount;
      count++;
      switch (s.paymentMethod) {
        case 'CASH':
          cash += s.totalAmount;
          break;
        case 'CARD_DEBIT':
          cardDebit += s.totalAmount;
          break;
        case 'CARD_CREDIT':
          cardCredit += s.totalAmount;
          break;
        case 'TRANSFER':
          transfer += s.totalAmount;
          break;
        default:
          cash += s.totalAmount;
      }
    }
    return SalesReportSummary(
      totalAmount: total,
      saleCount: count,
      cash: cash,
      cardDebit: cardDebit,
      cardCredit: cardCredit,
      transfer: transfer,
    );
  }

  /// Productos más vendidos en un rango de fechas (por monto).
  Future<List<ProductSalesRow>> getTopProductsByDateRange({
    required DateTime start,
    required DateTime end,
    int limit = 20,
  }) async {
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
      innerJoin(_db.products, _db.products.id.equalsExp(_db.saleItems.productId)),
    ])
      ..where(_db.sales.cancelledAt.isNull() &
          _db.sales.date.isBiggerOrEqualValue(start) &
          _db.sales.date.isSmallerOrEqualValue(endOfDay));

    final rows = await query.get();
    final byProduct = <String, ({double qty, double revenue})>{};
    for (final row in rows) {
      final saleItem = row.readTable(_db.saleItems);
      final product = row.readTable(_db.products);
      final name = product.name;
      final qty = saleItem.quantity;
      final revenue = saleItem.quantity * saleItem.unitPrice;
      final prev = byProduct[name] ?? (qty: 0.0, revenue: 0.0);
      byProduct[name] = (qty: prev.qty + qty, revenue: prev.revenue + revenue);
    }
    final list = byProduct.entries
        .map((e) => ProductSalesRow(
              productName: e.key,
              quantitySold: e.value.qty,
              revenue: e.value.revenue,
            ))
        .toList();
    list.sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  /// Resumen de inventario: todos los insumos con stock actual, punto de reorden y valor.
  Future<List<InventoryReportRow>> getInventoryReport() async {
    final supplies = await _db.select(_db.supplies).get();
    return supplies
        .map((s) => InventoryReportRow(
              supplyId: s.id,
              supplyName: s.name,
              unit: s.unit,
              currentStock: s.currentStock,
              reorderPoint: s.reorderPoint,
              costPerUnit: s.costPerUnit,
              category: s.category,
            ))
        .toList();
  }

  /// Insumos con stock por debajo del punto de reorden.
  Future<List<InventoryReportRow>> getLowStockSupplies() async {
    final list = await getInventoryReport();
    return list.where((r) => r.currentStock < r.reorderPoint).toList();
  }

  /// Movimientos de inventario en un rango (SALE, PURCHASE, WASTE).
  Future<List<InventoryLogRow>> getInventoryLogsSummary({
    required DateTime start,
    required DateTime end,
    int limit = 100,
  }) async {
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final query = _db.select(_db.inventoryLogs).join([
      innerJoin(_db.supplies, _db.supplies.id.equalsExp(_db.inventoryLogs.supplyId)),
    ])
      ..where(_db.inventoryLogs.date.isBiggerOrEqualValue(start) &
          _db.inventoryLogs.date.isSmallerOrEqualValue(endOfDay))
      ..orderBy([OrderingTerm.desc(_db.inventoryLogs.date)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map((row) {
          final log = row.readTable(_db.inventoryLogs);
          final supply = row.readTable(_db.supplies);
          return InventoryLogRow(
            supplyName: supply.name,
            unit: supply.unit,
            changeAmount: log.changeAmount,
            reason: log.reason,
            date: log.date,
          );
        })
        .toList();
  }
}

/// Resumen de ventas para reportes.
class SalesReportSummary {
  const SalesReportSummary({
    required this.totalAmount,
    required this.saleCount,
    required this.cash,
    required this.cardDebit,
    required this.cardCredit,
    required this.transfer,
  });
  final double totalAmount;
  final int saleCount;
  final double cash;
  final double cardDebit;
  final double cardCredit;
  final double transfer;
  double get card => cardDebit + cardCredit;
}

/// Fila de ventas por producto.
class ProductSalesRow {
  const ProductSalesRow({
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });
  final String productName;
  final double quantitySold;
  final double revenue;
}

/// Fila de reporte de inventario.
class InventoryReportRow {
  const InventoryReportRow({
    required this.supplyId,
    required this.supplyName,
    required this.unit,
    required this.currentStock,
    required this.reorderPoint,
    required this.costPerUnit,
    this.category,
  });
  final int supplyId;
  final String supplyName;
  final String unit;
  final double currentStock;
  final double reorderPoint;
  final double costPerUnit;
  final String? category;
  double get value => currentStock * costPerUnit;
  bool get isLowStock => currentStock < reorderPoint;
}

/// Fila de movimiento de inventario.
class InventoryLogRow {
  const InventoryLogRow({
    required this.supplyName,
    required this.unit,
    required this.changeAmount,
    required this.reason,
    required this.date,
  });
  final String supplyName;
  final String unit;
  final double changeAmount;
  final String reason;
  final DateTime date;
}

/// Fila del reporte Rayos X: un corte (cierre de turno) con resumen de ventas y caja.
class ClosureDayRow {
  const ClosureDayRow({
    required this.shiftId,
    required this.startTime,
    required this.endTime,
    required this.closingTime,
    required this.startingFund,
    required this.cashSales,
    required this.cardDebit,
    required this.cardCredit,
    required this.transferSales,
    required this.movementsCajaNet,
    required this.systemExpectedCash,
    required this.declaredCash,
    required this.difference,
    this.notes,
  });

  final int shiftId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime closingTime;
  final double startingFund;
  final double cashSales;
  final double cardDebit;
  final double cardCredit;
  final double transferSales;
  /// Neto de movimientos (entradas - salidas) de caja en ese turno.
  final double movementsCajaNet;
  final double systemExpectedCash;
  final double declaredCash;
  final double difference;
  final String? notes;

  double get cardSales => cardDebit + cardCredit;
  double get totalSales => cashSales + cardSales + transferSales;
}

@riverpod
PosRepository posRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return PosRepository(db);
}
