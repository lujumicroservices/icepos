import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local sales history (Drift) or cloud sales (Supabase) for admin UI.
abstract class SalesHistoryRepository {
  Stream<List<SaleWithItems>> watchSalesHistory();

  Future<void> deleteSale(int saleId);
}

class DriftSalesHistoryRepository implements SalesHistoryRepository {
  DriftSalesHistoryRepository(this._pos);

  final PosRepository _pos;

  @override
  Stream<List<SaleWithItems>> watchSalesHistory() => _pos.watchSalesHistory();

  @override
  Future<void> deleteSale(int saleId) => _pos.deleteSale(saleId);
}

class SupabaseSalesHistoryRepository implements SalesHistoryRepository {
  SupabaseSalesHistoryRepository(this._client);

  final SupabaseClient _client;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<List<SaleWithItems>> _fetch() async {
    final salesRes =
        await _client.from('sales').select('*').isFilter('cancelled_at', null).order('date', ascending: false);
    final salesList = salesRes as List<dynamic>? ?? [];
    if (salesList.isEmpty) return [];

    final itemsRes = await _client.from('sale_items').select('*');
    final itemsList =
        (itemsRes as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final prodRes = await _client.from('products').select('id, name');
    final productIdToName = <int, String>{};
    for (final p in prodRes as List<dynamic>? ?? []) {
      final m = Map<String, dynamic>.from(p as Map);
      final id = _asInt(m['id']);
      if (id != null) {
        productIdToName[id] = m['name'] as String? ?? '';
      }
    }

    final itemsBySaleId = <int, List<Map<String, dynamic>>>{};
    for (final it in itemsList) {
      final sid = _asInt(it['sale_id']);
      if (sid == null) continue;
      itemsBySaleId.putIfAbsent(sid, () => []).add(it);
    }

    final out = <SaleWithItems>[];
    for (final row in salesList) {
      final sm = Map<String, dynamic>.from(row as Map);
      final saleId = _asInt(sm['id']);
      if (saleId == null) continue;

      DateTime dt;
      final rawDate = sm['date'];
      if (rawDate is String) {
        dt = DateTime.parse(rawDate).toLocal();
      } else {
        dt = DateTime.now();
      }

      final sale = Sale(
        id: saleId,
        date: dt,
        totalAmount: (sm['total_amount'] as num).toDouble(),
        paymentMethod: sm['payment_method'] as String? ?? 'CASH',
        amountTendered: (sm['amount_tendered'] as num?)?.toDouble() ?? 0,
        changeGiven: (sm['change_given'] as num?)?.toDouble() ?? 0,
        cloudSaleId: saleId,
        cancelledAt: null,
      );

      final dtos = <SaleItemDto>[];
      for (final im in itemsBySaleId[saleId] ?? const []) {
        final pid = _asInt(im['product_id']);
        final productName = pid != null ? (productIdToName[pid] ?? 'Producto') : 'Producto';
        dtos.add(
          SaleItemDto(
            productName: productName,
            quantity: (im['quantity'] as num).toDouble(),
            priceAtSale: (im['unit_price'] as num).toDouble(),
          ),
        );
      }
      out.add(SaleWithItems(sale: sale, items: dtos));
    }
    return out;
  }

  @override
  Stream<List<SaleWithItems>> watchSalesHistory() async* {
    yield await _fetch();
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 12));
      yield await _fetch();
    }
  }

  @override
  Future<void> deleteSale(int saleId) async {
    final err = await CloudSyncService.softCancelSaleInCloud(saleId);
    if (err != null) {
      throw StateError(err);
    }
  }
}

final salesHistoryRepositoryProvider = Provider<SalesHistoryRepository>((ref) {
  if (isSupabaseOnlyBackend) {
    return SupabaseSalesHistoryRepository(Supabase.instance.client);
  }
  return DriftSalesHistoryRepository(ref.watch(posRepositoryProvider)!);
});
