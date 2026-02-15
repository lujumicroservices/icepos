import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/bundle_adjusted_cart.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';

/// Conflict-free pricing engine using a strict CONSUMPTION approach.
///
/// 1. Working Inventory: Map productId -> remaining quantity in cart.
/// 2. Consumption Loop: For each bundle, compute maxPossibleBundles (limiting
///    ingredient), add to bundleTotal, DECREMENT from working inventory.
/// 3. Leftovers: Remaining items get standard price. Discount applies ONLY to these.
/// 4. Virtual cart items: "Bundle X (Qty: N)" for UI clarity.
BundleAdjustedCart checkForBundles(
  List<CartItem> items,
  List<({Bundle bundle, List<BundleItem> bundleItems})> bundlesWithItems,
) {
  if (items.isEmpty) {
    return const BundleAdjustedCart(
      items: [],
      total: 0,
      bundleTotal: 0,
      standaloneTotal: 0,
      virtualBundles: [],
      leftoverItems: [],
    );
  }

  // ─── Step 1: Create Working Inventory ─────────────────────────────────────
  // productId -> remaining quantity (we consume from this)
  final workingInventory = <int, double>{};
  final productToEntries = <int, List<({CartItem item, int idx})>>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final pid = item.product.id;
    workingInventory[pid] = (workingInventory[pid] ?? 0) + item.quantity;
    productToEntries.putIfAbsent(pid, () => []).add((item: item, idx: i));
  }

  var bundleTotal = 0.0;
  final virtualBundles = <VirtualBundleLine>[];
  final bundledAllocation = <int, ({double qty, double value, String name})>{};

  // ─── Step 2: Consumption Loop ────────────────────────────────────────────
  var anyMatched = true;
  while (anyMatched) {
    anyMatched = false;
    for (final bw in bundlesWithItems) {
      final bundle = bw.bundle;
      final reqs = bw.bundleItems;
      if (reqs.isEmpty) continue;

      final reqMap = <int, double>{};
      for (final r in reqs) {
        reqMap[r.productId] = (reqMap[r.productId] ?? 0) + r.quantityRequired;
      }

      // Find limiting ingredient: maxPossibleBundles = min(have/need)
      var maxPossibleBundles = double.infinity;
      for (final e in reqMap.entries) {
        final need = e.value;
        if (need <= 0) continue;
        final have = workingInventory[e.key] ?? 0;
        final n = have / need;
        if (n < maxPossibleBundles) maxPossibleBundles = n;
      }
      if (maxPossibleBundles <= 0 ||
          maxPossibleBundles == double.infinity) {
        continue;
      }
      final numBundles = maxPossibleBundles.floor();
      if (numBundles < 1) continue;

      // Action: add to total, DECREMENT from working inventory
      anyMatched = true;
      bundleTotal += numBundles * bundle.price;
      final existing = virtualBundles
          .indexWhere((vb) => vb.bundleName == bundle.name);
      if (existing >= 0) {
        virtualBundles[existing] = VirtualBundleLine(
          bundleName: bundle.name,
          quantity: virtualBundles[existing].quantity + numBundles,
          unitPrice: bundle.price,
        );
      } else {
        virtualBundles.add(VirtualBundleLine(
          bundleName: bundle.name,
          quantity: numBundles,
          unitPrice: bundle.price,
        ));
      }

      // Allocate bundle price proportionally for display
      double sumOrig = 0;
      for (final e in reqMap.entries) {
        final entry = productToEntries[e.key]?.firstOrNull;
        if (entry != null) {
          final up = entry.item.product.price +
              entry.item.selectedModifiers.fold(0.0, (s, m) => s + m.priceExtra);
          sumOrig += e.value * up;
        }
      }
      if (sumOrig <= 0) sumOrig = 1;

      for (final e in reqMap.entries) {
        final pid = e.key;
        final consumed = numBundles * e.value;
        workingInventory[pid] = (workingInventory[pid] ?? 0) - consumed;
        if (workingInventory[pid]! <= 0) workingInventory.remove(pid);

        final entry = productToEntries[pid]?.firstOrNull;
        final up = entry != null
            ? entry.item.product.price +
                entry.item.selectedModifiers.fold(0.0, (s, m) => s + m.priceExtra)
            : 0.0;
        final share = sumOrig > 0 ? (e.value * up) / sumOrig : 0.0;
        final productValue = bundle.price * share;
        final prev = bundledAllocation[pid];
        bundledAllocation[pid] = (
          qty: (prev?.qty ?? 0) + consumed,
          value: (prev?.value ?? 0) + productValue,
          name: bundle.name,
        );
      }
    }
  }

  // ─── Step 3: Calculate Leftovers (standalone items) ───────────────────────
  final originalQty = <int, double>{};
  for (final item in items) {
    originalQty[item.product.id] =
        (originalQty[item.product.id] ?? 0) + item.quantity;
  }

  var standaloneTotal = 0.0;
  final result = <BundleAdjustedItem>[];
  final leftoverItems = <BundleAdjustedItem>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final pid = item.product.id;
    final origUp = item.product.price +
        item.selectedModifiers.fold<double>(0.0, (s, m) => s + m.priceExtra);
    final totalPidQty = originalQty[pid] ?? item.quantity;
    final remainingQty = workingInventory[pid] ?? 0;
    final bundledQty = totalPidQty - remainingQty;
    final bundledFrac = totalPidQty > 0
        ? (bundledQty / totalPidQty).clamp(0.0, 1.0)
        : 0.0;
    final thisBundled = item.quantity * bundledFrac;
    final thisStandalone = item.quantity - thisBundled;

    standaloneTotal += thisStandalone * origUp;

    if (thisStandalone > 0) {
      leftoverItems.add(BundleAdjustedItem(
        item: item.copyWith(quantity: thisStandalone),
        effectiveUnitPrice: origUp,
        bundleName: null,
      ));
    }

    final alloc = bundledAllocation[pid];
    double effectiveSubtotal;
    double effectiveUp;
    String? bundleName;
    if (alloc != null && alloc.qty > 0 && thisBundled > 0) {
      final bundledUnitPrice = alloc.value / alloc.qty;
      effectiveSubtotal = thisBundled * bundledUnitPrice + thisStandalone * origUp;
      effectiveUp = item.quantity > 0 ? effectiveSubtotal / item.quantity : origUp;
      bundleName = alloc.name;
    } else {
      effectiveSubtotal = item.quantity * origUp;
      effectiveUp = origUp;
    }

    result.add(BundleAdjustedItem(
      item: item,
      effectiveUnitPrice: effectiveUp,
      bundleName: bundleName,
    ));
  }

  final total = bundleTotal + standaloneTotal;
  return BundleAdjustedCart(
    items: result,
    total: total,
    bundleTotal: bundleTotal,
    standaloneTotal: standaloneTotal,
    virtualBundles: virtualBundles,
    leftoverItems: leftoverItems,
  );
}
