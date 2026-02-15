import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;

  DatabaseSeeder(this.db);

  Future<void> seed() async {
    // 1. Check if initial data exists
    final productsCount = await db.select(db.products).get();
    if (productsCount.isEmpty) {
      debugPrint('🌱 Seeding Database (Coffee/Latte)...');

      // Insert SUPPLIES
      final coffeeId = await db.into(db.supplies).insert(
        SuppliesCompanion.insert(
          name: 'Espresso Roast Beans',
          unit: 'kg',
          currentStock: const Value(10.0),
          costPerUnit: const Value(15.0),
        ),
      );

      final milkId = await db.into(db.supplies).insert(
        SuppliesCompanion.insert(
          name: 'Whole Milk',
          unit: 'lt',
          currentStock: const Value(50.0),
          costPerUnit: const Value(1.20),
        ),
      );

      // Insert PRODUCT
      final latteId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          name: 'Caffe Latte',
          price: 4.50,
          isActive: const Value(true),
        ),
      );

      // Insert RECIPES
      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          productId: latteId,
          supplyId: coffeeId,
          quantityRequired: 0.018,
        ),
      );
      await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          productId: latteId,
          supplyId: milkId,
          quantityRequired: 0.25,
        ),
      );

      debugPrint('✅ Coffee/Latte seeded.');
    }

    // 2. Check if Ice Cream & Baguette products exist (avoid duplicates)
    final vasoChico = await (db.select(db.products)
          ..where((p) => p.name.equals('Vaso Chico (3 Bolas)')))
        .getSingleOrNull();
    if (vasoChico != null) {
      debugPrint('Ice Cream & Baguette already seeded. Skipping.');
      return;
    }

    debugPrint('🌱 Seeding Ice Cream & Baguette...');

    // 3. Insert NEW SUPPLIES
    final nieveLimonId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Nieve Limón',
        unit: 'kg',
        currentStock: const Value(10.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final nieveVainillaId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Nieve Vainilla',
        unit: 'kg',
        currentStock: const Value(10.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final nieveFresaId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Nieve Fresa',
        unit: 'kg',
        currentStock: const Value(10.0),
        costPerUnit: const Value(0.0),
      ),
    );

    final panBaguetteId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Pan Baguette',
        unit: 'pcs',
        currentStock: const Value(50.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final jamonPavoId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Jamón de Pavo',
        unit: 'kg',
        currentStock: const Value(5.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final quesoManchegoId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Queso Manchego',
        unit: 'kg',
        currentStock: const Value(5.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final lechugaId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Lechuga',
        unit: 'pcs',
        currentStock: const Value(3.0),
        costPerUnit: const Value(0.0),
      ),
    );

    final vasoChicoSupplyId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Vaso Chico',
        unit: 'pcs',
        currentStock: const Value(500.0),
        costPerUnit: const Value(0.0),
      ),
    );
    final servilletaId = await db.into(db.supplies).insert(
      SuppliesCompanion.insert(
        name: 'Servilleta',
        unit: 'pcs',
        currentStock: const Value(1000.0),
        costPerUnit: const Value(0.0),
      ),
    );

    // 4. Insert NEW PRODUCTS
    final vasoChicoProductId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        name: 'Vaso Chico (3 Bolas)',
        price: 45.00,
        isActive: const Value(true),
      ),
    );

    final baguetteProductId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        name: 'Baguette Clásico',
        price: 85.00,
        isActive: const Value(true),
      ),
    );

    // 5. Configure FIXED RECIPES
    // Vaso Chico (3 Bolas): 1 Vaso Chico + 1 Servilleta
    await db.into(db.recipes).insert(
      RecipesCompanion.insert(
        productId: vasoChicoProductId,
        supplyId: vasoChicoSupplyId,
        quantityRequired: 1.0,
      ),
    );
    await db.into(db.recipes).insert(
      RecipesCompanion.insert(
        productId: vasoChicoProductId,
        supplyId: servilletaId,
        quantityRequired: 1.0,
      ),
    );

    // Baguette Clásico: 1 Pan + 0.100 kg Jamón + 0.05 Lechuga
    await db.into(db.recipes).insert(
      RecipesCompanion.insert(
        productId: baguetteProductId,
        supplyId: panBaguetteId,
        quantityRequired: 1.0,
      ),
    );
    await db.into(db.recipes).insert(
      RecipesCompanion.insert(
        productId: baguetteProductId,
        supplyId: jamonPavoId,
        quantityRequired: 0.100,
      ),
    );
    await db.into(db.recipes).insert(
      RecipesCompanion.insert(
        productId: baguetteProductId,
        supplyId: lechugaId,
        quantityRequired: 0.05,
      ),
    );

    // 6. Configure MODIFIER GROUPS
    final saboresGroupId = await db.into(db.modifierGroups).insert(
      ModifierGroupsCompanion.insert(
        name: 'Sabores (Elige 3)',
        minSelection: const Value(3),
        maxSelection: 3,
      ),
    );

    final extrasGroupId = await db.into(db.modifierGroups).insert(
      ModifierGroupsCompanion.insert(
        name: 'Extras',
        minSelection: const Value(0),
        maxSelection: 5,
      ),
    );

    // 7. Link Products to Modifier Groups
    await db.into(db.productModifiers).insert(
      ProductModifiersCompanion.insert(
        productId: vasoChicoProductId,
        modifierGroupId: saboresGroupId,
      ),
    );
    await db.into(db.productModifiers).insert(
      ProductModifiersCompanion.insert(
        productId: baguetteProductId,
        modifierGroupId: extrasGroupId,
      ),
    );

    // 8. Add MODIFIER OPTIONS
    // Ice Cream flavors: 0.050 kg per scoop
    await db.into(db.modifierOptions).insert(
      ModifierOptionsCompanion.insert(
        modifierGroupId: saboresGroupId,
        supplyId: nieveLimonId,
        quantityDeducted: 0.050,
      ),
    );
    await db.into(db.modifierOptions).insert(
      ModifierOptionsCompanion.insert(
        modifierGroupId: saboresGroupId,
        supplyId: nieveVainillaId,
        quantityDeducted: 0.050,
      ),
    );
    await db.into(db.modifierOptions).insert(
      ModifierOptionsCompanion.insert(
        modifierGroupId: saboresGroupId,
        supplyId: nieveFresaId,
        quantityDeducted: 0.050,
      ),
    );

    // Baguette extras
    await db.into(db.modifierOptions).insert(
      ModifierOptionsCompanion.insert(
        modifierGroupId: extrasGroupId,
        supplyId: quesoManchegoId,
        quantityDeducted: 0.050,
        priceExtra: const Value(15.0),
      ),
    );
    await db.into(db.modifierOptions).insert(
      ModifierOptionsCompanion.insert(
        modifierGroupId: extrasGroupId,
        supplyId: jamonPavoId,
        quantityDeducted: 0.050,
        priceExtra: const Value(20.0),
      ),
    );

    // 9. Add sample DISCOUNT for testing (e.g. school audience)
    final discountsCount = await db.select(db.discounts).get();
    if (discountsCount.isEmpty) {
      await db.into(db.discounts).insert(
        DiscountsCompanion.insert(
          code: 'SCHOOL_CAMPO_VERDE',
          percentage: 0.10,
          description: '10% off for Campo Verde School',
          isActive: const Value(true),
        ),
      );
      debugPrint('✅ Sample discount SCHOOL_CAMPO_VERDE (10%) seeded.');
    }

    // 10. Add sample BUNDLE (Desayuno Ejecutivo = Vaso Chico + Baguette)
    final bundlesCount = await db.select(db.bundles).get();
    if (bundlesCount.isEmpty && vasoChicoProductId != 0 && baguetteProductId != 0) {
      final bundleId = await db.into(db.bundles).insert(
        BundlesCompanion.insert(
          name: 'Desayuno Ejecutivo',
          price: 120.00,
        ),
      );
      await db.into(db.bundleItems).insert(
        BundleItemsCompanion.insert(
          bundleId: bundleId,
          productId: vasoChicoProductId,
          quantityRequired: const Value(1.0),
        ),
      );
      await db.into(db.bundleItems).insert(
        BundleItemsCompanion.insert(
          bundleId: bundleId,
          productId: baguetteProductId,
          quantityRequired: const Value(1.0),
        ),
      );
      debugPrint('✅ Sample bundle "Desayuno Ejecutivo" seeded.');
    }

    debugPrint('✅ Ice Cream & Baguette seeded successfully!');
  }
}