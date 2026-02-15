import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';

/// Computes receipt lines using a strict Quantity Map (inventory) approach.
/// Prevents double-counting by decrementing inventory when bundles are applied.
ReceiptResult computeReceipt(
  List<CartItem> items,
  List<({Bundle bundle, List<BundleItem> bundleItems})> bundlesWithItems,
  Discount? appliedDiscount,
) {
  final lines = <ReceiptLine>[];
  var standaloneSubtotal = 0.0;

  if (items.isEmpty) {
    return ReceiptResult(
      lines: lines,
      total: 0,
      standaloneSubtotal: 0,
    );
  }

  // Step A: Create inventory Map<productId, quantity>
  final inventory = <int, double>{};
  final productInfo = <int, ({String name, double unitPrice})>{};
  for (final item in items) {
    final pid = item.product.id;
    inventory[pid] = (inventory[pid] ?? 0) + item.quantity;
    if (!productInfo.containsKey(pid)) {
      final up = item.product.price +
          item.selectedModifiers.fold<double>(0.0, (s, m) => s + m.priceExtra);
      productInfo[pid] = (name: item.product.name, unitPrice: up);
    }
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

  // Step C: Leftovers loop - remaining items at standard price
  for (final e in inventory.entries) {
    final pid = e.key;
    final qty = e.value;
    if (qty <= 0) continue;

    final info = productInfo[pid];
    if (info == null) continue;

    final amount = qty * info.unitPrice;
    standaloneSubtotal += amount;
    lines.add(ReceiptLine(
      description: info.name,
      amount: amount,
      isBundle: false,
      quantity: qty.round(),
    ));
  }

  // Apply QR discount ONLY to leftover lines
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

  return ReceiptResult(
    lines: lines,
    total: total,
    standaloneSubtotal: standaloneSubtotal,
  );
}
