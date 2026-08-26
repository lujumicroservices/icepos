import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ice_pos/src/core/config/register_scope.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/operation_log_level.dart';
import 'package:ice_pos/src/core/services/operation_log_sink.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/category_image_service.dart';
import 'package:ice_pos/src/core/services/pending_cashier_approvals_cloud_service.dart';
import 'package:ice_pos/src/core/services/product_image_service.dart';
import 'package:ice_pos/src/core/services/modifier_option_image_service.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/core/services/sync_coordinator.dart';
import 'package:ice_pos/src/core/shift/shift_linkage.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart' as domain;
import 'package:ice_pos/src/features/pos/data/sale_receipt_print_mapper.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_print_data.dart';
import 'package:ice_pos/src/features/pos/domain/sale_payment.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:ice_pos/src/features/pos/domain/discount_type.dart';
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
    this.modifierDetails = const [],
  });

  final String productName;
  final double quantity;
  final double priceAtSale;
  final List<String> modifierDetails;
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
  DateTime? _lastReconcileOpenShifts;

  /// Evita dos filas locales idénticas por doble toque o reintento con mala red.
  static const Duration _kMovementIdempotencyWindow = Duration(seconds: 10);

  Future<Movement?> _recentMovementWithSameFingerprint({
    required String type,
    required String account,
    required double amount,
    required String reason,
    int? shiftId,
  }) async {
    final since = DateTime.now().subtract(_kMovementIdempotencyWindow);
    return (_db.select(_db.movements)
          ..where((m) {
            final base = m.type.equals(type) &
                m.account.equals(account) &
                m.amount.equals(amount) &
                m.reason.equals(reason) &
                m.date.isBiggerOrEqualValue(since);
            if (shiftId != null) {
              return base & m.shiftId.equals(shiftId);
            }
            return base & m.shiftId.isNull();
          })
          ..orderBy([(m) => OrderingTerm.desc(m.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Persists a diagnostic row (sale failures, cloud sync issues). Never throws.
  Future<void> logOperationEvent({
    required String level,
    required String operation,
    required String message,
    Map<String, Object?>? context,
    StackTrace? stackTrace,
  }) async {
    await OperationLogSink.report(
      level: level,
      operation: operation,
      message: message,
      context: context,
      stackTrace: stackTrace,
    );
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
    if (CloudSyncService.isEnabled) {
      final (cerr, cloudId) = await CloudSyncService.insertCategoryRowInCloud(
        name: name.trim(),
        parentId: parentId,
        color: color,
        imageUrl: newImageBytes != null ? null : imageUrl,
      );
      if (cerr != null) {
        throw StateError(cerr);
      }
      final cid = cloudId!;
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: Value(cid),
              name: name.trim(),
              parentId: Value(parentId),
              color: Value(color),
              imageUrl: newImageBytes != null ? const Value.absent() : Value(imageUrl),
            ),
          );
      if (newImageBytes != null && newImageBytes.isNotEmpty) {
        final url = await CategoryImageService.uploadCategoryImage(
          categoryId: cid,
          bytes: Uint8List.fromList(newImageBytes),
          mimeType: newImageMimeType ?? 'image/jpeg',
        );
        if (url != null) {
          await (_db.update(_db.categories)..where((c) => c.id.equals(cid)))
              .write(CategoriesCompanion(imageUrl: Value(url)));
          final uerr = await CloudSyncService.upsertCategoryToCloud(
            id: cid,
            name: name.trim(),
            parentId: parentId,
            color: color,
            imageUrl: url,
          );
          if (uerr != null) {
            debugPrint('insertCategory image upsert: $uerr');
          }
        }
      }
      return cid;
    }

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
    final existing = await getCategory(id);
    if (existing == null) {
      throw StateError('Category $id not found');
    }
    String? uploadedUrl;
    if (newImageBytes != null && newImageBytes.isNotEmpty) {
      uploadedUrl = await CategoryImageService.uploadCategoryImage(
        categoryId: id,
        bytes: Uint8List.fromList(newImageBytes),
        mimeType: newImageMimeType ?? 'image/jpeg',
      );
    }
    final mergedName = name?.trim() ?? existing.name;
    final mergedParent = parentId ?? existing.parentId;
    final mergedColor = color ?? existing.color;
    final mergedImageUrl = uploadedUrl ?? (newImageBytes == null ? imageUrl : existing.imageUrl);

    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.upsertCategoryToCloud(
        id: id,
        name: mergedName,
        parentId: mergedParent,
        color: mergedColor,
        imageUrl: mergedImageUrl,
      );
      if (err != null) {
        throw StateError(err);
      }
    }

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

    if (uploadedUrl != null) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(imageUrl: Value(uploadedUrl)));
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
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.deleteCategoryFromCloud(id);
      if (err != null) {
        throw StateError(err);
      }
    }
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
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

  /// Top sellers for the POS strip: ranked from **Supabase** (`pos_top_selling_product_ids`
  /// RPC), not from local `sale_items`. Local Drift is only used to resolve [Product]
  /// rows (name, price, image) from cloud product ids. Refreshes on first load,
  /// connectivity return, and local products cache changes (no periodic polling).
  Stream<List<Product>> watchPosTopSellingProducts({
    int limit = 12,
    int lookbackDays = 30,
  }) {
    if (limit < 1) return Stream.value([]);
    final safeDays = lookbackDays.clamp(1, 366);
    return Stream<List<Product>>.multi((controller) {
      var isReloading = false;
      Future<void> reload() async {
        if (isReloading) return;
        isReloading = true;
        try {
          final list = await getPosTopSellingProducts(
            limit: limit,
            lookbackDays: safeDays,
          );
          if (!controller.isClosed) {
            controller.add(list);
          }
        } catch (e, st) {
          if (!controller.isClosed) {
            controller.addError(e, st);
          }
        } finally {
          isReloading = false;
        }
      }

      final subProducts =
          (_db.select(_db.products)..limit(1)).watch().listen((_) => reload());
      final subOnline = ConnectivityService.instance.onConnectivityChanged.listen(
        (online) {
          if (online) {
            unawaited(reload());
          }
        },
      );

      controller.onCancel = () {
        subProducts.cancel();
        subOnline.cancel();
      };

      unawaited(reload());
    });
  }

  /// One-shot top sellers from Supabase for the active store; empty if offline,
  /// cloud disabled, or RPC returns no rows.
  Future<List<Product>> getPosTopSellingProducts({
    int limit = 12,
    int lookbackDays = 30,
  }) async {
    if (limit < 1) return [];
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) {
      return [];
    }
    final safeDays = lookbackDays.clamp(1, 366);
    const sqlBuffer = 48;
    final takeIds = limit + sqlBuffer;
    final storeId = await StoreScope.getActiveStoreId();
    final ids = await SalesSyncService.fetchTopSellingProductIdsFromCloud(
      days: safeDays,
      limit: takeIds,
      storeId: storeId,
    );
    if (ids.isEmpty) return [];
    final products =
        await (_db.select(_db.products)..where((p) => p.id.isIn(ids))).get();
    final byId = {for (final p in products) p.id: p};
    final out = <Product>[];
    for (final id in ids) {
      final p = byId[id];
      if (p != null) {
        out.add(p);
        if (out.length >= limit) break;
      }
    }
    return out;
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
    final p = await getProduct(productId);
    if (p == null) return;
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.upsertProductToCloud(
        id: p.id,
        name: p.name,
        price: p.price,
        employeePrice: p.employeePrice,
        categoryId: p.categoryId,
        isActive: active,
        imageUrl: p.imageUrl,
      );
      if (err != null) {
        throw StateError(err);
      }
    }
    await (_db.update(_db.products)..where((pr) => pr.id.equals(productId)))
        .write(ProductsCompanion(isActive: Value(active)));
  }

  /// Deletes a product and its recipes and product_modifiers.
  /// Throws StateError if the product has any sales (sale_items).
  Future<void> deleteProduct(int productId) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final saleCount = await (_db.selectOnly(_db.saleItems)
          ..addColumns([_db.saleItems.id.count()])
          ..where(_db.saleItems.productId.equals(productId)))
        .getSingle();
    if ((saleCount.read(_db.saleItems.id.count()) ?? 0) > 0) {
      throw StateError(
        'No se puede eliminar: el producto tiene ventas asociadas. Desactívalo en su lugar.',
      );
    }
    if (CloudSyncService.isEnabled) {
      var err = await CloudSyncService.deleteRecipesForProductFromCloud(productId);
      if (err != null) throw StateError(err);
      err = await CloudSyncService.deleteModifiersForProductFromCloud(productId);
      if (err != null) throw StateError(err);
      err = await CloudSyncService.deleteProductFromCloud(productId);
      if (err != null) throw StateError(err);
    }
    await _db.transaction(() async {
      await (_db.delete(_db.recipes)..where((r) => r.productId.equals(productId)))
          .go();
      await (_db.delete(_db.productModifiers)
            ..where((pm) => pm.productId.equals(productId)))
          .go();
      await (_db.delete(_db.products)..where((p) => p.id.equals(productId)))
          .go();
    });
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
    double? employeePrice,
    int? categoryId,
    String? imageUrl,
    List<int>? newImageBytes,
    String? newImageMimeType,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<({
      String name,
      int minSelection,
      int maxSelection,
      List<({
        int supplyId,
        double quantityDeducted,
        double priceExtra,
        String? imageUrl,
        List<int>? newImageBytes,
        String? newImageMimeType,
      })> options,
    })> modifierGroups,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final optionImageUploads =
        <({int optionId, List<int> bytes, String mime})>[];
    final savedProductId = await _db.transaction(() async {
      int id;
      if (productId == null) {
        id = await _db.into(_db.products).insert(
              ProductsCompanion.insert(
                name: name,
                price: price,
                employeePrice: Value(employeePrice),
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
          employeePrice: Value(employeePrice),
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
          final hasNewBytes =
              opt.newImageBytes != null && opt.newImageBytes!.isNotEmpty;
          final optionId = await _db.into(_db.modifierOptions).insert(
                ModifierOptionsCompanion.insert(
                  modifierGroupId: groupId,
                  supplyId: opt.supplyId,
                  quantityDeducted: opt.quantityDeducted,
                  priceExtra: Value(opt.priceExtra),
                  imageUrl: hasNewBytes
                      ? const Value.absent()
                      : Value(opt.imageUrl),
                ),
              );
          if (hasNewBytes) {
            optionImageUploads.add((
              optionId: optionId,
              bytes: opt.newImageBytes!,
              mime: opt.newImageMimeType ?? 'image/jpeg',
            ));
          }
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

    for (final upload in optionImageUploads) {
      final url = await ModifierOptionImageService.uploadModifierOptionImage(
        optionId: upload.optionId,
        bytes: Uint8List.fromList(upload.bytes),
        mimeType: upload.mime,
      );
      if (url != null) {
        await (_db.update(_db.modifierOptions)
              ..where((o) => o.id.equals(upload.optionId)))
            .write(ModifierOptionsCompanion(imageUrl: Value(url)));
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
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.deleteBundleFromCloud(id);
      if (err != null) {
        throw StateError(err);
      }
    }
    await (_db.delete(_db.bundleItems)
          ..where((bi) => bi.bundleId.equals(id)))
        .go();
    await (_db.delete(_db.bundles)..where((b) => b.id.equals(id))).go();
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

  /// Active catalog discounts for the POS picker, ordered by label then code.
  Stream<List<Discount>> watchActiveDiscountsCatalog() {
    return (_db.select(_db.discounts)
          ..where((d) => d.isActive.equals(true))
          ..orderBy([
            (d) => OrderingTerm.asc(d.description),
            (d) => OrderingTerm.asc(d.code),
          ]))
        .watch();
  }

  /// One-shot active discounts (e.g. before opening the discount dialog).
  Future<List<Discount>> getActiveDiscountsCatalog() {
    return (_db.select(_db.discounts)
          ..where((d) => d.isActive.equals(true))
          ..orderBy([
            (d) => OrderingTerm.asc(d.description),
            (d) => OrderingTerm.asc(d.code),
          ]))
        .get();
  }

  /// All discounts for admin (includes inactive).
  Future<List<Discount>> getAllDiscountsAdmin() {
    return (_db.select(_db.discounts)
          ..orderBy([
            (d) => OrderingTerm.asc(d.description),
            (d) => OrderingTerm.asc(d.code),
          ]))
        .get();
  }

  Stream<List<Discount>> watchDiscounts() {
    return (_db.select(_db.discounts)
          ..orderBy([(d) => OrderingTerm.asc(d.code)]))
        .watch();
  }

  Future<List<Discount>> getDiscounts() async {
    return (_db.select(_db.discounts)
          ..orderBy([(d) => OrderingTerm.asc(d.code)]))
        .get();
  }

  Future<Discount?> getDiscount(int id) async {
    return (_db.select(_db.discounts)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Creates or updates a catalog discount. [type] is [DiscountType.percentage]
  /// or [DiscountType.employee]. [percentage] is 0–1 (e.g. 0.1 = 10%).
  /// [code] is stored uppercase. Pushes to Supabase when cloud sync is enabled.
  Future<int> saveDiscountCatalog({
    int? id,
    required String code,
    String type = DiscountType.percentage,
    required double percentage,
    required String description,
    bool isActive = true,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    final trimmedCode = code.trim().toUpperCase();
    if (trimmedCode.isEmpty) {
      throw ArgumentError('Discount code is required');
    }
    final normalizedType =
        DiscountType.isValid(type) ? type : DiscountType.percentage;
    final pct = normalizedType == DiscountType.employee
        ? 0.0
        : percentage.clamp(0.0, 1.0);
    if (normalizedType == DiscountType.percentage && (pct <= 0 || pct > 1)) {
      throw ArgumentError('percentage must be between 0 and 1');
    }
    final desc = description.trim().isEmpty
        ? (normalizedType == DiscountType.employee
            ? 'Precio empleado'
            : 'Discount')
        : description.trim();

    if (id == null) {
      final newId = await _db.into(_db.discounts).insert(
            DiscountsCompanion.insert(
              code: trimmedCode,
              type: Value(normalizedType),
              percentage: pct,
              description: desc,
              isActive: Value(isActive),
            ),
          );
      if (CloudSyncService.isEnabled) {
        final err = await CloudSyncService.upsertDiscountToCloud(
          id: newId,
          code: trimmedCode,
          type: normalizedType,
          percentage: pct,
          description: desc,
          isActive: isActive,
        );
        if (err != null) throw StateError(err);
      }
      return newId;
    }

    await (_db.update(_db.discounts)..where((d) => d.id.equals(id))).write(
      DiscountsCompanion(
        code: Value(trimmedCode),
        type: Value(normalizedType),
        percentage: Value(pct),
        description: Value(desc),
        isActive: Value(isActive),
      ),
    );
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.upsertDiscountToCloud(
        id: id,
        code: trimmedCode,
        type: normalizedType,
        percentage: pct,
        description: desc,
        isActive: isActive,
      );
      if (err != null) throw StateError(err);
    }
    return id;
  }

  /// Alias for [saveDiscountCatalog] used by the discount editor screen.
  Future<int> saveDiscount({
    int? id,
    required String code,
    required String type,
    required double percentage,
    required String description,
    bool isActive = true,
  }) =>
      saveDiscountCatalog(
        id: id,
        code: code,
        type: type,
        percentage: percentage,
        description: description,
        isActive: isActive,
      );

  /// Deletes a catalog discount locally and in Supabase when enabled.
  Future<void> deleteDiscountCatalog(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.deleteDiscountFromCloud(id);
      if (err != null) throw StateError(err);
    }
    await (_db.delete(_db.discounts)..where((d) => d.id.equals(id))).go();
  }

  Future<void> deleteDiscount(int id) => deleteDiscountCatalog(id);

  /// Applies employee prices from [assets/data/precios_empleado.json].
  /// Returns the number of products updated.
  Future<int> applyEmployeePricesFromAsset() async {
    final raw = await rootBundle.loadString('assets/data/precios_empleado.json');
    final list = jsonDecode(raw) as List<dynamic>;
    var updated = 0;
    await _db.transaction(() async {
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final id = map['id'];
        final price = map['employeePrice'];
        if (id == null || price == null) continue;
        final productId = id is int ? id : int.tryParse(id.toString());
        final empPrice = price is num
            ? price.toDouble()
            : double.tryParse(price.toString());
        if (productId == null || empPrice == null) continue;
        final n = await (_db.update(_db.products)
              ..where((p) => p.id.equals(productId)))
            .write(ProductsCompanion(employeePrice: Value(empPrice)));
        updated += n;
      }
    });
    return updated;
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
      if (CloudSyncService.isEnabled) {
        final initialStock = mode == StockCountMode.qualitative && qualStock != null
            ? qualStock!
            : 0.0;
        // Serialize with catalog sync so SQLite isn't locked mid-replace.
        return SyncCoordinator.synchronized(() async {
          final (cerr, cloudId) = await CloudSyncService.insertSupplyRowInCloud(
            name: name,
            unit: unit,
            currentStock: initialStock,
            costPerUnit: costPerUnit,
            reorderPoint: reorderPoint,
            category: cat,
            stockCountMode: mode,
            qualitativeLevel: qLevel,
          );
          if (cerr != null) {
            throw StateError(cerr);
          }
          final sid = cloudId!;
          await _db.into(_db.supplies).insert(
                SuppliesCompanion.insert(
                  id: Value(sid),
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
          return sid;
        });
      }
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
      return newId;
    } else {
      final existing = await (_db.select(_db.supplies)..where((s) => s.id.equals(id)))
          .getSingleOrNull();
      if (existing == null) {
        throw StateError('Supply id=$id not found');
      }
      final mergedStock = mode == StockCountMode.qualitative && qualStock != null
          ? qualStock!
          : existing.currentStock;

      if (CloudSyncService.isEnabled) {
        final err = await CloudSyncService.upsertSupplyToCloud(
          id: id,
          name: name,
          unit: unit,
          currentStock: mergedStock,
          costPerUnit: costPerUnit,
          reorderPoint: reorderPoint,
          category: cat,
          stockCountMode: mode,
          qualitativeLevel: mode == StockCountMode.qualitative ? qLevel : null,
        );
        if (err != null) {
          throw StateError(err);
        }
      }

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
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.deleteSupplyFromCloud(id);
      if (err != null) {
        throw StateError(err);
      }
    }
    await (_db.delete(_db.supplies)..where((s) => s.id.equals(id))).go();
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

  /// Nombres de insumos (sabores) para etiquetas en ticket.
  Future<Map<int, String>> getSupplyNamesByIds(Set<int> supplyIds) async {
    if (supplyIds.isEmpty) return {};
    final rows = await (_db.select(_db.supplies)..where((s) => s.id.isIn(supplyIds))).get();
    return {for (final s in rows) s.id: s.name};
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
      final cloudErr = await CloudSyncService.softCancelSaleInCloud(sale.cloudSaleId!);
      if (cloudErr != null) {
        await logOperationEvent(
          level: OperationLogLevel.critical,
          operation: 'sale_cancel_cloud_sync',
          message: cloudErr,
          context: {'localSaleId': saleId, 'cloudSaleId': sale.cloudSaleId},
        );
      }
    }
    try {
      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId)))
          .write(SalesCompanion(cancelledAt: Value(DateTime.now())));
    } catch (e, st) {
      await logOperationEvent(
        level: OperationLogLevel.critical,
        operation: 'sale_cancel_local_update',
        message: e.toString(),
        context: {'localSaleId': saleId},
        stackTrace: st,
      );
      rethrow;
    }
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
    await _db.delete(_db.pendingCashierApprovals).go();
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
      leftOuterJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])
      ..where(_db.sales.cancelledAt.isNull())
      ..orderBy([OrderingTerm.desc(_db.sales.date)]);

    return query.watch().asyncMap((rows) async {
      final supplies = await (_db.select(_db.supplies).get());
      final supplyIdToName = {for (final s in supplies) s.id: s.name};

      final grouped = <int, ({Sale sale, List<SaleItemDto> items})>{};
      for (final row in rows) {
        final sale = row.readTable(_db.sales);
        final saleItem = row.readTable(_db.saleItems);
        final product = row.readTableOrNull(_db.products);

        final dto = SaleItemDto(
          productName: product?.name ?? 'Producto (id ${saleItem.productId})',
          quantity: saleItem.quantity,
          priceAtSale: saleItem.unitPrice,
          modifierDetails: SaleReceiptPrintMapper.modifierLabelsFromJson(
            saleItem.modifiersJson,
            supplyIdToName,
          ),
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

  /// Thermal ticket payload for reprinting a past sale.
  Future<ReceiptPrintData?> receiptPrintDataForSale(int saleId) async {
    final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();
    if (sale == null || sale.cancelledAt != null) return null;

    final rows = await (_db.select(_db.saleItems).join([
      leftOuterJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])
          ..where(_db.saleItems.saleId.equals(saleId)))
        .get();

    final supplies = await (_db.select(_db.supplies).get());
    final supplyIdToName = {for (final s in supplies) s.id: s.name};

    final items = rows.map((row) {
      final saleItem = row.readTable(_db.saleItems);
      final product = row.readTableOrNull(_db.products);
      return (
        productName: product?.name ?? 'Producto (id ${saleItem.productId})',
        quantity: saleItem.quantity,
        unitPrice: saleItem.unitPrice,
        modifiersJson: saleItem.modifiersJson,
      );
    }).toList();

    return SaleReceiptPrintMapper.fromLocalSale(
      sale: sale,
      items: items,
      supplyIdToName: supplyIdToName,
    );
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
  /// [paymentMethod] should be CASH, CARD_DEBIT, CARD_CREDIT, TRANSFER, or SPLIT.
  /// [payments] required when [paymentMethod] is SPLIT (stored as [Sales.paymentsJson]).
  /// [amountTendered] and [changeGiven] are stored on the sale record.
  Future<SaleSyncPayload?> processSale(
    List<CartItem> items, {
    Discount? discount,
    double? totalAmount,
    String paymentMethod = 'CASH',
    double amountTendered = 0.0,
    double changeGiven = 0.0,
    List<SalePaymentLine>? payments,
  }) async {
    if (items.isEmpty) return null;

    final paymentsJson = payments != null && payments.isNotEmpty
        ? SalePaymentLine.encodeList(payments)
        : null;

    final shiftForSale = await getCurrentShift();
    if (shiftForSale == null) {
      throw StateError(
        'No hay turno abierto. Abre un turno en «Cierre de caja» antes de cobrar. '
        'There is no open shift. Open a shift before taking sales.',
      );
    }

    var amount = totalAmount ?? items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    if (totalAmount == null &&
        discount != null &&
        !DiscountType.isEmployee(discount.type)) {
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
              paymentsJson: paymentsJson == null
                  ? const Value.absent()
                  : Value(paymentsJson),
              cloudSaleId: const Value.absent(),
              shiftId: shiftForSale.id,
            ),
          );

      for (final item in items) {
        String? modifiersJson;
        if (item.selectedModifiers.isNotEmpty) {
          modifiersJson = jsonEncode(
            item.selectedModifiers
                .map(
                  (m) => ModifierOptionDto(
                    id: m.id,
                    modifierGroupId: m.modifierGroupId,
                    supplyId: m.supplyId,
                    quantityDeducted: m.quantityDeducted,
                    priceExtra: m.priceExtra,
                  ).toJson(),
                )
                .toList(),
          );
        }
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: localSaleId,
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                modifiersJson: modifiersJson == null
                    ? const Value.absent()
                    : Value(modifiersJson),
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
        paymentsJson: paymentsJson,
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
        level: OperationLogLevel.critical,
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

    if (CloudSyncService.isEnabled) {
      if (ConnectivityService.instance.isConnected) {
        unawaited(
          _syncSaleToCloudAfterLocalCommit(
            localSaleId: localSaleId,
            shiftForSale: shiftForSale,
            items: items,
            amount: amount,
            paymentMethod: paymentMethod,
            amountTendered: amountTendered,
            changeGiven: changeGiven,
            paymentsJson: paymentsJson,
            itemsContext: itemsContext,
          ),
        );
      } else {
        await logOperationEvent(
          level: OperationLogLevel.info,
          operation: 'sale_cloud_sync',
          message: 'Sin conexión; la venta quedó registrada solo en este dispositivo.',
          context: {
            'localSaleId': localSaleId,
            'totalAmount': amount,
            'paymentMethod': paymentMethod,
            'items': itemsContext,
            'kind': 'offline_local_only',
          },
        );
      }
    }
    return payload;
  }

  Future<void> _syncSaleToCloudAfterLocalCommit({
    required int localSaleId,
    required Shift shiftForSale,
    required List<CartItem> items,
    required double amount,
    required String paymentMethod,
    required double amountTendered,
    required double changeGiven,
    String? paymentsJson,
    required List<Map<String, Object?>> itemsContext,
  }) async {
    try {
      final cloudSid = CloudSyncService.supabaseShiftId(shiftForSale);
      final (err, cloudId) = await CloudSyncService.writeSaleToCloud(
        items,
        totalAmount: amount,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        changeGiven: changeGiven,
        paymentsJson: paymentsJson,
        cloudShiftId: cloudSid,
      );
      if (err != null) {
        debugPrint('CloudSyncService.writeSaleToCloud (background): $err');
        await logOperationEvent(
          level: OperationLogLevel.critical,
          operation: 'sale_cloud_sync',
          message: err,
          context: {
            'localSaleId': localSaleId,
            'totalAmount': amount,
            'paymentMethod': paymentMethod,
            'items': itemsContext,
          },
        );
        return;
      }
      if (cloudId == null) return;
      await (_db.update(_db.sales)..where((s) => s.id.equals(localSaleId))).write(
            SalesCompanion(cloudSaleId: Value(cloudId)),
          );
    } catch (e, st) {
      await logOperationEvent(
        level: OperationLogLevel.critical,
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
    /// Supabase `shifts.id` when there is no fila local para [shiftId] (p. ej. turno solo en nube).
    int? cloudShiftIdForSync,
  }) async {
    late final int id;
    late final bool reusedExisting;
    try {
      final outcome = await _db.transaction<(int, bool)>(() async {
        final recent = await _recentMovementWithSameFingerprint(
          type: type,
          account: account,
          amount: amount,
          reason: reason,
          shiftId: shiftId,
        );
        if (recent != null) {
          return (recent.id, true);
        }
        final pendingCloud = CloudSyncService.isEnabled &&
            !ConnectivityService.instance.isConnected;
        final newId = await _db.into(_db.movements).insert(
              MovementsCompanion.insert(
                type: type,
                account: account,
                amount: amount,
                reason: reason,
                shiftId: shiftId != null ? Value(shiftId) : const Value.absent(),
                needsCloudSync: Value(pendingCloud),
              ),
            );
        return (newId, false);
      });
      id = outcome.$1;
      reusedExisting = outcome.$2;
    } catch (e, st) {
      await logOperationEvent(
        level: OperationLogLevel.critical,
        operation: 'movement_local_insert',
        message: e.toString(),
        context: {
          'type': type,
          'account': account,
          'amount': amount,
          'reason': reason,
          'shiftId': shiftId,
        },
        stackTrace: st,
      );
      rethrow;
    }
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final movement = await (_db.select(_db.movements)..where((m) => m.id.equals(id))).getSingle();
      final err = await CloudSyncService.writeMovementToCloud(
        movement,
        _db,
        cloudShiftIdOverride: cloudShiftIdForSync,
      );
      if (err == null) {
        await (_db.update(_db.movements)..where((m) => m.id.equals(id))).write(
              const MovementsCompanion(needsCloudSync: Value(false)),
            );
      } else {
        debugPrint(
          reusedExisting ? 'Cloud write movement (idempotent re-sync): $err' : 'Cloud write movement: $err',
        );
        await (_db.update(_db.movements)..where((m) => m.id.equals(id))).write(
              const MovementsCompanion(needsCloudSync: Value(true)),
            );
        await logOperationEvent(
          level: reusedExisting ? OperationLogLevel.warning : OperationLogLevel.critical,
          operation: reusedExisting ? 'movement_cloud_sync_idempotent' : 'movement_cloud_sync',
          message: err,
          context: {
            'localMovementId': id,
            'type': type,
            'account': account,
            'amount': amount,
          },
        );
      }
    }
    return id;
  }

  static const _pendingKindMovement = 'movement';
  static const _pendingKindSaleCancel = 'sale_cancel';
  static const _pendingKindShiftClose = 'shift_close';
  static const _pendingApprovalStatusKey = 'approvalStatus';
  static const _pendingApprovedAtKey = 'approvedAt';

  void _schedulePendingCloudPush(int localId, String kind, Map<String, dynamic> payload) {
    if (!CloudSyncService.isEnabled) return;
    unawaited(_pushPendingRowToCloud(localId, kind, payload));
  }

  Future<void> _pushPendingRowToCloud(int localId, String kind, Map<String, dynamic> payload) async {
    if (!ConnectivityService.instance.isConnected) return;
    final uuid = await PendingCashierApprovalsCloudService.pushLocalPendingRow(
      kind: kind,
      payload: payload,
    );
    if (uuid == null) return;
    await (_db.update(_db.pendingCashierApprovals)..where((t) => t.id.equals(localId))).write(
          PendingCashierApprovalsCompanion(cloudPendingId: Value(uuid)),
        );
  }

  /// Cuando el admin aprueba/rechaza en web, Realtime dispara esta ruta en la caja.
  Future<void> applyCloudResolutionForPending({
    required String cloudId,
    required String status,
    String? kind,
    Map<String, dynamic>? cloudPayload,
  }) async {
    PendingCashierApproval? row = await (_db.select(_db.pendingCashierApprovals)
          ..where((t) => t.cloudPendingId.equals(cloudId)))
        .getSingleOrNull();
    row ??= await _findFallbackPendingRow(kind: kind, cloudPayload: cloudPayload);
    final resolvedRow = row;
    if (resolvedRow == null) return;
    if (status == 'rejected') {
      await (_db.delete(_db.pendingCashierApprovals)
            ..where((t) => t.id.equals(resolvedRow.id)))
          .go();
      return;
    }
    final map = jsonDecode(resolvedRow.payloadJson) as Map<String, dynamic>;
    if (resolvedRow.kind == _pendingKindShiftClose) {
      map[_pendingApprovalStatusKey] = 'approved';
      map[_pendingApprovedAtKey] = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.pendingCashierApprovals)
            ..where((t) => t.id.equals(resolvedRow.id)))
          .write(
            PendingCashierApprovalsCompanion(
              payloadJson: Value(jsonEncode(map)),
            ),
          );
      return;
    }
    await (_db.delete(_db.pendingCashierApprovals)
          ..where((t) => t.id.equals(resolvedRow.id)))
        .go();
  }

  Future<PendingCashierApproval?> _findFallbackPendingRow({
    String? kind,
    Map<String, dynamic>? cloudPayload,
  }) async {
    if (kind == null || cloudPayload == null) return null;
    final rows = await (_db.select(_db.pendingCashierApprovals)
          ..where((t) => t.cloudPendingId.isNull() & t.kind.equals(kind)))
        .get();
    for (final row in rows) {
      try {
        final localPayload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        if (_payloadMatchesForResolution(kind, localPayload, cloudPayload)) {
          return row;
        }
      } catch (_) {}
    }
    return null;
  }

  bool _payloadMatchesForResolution(
    String kind,
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    switch (kind) {
      case _pendingKindMovement:
        return local['type'] == cloud['type'] &&
            local['account'] == cloud['account'] &&
            (local['reason'] ?? '') == (cloud['reason'] ?? '') &&
            ((local['amount'] as num?)?.toDouble() ?? 0) ==
                ((cloud['amount'] as num?)?.toDouble() ?? 0);
      case _pendingKindSaleCancel:
        return (local['saleId'] as num?)?.toInt() == (cloud['saleId'] as num?)?.toInt();
      case _pendingKindShiftClose:
        return (local['shiftId'] as num?)?.toInt() == (cloud['shiftId'] as num?)?.toInt();
      default:
        return false;
    }
  }

  /// Solicitudes de cajero pendientes de aprobación (mismo terminal).
  Stream<List<PendingCashierApproval>> watchPendingCashierApprovals() {
    return (_db.select(_db.pendingCashierApprovals)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Snapshot de solicitudes pendientes (mismo terminal).
  Future<List<PendingCashierApproval>> getPendingCashierApprovals() {
    return (_db.select(_db.pendingCashierApprovals)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> countPendingCashierApprovals() async {
    final q = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM pending_cashier_approvals',
      readsFrom: {_db.pendingCashierApprovals},
    ).getSingle();
    final raw = q.data['c'];
    if (raw is int) return raw;
    if (raw is BigInt) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  Future<int> enqueuePendingMovement({
    required String type,
    required String account,
    required double amount,
    required String reason,
    int? shiftId,
    int? cloudShiftId,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      'account': account,
      'amount': amount,
      'reason': reason,
      if (shiftId != null) 'shiftId': shiftId,
      if (cloudShiftId != null) 'cloudShiftId': cloudShiftId,
    };
    final id = await _db.into(_db.pendingCashierApprovals).insert(
          PendingCashierApprovalsCompanion.insert(
            kind: _pendingKindMovement,
            payloadJson: jsonEncode(payload),
          ),
        );
    _schedulePendingCloudPush(id, _pendingKindMovement, Map<String, dynamic>.from(payload));
    return id;
  }

  Future<int> enqueuePendingSaleCancel(int saleId) async {
    final payload = <String, dynamic>{'saleId': saleId};
    final id = await _db.into(_db.pendingCashierApprovals).insert(
          PendingCashierApprovalsCompanion.insert(
            kind: _pendingKindSaleCancel,
            payloadJson: jsonEncode(payload),
          ),
        );
    _schedulePendingCloudPush(id, _pendingKindSaleCancel, Map<String, dynamic>.from(payload));
    return id;
  }

  /// Incluye [expectedCash] y [difference] solo para mostrar al admin (al aprobar se recalcula en servidor local).
  Future<int> enqueuePendingShiftClose({
    required int shiftId,
    required double declaredCash,
    String? notes,
    double? expectedCash,
    double? difference,
    int? cloudShiftId,
  }) async {
    final existing = await _db.select(_db.pendingCashierApprovals).get();
    for (final e in existing) {
      if (e.kind != _pendingKindShiftClose) continue;
      final m = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      if ((m['shiftId'] as num?)?.toInt() == shiftId) {
        throw StateError('pending_shift_close_exists');
      }
    }
    final payload = <String, dynamic>{
      'shiftId': shiftId,
      'declaredCash': declaredCash,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (expectedCash != null) 'expectedCash': expectedCash,
      if (difference != null) 'difference': difference,
      if (cloudShiftId != null) 'cloudShiftId': cloudShiftId,
    };
    final id = await _db.into(_db.pendingCashierApprovals).insert(
          PendingCashierApprovalsCompanion.insert(
            kind: _pendingKindShiftClose,
            payloadJson: jsonEncode(payload),
          ),
        );
    _schedulePendingCloudPush(id, _pendingKindShiftClose, Map<String, dynamic>.from(payload));
    return id;
  }

  Future<void> clearPendingShiftCloseForShift(int shiftId) async {
    final rows = await _db.select(_db.pendingCashierApprovals).get();
    for (final row in rows) {
      if (row.kind != _pendingKindShiftClose) continue;
      try {
        final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        if ((payload['shiftId'] as num?)?.toInt() != shiftId) continue;
        await (_db.delete(_db.pendingCashierApprovals)..where((t) => t.id.equals(row.id))).go();
      } catch (_) {}
    }
  }

  /// Ejecuta la acción y elimina la fila. Devuelve mensaje de error o null si OK.
  Future<String?> approvePendingCashierApproval(int id) async {
    final row = await (_db.select(_db.pendingCashierApprovals)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return 'approval_not_found';
    final cloudId = row.cloudPendingId;
    final map = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    try {
      switch (row.kind) {
        case _pendingKindMovement:
          final account = map['account']! as String;
          final resolved = await resolveMovementShiftForInsert(
            account: account,
            pickedLocalShiftId: (map['shiftId'] as num?)?.toInt(),
            pickedCloudShiftId: (map['cloudShiftId'] as num?)?.toInt(),
          );
          await insertMovement(
            type: map['type']! as String,
            account: account,
            amount: (map['amount'] as num).toDouble(),
            reason: map['reason']! as String,
            shiftId: resolved.localShiftId,
            cloudShiftIdForSync: resolved.cloudShiftIdForSync,
          );
          break;
        case _pendingKindSaleCancel:
          await deleteSale((map['saleId'] as num).toInt());
          break;
        case _pendingKindShiftClose:
          await performCloseShift(
            shiftId: (map['shiftId'] as num).toInt(),
            declaredCash: (map['declaredCash'] as num).toDouble(),
            notes: map['notes'] as String?,
          );
          await startShift((map['declaredCash'] as num).toDouble());
          break;
        default:
          return 'approval_unknown_kind';
      }
    } catch (e) {
      return e.toString();
    }
    await (_db.delete(_db.pendingCashierApprovals)..where((t) => t.id.equals(id))).go();
    if (cloudId != null &&
        CloudSyncService.isEnabled &&
        ConnectivityService.instance.isConnected) {
      await PendingCashierApprovalsCloudService.markResolvedOnCloud(cloudId, 'approved');
    }
    return null;
  }

  Future<void> rejectPendingCashierApproval(int id) async {
    final row = await (_db.select(_db.pendingCashierApprovals)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final cloudId = row.cloudPendingId;
    await (_db.delete(_db.pendingCashierApprovals)..where((t) => t.id.equals(id))).go();
    if (cloudId != null &&
        CloudSyncService.isEnabled &&
        ConnectivityService.instance.isConnected) {
      await PendingCashierApprovalsCloudService.markResolvedOnCloud(cloudId, 'rejected');
    }
  }

  /// Lista de movimientos activos (no cancelados), ordenados por fecha descendente.
  Stream<List<Movement>> watchMovements({String? account, int limit = 200}) {
    if (account != null) {
      return (_db.select(_db.movements)
            ..where((m) => m.account.equals(account) & m.cancelledAt.isNull())
            ..orderBy([(m) => OrderingTerm.desc(m.date)])
            ..limit(limit))
          .watch();
    }
    return (_db.select(_db.movements)
          ..where((m) => m.cancelledAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.date)])
          ..limit(limit))
        .watch();
  }

  /// Admin: borrado lógico local + nube.
  Future<String?> cancelMovement(int movementId) async {
    final now = DateTime.now();
    await (_db.update(_db.movements)..where((m) => m.id.equals(movementId))).write(
          MovementsCompanion(cancelledAt: Value(now)),
        );
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      return CloudSyncService.cancelMovementInCloud(movementId);
    }
    return null;
  }

  /// Ventas del turno por forma de pago (rango [rangeStart, rangeEnd]) y neto de movimientos de caja.
  ///
  /// Incluye ventas con [shiftId] local correcto y ventas con otro `shift_id` pero fecha en el turno
  /// (p. ej. id de nube guardado por error en SQLite). `sales.shift_id` es obligatorio (schema ≥ 22).
  Future<({double cashSales, double debitSales, double creditSales, double transferSales, double movementsCajaNet})>
      _getShiftSalesByPaymentType(
    int shiftId,
    DateTime rangeStart,
    DateTime rangeEnd, {
    Set<int> excludeCloudSaleIds = const <int>{},
  }) async {
    final rows = await (_db.select(_db.sales)..where((s) {
      final dateInRange =
          s.date.isBiggerOrEqualValue(rangeStart) & s.date.isSmallerOrEqualValue(rangeEnd);
      final notCancelled = s.cancelledAt.isNull();
      final forThisShift = s.shiftId.equals(shiftId);
      final mislinkedInRange = dateInRange & s.shiftId.equals(shiftId).not();
      final saleWindow = forThisShift | mislinkedInRange;
      return saleWindow & notCancelled;
    })).get();
    double cash = 0.0;
    double debit = 0.0;
    double credit = 0.0;
    double transfer = 0.0;
    for (final r in rows) {
      final cloudId = r.cloudSaleId;
      if (cloudId != null && excludeCloudSaleIds.contains(cloudId)) continue;
      final breakdown = SalePaymentBreakdown.fromSale(
        paymentMethod: r.paymentMethod,
        totalAmount: r.totalAmount,
        paymentsJson: r.paymentsJson,
      );
      cash += breakdown.cash;
      debit += breakdown.debit;
      credit += breakdown.credit;
      transfer += breakdown.transfer;
    }
    final movementsCajaNet = await getMovementsCajaNetForShift(shiftId);
    return (
      cashSales: cash,
      debitSales: debit,
      creditSales: credit,
      transferSales: transfer,
      movementsCajaNet: movementsCajaNet,
    );
  }

  /// Ids de venta en Supabase ya representados en SQLite (ventas del turno en la ventana local).
  Future<Set<int>> _localCloudSaleIdsInShiftWindow(
    int localShiftId,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final rows = await (_db.select(_db.sales)..where((s) {
      final dateInRange =
          s.date.isBiggerOrEqualValue(rangeStart) & s.date.isSmallerOrEqualValue(rangeEnd);
      final notCancelled = s.cancelledAt.isNull();
      final forThisShift = s.shiftId.equals(localShiftId);
      final mislinkedInRange = dateInRange & s.shiftId.equals(localShiftId).not();
      final saleWindow = forThisShift | mislinkedInRange;
      return saleWindow & notCancelled;
    })).get();
    final ids = <int>{};
    for (final r in rows) {
      final cid = r.cloudSaleId;
      if (cid != null) ids.add(cid);
    }
    return ids;
  }

  /// Cantidad de ventas locales del turno que quedan excluidas por cancelación en nube.
  /// Útil para mostrar un badge informativo en cierre de caja.
  Future<int> countCloudCancelledSalesAppliedToLocalShift(int localShiftId) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localShiftId)))
        .getSingleOrNull();
    if (shift == null) return 0;
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) return 0;
    final cloudSid = CloudSyncService.supabaseShiftId(shift);
    final cancelledIds = await CloudSyncService.fetchCancelledSaleIdsForShift(cloudSid);
    if (cancelledIds.isEmpty) return 0;
    final now = DateTime.now();
    final rows = await (_db.select(_db.sales)..where((s) {
      final dateInRange =
          s.date.isBiggerOrEqualValue(shift.startTime) & s.date.isSmallerOrEqualValue(now);
      final notCancelled = s.cancelledAt.isNull();
      final forThisShift = s.shiftId.equals(localShiftId);
      final mislinkedInRange = dateInRange & s.shiftId.equals(localShiftId).not();
      final saleWindow = forThisShift | mislinkedInRange;
      return saleWindow & notCancelled;
    })).get();
    var count = 0;
    for (final r in rows) {
      final cid = r.cloudSaleId;
      if (cid != null && cancelledIds.contains(cid)) count++;
    }
    return count;
  }

  Future<Set<int>> _localMovementIdsForShift(int localShiftId) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localShiftId)))
        .getSingleOrNull();
    if (shift == null) return {};
    final rows = await (_db.select(_db.movements)
          ..where((m) => m.shiftId.equals(localShiftId) & m.cancelledAt.isNull()))
        .get();
    return rows
        .where((m) => isMovementInShiftWindow(movementDate: m.date, shift: shift))
        .map((e) => e.id)
        .toSet();
  }

  /// Desvincula movimientos con [shiftId] local pero fecha fuera del turno (p. ej. id local
  /// reutilizado o sync de un `shifts.id` antiguo en nube).
  Future<int> reconcileMislinkedMovementsForShift(int localShiftId) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localShiftId)))
        .getSingleOrNull();
    if (shift == null) return 0;
    final rows = await (_db.select(_db.movements)
          ..where((m) => m.shiftId.equals(localShiftId) & m.cancelledAt.isNull()))
        .get();
    var detached = 0;
    for (final m in rows) {
      if (isMovementInShiftWindow(movementDate: m.date, shift: shift)) continue;
      await (_db.update(_db.movements)..where((t) => t.id.equals(m.id))).write(
            const MovementsCompanion(shiftId: Value(null)),
          );
      detached++;
    }
    if (detached > 0) {
      await logOperationEvent(
        level: OperationLogLevel.warning,
        operation: 'movement_shift_reconcile',
        message:
            'Se desvincularon $detached movimiento(s) del turno local $localShiftId '
            '(cloud_shift_id ${shift.cloudShiftId}): fecha fuera del rango del turno.',
        context: {
          'localShiftId': localShiftId,
          'cloudShiftId': shift.cloudShiftId,
          'detachedCount': detached,
        },
      );
    }
    return detached;
  }

  /// Totales del turno: SQLite + filas en nube del mismo `shifts.id` que no están ya enlazadas localmente.
  Future<
      ({
        double cashSales,
        double debitSales,
        double creditSales,
        double transferSales,
        double movementsCajaNet,
        double cloudAddedCash,
        double cloudAddedDebit,
        double cloudAddedCredit,
        double cloudAddedTransfer,
        double cloudAddedMovNet,
      })> _getMergedShiftMonetaryTotals(int localShiftId) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localShiftId)))
        .getSingleOrNull();
    if (shift == null) {
      return (
        cashSales: 0.0,
        debitSales: 0.0,
        creditSales: 0.0,
        transferSales: 0.0,
        movementsCajaNet: 0.0,
        cloudAddedCash: 0.0,
        cloudAddedDebit: 0.0,
        cloudAddedCredit: 0.0,
        cloudAddedTransfer: 0.0,
        cloudAddedMovNet: 0.0,
      );
    }
    final now = DateTime.now();
    final cloudSid = CloudSyncService.supabaseShiftId(shift);
    final cancelledCloudSaleIds = await CloudSyncService.fetchCancelledSaleIdsForShift(cloudSid);
    final local = await _getShiftSalesByPaymentType(
      localShiftId,
      shift.startTime,
      now,
      excludeCloudSaleIds: cancelledCloudSaleIds,
    );
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) {
      return (
        cashSales: local.cashSales,
        debitSales: local.debitSales,
        creditSales: local.creditSales,
        transferSales: local.transferSales,
        movementsCajaNet: local.movementsCajaNet,
        cloudAddedCash: 0.0,
        cloudAddedDebit: 0.0,
        cloudAddedCredit: 0.0,
        cloudAddedTransfer: 0.0,
        cloudAddedMovNet: 0.0,
      );
    }
    final excludedSaleIds = await _localCloudSaleIdsInShiftWindow(localShiftId, shift.startTime, now);
    final localMovIds = await _localMovementIdsForShift(localShiftId);
    final cloudSales = await CloudSyncService.fetchCloudOnlySalesTotalsForShift(
      cloudShiftId: cloudSid,
      excludeCloudSaleIds: excludedSaleIds,
    );
    final cloudMovNet = await CloudSyncService.fetchCloudOnlyCajaMovementNetForShift(
      cloudShiftId: cloudSid,
      excludeCloudMovementIds: localMovIds,
    );
    return (
      cashSales: local.cashSales + cloudSales.cash,
      debitSales: local.debitSales + cloudSales.debit,
      creditSales: local.creditSales + cloudSales.credit,
      transferSales: local.transferSales + cloudSales.transfer,
      movementsCajaNet: local.movementsCajaNet + cloudMovNet,
      cloudAddedCash: cloudSales.cash,
      cloudAddedDebit: cloudSales.debit,
      cloudAddedCredit: cloudSales.credit,
      cloudAddedTransfer: cloudSales.transfer,
      cloudAddedMovNet: cloudMovNet,
    );
  }

  /// Neto de movimientos de caja para un turno: sum(ENTRADA) - sum(SALIDA). Afecta el esperado en caja.
  /// Solo cuenta movimientos cuya fecha cae dentro del turno (evita filas con `shift_id` local erróneo).
  Future<double> getMovementsCajaNetForShift(int shiftId) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shift == null) return 0;
    final rows = await (_db.select(_db.movements)
          ..where((m) =>
              m.account.equals('CAJA') &
              m.shiftId.equals(shiftId) &
              m.cancelledAt.isNull()))
        .get();
    final inWindow = rows.where(
      (m) => isMovementInShiftWindow(movementDate: m.date, shift: shift),
    );
    return netCajaFromMovements(inWindow);
  }

  /// Alinea turnos abiertos locales con Supabase (cierra fantasmas ya cerrados en la nube).
  Future<void> _maybeReconcileOpenShiftsWithCloud() async {
    if (!CloudSyncService.isEnabled) return;
    final now = DateTime.now();
    if (_lastReconcileOpenShifts != null &&
        now.difference(_lastReconcileOpenShifts!) < const Duration(seconds: 25)) {
      return;
    }
    _lastReconcileOpenShifts = now;
    await CloudSyncService.reconcileLocalOpenShiftsWithCloud(_db);
  }

  /// Turnos abiertos en SQLite (puede haber más de uno antes de reconciliar).
  Future<List<Shift>> getOpenShiftsLocal() async {
    await _maybeReconcileOpenShiftsWithCloud();
    return (_db.select(_db.shifts)
          ..where((s) => s.endTime.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.id)]))
        .get();
  }

  /// Resuelve ids de turno para insertar un movimiento de caja en este dispositivo.
  /// Prioriza fila local; si no hay, envía solo a nube con [cloudShiftIdForSync].
  Future<({int? localShiftId, int? cloudShiftIdForSync})> resolveMovementShiftForInsert({
    required String account,
    int? pickedLocalShiftId,
    int? pickedCloudShiftId,
  }) async {
    if (account != 'CAJA') {
      return (localShiftId: null, cloudShiftIdForSync: null);
    }
    if (pickedLocalShiftId != null) {
      return (localShiftId: pickedLocalShiftId, cloudShiftIdForSync: null);
    }
    if (pickedCloudShiftId == null) {
      return (localShiftId: null, cloudShiftIdForSync: null);
    }
    final local = await findOpenLocalShiftForCloudId(pickedCloudShiftId);
    if (local != null) {
      return (localShiftId: local.id, cloudShiftIdForSync: null);
    }
    final cur = await getCurrentShift();
    if (cur != null && CloudSyncService.supabaseShiftId(cur) == pickedCloudShiftId) {
      return (localShiftId: cur.id, cloudShiftIdForSync: null);
    }
    return (localShiftId: null, cloudShiftIdForSync: pickedCloudShiftId);
  }

  /// Trae movimientos recientes de Supabase a SQLite (misma tienda) para verlos en la app.
  Future<void> syncMovementsFromCloudIntoLocal({String? account}) async {
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) {
      return;
    }
    final cloudRows = await CloudSyncService.fetchMovementsFromCloud(account: account);
    if (cloudRows.isEmpty) return;

    final shifts = await _db.select(_db.shifts).get();
    final cloudToLocalShift = buildStrictCloudToLocalShiftMap(shifts);
    final shiftByLocalId = {for (final s in shifts) s.id: s};

    final existingRows = await _db.select(_db.movements).get();
    final existingById = {for (final m in existingRows) m.id: m};

    int? localShiftIdForCloudMovement(Movement cm) {
      final cloudSid = cm.shiftId;
      if (cloudSid == null) return null;
      final localId = cloudToLocalShift[cloudSid];
      if (localId == null) return null;
      final localShift = shiftByLocalId[localId];
      if (localShift == null) return null;
      if (!isMovementInShiftWindow(movementDate: cm.date, shift: localShift)) {
        return null;
      }
      return localId;
    }

    for (final cm in cloudRows) {
      final localShiftId = localShiftIdForCloudMovement(cm);
      final existing = existingById[cm.id];
      if (existing == null) {
        await _db.into(_db.movements).insert(
              MovementsCompanion.insert(
                id: Value(cm.id),
                type: cm.type,
                account: cm.account,
                amount: cm.amount,
                reason: cm.reason,
                date: Value(cm.date),
                shiftId: localShiftId != null
                    ? Value(localShiftId)
                    : const Value.absent(),
                needsCloudSync: const Value(false),
              ),
            );
        continue;
      }
      if (existing.shiftId == null && localShiftId != null) {
        await (_db.update(_db.movements)..where((m) => m.id.equals(cm.id))).write(
              MovementsCompanion(shiftId: Value(localShiftId)),
            );
      }
    }

    final openShift = await getCurrentShift();
    if (openShift != null) {
      await reconcileMislinkedMovementsForShift(openShift.id);
    }

    // Propaga cancelaciones hechas en web/admin.
    final cancelledInCloud = await CloudSyncService.fetchCancelledMovementIdsFromCloud(
      account: account,
    );
    if (cancelledInCloud.isEmpty) return;
    final now = DateTime.now();
    for (final id in cancelledInCloud) {
      final existing = existingById[id];
      if (existing == null || existing.cancelledAt != null) continue;
      await (_db.update(_db.movements)..where((m) => m.id.equals(id))).write(
            MovementsCompanion(cancelledAt: Value(now)),
          );
    }
  }

  /// Fila local abierta cuyo [Shift.cloudShiftId] coincide con `shifts.id` en Supabase.
  ///
  /// No usa el id autoincrement local: evita enlazar el turno nube 74 (cerrado) con el local 74.
  Future<Shift?> findOpenLocalShiftForCloudId(int cloudShiftId) async {
    final openRows = await (_db.select(_db.shifts)..where((s) => s.endTime.isNull())).get();
    return findOpenLocalShiftByCloudId(openRows, cloudShiftId);
  }

  /// Turno abierto actual: mayor [id] entre los abiertos (más reciente en SQLite), no solo por fecha.
  Future<Shift?> getCurrentShift() async {
    await _maybeReconcileOpenShiftsWithCloud();
    final list = await (_db.select(_db.shifts)
          ..where((s) => s.endTime.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .get();
    return list.isEmpty ? null : list.first;
  }

  /// Cierra en local otros turnos que sigan abiertos dejando solo [keepShiftId] (evita fantasma p. ej. 6 al abrir tras cerrar 5).
  Future<void> _closeOtherOpenShiftsExcept(int keepShiftId) async {
    final openRows = await (_db.select(_db.shifts)..where((s) => s.endTime.isNull())).get();
    final now = DateTime.now();
    for (final o in openRows) {
      if (o.id == keepShiftId) continue;
      await (_db.update(_db.shifts)..where((s) => s.id.equals(o.id))).write(
        ShiftsCompanion(endTime: Value(now)),
      );
      await logOperationEvent(
        level: 'warning',
        operation: 'shift_auto_close_stale_open',
        message: 'Turno ${o.id} cerrado automáticamente al abrir el turno $keepShiftId (quedaba abierto en SQLite).',
        context: {'closedShiftId': o.id, 'keptShiftId': keepShiftId},
      );
      if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
        final updated = await (_db.select(_db.shifts)..where((s) => s.id.equals(o.id))).getSingle();
        final err = await CloudSyncService.writeShiftToCloud(updated, _db);
        if (err != null) {
          debugPrint('Cloud write stale shift close: $err');
          await logOperationEvent(
            level: OperationLogLevel.critical,
            operation: 'shift_stale_close_cloud_sync',
            message: err,
            context: {'closedShiftId': o.id, 'keptShiftId': keepShiftId},
          );
        }
      }
    }
  }

  /// Deja de usar en **este dispositivo** los turnos abiertos en SQLite (pone `end_time`
  /// local) sin modificar Supabase: el turno anterior sigue figurando abierto en la nube
  /// hasta un cierre normal en su caja. Solo para enlazar el terminal a otro turno (admin).
  Future<void> _adminUnlinkLocalOpenShiftsForDeviceSwitch({required int exceptCloudShiftId}) async {
    final openRows = await (_db.select(_db.shifts)..where((s) => s.endTime.isNull())).get();
    final now = DateTime.now();
    for (final o in openRows) {
      final cid = CloudSyncService.supabaseShiftId(o);
      if (cid == exceptCloudShiftId) continue;
      await (_db.update(_db.shifts)..where((s) => s.id.equals(o.id))).write(
        ShiftsCompanion(endTime: Value(now)),
      );
      await logOperationEvent(
        level: OperationLogLevel.warning,
        operation: 'admin_unlink_local_shift_for_device_link',
        message:
            'Turno local ${o.id} (nube $cid) desvinculado en este equipo para enlazar otro turno; '
            'no se envió cierre a Supabase.',
        context: {'localShiftId': o.id, 'cloudShiftId': cid},
      );
    }
  }

  /// Mayor `cloud_shift_id` asignado (o 0 si no hay filas).
  Future<int> _maxAssignedCloudShiftId() async {
    final r = await _db
        .customSelect(
          'SELECT COALESCE(MAX(cloud_shift_id), 0) AS m FROM shifts',
          readsFrom: {_db.shifts},
        )
        .getSingle();
    final n = r.data['m'];
    if (n is int) return n;
    if (n is BigInt) return n.toInt();
    return 0;
  }

  /// Starts a new shift with the given starting fund.
  ///
  /// [Shift.id] es autoincrement local (FKs). [Shift.cloudShiftId] es `shifts.id` en Supabase
  /// (`max` en nube + 1 cuando hay conexión; si no, max local de `cloud_shift_id` + 1).
  Future<Shift> startShift(double startingFund) async {
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      await CloudSyncService.reconcileLocalOpenShiftsWithCloud(_db);
    }

    final assignedCloudMax = await _maxAssignedCloudShiftId();
    int nextCloudId;
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final cloudMax = await CloudSyncService.fetchMaxShiftIdFromCloud();
      if (cloudMax != null) {
        nextCloudId = cloudMax + 1;
        if (nextCloudId <= assignedCloudMax) {
          nextCloudId = assignedCloudMax + 1;
          await logOperationEvent(
            level: 'warning',
            operation: 'shift_cloud_id_bumped_local',
            message:
                'Siguiente id nube sería ${cloudMax + 1} pero cloud_shift_id local ya llega a $assignedCloudMax; se usa $nextCloudId.',
            context: {
              'cloudMax': cloudMax,
              'assignedCloudMax': assignedCloudMax,
              'chosenCloudId': nextCloudId,
            },
          );
        }
      } else {
        nextCloudId = assignedCloudMax + 1;
        await logOperationEvent(
          level: 'warning',
          operation: 'shift_id_cloud_max_unavailable',
          message:
              'No se pudo leer max(id) en Supabase; cloud_shift_id = max local asignado + 1 ($nextCloudId).',
          context: {'assignedCloudMax': assignedCloudMax},
        );
      }
    } else {
      nextCloudId = assignedCloudMax + 1;
    }

    final registerId = await RegisterScope.getActiveRegisterId();
    final localId = await _db.into(_db.shifts).insert(
          ShiftsCompanion.insert(
            cloudShiftId: Value(nextCloudId),
            cloudRegisterId: Value(registerId),
            startingFund: Value(startingFund),
          ),
        );
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localId)))
        .getSingle();
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final err = await CloudSyncService.writeShiftToCloud(shift, _db);
      if (err != null) {
        debugPrint('Cloud write shift: $err');
        await logOperationEvent(
          level: OperationLogLevel.critical,
          operation: 'shift_start_cloud_sync',
          message: err,
          context: {'localShiftId': localId, 'cloudShiftId': nextCloudId},
        );
      }
    }
    await _closeOtherOpenShiftsExcept(localId);
    return shift;
  }

  /// Con nube y red: aplica tienda/cajón desde [pos_devices], reconcilia turnos, y si no hay turno local
  /// pero en Supabase hay uno abierto para ese cajón, llama a [adoptOpenShiftFromCloud].
  /// Devuelve mensaje de error solo si la adopción falla; si no hay turno en nube, null.
  Future<String?> syncPosSessionWithCloud() async {
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) {
      return null;
    }
    await CloudSyncService.applyDeviceStoreRegisterFromCloudPrefs();
    final regErr = await CloudSyncService.registerPosDeviceInCloud();
    if (regErr != null) {
      debugPrint('syncPosSessionWithCloud register device: $regErr');
    }
    await CloudSyncService.reconcileLocalOpenShiftsWithCloud(_db);
    final existing = await (_db.select(_db.shifts)
          ..where((s) => s.endTime.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return null;
    final storeId = await StoreScope.getActiveStoreId();
    final registerId = await RegisterScope.getActiveRegisterId();
    var open = await CloudSyncService.fetchOpenShiftForRegisterCloud(
      storeId: storeId,
      registerId: registerId,
    );
    if (open == null || !open.isOpen) {
      final device = await DeviceIdService.getDeviceInfo();
      open = await CloudSyncService.fetchOpenShiftForDeviceCloud(
        device.deviceId,
        storeId: storeId,
      );
    }
    if (open == null || !open.isOpen) return null;
    return adoptOpenShiftFromCloud(open);
  }

  /// Admin: alinea tienda/cajón con el turno en nube y adopta el turno.
  /// Actualiza [pos_devices] en la nube.
  ///
  /// Si hay otro turno abierto en SQLite distinto del elegido, se **desvincula solo en
  /// este dispositivo** (fin local sin enviar cierre a Supabase); el turno anterior sigue
  /// abierto en la nube para su caja o cierre posterior.
  Future<String?> adminLinkDeviceToCloudOpenShift(CloudShiftSummary cloud) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!cloud.isOpen) return 'El turno seleccionado ya está cerrado en la nube.';
    await _maybeReconcileOpenShiftsWithCloud();
    final localOpen0 = await getCurrentShift();
    if (localOpen0 != null) {
      final localCloudId = CloudSyncService.supabaseShiftId(localOpen0);
      if (localCloudId == cloud.id) {
        await StoreScope.setActiveStoreId(cloud.storeId);
        if (cloud.registerId != null && cloud.registerId! >= 1) {
          await RegisterScope.setActiveRegisterId(cloud.registerId!);
        }
        await CloudSyncService.registerPosDeviceInCloud();
        return null;
      }
      await _adminUnlinkLocalOpenShiftsForDeviceSwitch(exceptCloudShiftId: cloud.id);
    }
    await StoreScope.setActiveStoreId(cloud.storeId);
    if (cloud.registerId != null && cloud.registerId! >= 1) {
      await RegisterScope.setActiveRegisterId(cloud.registerId!);
    }
    await _maybeReconcileOpenShiftsWithCloud();
    final localOpen1 = await getCurrentShift();
    if (localOpen1 != null) {
      final lingering = CloudSyncService.supabaseShiftId(localOpen1);
      if (lingering == cloud.id) {
        await CloudSyncService.registerPosDeviceInCloud();
        return null;
      }
      return 'No se pudo dejar sin turno local antes de enlazar. Turno nube local $lingering.';
    }
    final err = await adoptOpenShiftFromCloud(cloud);
    if (err != null) return err;
    await CloudSyncService.registerPosDeviceInCloud();
    return null;
  }

  /// Enlaza este dispositivo a un turno ya abierto en la nube (mismo `shifts.id`), p. ej. tras reinstalar la app.
  /// Requiere cajón correcto en [RegisterScope] y turno abierto en nube para ese cajón.
  Future<String?> adoptOpenShiftFromCloud(CloudShiftSummary cloud) async {
    if (!cloud.isOpen) return 'El turno en la nube ya está cerrado.';
    await _maybeReconcileOpenShiftsWithCloud();
    final localOpen = await getCurrentShift();
    if (localOpen != null) {
      return 'Ya hay un turno abierto en este dispositivo. Ciérralo antes de continuar otro.';
    }
    if (cloud.registerId != null) {
      final activeReg = await RegisterScope.getActiveRegisterId();
      if (activeReg != cloud.registerId) {
        return 'El turno es del cajón #${cloud.registerId} (${cloud.registerLabel ?? "?"}) '
            'y este terminal está en el cajón #$activeReg. Cambia la caja en el menú lateral.';
      }
    }
    final localId = await _db.into(_db.shifts).insert(
          ShiftsCompanion.insert(
            cloudShiftId: Value(cloud.id),
            cloudRegisterId: cloud.registerId != null
                ? Value(cloud.registerId!)
                : const Value.absent(),
            startingFund: Value(cloud.startingFund),
            startTime: Value(cloud.startTime),
          ),
        );
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(localId)))
        .getSingle();
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      return await CloudSyncService.writeShiftToCloud(shift, _db);
    }
    return null;
  }

  /// Actualiza el fondo inicial del turno (hotfix: tras reinstalar la app el turno puede tener 0).
  /// Así puedes hacer el corte con el efectivo real en caja.
  Future<void> updateShiftStartingFund(int shiftId, double startingFund) async {
    await (_db.update(_db.shifts)..where((s) => s.id.equals(shiftId)))
        .write(ShiftsCompanion(startingFund: Value(startingFund)));
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(shiftId)))
          .getSingleOrNull();
      if (shift != null) {
        final err = await CloudSyncService.writeShiftToCloud(shift, _db);
        if (err != null) {
          debugPrint('Cloud write shift (starting fund): $err');
          await logOperationEvent(
            level: OperationLogLevel.critical,
            operation: 'shift_starting_fund_cloud_sync',
            message: err,
            context: {'shiftId': shiftId},
          );
        }
      }
    }
  }

  /// Closes a shift with blind count reconciliation.
  /// Returns the ShiftClosureResult (Z-Report) for display.
  Future<ShiftClosureResult> performCloseShift({
    required int shiftId,
    required double declaredCash,
    String? notes,
  }) async {
    final shiftOpen = await (_db.select(_db.shifts)..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shiftOpen == null) {
      throw StateError('Shift $shiftId not found');
    }
    if (shiftOpen.endTime != null) {
      throw StateError('Shift $shiftId is already closed');
    }

    await reconcileMislinkedMovementsForShift(shiftId);
    final merged = await _getMergedShiftMonetaryTotals(shiftId);
    final cloudExtra = merged.cloudAddedCash +
        merged.cloudAddedDebit +
        merged.cloudAddedCredit +
        merged.cloudAddedTransfer +
        merged.cloudAddedMovNet.abs();
    if (cloudExtra > 0.0001 &&
        CloudSyncService.isEnabled &&
        ConnectivityService.instance.isConnected) {
      await CloudSyncService.logShiftCloseDiagnostic(
        event: 'shift_close_merged_cloud_orphans',
        shiftId: CloudSyncService.supabaseShiftId(shiftOpen),
        context: {
          'localShiftId': shiftId,
          'cloudAddedCash': merged.cloudAddedCash,
          'cloudAddedDebit': merged.cloudAddedDebit,
          'cloudAddedCredit': merged.cloudAddedCredit,
          'cloudAddedTransfer': merged.cloudAddedTransfer,
          'cloudAddedMovNet': merged.cloudAddedMovNet,
        },
      );
    }

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
      final cashSalesTotal = merged.cashSales;
      final cardSalesTotal = merged.debitSales + merged.creditSales;
      final transferSalesTotal = merged.transferSales;
      final movementsCajaNet = merged.movementsCajaNet;

      // systemExpectedCash = startingFund + cashSales + movimientos (entradas - salidas)
      final systemExpectedCash =
          shift.startingFund + cashSalesTotal + movementsCajaNet;

      final difference = declaredCash - systemExpectedCash;
      final adjustmentType = difference < 0
          ? 'shortage'
          : difference > 0
              ? 'surplus'
              : 'balanced';
      final adjustmentAmount = difference.abs();

      final closureId = await _db.into(_db.shiftClosures).insert(
            ShiftClosuresCompanion.insert(
              shiftId: shiftId,
              systemExpectedCash: systemExpectedCash,
              declaredCash: declaredCash,
              difference: difference,
              notes: notes != null ? Value(notes) : const Value.absent(),
            ),
          );

      await _db.customStatement(
        '''
INSERT INTO shift_cash_adjustments (
  shift_closure_id,
  shift_id,
  adjustment_type,
  amount,
  signed_amount
) VALUES (?, ?, ?, ?, ?)
''',
        [
          closureId,
          shiftId,
          adjustmentType,
          adjustmentAmount,
          difference,
        ],
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
    await CloudSyncService.logShiftCloseDiagnostic(
      event: 'shift_close_local_committed',
      shiftId: shiftId,
      context: {
        'closureId': tx.result.closure.id,
        'declaredCash': tx.result.closure.declaredCash,
        'systemExpectedCash': tx.result.closure.systemExpectedCash,
        'difference': tx.result.closure.difference,
      },
    );
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      final err = await CloudSyncService.writeShiftClosureToCloud(
        tx.shiftForCloud,
        tx.result.closure,
      );
      if (err != null) {
        debugPrint('Cloud write shift closure: $err');
        await CloudSyncService.logShiftCloseDiagnostic(
          event: 'shift_close_cloud_failed',
          shiftId: shiftId,
          context: {'error': err, 'closureId': tx.result.closure.id},
        );
        await logOperationEvent(
          level: OperationLogLevel.critical,
          operation: 'shift_closure_cloud_sync',
          message: err,
          context: {
            'shiftId': shiftId,
            'closureId': tx.result.closure.id,
            'declaredCash': tx.result.closure.declaredCash,
            'systemExpectedCash': tx.result.closure.systemExpectedCash,
          },
        );
      } else {
        await CloudSyncService.logShiftCloseDiagnostic(
          event: 'shift_close_cloud_ok',
          shiftId: shiftId,
          context: {'closureId': tx.result.closure.id},
        );
      }
    } else {
      await CloudSyncService.logShiftCloseDiagnostic(
        event: 'shift_close_cloud_skipped',
        shiftId: shiftId,
        context: {
          'closureId': tx.result.closure.id,
          'reason': !CloudSyncService.isEnabled ? 'cloud_disabled' : 'offline',
        },
      );
    }
    if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
      await CloudSyncService.reconcileLocalOpenShiftsWithCloud(_db);
    }
    return tx.result;
  }

  /// Totals for closure form (expected in drawer, sales by payment type). Does not close the shift.
  ///
  /// Con nube: incluye ventas y movimientos CAJA en Supabase para el mismo turno (`cloud_shift_id`)
  /// que no están ya enlazados en SQLite (por `cloud_sale_id` / id de movimiento).
  Future<ShiftTotalsForClosure?> getShiftTotalsForClosure(int shiftId) async {
    final shift = await (_db.select(_db.shifts)
          ..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shift == null) return null;
    await reconcileMislinkedMovementsForShift(shiftId);
    final merged = await _getMergedShiftMonetaryTotals(shiftId);
    return ShiftTotalsForClosure(
      startingFund: shift.startingFund,
      cashSales: merged.cashSales,
      debitSales: merged.debitSales,
      creditSales: merged.creditSales,
      transferSales: merged.transferSales,
      movementsCajaNet: merged.movementsCajaNet,
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

      final salesRows = await (_db.select(_db.sales)
            ..where((s) {
              final dateInRange = s.date.isBiggerOrEqualValue(shift.startTime) &
                  s.date.isSmallerOrEqualValue(endTime);
              return dateInRange & s.cancelledAt.isNull();
            }))
          .get();

      var cashSales = 0.0;
      var cardDebit = 0.0;
      var cardCredit = 0.0;
      var transferSales = 0.0;
      for (final s in salesRows) {
        final b = SalePaymentBreakdown.fromSale(
          paymentMethod: s.paymentMethod,
          totalAmount: s.totalAmount,
          paymentsJson: s.paymentsJson,
        );
        cashSales += b.cash;
        cardDebit += b.debit;
        cardCredit += b.credit;
        transferSales += b.transfer;
      }

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
      final b = SalePaymentBreakdown.fromSale(
        paymentMethod: s.paymentMethod,
        totalAmount: s.totalAmount,
        paymentsJson: s.paymentsJson,
      );
      cash += b.cash;
      cardDebit += b.debit;
      cardCredit += b.credit;
      transfer += b.transfer;
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

  /// Ventas del día (hora local) agrupadas por turno (incluye turnos abiertos).
  Future<List<ShiftSalesRow>> getSalesByShiftForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final sales = await (_db.select(_db.sales)
          ..where((s) =>
              s.cancelledAt.isNull() &
              s.date.isBiggerOrEqualValue(start) &
              s.date.isSmallerOrEqualValue(end)))
        .get();

    final totals = <int, ({int count, double total})>{};
    for (final s in sales) {
      final prev = totals[s.shiftId] ?? (count: 0, total: 0.0);
      totals[s.shiftId] = (count: prev.count + 1, total: prev.total + s.totalAmount);
    }

    final shiftIds = totals.keys.toList()..sort();
    final rows = <ShiftSalesRow>[];
    for (final shiftId in shiftIds) {
      final shift = await (_db.select(_db.shifts)..where((sh) => sh.id.equals(shiftId)))
          .getSingleOrNull();
      final meta = totals[shiftId] ?? (count: 0, total: 0.0);
      rows.add(
        ShiftSalesRow(
          shiftId: shiftId,
          startTime: shift?.startTime ?? start,
          endTime: shift?.endTime,
          saleCount: meta.count,
          totalAmount: meta.total,
        ),
      );
    }
    rows.sort((a, b) => a.startTime.compareTo(b.startTime));
    return rows;
  }

  /// Distribución por categoría del día (hora local), por monto.
  Future<List<CategorySalesRow>> getCategoryDistributionForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
      innerJoin(_db.products, _db.products.id.equalsExp(_db.saleItems.productId)),
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.products.categoryId)),
    ])
      ..where(_db.sales.cancelledAt.isNull() &
          _db.sales.date.isBiggerOrEqualValue(start) &
          _db.sales.date.isSmallerOrEqualValue(end));

    final rows = await query.get();
    final byCat = <int?, ({String name, double revenue})>{};
    for (final row in rows) {
      final item = row.readTable(_db.saleItems);
      final product = row.readTable(_db.products);
      final cat = row.readTableOrNull(_db.categories);
      final catId = product.categoryId;
      final name = (cat?.name.trim().isNotEmpty == true) ? cat!.name : 'Sin categoría';
      final rev = item.quantity * item.unitPrice;
      final prev = byCat[catId] ?? (name: name, revenue: 0.0);
      byCat[catId] = (name: prev.name, revenue: prev.revenue + rev);
    }

    final list = byCat.entries
        .map((e) => CategorySalesRow(
              categoryId: e.key,
              categoryName: e.value.name,
              revenue: e.value.revenue,
            ))
        .toList();
    list.sort((a, b) => b.revenue.compareTo(a.revenue));
    return list;
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

/// Ventas agrupadas por turno (para resumen rápido).
class ShiftSalesRow {
  const ShiftSalesRow({
    required this.shiftId,
    required this.startTime,
    required this.endTime,
    required this.saleCount,
    required this.totalAmount,
  });
  final int shiftId;
  final DateTime startTime;
  final DateTime? endTime;
  final int saleCount;
  final double totalAmount;
}

/// Ventas agrupadas por categoría (para resumen rápido).
class CategorySalesRow {
  const CategorySalesRow({
    required this.categoryId,
    required this.categoryName,
    required this.revenue,
  });
  final int? categoryId;
  final String categoryName;
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
PosRepository? posRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return PosRepository(db);
}
