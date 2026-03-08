import 'package:flutter/foundation.dart';

import 'package:ice_pos/src/core/services/supabase_service.dart';

/// Payload for syncing a sale to Supabase (cloud).
class SaleSyncPayload {
  const SaleSyncPayload({
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
    required this.amountTendered,
    required this.changeGiven,
    required this.items,
  });

  final DateTime date;
  final double totalAmount;
  final String paymentMethod;
  final double amountTendered;
  final double changeGiven;
  final List<SaleSyncItem> items;

  Map<String, dynamic> toJson() => {
        'created_at': date.toIso8601String(),
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'amount_tendered': amountTendered,
        'change_given': changeGiven,
      };

  static List<Map<String, dynamic>> itemsToJson(List<SaleSyncItem> items) =>
      items.map((e) => e.toJson()).toList();
}

class SaleSyncItem {
  const SaleSyncItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

/// Remote sale as returned from Supabase (for "consultar ventas" from cloud).
class RemoteSale {
  const RemoteSale({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    this.amountTendered = 0.0,
    this.changeGiven = 0.0,
    required this.items,
  });

  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final double amountTendered;
  final double changeGiven;
  final List<RemoteSaleItem> items;

  static RemoteSale? fromSupabase(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> itemRows,
    Map<int, String> productIdToName,
  ) {
    final id = row['id'];
    if (id == null) return null;
    final idStr = id is int ? id.toString() : id as String;
    final dateStr = row['date'] as String? ?? row['created_at'] as String?;
    final createdAt = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (createdAt == null) return null;
    final totalAmount = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = row['payment_method'] as String? ?? 'CASH';
    final amountTendered = (row['amount_tendered'] as num?)?.toDouble() ?? 0.0;
    final changeGiven = (row['change_given'] as num?)?.toDouble() ?? 0.0;
    final saleIdMatch = id is int ? id : int.tryParse(idStr);
    final items = itemRows
        .where((r) => r['sale_id'] == id || r['sale_id'] == saleIdMatch)
        .map((r) {
          final pid = r['product_id'];
          final productId = pid is int ? pid : int.tryParse(pid?.toString() ?? '');
          final name = productId != null ? (productIdToName[productId] ?? 'Producto') : (r['product_name'] as String? ?? '');
          return RemoteSaleItem(
            productName: name,
            quantity: (r['quantity'] as num?)?.toDouble() ?? 0,
            unitPrice: (r['unit_price'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList();
    return RemoteSale(
      id: idStr,
      createdAt: createdAt,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      changeGiven: changeGiven,
      items: items,
    );
  }
}

class RemoteSaleItem {
  const RemoteSaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;
}

/// Syncs sales to Supabase and fetches remote sales. No-op when Supabase is not configured.
class SalesSyncService {
  SalesSyncService._();

  static bool get isAvailable => SupabaseService.isInitialized;

  /// Uploads a sale to Supabase. Returns null on success, or error message.
  static Future<String?> uploadSale(SaleSyncPayload payload) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final client = SupabaseService.instance.client;
      final saleRow = {
        'created_at': payload.date.toIso8601String(),
        'total_amount': payload.totalAmount,
        'payment_method': payload.paymentMethod,
        'amount_tendered': payload.amountTendered,
        'change_given': payload.changeGiven,
      };
      final res = await client.from('sales').insert(saleRow).select('id');
      final list = res as List<dynamic>? ?? [];
      final id = list.isNotEmpty ? (list.first as Map<String, dynamic>)['id'] as String? : null;
      if (id == null || payload.items.isEmpty) return null;
      final items = payload.items.map((e) => {
        'sale_id': id,
        'product_name': e.productName,
        'quantity': e.quantity,
        'unit_price': e.unitPrice,
      }).toList();
      await client.from('sale_items').insert(items);
      return null;
    } catch (e, st) {
      debugPrint('SalesSyncService.uploadSale: $e');
      debugPrint('$st');
      return e.toString();
    }
  }

  /// Fetches sales from Supabase (full schema: sales.date, sale_items.product_id).
  static Future<List<RemoteSale>> getRemoteSales() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final salesRes = await client.from('sales').select('*').order('date', ascending: false);
      final salesList = salesRes as List<dynamic>? ?? [];
      if (salesList.isEmpty) return [];
      final itemsRes = await client.from('sale_items').select('*');
      final itemsList = (itemsRes as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>)).toList();
      final prodRes = await client.from('products').select('id, name');
      final productIdToName = <int, String>{};
      for (final p in prodRes as List<dynamic>? ?? []) {
        final m = Map<String, dynamic>.from(p as Map<dynamic, dynamic>);
        final id = m['id'];
        final idInt = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (idInt != null) productIdToName[idInt] = m['name'] as String? ?? '';
      }
      final sales = <RemoteSale>[];
      for (final row in salesList) {
        final map = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final sale = RemoteSale.fromSupabase(map, itemsList, productIdToName);
        if (sale != null) sales.add(sale);
      }
      return sales;
    } catch (e, st) {
      debugPrint('SalesSyncService.getRemoteSales: $e');
      debugPrint('$st');
      return [];
    }
  }
}
