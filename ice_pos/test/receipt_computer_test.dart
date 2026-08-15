import 'package:flutter_test/flutter_test.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/bundle_promotion.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_computer.dart';

Product _product({required int id, required String name, required double price}) {
  return Product(
    id: id,
    name: name,
    price: price,
    imageUrl: null,
    isActive: true,
  );
}

ModifierOption _modifier({required int id, double priceExtra = 0}) {
  return ModifierOptionDto(
    id: id,
    modifierGroupId: 1,
    supplyId: 100 + id,
    quantityDeducted: 0.1,
    priceExtra: priceExtra,
  ).toModifierOption();
}

void main() {
  group('computeReceipt bundle modifier extras', () {
    test('charges bundle price plus paid coffee modifier', () {
      const baguetteId = 1;
      const cafeId = 2;
      final baguette = _product(id: baguetteId, name: 'Baguette jamón', price: 55);
      final cafe = _product(id: cafeId, name: 'Café americano', price: 45);
      final almondMilk = _modifier(id: 1, priceExtra: 15);

      final items = [
        CartItem(product: baguette, quantity: 1),
        CartItem(
          product: cafe,
          quantity: 1,
          selectedModifiers: [almondMilk],
          modifierLabels: ['Leche de almendra'],
        ),
      ];

      final bundles = [
        (
          bundle: Bundle(
            id: 1,
            name: 'Desayuno',
            price: 89,
            isActive: true,
            categoryId: null,
          ),
          bundleItems: [
            BundleItem(id: 1, bundleId: 1, productId: baguetteId, quantityRequired: 1),
            BundleItem(id: 2, bundleId: 1, productId: cafeId, quantityRequired: 1),
          ],
        ),
      ];

      final receipt = computeReceipt(
        items,
        bundles,
        null,
        supplyIdToName: {101: 'Leche de almendra'},
      );

      expect(receipt.total, 104);
      expect(
        receipt.lines.any((l) => l.isBundle && l.amount == 89),
        isTrue,
      );
      expect(
        receipt.lines.any(
          (l) =>
              !l.isBundle &&
              l.amount == 15 &&
              l.modifierDetails.contains('Leche de almendra'),
        ),
        isTrue,
      );
    });

    test('standalone item with modifier still priced normally', () {
      final cafe = _product(id: 2, name: 'Café americano', price: 45);
      final almondMilk = _modifier(id: 1, priceExtra: 15);
      final items = [
        CartItem(
          product: cafe,
          quantity: 1,
          selectedModifiers: [almondMilk],
          modifierLabels: ['Leche de almendra'],
        ),
      ];

      final receipt = computeReceipt(items, const [], null);

      expect(receipt.total, 60);
    });
  });

  group('checkForBundles modifier extras', () {
    test('includes modifier extra in bundle total', () {
      const baguetteId = 1;
      const cafeId = 2;
      final baguette = _product(id: baguetteId, name: 'Baguette jamón', price: 55);
      final cafe = _product(id: cafeId, name: 'Café americano', price: 45);
      final almondMilk = _modifier(id: 1, priceExtra: 15);

      final items = [
        CartItem(product: baguette, quantity: 1),
        CartItem(
          product: cafe,
          quantity: 1,
          selectedModifiers: [almondMilk],
        ),
      ];

      final bundles = [
        (
          bundle: Bundle(
            id: 1,
            name: 'Desayuno',
            price: 89,
            isActive: true,
            categoryId: null,
          ),
          bundleItems: [
            BundleItem(id: 1, bundleId: 1, productId: baguetteId, quantityRequired: 1),
            BundleItem(id: 2, bundleId: 1, productId: cafeId, quantityRequired: 1),
          ],
        ),
      ];

      final adjusted = checkForBundles(items, bundles);

      expect(adjusted.total, 104);
      expect(adjusted.bundleTotal, 104);
      expect(adjusted.standaloneTotal, 0);
    });
  });
}
