import 'package:drift/drift.dart';

// 1. SUPPLIES (Raw Materials)
// e.g., Coffee Beans (kg), Milk (L), Paper Cups (unit)
class Supplies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))(); 
  TextColumn get unit => text().withLength(min: 1, max: 10)(); // 'kg', 'lt', 'pcs'
  RealColumn get costPerUnit => real().withDefault(const Constant(0.0))();
  RealColumn get reorderPoint => real().withDefault(const Constant(0.0))(); // Alert threshold
}

// 2. PRODUCTS (Menu Items)
// e.g., "Latte Medium". It has NO direct stock; availability is calculated from supplies.
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get price => real()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// 3. RECIPES (The Logic Core)
// Links Product <-> Supply. 
// e.g., 1 Latte = 0.018 kg Coffee + 0.25 L Milk.
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get supplyId => integer().references(Supplies, #id)();
  RealColumn get quantityRequired => real()(); 
}

// 4. SALES (Header)
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('CASH'))(); 
}

// 5. SALE ITEMS (Details)
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()(); 
  RealColumn get unitPrice => real()(); 
}

// 6. INVENTORY LOGS (Audit Trail)
// Tracks WHY stock changed (Sale, Purchase, Waste)
class InventoryLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplyId => integer().references(Supplies, #id)();
  RealColumn get changeAmount => real()(); // -0.2 (Sale) or +10.0 (Purchase)
  TextColumn get reason => text()(); // 'SALE', 'PURCHASE', 'WASTE'
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

// 7. MODIFIER GROUPS (Dynamic recipe options)
// e.g., 'Sabores Vaso Chico' with min=3, max=3 scoops
class ModifierGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get minSelection => integer().withDefault(const Constant(0))();
  IntColumn get maxSelection => integer()();
}

// 8. PRODUCT MODIFIERS (Links Product <-> ModifierGroup)
class ProductModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get modifierGroupId => integer().references(ModifierGroups, #id)();
}

// 9. MODIFIER OPTIONS (Links ModifierGroup <-> Supply with quantity & price)
// e.g., 'Lemon Ice Cream' = 0.150 kg per scoop, +$0.50 extra
class ModifierOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get modifierGroupId => integer().references(ModifierGroups, #id)();
  IntColumn get supplyId => integer().references(Supplies, #id)();
  RealColumn get quantityDeducted => real()(); // e.g., 0.150 kg per scoop
  RealColumn get priceExtra => real().withDefault(const Constant(0.0))();
}

// 10. PARKED ORDERS (Orders saved for later - Park Order)
class ParkedOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text().nullable()();
  TextColumn get itemsJson => text()();
  DateTimeColumn get parkedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real()();
}

// 11. DISCOUNTS (QR-based codes for specific audiences)
class Discounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  RealColumn get percentage => real()(); // 0.10 = 10%
  TextColumn get description => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// 12. BUNDLES (Package promotions, e.g. Desayuno Ejecutivo)
class Bundles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get price => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// 13. BUNDLE ITEMS (Products that compose a bundle)
class BundleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bundleId => integer().references(Bundles, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantityRequired =>
      real().named('quantity').withDefault(const Constant(1.0))();
}

// 14. SHIFTS (Work sessions - open/close)
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get startingFund => real().withDefault(const Constant(0.0))();
}

// 15. CASH MOVEMENTS (Expenses, petty cash - reduce drawer)
class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shiftId => integer().references(Shifts, #id)();
  RealColumn get amount => real()(); // Negative = cash out (expense)
  TextColumn get reason => text()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

// 16. SHIFT CLOSURES (Z-Reports - reconciliation)
class ShiftClosures extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shiftId => integer().references(Shifts, #id)();
  DateTimeColumn get closingTime => dateTime().withDefault(currentDateAndTime)();
  RealColumn get systemExpectedCash => real()();
  RealColumn get declaredCash => real()();
  RealColumn get difference => real()();
  TextColumn get notes => text().nullable()();
}