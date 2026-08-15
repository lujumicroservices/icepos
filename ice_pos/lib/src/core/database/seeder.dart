import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart' show rootBundle;
import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;

  DatabaseSeeder(this.db);

  /// Loads categories and products from [menu_reyes_nieves.json] and inserts them.
  /// Call after schema v9 (Categories table, products.categoryId). Skips if any category already exists.
  Future<void> seedMenuReyesNieves() async {
    final existing = await db.select(db.categories).get();
    if (existing.isNotEmpty) {
      debugPrint('Menu Reyes Nieves already seeded (categories exist). Skipping.');
      return;
    }
    await _loadMenuFromJson();
  }

  /// Clears existing menu (categories + products that belong to a category), then loads from JSON again.
  /// Also removes modifier groups/options linked to those products so no orphans remain.
  Future<void> seedMenuReyesNievesForce() async {
    await db.transaction(() async {
      final categoryProducts = await (db.select(db.products)
            ..where((p) => p.categoryId.isNotNull()))
          .get();
      final productIds = categoryProducts.map((p) => p.id).toList();
      for (final pid in productIds) {
        final pmLinks = await (db.select(db.productModifiers)
              ..where((pm) => pm.productId.equals(pid)))
            .get();
        final groupIds = pmLinks.map((pm) => pm.modifierGroupId).toSet().toList();
        for (final gid in groupIds) {
          await (db.delete(db.modifierOptions)
                ..where((o) => o.modifierGroupId.equals(gid)))
              .go();
        }
        await (db.delete(db.productModifiers)..where((pm) => pm.productId.equals(pid))).go();
        for (final gid in groupIds) {
          await (db.delete(db.modifierGroups)..where((g) => g.id.equals(gid))).go();
        }
      }
      await (db.delete(db.products)..where((p) => p.categoryId.isNotNull())).go();
      await db.delete(db.categories).go();
    });
    debugPrint('Cleared menu (categories and linked products). Reloading from JSON...');
    await _loadMenuFromJson();
  }

  Future<void> _loadMenuFromJson() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString('assets/data/menu_reyes_nieves.json');
    } catch (e) {
      debugPrint('Could not load menu_reyes_nieves.json: $e');
      return;
    }
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final categoriesJson = map['categories'] as List<dynamic>? ?? [];
    final productsByCategory = map['products'] as List<dynamic>? ?? [];

    final categoryNameToId = <String, int>{};
    for (final c in categoriesJson) {
      final m = c as Map<String, dynamic>;
      final name = m['name'] as String;
      final parentName = m['parentName'] as String?;
      final parentId = parentName != null && parentName.isNotEmpty
          ? categoryNameToId[parentName]
          : m['parentId'] as int?;
      final color = m['color'] as String?;
      final id = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: name,
          parentId: Value(parentId),
          color: Value(color),
        ),
      );
      categoryNameToId[name] = id;
    }
    debugPrint('✅ Inserted ${categoryNameToId.length} categories (Menu Reyes Nieves).');

    int productCount = 0;
    for (final group in productsByCategory) {
      final g = group as Map<String, dynamic>;
      final categoryName = g['category'] as String?;
      final items = g['items'] as List<dynamic>? ?? [];
      final categoryId = categoryName == null ? null : categoryNameToId[categoryName];
      for (final item in items) {
        final i = item as Map<String, dynamic>;
        final name = i['name'] as String;
        final price = (i['price'] as num).toDouble();
        await db.into(db.products).insert(
          ProductsCompanion.insert(
            name: name,
            price: price,
            categoryId: Value(categoryId),
          ),
        );
        productCount++;
      }
    }
    debugPrint('✅ Inserted $productCount products (Menu Reyes Nieves).');
  }

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
      await seedMenuReyesNieves();
      try {
        await seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
      } catch (e, st) {
        debugPrint('Bolis seed error: $e');
        debugPrint('$st');
      }
      try {
        await seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
      } catch (e, st) {
        debugPrint('Paletas seed error: $e');
        debugPrint('$st');
      }
      try {
        await seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
      } catch (e, st) {
        debugPrint('Nieves seed error: $e');
        debugPrint('$st');
      }
      try {
        await seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
      } catch (e, st) {
        debugPrint('Bebidas leche modifiers seed error: $e');
        debugPrint('$st');
      }
      try {
        await seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
      } catch (e, st) {
        debugPrint('Malteadas modifiers seed error: $e');
        debugPrint('$st');
      }
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
      await db.into(db.discounts).insert(
        DiscountsCompanion.insert(
          code: 'ESTUDIANTE',
          percentage: 0.10,
          description: 'Descuento estudiantes 10%',
          isActive: const Value(true),
        ),
      );
      debugPrint('✅ Sample discounts (SCHOOL_CAMPO_VERDE, ESTUDIANTE 10%) seeded.');
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

    // 11. Seed Menu Reyes Nieves (categories + products from JSON) if not already present
    await seedMenuReyesNieves();

    // 12. Seed products with modifiers from JSON (Boli, Paletas, Nieves)
    await seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
    await seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
    try {
      await seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
    } catch (e, st) {
      debugPrint('Nieves seed error: $e');
      debugPrint('$st');
    }
    try {
      await seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
    } catch (e, st) {
      debugPrint('Bebidas leche modifiers seed error: $e');
      debugPrint('$st');
    }
    try {
      await seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
    } catch (e, st) {
      debugPrint('Malteadas modifiers seed error: $e');
      debugPrint('$st');
    }
  }

  /// Loads product with modifier groups from JSON (e.g. bolis_modifiers.json). Skips if product already has modifiers.
  Future<void> seedProductWithModifiersFromJson(String assetPath) async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString(assetPath);
    } catch (e) {
      debugPrint('Could not load $assetPath: $e');
      return;
    }
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    await _createProductWithModifiers(map);
  }

  /// Ensures categories required by nieves_modifiers.json exist (Conos, Vasos, Canastas under Nieves de Garrafa y Paquetes).
  /// Call before seedProductsWithModifiersFromJson('nieves_modifiers.json') when menu may have been seeded from an old JSON.
  Future<void> _ensureNievesSubcategories() async {
    const parentName = 'Nieves de Garrafa y Paquetes';
    const subNames = ['Conos', 'Vasos', 'Canastas'];
    const subColors = ['#B0E0E6', '#ADD8E6', '#87CEFA'];

    final parentList = await (db.select(db.categories)
          ..where((c) => c.name.equals(parentName)))
        .get();
    int? parentId;
    if (parentList.isEmpty) {
      parentId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: parentName,
          parentId: const Value(null),
          color: const Value('#87CEEB'),
        ),
      );
      debugPrint('Created category "$parentName" for nieves subcategories.');
    } else {
      parentId = parentList.first.id;
    }

    for (var i = 0; i < subNames.length; i++) {
      final name = subNames[i];
      final list = await (db.select(db.categories)
            ..where((c) => c.name.equals(name)))
          .get();
      if (list.isEmpty) {
        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            parentId: Value(parentId),
            color: Value(subColors[i]),
          ),
        );
        debugPrint('Created category "$name" for nieves products.');
      }
    }
  }

  /// Loads multiple products with modifiers from JSON (e.g. paletas_modifiers.json).
  /// If the JSON has "flavorOptions" and groups use "optionsRef": "flavorOptions", options are expanded from that list.
  Future<void> seedProductsWithModifiersFromJson(String assetPath) async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString(assetPath);
    } catch (e) {
      debugPrint('Could not load $assetPath: $e');
      return;
    }
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final list = map['products'] as List<dynamic>? ?? [];
    final flavorOptions = map['flavorOptions'] as List<dynamic>?;

    if (assetPath.contains('nieves_modifiers')) {
      await _ensureNievesSubcategories();
    }

    for (final item in list) {
      final productMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
      if (flavorOptions != null) {
        final groups = productMap['modifierGroups'] as List<dynamic>? ?? [];
        final newGroups = <Map<String, dynamic>>[];
        for (final g in groups) {
          final groupMap = Map<String, dynamic>.from(g as Map<String, dynamic>);
          final ref = groupMap['optionsRef'] as String?;
          if (ref == 'flavorOptions' && flavorOptions.isNotEmpty) {
            groupMap['options'] = List<dynamic>.from(flavorOptions);
            groupMap.remove('optionsRef');
          }
          newGroups.add(groupMap);
        }
        productMap['modifierGroups'] = newGroups;
      }
      await _createProductWithModifiers(productMap);
    }
  }

  Future<void> _createProductWithModifiers(Map<String, dynamic> map) async {
    final productJson = map['product'] as Map<String, dynamic>?;
    final groupsJson = map['modifierGroups'] as List<dynamic>? ?? [];
    if (productJson == null || groupsJson.isEmpty) return;

    final productName = productJson['name'] as String?;
    final price = (productJson['price'] as num?)?.toDouble() ?? 0.0;
    final categoryName = productJson['categoryName'] as String?;
    if (productName == null || productName.isEmpty) return;

    final categoryList = categoryName != null && categoryName.isNotEmpty
        ? await (db.select(db.categories)
              ..where((c) => c.name.equals(categoryName)))
            .get()
        : <Category>[];
    final category = categoryList.isNotEmpty ? categoryList.first : null;
    if (categoryName != null && category == null) {
      debugPrint('Category "$categoryName" not found. Skipping product "$productName".');
      return;
    }
    final categoryId = category?.id;

    // Remove any existing product with this name (with or without modifiers) so reload from JSON always wins.
    final existingList = await (db.select(db.products)
          ..where((p) => p.name.equals(productName)))
        .get();
    for (final p in existingList) {
      final pmLinks = await (db.select(db.productModifiers)
            ..where((pm) => pm.productId.equals(p.id)))
          .get();
      final groupIds = pmLinks.map((pm) => pm.modifierGroupId).toSet().toList();
      for (final gid in groupIds) {
        await (db.delete(db.modifierOptions)
              ..where((o) => o.modifierGroupId.equals(gid)))
            .go();
      }
      await (db.delete(db.productModifiers)..where((pm) => pm.productId.equals(p.id))).go();
      for (final gid in groupIds) {
        await (db.delete(db.modifierGroups)..where((g) => g.id.equals(gid))).go();
      }
      await (db.delete(db.recipes)..where((r) => r.productId.equals(p.id))).go();
      await (db.delete(db.products)..where((p2) => p2.id.equals(p.id))).go();
    }

    final supplyIds = <String, int>{};

    for (final g in groupsJson) {
      final groupMap = g as Map<String, dynamic>;
      final options = groupMap['options'] as List<dynamic>? ?? [];
      for (final o in options) {
        final opt = o as Map<String, dynamic>;
        final supplyName = opt['supplyName'] as String? ?? '';
        if (supplyName.isEmpty || supplyIds.containsKey(supplyName)) continue;
        final existingList = await (db.select(db.supplies)
              ..where((s) => s.name.equals(supplyName)))
            .get();
        final existing = existingList.isNotEmpty ? existingList.first : null;
        if (existing != null) {
          final isNieveFlavor = supplyName.startsWith('Nieve ');
          if (isNieveFlavor && existing.unit != 'ml') {
            await (db.update(db.supplies)..where((s) => s.id.equals(existing.id)))
                .write(SuppliesCompanion(unit: Value('ml')));
          }
          supplyIds[supplyName] = existing.id;
          continue;
        }
        final isBoliType = supplyName.startsWith('Boli Regular') || supplyName.startsWith('Boli Light');
        final isPaletaType = supplyName.startsWith('Paleta Agua') || supplyName.startsWith('Paleta Forrada');
        final isNieveType = supplyName.startsWith('Nieve ');
        // Sabores de nieve: unidad ml; se descontarán quantityDeducted (ml) por cada bola en el modificador.
        final id = await db.into(db.supplies).insert(
          SuppliesCompanion.insert(
            name: supplyName,
            unit: isNieveType ? 'ml' : 'pcs',
            currentStock: Value(isBoliType || isPaletaType ? 100.0 : (isNieveType ? 5000.0 : 0.0)),
            costPerUnit: const Value(0.0),
          ),
        );
        supplyIds[supplyName] = id;
      }
    }

    final productId = await db.into(db.products).insert(
      ProductsCompanion.insert(
        name: productName,
        price: price,
        categoryId: Value(categoryId),
      ),
    );

    for (final g in groupsJson) {
      final groupMap = g as Map<String, dynamic>;
      final name = groupMap['name'] as String? ?? '';
      final minSel = groupMap['minSelection'] as int? ?? 0;
      final maxSel = groupMap['maxSelection'] as int? ?? 1;
      final options = groupMap['options'] as List<dynamic>? ?? [];

      final groupId = await db.into(db.modifierGroups).insert(
        ModifierGroupsCompanion.insert(
          name: name,
          minSelection: Value(minSel),
          maxSelection: maxSel,
        ),
      );
      await db.into(db.productModifiers).insert(
        ProductModifiersCompanion.insert(
          productId: productId,
          modifierGroupId: groupId,
        ),
      );
      for (final o in options) {
        final opt = o as Map<String, dynamic>;
        final supplyName = opt['supplyName'] as String? ?? '';
        final qty = (opt['quantityDeducted'] as num?)?.toDouble() ?? 0.0;
        final extra = (opt['priceExtra'] as num?)?.toDouble() ?? 0.0;
        final supplyId = supplyIds[supplyName];
        if (supplyId == null) continue;
        await db.into(db.modifierOptions).insert(
          ModifierOptionsCompanion.insert(
            modifierGroupId: groupId,
            supplyId: supplyId,
            quantityDeducted: qty,
            priceExtra: Value(extra),
          ),
        );
      }
    }

    debugPrint('✅ Product "$productName" with modifiers seeded from JSON.');
  }
}