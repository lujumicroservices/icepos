import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Import the tables we just created
import 'tables.dart';

// THIS LINE IS CRITICAL. Drift will generate this file.
part 'app_database.g.dart'; 

@DriftDatabase(tables: [
  Categories,
  Products,
  Supplies,
  Recipes,
  Sales,
  SaleItems,
  InventoryLogs,
  ModifierGroups,
  ProductModifiers,
  ModifierOptions,
  ParkedOrders,
  Discounts,
  Bundles,
  BundleItems,
  Shifts,
  CashMovements,
  ShiftClosures,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 12) {
            final hasCategory = await customSelect(
              "SELECT 1 FROM pragma_table_info('supplies') WHERE name='category'",
            ).get();
            if (hasCategory.isEmpty) {
              await migrator.addColumn(supplies, supplies.category);
            }
          }
          if (from < 11) {
            final hasColumn = await customSelect(
              "SELECT 1 FROM pragma_table_info('bundles') WHERE name='category_id'",
            ).get();
            if (hasColumn.isEmpty) {
              await migrator.addColumn(bundles, bundles.categoryId);
            }
          }
          if (from < 10) {
            await migrator.addColumn(sales, sales.amountTendered);
            await migrator.addColumn(sales, sales.changeGiven);
          }
          if (from < 2) {
            await migrator.createTable(modifierGroups);
            await migrator.createTable(productModifiers);
            await migrator.createTable(modifierOptions);
          }
          if (from < 3) {
            await migrator.addColumn(supplies, supplies.reorderPoint);
          }
          if (from < 4) {
            await migrator.createTable(parkedOrders);
          }
          if (from < 5) {
            await migrator.createTable(discounts);
          }
          if (from < 6) {
            await migrator.createTable(bundles);
            await migrator.createTable(bundleItems);
          }
          if (from < 7) {
            await migrator.addColumn(bundles, bundles.isActive);
          }
          if (from < 8) {
            await migrator.createTable(shifts);
            await migrator.createTable(cashMovements);
            await migrator.createTable(shiftClosures);
          }
          if (from < 9) {
            await migrator.createTable(categories);
            await migrator.addColumn(products, products.categoryId);
          }
        },
      );

  // Connection logic for Android/iOS/Windows
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pos_database_v2',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }
}