/// Data needed to print a sale receipt (ticket).
class ReceiptPrintData {
  const ReceiptPrintData({
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.amountTendered,
    this.changeGiven,
    this.splitPayments = const [],
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
  final List<SalePaymentPrintLine> splitPayments;
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
      case 'SPLIT':
        return 'Pago dividido';
      default:
        return paymentMethod!;
    }
  }

  bool get isSplitPayment =>
      splitPayments.isNotEmpty || paymentMethod == 'SPLIT';
}

class SalePaymentPrintLine {
  const SalePaymentPrintLine({
    required this.label,
    required this.amount,
    this.amountTendered,
    this.changeGiven,
  });

  final String label;
  final double amount;
  final double? amountTendered;
  final double? changeGiven;
}

class ReceiptPrintLine {
  const ReceiptPrintLine({
    required this.description,
    required this.quantity,
    required this.amount,
    this.modifierDetails = const [],
  });

  final String description;
  final int quantity;
  final double amount;
  final List<String> modifierDetails;
}
