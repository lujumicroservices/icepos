import 'dart:convert';

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
    this.paymentsJson,
  });

  final DateTime date;
  final double totalAmount;
  final String paymentMethod;
  final double amountTendered;
  final double changeGiven;
  final List<SaleSyncItem> items;
  final String? paymentsJson;

  Map<String, dynamic> toJson() => {
        'created_at': date.toIso8601String(),
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'amount_tendered': amountTendered,
        'change_given': changeGiven,
        if (paymentsJson != null) 'payments_json': jsonDecode(paymentsJson!),
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
    this.deviceId,
    this.deviceName,
    this.paymentsJson,
  });

  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final double amountTendered;
  final double changeGiven;
  final List<RemoteSaleItem> items;
  /// ID del dispositivo que registró la venta (en la nube).
  final String? deviceId;
  /// Nombre legible del dispositivo (ej. Caja 1).
  final String? deviceName;
  final String? paymentsJson;

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
        .where((r) {
          final raw = r['sale_id'];
          if (raw == id || raw == saleIdMatch) return true;
          // Defensive match across types (int vs string).
          final rawStr = raw?.toString();
          return rawStr != null &&
              (rawStr == idStr || (saleIdMatch != null && rawStr == saleIdMatch.toString()));
        })
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
    final deviceId = row['device_id'] as String?;
    final deviceName = row['device_name'] as String?;
    final paymentsRaw = row['payments_json'];
    final paymentsJson = paymentsRaw == null
        ? null
        : paymentsRaw is String
            ? paymentsRaw
            : jsonEncode(paymentsRaw);
    return RemoteSale(
      id: idStr,
      createdAt: createdAt,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      changeGiven: changeGiven,
      items: items,
      deviceId: deviceId?.isNotEmpty == true ? deviceId : null,
      deviceName: deviceName?.isNotEmpty == true ? deviceName : null,
      paymentsJson: paymentsJson,
    );
  }
}

class RemoteSaleItem {
  const RemoteSaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.modifierDetails = const [],
  });

  final String productName;
  final double quantity;
  final double unitPrice;
  final List<String> modifierDetails;
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
      // Prefer nested fetch so each sale already includes its own sale_items.
      dynamic salesRes;
      try {
        salesRes = await client
            .from('sales')
            .select('*, sale_items(*)')
            .isFilter('cancelled_at', null)
            .order('date', ascending: false);
      } catch (_) {
        salesRes = await client
            .from('sales')
            .select('*')
            .isFilter('cancelled_at', null)
            .order('date', ascending: false);
      }
      final salesList = salesRes as List<dynamic>? ?? [];
      if (salesList.isEmpty) return [];
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
        List<Map<String, dynamic>> itemRows = const [];
        final nested = map['sale_items'];
        if (nested is List) {
          itemRows = nested
              .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
        } else {
          final saleId = map['id'];
          if (saleId != null) {
            final itemsRes = await client.from('sale_items').select('*').eq('sale_id', saleId);
            itemRows = (itemsRes as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
                .toList();
          }
        }
        final sale = RemoteSale.fromSupabase(map, itemRows, productIdToName);
        if (sale != null) sales.add(sale);
      }
      return sales;
    } catch (e, st) {
      debugPrint('SalesSyncService.getRemoteSales: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Supabase RPC `pos_top_selling_product_ids`: sum(quantity) by product on
  /// non-cancelled sales in the last [days] for [storeId] (UTC window).
  static Future<List<int>> fetchTopSellingProductIdsFromCloud({
    required int days,
    required int limit,
    required int storeId,
  }) async {
    if (!isAvailable) return [];
    try {
      final client = SupabaseService.instance.client;
      final dynamic res = await client.rpc(
        'pos_top_selling_product_ids',
        params: {
          'p_days': days,
          'p_limit': limit,
          'p_store_id': storeId,
        },
      );
      final list = res as List<dynamic>? ?? [];
      final out = <int>[];
      for (final row in list) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final id = m['product_id'];
        final idInt = id is int
            ? id
            : id is num
                ? id.toInt()
                : int.tryParse(id?.toString() ?? '');
        if (idInt != null) {
          out.add(idInt);
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('SalesSyncService.fetchTopSellingProductIdsFromCloud: $e');
      debugPrint('$st');
      return [];
    }
  }
}
