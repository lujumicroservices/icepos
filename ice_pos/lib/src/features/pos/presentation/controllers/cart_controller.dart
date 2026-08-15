import 'dart:convert';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart' as pos_data;
import 'package:ice_pos/src/features/pos/domain/bundle_adjusted_cart.dart';
import 'package:ice_pos/src/features/pos/domain/bundle_promotion.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/product_discount_rule.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_computer.dart';
import 'package:ice_pos/src/features/pos/domain/sale_payment.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/features/pos/domain/cart_state.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_controller.g.dart';

/// Provides receipt lines using the Quantity Map approach (no double-counting).
final currentReceiptProvider =
    FutureProvider<ReceiptResult>((ref) async {
  ref.watch(posCategoriesRefreshProvider);
  final cartState = ref.watch(cartControllerProvider);
  if (cartState.items.isEmpty) {
    return const ReceiptResult(lines: [], total: 0, standaloneSubtotal: 0);
  }
  final repo = ref.read(pos_data.posRepositoryProvider)!;
  final bundles = await repo.getBundlesWithItems();
  final supplyIds = cartState.items
      .expand((item) => item.selectedModifiers.map((m) => m.supplyId))
      .toSet();
  final supplyIdToName = await repo.getSupplyNamesByIds(supplyIds);
  return computeReceipt(
    cartState.items,
    bundles,
    cartState.appliedDiscount,
    productDiscounts: cartState.productDiscounts,
    supplyIdToName: supplyIdToName,
  );
});

/// Nombres de insumos para mostrar sabores en el carrito del POS.
final cartModifierSupplyNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  ref.watch(cartControllerProvider);
  final items = ref.read(cartControllerProvider).items;
  final supplyIds =
      items.expand((item) => item.selectedModifiers.map((m) => m.supplyId)).toSet();
  if (supplyIds.isEmpty) return {};
  final repo = ref.read(pos_data.posRepositoryProvider);
  if (repo == null) return {};
  return repo.getSupplyNamesByIds(supplyIds);
});

/// Legacy provider - kept for checkout which needs bundle-adjusted items.
final bundleAdjustedCartProvider = FutureProvider<BundleAdjustedCart>((ref) async {
  final cartState = ref.watch(cartControllerProvider);
  if (cartState.items.isEmpty) {
    return const BundleAdjustedCart(items: [], total: 0, virtualBundles: []);
  }
  final bundles =
      await ref.read(pos_data.posRepositoryProvider)!.getBundlesWithItems();
  return checkForBundles(cartState.items, bundles);
});

@riverpod
class CartController extends _$CartController {
  @override
  CartState build() => const CartState();

  /// Returns the current receipt using the Quantity Map approach.
  /// Use [currentReceiptProvider] for reactive UI updates.
  Future<ReceiptResult> get currentReceipt async {
    if (state.items.isEmpty) {
      return const ReceiptResult(lines: [], total: 0, standaloneSubtotal: 0);
    }
    final repo = ref.read(pos_data.posRepositoryProvider)!;
    final bundles = await repo.getBundlesWithItems();
    final supplyIds = state.items
        .expand((item) => item.selectedModifiers.map((m) => m.supplyId))
        .toSet();
    final supplyIdToName = await repo.getSupplyNamesByIds(supplyIds);
    return computeReceipt(
      state.items,
      bundles,
      state.appliedDiscount,
      productDiscounts: state.productDiscounts,
      supplyIdToName: supplyIdToName,
    );
  }

  void addToCart(
    Product product, {
    List<ModifierOption> selectedModifiers = const [],
    List<String> modifierLabels = const [],
    double quantity = 1,
  }) {
    final double qty = quantity > 0 ? quantity : 1.0;
    final index = state.items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          _modifiersEqual(item.selectedModifiers, selectedModifiers),
    );
    if (index >= 0) {
      final existing = state.items[index];
      final updated = [...state.items];
      updated[index] = existing.copyWith(quantity: existing.quantity + qty);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            quantity: qty,
            selectedModifiers: selectedModifiers,
            modifierLabels: modifierLabels,
          ),
        ],
      );
    }
  }

  bool _modifiersEqual(
    List<ModifierOption> a,
    List<ModifierOption> b,
  ) {
    if (a.length != b.length) return false;
    final aIds = a.map((m) => m.id).toList()..sort();
    final bIds = b.map((m) => m.id).toList()..sort();
    for (var i = 0; i < aIds.length; i++) {
      if (aIds[i] != bIds[i]) return false;
    }
    return true;
  }

  void removeFromCart(CartItem item) {
    final index = state.items.indexWhere((i) => i == item);
    if (index < 0) return;
    final existing = state.items[index];
    if (existing.quantity <= 1) {
      state = state.copyWith(
        items: state.items.where((i) => i != item).toList(),
      );
    } else {
      final updated = [...state.items];
      updated[index] = existing.copyWith(quantity: existing.quantity - 1);
      state = state.copyWith(items: updated);
    }
  }

  void clearCart() {
    state = const CartState();
  }

  /// Applies a discount by code. Returns true if valid.
  Future<bool> applyDiscount(String code) async {
    final discount =
        await ref.read(pos_data.posRepositoryProvider)!.findDiscountByCode(code);
    if (discount == null) return false;
    state = state.copyWith(appliedDiscount: discount);
    return true;
  }

  /// Applies a preloaded catalog discount (from admin list / picker).
  void applyCatalogDiscount(Discount discount) {
    if (!discount.isActive) return;
    state = state.copyWith(appliedDiscount: discount);
  }

  void removeDiscount() {
    state = state.copyWith(clearDiscount: true);
  }

  /// Aplica un descuento por porcentaje a productos cuyo nombre contenga [nameContains].
  /// [percentage] 0.20 = 20%. [label] opcional para el ticket (ej. "Día de la mujer").
  void applyProductDiscount({
    required String nameContains,
    required double percentage,
    String? label,
  }) {
    if (nameContains.trim().isEmpty || percentage <= 0 || percentage > 1) return;
    state = state.copyWith(
      productDiscounts: [
        ...state.productDiscounts,
        ProductDiscountRule(
          nameContains: nameContains.trim(),
          percentage: percentage,
          label: label?.trim().isEmpty == true ? null : label?.trim(),
        ),
      ],
    );
  }

  /// Quita el descuento por producto en el índice indicado.
  void removeProductDiscountAt(int index) {
    if (index < 0 || index >= state.productDiscounts.length) return;
    final updated = List<ProductDiscountRule>.from(state.productDiscounts)
      ..removeAt(index);
    state = state.copyWith(productDiscounts: updated);
  }

  /// Restores a parked order into the cart and removes it from DB.
  Future<void> restoreOrder(ParkedOrder order) async {
    clearCart();
    final decoded = jsonDecode(order.itemsJson) as List<dynamic>;
    final items = decoded
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
    state = CartState(items: items);
    await ref.read(pos_data.posRepositoryProvider)!.deleteParkedOrder(order.id);
  }

  /// Completes the sale and clears the cart.
  /// [paymentData] from CheckoutDialog: single method or split (`split: true`, `payments: [...]`).
  Future<void> completeSale(Map<String, dynamic> paymentData) async {
    if (state.items.isEmpty) return;

    final receipt = await currentReceipt;
    final payments = SalePaymentLine.fromCheckoutPaymentData(
      paymentData,
      cartTotal: receipt.total,
    );
    final isSplit = payments.length > 1;
    final primary = payments.first;
    final paymentMethod = isSplit ? 'SPLIT' : primary.method;
    final amountTendered = payments
        .where((p) => p.method == 'CASH')
        .fold<double>(0, (s, p) => s + (p.amountTendered ?? p.amount));
    final changeGiven = payments
        .where((p) => p.method == 'CASH')
        .fold<double>(0, (s, p) => s + (p.changeGiven ?? 0));

    final bundles =
        await ref.read(pos_data.posRepositoryProvider)!.getBundlesWithItems();
    final adjusted = checkForBundles(state.items, bundles);

    final items = adjusted.items
        .map(
          (adj) => pos_data.CartItem(
            productId: adj.item.product.id,
            quantity: adj.item.quantity,
            unitPrice: adj.effectiveUnitPrice,
            productName: adj.item.product.name,
            selectedModifiers: adj.item.selectedModifiers,
          ),
        )
        .toList();

    await ref.read(pos_data.posRepositoryProvider)!.processSale(
          items,
          totalAmount: receipt.total,
          paymentMethod: paymentMethod,
          amountTendered: amountTendered,
          changeGiven: changeGiven,
          payments: isSplit ? payments : null,
        );
    clearCart();
  }
}
