/// Data needed to print a sale receipt (ticket).
class ReceiptPrintData {
  const ReceiptPrintData({
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.amountTendered,
    this.changeGiven,
    this.storeName = 'Reyes Nieves',
    this.storeTagline,
    this.storeAddress,
    this.storePhone,
  });

  final List<ReceiptPrintLine> lines;
  final double total;
  final String? paymentMethod;
  final double? amountTendered;
  final double? changeGiven;
  final String storeName;
  /// Optional line under the name (e.g. "Nieves · Baguettes · Bebidas").
  final String? storeTagline;
  final String? storeAddress;
  final String? storePhone;

  String get paymentMethodLabel {
    if (paymentMethod == null) return '';
    switch (paymentMethod!) {
      case 'CASH':
        return 'Efectivo';
      case 'CARD_DEBIT':
        return 'Tarjeta débito';
      case 'CARD_CREDIT':
        return 'Tarjeta crédito';
      case 'TRANSFER':
        return 'Transferencia';
      default:
        return paymentMethod!;
    }
  }
}

class ReceiptPrintLine {
  const ReceiptPrintLine({
    required this.description,
    required this.quantity,
    required this.amount,
  });

  final String description;
  final int quantity;
  final double amount;
}
