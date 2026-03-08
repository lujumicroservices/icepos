import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
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
    required this.expenses,
  });

  final ShiftClosure closure;
  final double startingFund;
  final double cashSales;
  final double cardSales;
  final double transferSales;
  final double expenses;

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
    required this.expenses,
  });

  final double startingFund;
  final double cashSales;
  final double debitSales;
  final double creditSales;
  final double transferSales;
  final double expenses;

  double get cardSales => debitSales + creditSales;
  double get totalSales => cashSales + cardSales + transferSales;

  /// Lo que debería haber en caja: fondo inicial + ventas efectivo - gastos.
  double get expectedCashInDrawer =>
      startingFund + cashSales + expensesNeg;
  /// Gastos como número negativo (retiros).
  double get expensesNeg => -expenses.abs();
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

/// Repository for POS (Point of Sale) operations.
class PosRepository {
  PosRepository(this._db);

  final AppDatabase _db;

  /// Fetches categories. If [parentId] is null, returns root categories.
  Future<List<domain_cat.Category>> getCategories({int? parentId}) async {
    final query = parentId == null
        ? 'SELECT id, name, parent_id, color FROM categories WHERE parent_id IS NULL'
        : 'SELECT id, name, parent_id, color FROM categories WHERE parent_id = ?';
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
          ),
        )
        .toList();
  }

  /// Returns all categories (root and subcategories) for admin/grouping.
  /// Order: root first (parent_id IS NULL), then by name.
  Future<List<domain_cat.Category>> getAllCategories() async {
    const query = '''
      SELECT id, name, parent_id, color FROM categories
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
    );
  }

  /// Inserts a new category. Returns the new id.
  Future<int> insertCategory({
    required String name,
    int? parentId,
    String? color,
  }) async {
    return await _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        name: name.trim(),
        parentId: Value(parentId),
        color: Value(color),
      ),
    );
  }

  /// Updates an existing category.
  Future<void> updateCategory(
    int id, {
    String? name,
    int? parentId,
    String? color,
  }) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? Value(name.trim()) : const Value.absent(),
        parentId: parentId != null ? Value<int?>(parentId) : const Value.absent(),
        color: color != null ? Value<String?>(color) : const Value.absent(),
      ),
    );
  }

  /// Deletes a category. Fails if it has products or child categories.
  /// Use [reassignProductCategoryId] first if needed.
  Future<void> deleteCategory(int id) async {
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
    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(isActive: Value(active)));
  }

  /// Deletes a product and its recipes and product_modifiers.
  /// Throws StateError if the product has any sales (sale_items).
  Future<void> deleteProduct(int productId) async {
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
  Future<void> saveProduct({
    required int? productId,
    required String name,
    required double price,
    int? categoryId,
    required List<({int supplyId, double quantityRequired})> recipeItems,
    required List<({
      String name,
      int minSelection,
      int maxSelection,
      List<({int supplyId, double quantityDeducted, double priceExtra})> options,
    })> modifierGroups,
  }) async {
    await _db.transaction(() async {
      int id;
      if (productId == null) {
        id = await _db.into(_db.products).insert(
              ProductsCompanion.insert(
                name: name,
                price: price,
                categoryId: Value(categoryId),
              ),
            );
      } else {
        id = productId;
        await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
          ProductsCompanion(
            name: Value(name),
            price: Value(price),
            categoryId: Value(categoryId),
          ),
        );
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
    });
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

  /// Saves a bundle (insert or update) with its items.
  Future<void> saveBundle({
    int? id,
    required String name,
    required double price,
    int? categoryId,
    required List<({int productId, double quantity})> productItems,
  }) async {
    await _db.transaction(() async {
      if (id == null) {
        final bundleId = await _db.into(_db.bundles).insert(
          BundlesCompanion.insert(
            name: name,
            price: price,
            categoryId: Value(categoryId),
          ),
        );
        for (final item in productItems) {
          await _db.into(_db.bundleItems).insert(
            BundleItemsCompanion.insert(
              bundleId: bundleId,
              productId: item.productId,
              quantityRequired: Value(item.quantity),
            ),
          );
        }
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
      }
    });
  }

  /// Deletes a bundle and its items.
  Future<void> deleteBundle(int id) async {
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

  /// Saves a supply (insert if id is null, update otherwise).
  Future<void> saveSupply({
    int? id,
    required String name,
    required String unit,
    required double costPerUnit,
    double reorderPoint = 0,
    String? category,
  }) async {
    if (id == null) {
      await _db.into(_db.supplies).insert(
        SuppliesCompanion.insert(
          name: name,
          unit: unit,
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
          category: Value(category?.trim().isEmpty == true ? null : category?.trim()),
        ),
      );
    } else {
      await (_db.update(_db.supplies)..where((s) => s.id.equals(id))).write(
        SuppliesCompanion(
          name: Value(name),
          unit: Value(unit),
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
          category: Value(category?.trim().isEmpty == true ? null : category?.trim()),
        ),
      );
    }
  }

  /// Deletes a supply by id.
  Future<void> deleteSupply(int id) async {
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
      final groups = await _getModifierGroupsForProductId(product.id);
      if (groups.isNotEmpty) {
        return (product: product, groups: groups);
      }
    }
    for (final product in products) {
      final groups = await _getModifierGroupsForProductId(product.id);
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

  /// Deletes ALL local data in FK order. Use before "Sincronizar desde la nube" for a full reload from cloud.
  Future<void> deleteAllLocalData() async {
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
    await _db.delete(_db.cashMovements).go();
    await _db.delete(_db.shiftClosures).go();
    await _db.delete(_db.shifts).go();
    await _db.delete(_db.parkedOrders).go();
    await _db.delete(_db.discounts).go();
  }

  /// Observes sales history with items, ordered by date descending.
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

    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.writeSaleToCloud(
        items,
        totalAmount: amount,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        changeGiven: changeGiven,
      );
      if (err != null) throw StateError(err);
    }

    SaleSyncPayload? payload;
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

      // 2. Finally, insert the Sale record and sale items
      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              totalAmount: amount,
              paymentMethod: Value(paymentMethod),
              amountTendered: Value(amountTendered),
              changeGiven: Value(changeGiven),
            ),
          );

      for (final item in items) {
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
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
    return payload;
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
    if (CloudSyncService.isEnabled) {
      final err = await CloudSyncService.writeShiftToCloud(shift);
      if (err != null) debugPrint('Cloud write shift: $err');
    }
    return shift;
  }

  /// Closes a shift with blind count reconciliation.
  /// Returns the ShiftClosureResult (Z-Report) for display.
  Future<ShiftClosureResult> performCloseShift({
    required int shiftId,
    required double declaredCash,
    String? notes,
  }) async {
    final result = await _db.transaction(() async {
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

      final dateInRange = _db.sales.date.isBiggerOrEqualValue(shift.startTime) &
          _db.sales.date.isSmallerOrEqualValue(now);

      // Cash sales
      final cashSales = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('CASH') & dateInRange))
          .getSingle();
      final cashSalesTotal =
          cashSales.read(_db.sales.totalAmount.sum()) ?? 0.0;

      // Card sales (débito + crédito)
      final cardSalesQuery = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where((_db.sales.paymentMethod.equals('CARD_DEBIT') |
                    _db.sales.paymentMethod.equals('CARD_CREDIT')) &
                dateInRange))
          .getSingle();
      final cardSalesTotal =
          cardSalesQuery.read(_db.sales.totalAmount.sum()) ?? 0.0;

      // Transfer sales
      final transferSalesQuery = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('TRANSFER') & dateInRange))
          .getSingle();
      final transferSalesTotal =
          transferSalesQuery.read(_db.sales.totalAmount.sum()) ?? 0.0;

      // Expenses: sum of cash movements (negative = out)
      final expensesResult = await (_db.selectOnly(_db.cashMovements)
            ..addColumns([_db.cashMovements.amount.sum()])
            ..where(_db.cashMovements.shiftId.equals(shiftId)))
          .getSingle();
      final expensesTotal =
          expensesResult.read(_db.cashMovements.amount.sum()) ?? 0.0;
      // amount is negative for expenses, so expensesTotal is negative
      final expensesAbs = expensesTotal.abs();

      // systemExpectedCash = startingFund + cashSales - expenses
      final systemExpectedCash =
          shift.startingFund + cashSalesTotal + expensesTotal;

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
      return ShiftClosureResult(
        closure: closure,
        startingFund: shift.startingFund,
        cashSales: cashSalesTotal,
        cardSales: cardSalesTotal,
        transferSales: transferSalesTotal,
        expenses: expensesAbs,
      );
    });
    if (CloudSyncService.isEnabled) {
      final updatedShift = await (_db.select(_db.shifts)
            ..where((s) => s.id.equals(shiftId)))
          .getSingle();
      final err = await CloudSyncService.writeShiftClosureToCloud(
        updatedShift,
        result.closure,
      );
      if (err != null) debugPrint('Cloud write shift closure: $err');
    }
    return result;
  }

  /// Totals for closure form (expected in drawer, sales by payment type). Does not close the shift.
  Future<ShiftTotalsForClosure?> getShiftTotalsForClosure(int shiftId) async {
    final shift = await (_db.select(_db.shifts)
          ..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shift == null) return null;
    final now = DateTime.now();
    final dateInRange = _db.sales.date.isBiggerOrEqualValue(shift.startTime) &
        _db.sales.date.isSmallerOrEqualValue(now);

    final cashR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CASH') & dateInRange))
        .getSingle();
    final cashSales = cashR.read(_db.sales.totalAmount.sum()) ?? 0.0;

    final debitR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CARD_DEBIT') & dateInRange))
        .getSingle();
    final debitSales = debitR.read(_db.sales.totalAmount.sum()) ?? 0.0;

    final creditR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CARD_CREDIT') & dateInRange))
        .getSingle();
    final creditSales = creditR.read(_db.sales.totalAmount.sum()) ?? 0.0;

    final transferR = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('TRANSFER') & dateInRange))
        .getSingle();
    final transferSales = transferR.read(_db.sales.totalAmount.sum()) ?? 0.0;

    final expR = await (_db.selectOnly(_db.cashMovements)
          ..addColumns([_db.cashMovements.amount.sum()])
          ..where(_db.cashMovements.shiftId.equals(shiftId)))
        .getSingle();
    final expensesSum = expR.read(_db.cashMovements.amount.sum()) ?? 0.0;
    final expenses = expensesSum.abs();

    return ShiftTotalsForClosure(
      startingFund: shift.startingFund,
      cashSales: cashSales,
      debitSales: debitSales,
      creditSales: creditSales,
      transferSales: transferSales,
      expenses: expenses,
    );
  }

  /// Gets shift summary for Z-Report display (starting fund, cash sales, expenses).
  Future<({double startingFund, double cashSales, double expenses})>
      getShiftSummary(int shiftId) async {
    final shift = await (_db.select(_db.shifts)
          ..where((s) => s.id.equals(shiftId)))
        .getSingleOrNull();
    if (shift == null) {
      return (startingFund: 0.0, cashSales: 0.0, expenses: 0.0);
    }
    final now = DateTime.now();
    final cashSalesResult = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.totalAmount.sum()])
          ..where(_db.sales.paymentMethod.equals('CASH') &
              _db.sales.date.isBiggerOrEqualValue(shift.startTime) &
              _db.sales.date.isSmallerOrEqualValue(now)))
        .getSingle();
    final cashSales =
        cashSalesResult.read(_db.sales.totalAmount.sum()) ?? 0.0;
    final expensesResult = await (_db.selectOnly(_db.cashMovements)
          ..addColumns([_db.cashMovements.amount.sum()])
          ..where(_db.cashMovements.shiftId.equals(shiftId)))
        .getSingle();
    final expensesSum =
        expensesResult.read(_db.cashMovements.amount.sum()) ?? 0.0;
    final expenses = expensesSum.abs();
    return (
      startingFund: shift.startingFund,
      cashSales: cashSales,
      expenses: expenses,
    );
  }
}

@riverpod
PosRepository posRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return PosRepository(db);
}
