import 'dart:convert';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_print_data.dart';
import 'package:ice_pos/src/features/pos/domain/sale_payment.dart';

/// Builds thermal receipt payloads from persisted sales (reprint from history).
class SaleReceiptPrintMapper {
  const SaleReceiptPrintMapper._();

  static ReceiptPrintData fromLocalSale({
    required Sale sale,
    required List<({String productName, double quantity, double unitPrice, String? modifiersJson})> items,
    required Map<int, String> supplyIdToName,
  }) {
    final lines = items.map((item) {
      final modifierDetails = modifierLabelsFromJson(item.modifiersJson, supplyIdToName);
      final qty = item.quantity;
      final lineAmount = qty * item.unitPrice;
      return ReceiptPrintLine(
        description: item.productName,
        quantity: qty >= 1 ? qty.round().clamp(1, 9999) : 1,
        amount: lineAmount,
        modifierDetails: modifierDetails,
      );
    }).toList();

    return _receiptFromSaleFields(
      total: sale.totalAmount,
      paymentMethod: sale.paymentMethod,
      amountTendered: sale.amountTendered,
      changeGiven: sale.changeGiven,
      paymentsJson: sale.paymentsJson,
      lines: lines,
    );
  }

  static ReceiptPrintData fromRemoteSale(RemoteSale sale) {
    final lines = sale.items.map((item) {
      final qty = item.quantity;
      return ReceiptPrintLine(
        description: item.productName,
        quantity: qty >= 1 ? qty.round().clamp(1, 9999) : 1,
        amount: qty * item.unitPrice,
        modifierDetails: item.modifierDetails,
      );
    }).toList();

    return _receiptFromSaleFields(
      total: sale.totalAmount,
      paymentMethod: sale.paymentMethod,
      amountTendered: sale.amountTendered,
      changeGiven: sale.changeGiven,
      paymentsJson: sale.paymentsJson,
      lines: lines,
    );
  }

  static ReceiptPrintData _receiptFromSaleFields({
    required double total,
    required String paymentMethod,
    required double amountTendered,
    required double changeGiven,
    String? paymentsJson,
    required List<ReceiptPrintLine> lines,
  }) {
    final splitLines = SalePaymentLine.listFromJson(paymentsJson);
    if (splitLines.isNotEmpty) {
      return ReceiptPrintData(
        lines: lines,
        total: total,
        paymentMethod: 'SPLIT',
        splitPayments: splitLines
            .map(
              (p) => SalePaymentPrintLine(
                label: p.label,
                amount: p.amount,
                amountTendered: p.amountTendered,
                changeGiven: p.changeGiven,
              ),
            )
            .toList(),
        storeName: 'Reyes Nieves',
        storeTagline: 'Nieves · Baguettes · Bebidas',
      );
    }
    final isCash = paymentMethod == 'CASH';
    return ReceiptPrintData(
      lines: lines,
      total: total,
      paymentMethod: paymentMethod,
      amountTendered: isCash && amountTendered > 0 ? amountTendered : null,
      changeGiven: isCash && changeGiven > 0 ? changeGiven : null,
      storeName: 'Reyes Nieves',
      storeTagline: 'Nieves · Baguettes · Bebidas',
    );
  }

  static List<String> modifierLabelsFromJson(
    String? modifiersJson,
    Map<int, String> supplyIdToName,
  ) {
    if (modifiersJson == null || modifiersJson.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(modifiersJson) as List<dynamic>;
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final dto = ModifierOptionDto.fromJson(m);
        return supplyIdToName[dto.supplyId] ?? 'Extra';
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
