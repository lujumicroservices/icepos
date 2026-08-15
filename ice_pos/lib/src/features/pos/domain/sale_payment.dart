import 'dart:convert';

/// One portion of a sale paid with a specific method.
class SalePaymentLine {
  const SalePaymentLine({
    required this.method,
    required this.amount,
    this.amountTendered,
    this.changeGiven,
  });

  /// CASH, CARD_DEBIT, CARD_CREDIT, TRANSFER
  final String method;
  final double amount;
  final double? amountTendered;
  final double? changeGiven;

  Map<String, dynamic> toJson() => {
        'method': method,
        'amount': amount,
        if (amountTendered != null) 'amount_tendered': amountTendered,
        if (changeGiven != null) 'change_given': changeGiven,
      };

  factory SalePaymentLine.fromJson(Map<String, dynamic> json) {
    return SalePaymentLine(
      method: json['method'] as String? ?? 'CASH',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountTendered: (json['amount_tendered'] as num?)?.toDouble(),
      changeGiven: (json['change_given'] as num?)?.toDouble(),
    );
  }

  static List<SalePaymentLine> listFromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SalePaymentLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<SalePaymentLine> payments) =>
      jsonEncode(payments.map((p) => p.toJson()).toList());

  static String methodFromCheckout(String method, String? cardType) {
    switch (method) {
      case 'cash':
        return 'CASH';
      case 'card':
        return cardType == 'credit' ? 'CARD_CREDIT' : 'CARD_DEBIT';
      case 'transfer':
        return 'TRANSFER';
      default:
        return 'CASH';
    }
  }

  factory SalePaymentLine.fromCheckoutMap(Map<String, dynamic> m) {
    final method = m['method'] as String? ?? 'cash';
    final amount = (m['amount'] as num?)?.toDouble() ?? 0;
    final cardType = m['cardType'] as String?;
    final dbMethod = methodFromCheckout(method, cardType);
    if (method == 'cash') {
      final tendered = (m['amountTendered'] as num?)?.toDouble();
      final change = tendered != null && tendered > amount ? tendered - amount : null;
      return SalePaymentLine(
        method: dbMethod,
        amount: amount,
        amountTendered: tendered,
        changeGiven: change,
      );
    }
    return SalePaymentLine(method: dbMethod, amount: amount);
  }

  factory SalePaymentLine.fromSingleCheckout(Map<String, dynamic> data) {
    final total = (data['cartTotal'] as num?)?.toDouble();
    final amount = (data['amount'] as num?)?.toDouble() ??
        (data['amountTendered'] as num?)?.toDouble() ??
        total ??
        0;
    return SalePaymentLine.fromCheckoutMap({
      ...data,
      'amount': amount,
    });
  }

  static List<SalePaymentLine> fromCheckoutPaymentData(
    Map<String, dynamic> data, {
    required double cartTotal,
  }) {
    if (data['split'] == true) {
      final raw = data['payments'] as List<dynamic>? ?? const [];
      return raw
          .map((e) => SalePaymentLine.fromCheckoutMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [
      SalePaymentLine.fromCheckoutMap({
        ...data,
        'amount': cartTotal,
      }),
    ];
  }

  static String labelForMethod(String method) {
    switch (method) {
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
        return method;
    }
  }

  String get label => labelForMethod(method);
}

/// Totals by payment type for reports and shift close.
class SalePaymentBreakdown {
  const SalePaymentBreakdown({
    this.cash = 0,
    this.debit = 0,
    this.credit = 0,
    this.transfer = 0,
  });

  final double cash;
  final double debit;
  final double credit;
  final double transfer;

  static SalePaymentBreakdown fromSale({
    required String paymentMethod,
    required double totalAmount,
    String? paymentsJson,
  }) {
    final lines = listFromJson(paymentsJson);
    if (lines.isEmpty) {
      return SalePaymentBreakdown()._add(paymentMethod, totalAmount);
    }
    var b = const SalePaymentBreakdown();
    for (final line in lines) {
      b = b._add(line.method, line.amount);
    }
    return b;
  }

  static List<SalePaymentLine> listFromJson(String? raw) =>
      SalePaymentLine.listFromJson(raw);

  SalePaymentBreakdown _add(String method, double amount) {
    switch (method) {
      case 'CARD_DEBIT':
        return SalePaymentBreakdown(
          cash: cash,
          debit: debit + amount,
          credit: credit,
          transfer: transfer,
        );
      case 'CARD_CREDIT':
        return SalePaymentBreakdown(
          cash: cash,
          debit: debit,
          credit: credit + amount,
          transfer: transfer,
        );
      case 'TRANSFER':
        return SalePaymentBreakdown(
          cash: cash,
          debit: debit,
          credit: credit,
          transfer: transfer + amount,
        );
      default:
        return SalePaymentBreakdown(
          cash: cash + amount,
          debit: debit,
          credit: credit,
          transfer: transfer,
        );
    }
  }

  static String formatPaymentSummary({
    String? paymentsJson,
    String? paymentMethod,
  }) {
    final lines = listFromJson(paymentsJson);
    if (lines.isEmpty) {
      return SalePaymentLine.labelForMethod(paymentMethod ?? 'CASH');
    }
    return lines.map((l) => '${l.label} \$${l.amount.toStringAsFixed(2)}').join(' · ');
  }
}
