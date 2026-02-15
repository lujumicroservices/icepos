/// A single line on the receipt (bundle or raw item).
class ReceiptLine {
  const ReceiptLine({
    required this.description,
    required this.amount,
    required this.isBundle,
    required this.quantity,
  });

  final String description;
  final double amount;
  final bool isBundle;
  /// Quantity for this line (bundles or raw items).
  final int quantity;
}

/// Result of receipt computation: lines and totals.
class ReceiptResult {
  const ReceiptResult({
    required this.lines,
    required this.total,
    required this.standaloneSubtotal,
  });

  final List<ReceiptLine> lines;
  final double total;
  /// Subtotal of leftover lines (before discount) - for discount application.
  final double standaloneSubtotal;
}
