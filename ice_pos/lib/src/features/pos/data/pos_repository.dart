import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart' as domain;
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
    required this.expenses,
  });

  final ShiftClosure closure;
  final double startingFund;
  final double cashSales;
  final double expenses;
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
              ProductsCompanion.insert(name: name, price: price),
            );
      } else {
        id = productId;
        await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
          ProductsCompanion(
            name: Value(name),
            price: Value(price),
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
    required List<({int productId, double quantity})> productItems,
  }) async {
    await _db.transaction(() async {
      if (id == null) {
        final bundleId = await _db.into(_db.bundles).insert(
          BundlesCompanion.insert(name: name, price: price),
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
          BundlesCompanion(name: Value(name), price: Value(price)),
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
  }) async {
    if (id == null) {
      await _db.into(_db.supplies).insert(
        SuppliesCompanion.insert(
          name: name,
          unit: unit,
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
        ),
      );
    } else {
      await (_db.update(_db.supplies)..where((s) => s.id.equals(id))).write(
        SuppliesCompanion(
          name: Value(name),
          unit: Value(unit),
          costPerUnit: Value(costPerUnit),
          reorderPoint: Value(reorderPoint),
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
  /// Creates sale record, sale items, deducts inventory, and logs changes.
  /// If [totalAmount] is provided, uses it (e.g. bundle-adjusted + discount on standalone).
  /// Otherwise computes from items and applies [discount] to full total.
  Future<void> processSale(
    List<CartItem> items, {
    Discount? discount,
    double? totalAmount,
  }) async {
    if (items.isEmpty) return;

    await _db.transaction(() async {
      var amount = totalAmount ??
          items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
      if (totalAmount == null && discount != null) {
        amount = amount * (1 - discount.percentage);
      }

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
            '❌ ERROR: No recipe found for $productLabel. Check Database!',
          );
          throw StateError(
            'No recipe found for $productLabel (productId=${cartItem.productId}). '
            'Add recipe entries linking this product to supplies.',
          );
        }

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

          if (supply.currentStock < amount) {
            throw StateError(
              'Insufficient stock for supply "${supply.name}" '
              '(required: $amount, available: ${supply.currentStock})',
            );
          }

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

          if (supply.currentStock < amount) {
            throw StateError(
              'Insufficient stock for supply "${supply.name}" '
              '(modifier required: $amount, available: ${supply.currentStock})',
            );
          }

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
            SalesCompanion.insert(totalAmount: amount),
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
    });
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
  Future<Shift> startShift(double startingFund) async {
    final id = await _db.into(_db.shifts).insert(
          ShiftsCompanion.insert(startingFund: Value(startingFund)),
        );
    return await (_db.select(_db.shifts)..where((s) => s.id.equals(id)))
        .getSingle();
  }

  /// Closes a shift with blind count reconciliation.
  /// Returns the ShiftClosureResult (Z-Report) for display.
  Future<ShiftClosureResult> performCloseShift({
    required int shiftId,
    required double declaredCash,
    String? notes,
  }) async {
    return _db.transaction(() async {
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

      // Cash sales: sum of CASH sales between shift start and now
      final cashSales = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum()])
            ..where(_db.sales.paymentMethod.equals('CASH') &
                _db.sales.date.isBiggerOrEqualValue(shift.startTime) &
                _db.sales.date.isSmallerOrEqualValue(now)))
          .getSingle();
      final cashSalesTotal =
          cashSales.read(_db.sales.totalAmount.sum()) ?? 0.0;

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
        expenses: expensesAbs,
      );
    });
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
