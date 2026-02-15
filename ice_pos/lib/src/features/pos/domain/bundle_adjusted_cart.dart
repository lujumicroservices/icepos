import 'package:ice_pos/src/features/pos/domain/cart_item.dart';

/// A virtual cart line for a bundle (e.g. "Desayuno Ejecutivo × 2").
class VirtualBundleLine {
  const VirtualBundleLine({
    required this.bundleName,
    required this.quantity,
    required this.unitPrice,
  });

  final String bundleName;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

/// A cart item with its effective (possibly bundle-adjusted) unit price.
class BundleAdjustedItem {
  const BundleAdjustedItem({
    required this.item,
    required this.effectiveUnitPrice,
    this.bundleName,
    this.bundleGroupIndex,
  });

  final CartItem item;
  final double effectiveUnitPrice;
  final String? bundleName;
  final int? bundleGroupIndex;

  double get effectiveSubtotal => item.quantity * effectiveUnitPrice;
}

/// Cart with bundle-adjusted prices applied.
/// bundleTotal + standaloneTotal = pre-discount total.
/// Discount applies only to standaloneTotal.
///
/// [items]: Full cart items with effective (blended) prices (for checkout).
/// [virtualBundles]: "Bundle X (Qty: N)" lines for UI.
/// [leftoverItems]: Standalone items only (for virtual display mode).
class BundleAdjustedCart {
  const BundleAdjustedCart({
    required this.items,
    required this.total,
    this.bundleTotal = 0,
    this.standaloneTotal = 0,
    this.virtualBundles = const [],
    this.leftoverItems = const [],
  });

  final List<BundleAdjustedItem> items;
  final double total;
  final double bundleTotal;
  final double standaloneTotal;
  final List<VirtualBundleLine> virtualBundles;
  final List<BundleAdjustedItem> leftoverItems;
}
