import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/product_discount_rule.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';

/// Computes receipt lines using a strict Quantity Map (inventory) approach.
/// Prevents double-counting by decrementing inventory when bundles are applied.
/// [productDiscounts]: descuentos por producto (ej. 20% en productos que contengan "nieve").
ReceiptResult computeReceipt(
  List<CartItem> items,
  List<({Bundle bundle, List<BundleItem> bundleItems})> bundlesWithItems,
  Discount? appliedDiscount, {
  List<ProductDiscountRule> productDiscounts = const [],
}) {
  final lines = <ReceiptLine>[];
  var standaloneSubtotal = 0.0;

  if (items.isEmpty) {
    return ReceiptResult(
      lines: lines,
      total: 0,
      standaloneSubtotal: 0,
    );
  }

  // Step A: Inventory (quantity) and subtotal per product (so modifiers priced per piece are correct)
  final inventory = <int, double>{};
  final productInfo = <int, ({String name, double subtotal})>{};
  for (final item in items) {
    final pid = item.product.id;
    inventory[pid] = (inventory[pid] ?? 0) + item.quantity;
    final prev = productInfo[pid];
    productInfo[pid] = (
      name: prev?.name ?? item.product.name,
      subtotal: (prev?.subtotal ?? 0) + item.subtotal,
    );
  }

  // Step B: Bundle loop - consume from inventory
  for (final bw in bundlesWithItems) {
    final bundle = bw.bundle;
    final reqs = bw.bundleItems;
    if (reqs.isEmpty) continue;

    final reqMap = <int, double>{};
    for (final r in reqs) {
      reqMap[r.productId] = (reqMap[r.productId] ?? 0) + r.quantityRequired;
    }

    while (true) {
      var maxPossible = double.infinity;
      for (final e in reqMap.entries) {
        final need = e.value;
        if (need <= 0) continue;
        final have = inventory[e.key] ?? 0;
        final n = have / need;
        if (n < maxPossible) maxPossible = n;
      }
      if (maxPossible < 1) break;

      final numBundles = maxPossible.floor();
      if (numBundles < 1) break;

      lines.add(ReceiptLine(
        description: 'Bundle: ${bundle.name}',
        amount: numBundles * bundle.price,
        isBundle: true,
        quantity: numBundles,
      ));

      for (final e in reqMap.entries) {
        final pid = e.key;
        final consumed = numBundles * e.value;
        inventory[pid] = (inventory[pid] ?? 0) - consumed;
        if (inventory[pid]! <= 0) inventory.remove(pid);
      }
    }
  }

  // Step C: Leftovers loop - use actual subtotal per product (correct for per-modifier pricing)
  for (final e in inventory.entries) {
    final pid = e.key;
    final qty = e.value;
    if (qty <= 0) continue;

    final info = productInfo[pid];
    if (info == null) continue;

    final amount = info.subtotal;
    standaloneSubtotal += amount;
    lines.add(ReceiptLine(
      description: info.name,
      amount: amount,
      isBundle: false,
      quantity: qty.round(),
    ));
  }

  // Apply QR/code discount ONLY to leftover lines
  var total = lines.fold<double>(0.0, (s, l) => s + l.amount);
  if (appliedDiscount != null && standaloneSubtotal > 0) {
    final discountAmount = standaloneSubtotal * appliedDiscount.percentage;
    total -= discountAmount;
    lines.add(ReceiptLine(
      description: 'Discount (${(appliedDiscount.percentage * 100).toStringAsFixed(0)}%)',
      amount: -discountAmount,
      isBundle: false,
      quantity: 1,
    ));
  }

  // Apply product discounts: match by name (e.g. 20% on "nieve" → Cono Chico, Vaso Grande, etc.)
  final discountLinesToAdd = <ReceiptLine>[];
  for (final line in lines) {
    if (line.isBundle) continue;
    final nameLower = line.description.toLowerCase();
    for (final rule in productDiscounts) {
      if (rule.nameContains.trim().isEmpty) continue;
      if (!nameLower.contains(rule.nameContains.trim().toLowerCase())) continue;
      final discountAmount = line.amount * rule.percentage;
      if (discountAmount <= 0) continue;
      final label = rule.label?.trim().isNotEmpty == true
          ? rule.label!.trim()
          : rule.nameContains.trim();
      discountLinesToAdd.add(ReceiptLine(
        description: 'Descuento ${(rule.percentage * 100).toStringAsFixed(0)}% ($label)',
        amount: -discountAmount,
        isBundle: false,
        quantity: 1,
      ));
      total -= discountAmount;
      break; // one rule per line
    }
  }
  lines.addAll(discountLinesToAdd);

  return ReceiptResult(
    lines: lines,
    total: total,
    standaloneSubtotal: standaloneSubtotal,
  );
}
