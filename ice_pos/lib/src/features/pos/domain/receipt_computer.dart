import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/discount_type.dart';
import 'package:ice_pos/src/features/pos/domain/product_discount_rule.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';

class _ReceiptUnit {
  _ReceiptUnit({
    required this.productId,
    required this.productName,
    required this.modifierDetails,
    required this.amount,
    double? employeeAmount,
    this.modifierExtra = 0,
    this.lineQuantity = 1,
  }) : employeeAmount = employeeAmount ?? amount;

  final int productId;
  final String productName;
  final List<String> modifierDetails;
  final double amount;
  /// Same line total using employee base prices (for employee discount codes).
  final double employeeAmount;
  /// Paid add-ons (e.g. leche de almendra) — billed on top of bundle price.
  final double modifierExtra;
  final int lineQuantity;
}

List<String> _modifierDetailsForItem(CartItem item, Map<int, String> supplyIdToName) {
  return cartItemModifierLabels(item, supplyIdToName: supplyIdToName);
}

List<_ReceiptUnit> _expandCartItemsToUnits(
  List<CartItem> items,
  Map<int, String> supplyIdToName,
) {
  final units = <_ReceiptUnit>[];
  for (final item in items) {
    final modDetails = _modifierDetailsForItem(item, supplyIdToName);
    final empBase = item.basePrice(useEmployeePrice: true);
    if (item.selectedModifiers.isEmpty) {
      final qty = item.quantity;
      if (qty == qty.roundToDouble() && qty >= 1) {
        for (var i = 0; i < qty.round(); i++) {
          units.add(
            _ReceiptUnit(
              productId: item.product.id,
              productName: item.product.name,
              modifierDetails: const [],
              amount: item.product.price,
              employeeAmount: empBase,
            ),
          );
        }
      } else {
        units.add(
          _ReceiptUnit(
            productId: item.product.id,
            productName: item.product.name,
            modifierDetails: const [],
            amount: item.subtotal,
            employeeAmount: item.getSubtotal(useEmployeePrice: true),
            lineQuantity: 1,
          ),
        );
      }
      continue;
    }

    final qty = item.quantity;
    final modCount = item.selectedModifiers.length;
    if (qty > 0 && modCount == qty.round()) {
      for (var i = 0; i < modCount; i++) {
        final m = item.selectedModifiers[i];
        units.add(
          _ReceiptUnit(
            productId: item.product.id,
            productName: item.product.name,
            modifierDetails: [modDetails[i]],
            amount: item.product.price + m.priceExtra,
            employeeAmount: empBase + m.priceExtra,
            modifierExtra: m.priceExtra,
          ),
        );
      }
      continue;
    }

    final modifierExtra = item.selectedModifiers.fold<double>(
      0.0,
      (sum, m) => sum + m.priceExtra,
    );
    units.add(
      _ReceiptUnit(
        productId: item.product.id,
        productName: item.product.name,
        modifierDetails: modDetails,
        amount: item.subtotal,
        employeeAmount: item.getSubtotal(useEmployeePrice: true),
        modifierExtra: modifierExtra,
        lineQuantity: qty.round().clamp(1, 999),
      ),
    );
  }
  return units;
}

Map<int, List<_ReceiptUnit>> _unitsByProduct(List<_ReceiptUnit> units) {
  final map = <int, List<_ReceiptUnit>>{};
  for (final unit in units) {
    map.putIfAbsent(unit.productId, () => []).add(unit);
  }
  return map;
}

double _inventoryCount(List<_ReceiptUnit>? units) {
  if (units == null || units.isEmpty) return 0;
  return units.fold<double>(0, (sum, u) => sum + u.lineQuantity);
}

void _consumeUnits(
  List<_ReceiptUnit> units,
  double toConsume, {
  List<_ReceiptUnit>? consumedOut,
}) {
  var remaining = toConsume;
  var i = 0;
  while (remaining > 0 && i < units.length) {
    final u = units[i];
    if (u.lineQuantity <= remaining) {
      consumedOut?.add(u);
      remaining -= u.lineQuantity;
      units.removeAt(i);
    } else {
      final take = remaining;
      final keep = u.lineQuantity - take.ceil();
      final takeFraction = take / u.lineQuantity;
      final keepFraction = keep / u.lineQuantity;
      consumedOut?.add(
        _ReceiptUnit(
          productId: u.productId,
          productName: u.productName,
          modifierDetails: u.modifierDetails,
          amount: u.amount * takeFraction,
          employeeAmount: u.employeeAmount * takeFraction,
          modifierExtra: u.modifierExtra * takeFraction,
          lineQuantity: take.ceil().clamp(1, u.lineQuantity),
        ),
      );
      units[i] = _ReceiptUnit(
        productId: u.productId,
        productName: u.productName,
        modifierDetails: u.modifierDetails,
        amount: u.amount * keepFraction,
        employeeAmount: u.employeeAmount * keepFraction,
        modifierExtra: u.modifierExtra * keepFraction,
        lineQuantity: keep,
      );
      remaining = 0;
    }
  }
}

void _addBundledModifierExtraLines(
  List<ReceiptLine> lines,
  List<_ReceiptUnit> consumedUnits,
) {
  final grouped = <String, ({String name, List<String> mods, double amount, int qty})>{};
  for (final u in consumedUnits) {
    if (u.modifierExtra <= 0) continue;
    final key = '${u.productName}|${u.modifierDetails.join('\u0001')}';
    final prev = grouped[key];
    grouped[key] = (
      name: u.productName,
      mods: u.modifierDetails,
      amount: (prev?.amount ?? 0) + u.modifierExtra,
      qty: (prev?.qty ?? 0) + u.lineQuantity,
    );
  }
  for (final g in grouped.values) {
    lines.add(
      ReceiptLine(
        description: g.name,
        amount: g.amount,
        isBundle: false,
        quantity: g.qty,
        modifierDetails: g.mods,
      ),
    );
  }
}

String _unitGroupKey(_ReceiptUnit unit) =>
    '${unit.productId}|${unit.modifierDetails.join('\u0001')}|${unit.lineQuantity}';

/// Computes receipt lines using a strict Quantity Map (inventory) approach.
/// Prevents double-counting by decrementing inventory when bundles are applied.
/// [productDiscounts]: descuentos por producto (ej. 20% en productos que contengan "nieve").
/// [supplyIdToName]: nombres de insumos para etiquetas de sabores en el ticket.
ReceiptResult computeReceipt(
  List<CartItem> items,
  List<({Bundle bundle, List<BundleItem> bundleItems})> bundlesWithItems,
  Discount? appliedDiscount, {
  List<ProductDiscountRule> productDiscounts = const [],
  Map<int, String> supplyIdToName = const {},
}) {
  final lines = <ReceiptLine>[];
  var standaloneSubtotal = 0.0;
  var employeeStandaloneSubtotal = 0.0;
  final isEmployeeDiscount = DiscountType.isEmployee(appliedDiscount?.type);

  if (items.isEmpty) {
    return ReceiptResult(
      lines: lines,
      total: 0,
      standaloneSubtotal: 0,
    );
  }

  final allUnits = _expandCartItemsToUnits(items, supplyIdToName);
  final unitsByProduct = _unitsByProduct(allUnits);

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
        final have = _inventoryCount(unitsByProduct[e.key]);
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

      final consumedForBundle = <_ReceiptUnit>[];
      for (final e in reqMap.entries) {
        final pid = e.key;
        final consumed = numBundles * e.value;
        final list = unitsByProduct[pid];
        if (list != null) {
          _consumeUnits(list, consumed, consumedOut: consumedForBundle);
          if (list.isEmpty) unitsByProduct.remove(pid);
        }
      }
      _addBundledModifierExtraLines(lines, consumedForBundle);
    }
  }

  // Step C: Leftovers with modifier detail
  final leftoverUnits = unitsByProduct.values.expand((list) => list).toList();
  final grouped = <String, List<_ReceiptUnit>>{};
  for (final unit in leftoverUnits) {
    grouped.putIfAbsent(_unitGroupKey(unit), () => []).add(unit);
  }

  for (final group in grouped.values) {
    final sample = group.first;
    final lineQty = group.fold<int>(0, (s, u) => s + u.lineQuantity);
    final amount = group.fold<double>(0, (s, u) => s + u.amount);
    final empAmount = group.fold<double>(0, (s, u) => s + u.employeeAmount);
    standaloneSubtotal += amount;
    employeeStandaloneSubtotal += empAmount;
    lines.add(
      ReceiptLine(
        description: sample.productName,
        amount: amount,
        isBundle: false,
        quantity: lineQty,
        modifierDetails: sample.modifierDetails,
      ),
    );
  }

  // Apply code discount ONLY to leftover lines
  var total = lines.fold<double>(0.0, (s, l) => s + l.amount);
  if (appliedDiscount != null && standaloneSubtotal > 0) {
    if (isEmployeeDiscount) {
      final discountAmount = (standaloneSubtotal - employeeStandaloneSubtotal)
          .clamp(0.0, standaloneSubtotal);
      if (discountAmount > 0) {
        total -= discountAmount;
        lines.add(ReceiptLine(
          description: 'Precio empleado',
          amount: -discountAmount,
          isBundle: false,
          quantity: 1,
        ));
      }
    } else {
      final discountAmount = standaloneSubtotal * appliedDiscount.percentage;
      total -= discountAmount;
      final label = appliedDiscount.description.trim().isNotEmpty
          ? appliedDiscount.description.trim()
          : 'Discount';
      lines.add(ReceiptLine(
        description:
            '$label (${(appliedDiscount.percentage * 100).toStringAsFixed(0)}%)',
        amount: -discountAmount,
        isBundle: false,
        quantity: 1,
      ));
    }
  }

  // Apply product discounts: match by name (e.g. 20% on "nieve" → Cono Chico, Vaso Grande, etc.)
  final discountLinesToAdd = <ReceiptLine>[];
  for (final line in lines) {
    if (line.isBundle) continue;
    if (line.amount < 0) continue; // skip discount lines
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
