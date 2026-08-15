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
  Movements,
  AppUsers,
  OperationLogs,
  PendingCashierApprovals,
])
class AppDatabase extends _$AppDatabase {
  // Constructor
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 28;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 28) {
            await migrator.addColumn(sales, sales.paymentsJson);
          }
          if (from < 27) {
            await migrator.addColumn(movements, movements.cancelledAt);
          }
          if (from < 23) {
            await migrator.createTable(pendingCashierApprovals);
          } else if (from < 24) {
            await migrator.addColumn(
              pendingCashierApprovals,
              pendingCashierApprovals.cloudPendingId,
            );
          }
          if (from < 25) {
            await migrator.addColumn(saleItems, saleItems.modifiersJson);
            await migrator.addColumn(movements, movements.needsCloudSync);
          }
          if (from < 26) {
            await customStatement('''
CREATE TABLE IF NOT EXISTS shift_cash_adjustments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shift_closure_id INTEGER NOT NULL REFERENCES shift_closures(id),
  shift_id INTEGER NOT NULL REFERENCES shifts(id),
  recorded_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('shortage','surplus','balanced')),
  amount REAL NOT NULL,
  signed_amount REAL NOT NULL
)
''');
            await customStatement('''
CREATE INDEX IF NOT EXISTS shift_cash_adjustments_shift_idx
ON shift_cash_adjustments(shift_id, recorded_at)
''');
          }
          if (from < 22) {
            final shiftCountRow = await customSelect(
              'SELECT COUNT(*) AS c FROM shifts',
              readsFrom: {shifts},
            ).getSingle();
            final rawC = shiftCountRow.data['c'];
            final shiftCount = rawC is int
                ? rawC
                : rawC is BigInt
                    ? rawC.toInt()
                    : int.tryParse(rawC.toString()) ?? 0;
            if (shiftCount == 0) {
              await into(shifts).insert(
                ShiftsCompanion.insert(startingFund: const Value(0)),
              );
            }
            await customStatement(
              'UPDATE sales SET shift_id = (SELECT MIN(id) FROM shifts) WHERE shift_id IS NULL',
            );
            await customStatement(r'''
UPDATE sales
SET shift_id = (
  SELECT sh.id FROM shifts sh
  WHERE sales.date >= sh.start_time
    AND (sh.end_time IS NULL OR sales.date <= sh.end_time)
  ORDER BY sh.id DESC
  LIMIT 1
)
WHERE EXISTS (
  SELECT 1 FROM shifts sh
  WHERE sales.date >= sh.start_time
    AND (sh.end_time IS NULL OR sales.date <= sh.end_time)
);
''');
            await customStatement(
              'UPDATE sales SET shift_id = (SELECT MIN(id) FROM shifts) WHERE shift_id IS NULL',
            );
            await customStatement(
              'ALTER TABLE sales ALTER COLUMN shift_id SET NOT NULL',
            );
          }
          if (from < 21) {
            await migrator.addColumn(shifts, shifts.cloudRegisterId);
            await migrator.addColumn(sales, sales.shiftId);
          }
          if (from < 20) {
            await migrator.addColumn(shifts, shifts.cloudShiftId);
            await customStatement(
              'UPDATE shifts SET cloud_shift_id = id WHERE cloud_shift_id IS NULL',
            );
          }
          if (from < 19) {
            await migrator.createTable(operationLogs);
          }
          if (from < 18) {
            await migrator.addColumn(supplies, supplies.stockCountMode);
            await migrator.addColumn(supplies, supplies.qualitativeLevel);
          }
          if (from < 17) {
            await migrator.addColumn(categories, categories.imageUrl);
          }
          if (from < 16) {
            await migrator.addColumn(sales, sales.cancelledAt);
          }
          if (from < 15) {
            await migrator.addColumn(sales, sales.cloudSaleId);
          }
          if (from < 14) {
            await migrator.createTable(appUsers);
          }
          if (from < 13) {
            await migrator.createTable(movements);
          }
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

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pos_database_v2',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }
}