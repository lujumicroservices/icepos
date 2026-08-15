import 'package:flutter/foundation.dart';

import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

/// Raw supply row from cloud (for inventory report).
class CloudSupplyRow {
  const CloudSupplyRow({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.costPerUnit,
    required this.reorderPoint,
    this.category,
  });
  final int id;
  final String name;
  final String unit;
  final double currentStock;
  final double costPerUnit;
  final double reorderPoint;
  final String? category;
}

/// Raw inventory log row from cloud (supply name/unit joined).
class CloudInventoryLogRow {
  const CloudInventoryLogRow({
    required this.supplyName,
    required this.unit,
    required this.changeAmount,
    required this.reason,
    required this.date,
  });
  final String supplyName;
  final String unit;
  final double changeAmount;
  final String reason;
  final DateTime date;
}

/// Shift + closure from cloud (for Rayos X).
class CloudShiftClosure {
  const CloudShiftClosure({
    required this.shiftId,
    required this.startTime,
    required this.endTime,
    required this.startingFund,
    required this.closingTime,
    required this.systemExpectedCash,
    required this.declaredCash,
    required this.difference,
    this.notes,
  });
  final int shiftId;
  final DateTime startTime;
  final DateTime endTime;
  final double startingFund;
  final DateTime closingTime;
  final double systemExpectedCash;
  final double declaredCash;
  final double difference;
  final String? notes;
}

/// Fetches data from Supabase for reportes (inventario, Rayos X).
class CloudReportsService {
  CloudReportsService._();

  static bool get isAvailable => SupabaseService.isInitialized;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// Supplies from cloud (for inventory report and low stock).
  static Future<List<CloudSupplyRow>> getCloudSupplies() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client.from('supplies').select('*').order('id');
      final list = res as List<dynamic>? ?? [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        return CloudSupplyRow(
          id: _int(m['id']),
          name: m['name'] as String? ?? '',
          unit: m['unit'] as String? ?? 'pcs',
          currentStock: _d(m['current_stock']),
          costPerUnit: _d(m['cost_per_unit']),
          reorderPoint: _d(m['reorder_point']),
          category: m['category'] as String?,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('CloudReportsService.getCloudSupplies: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Inventory logs in date range (with supply name from supplies).
  static Future<List<CloudInventoryLogRow>> getCloudInventoryLogs(DateTime start, DateTime end) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final startStr = start.toUtc().toIso8601String();
      final endStr = end.toUtc().toIso8601String();
      final logsRes = await client
          .from('inventory_logs')
          .select('*')
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: false)
          .limit(100);
      final logsList = logsRes as List<dynamic>? ?? [];
      if (logsList.isEmpty) return [];
      final suppliesRes = await client.from('supplies').select('id, name, unit');
      final supplyMap = <int, ({String name, String unit})>{};
      for (final s in suppliesRes as List<dynamic>? ?? []) {
        final m = Map<String, dynamic>.from(s as Map<dynamic, dynamic>);
        final id = _int(m['id']);
        supplyMap[id] = (name: m['name'] as String? ?? '', unit: m['unit'] as String? ?? 'pcs');
      }
      return logsList.map((e) {
        final m = Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        final supplyId = _int(m['supply_id']);
        final info = supplyMap[supplyId] ?? (name: 'Insumo $supplyId', unit: 'pcs');
        final date = _dt(m['date']);
        return CloudInventoryLogRow(
          supplyName: info.name,
          unit: info.unit,
          changeAmount: _d(m['change_amount']),
          reason: m['reason'] as String? ?? 'SALE',
          date: date ?? DateTime.now(),
        );
      }).toList();
    } catch (e, st) {
      debugPrint('CloudReportsService.getCloudInventoryLogs: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Shifts with their closures (for Rayos X). Filter by day in caller.
  static Future<List<CloudShiftClosure>> getCloudShiftsWithClosures() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final closuresRes = await client.from('shift_closures').select('*, shifts(*)').order('closing_time');
      final list = closuresRes as List<dynamic>? ?? [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        final shift = (m['shifts'] ?? m['shift']) as Map<String, dynamic>?;
        if (shift == null) return null;
        final startTime = _dt(shift['start_time']) ?? DateTime.now();
        final endTime = _dt(shift['end_time']) ?? _dt(m['closing_time']) ?? DateTime.now();
        return CloudShiftClosure(
          shiftId: _int(shift['id']),
          startTime: startTime,
          endTime: endTime,
          startingFund: _d(shift['starting_fund']),
          closingTime: _dt(m['closing_time']) ?? DateTime.now(),
          systemExpectedCash: _d(m['system_expected_cash']),
          declaredCash: _d(m['declared_cash']),
          difference: _d(m['difference']),
          notes: m['notes'] as String?,
        );
      }).whereType<CloudShiftClosure>().toList();
    } catch (e, st) {
      debugPrint('CloudReportsService.getCloudShiftsWithClosures: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Neto CAJA por turno (ENTRADA − SALIDA), igual que en POS local / cierre.
  static Future<Map<int, double>> getCajaMovementNetByShiftIds(List<int> shiftIds) async {
    if (!SupabaseService.isInitialized || shiftIds.isEmpty) return {};
    final unique = shiftIds.toSet().toList();
    try {
      final client = SupabaseService.instance.client;
      final res = await client
          .from('movements')
          .select('shift_id, type, amount')
          .eq('account', 'CAJA')
          .isFilter('cancelled_at', null)
          .inFilter('shift_id', unique);
      final list = res as List<dynamic>? ?? [];
      final netByShift = <int, double>{};
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        final sid = _int(m['shift_id']);
        if (sid == 0) continue;
        final t = m['type'] as String? ?? '';
        final amt = _d(m['amount']);
        if (t == 'ENTRADA') {
          netByShift[sid] = (netByShift[sid] ?? 0) + amt;
        } else if (t == 'SALIDA') {
          netByShift[sid] = (netByShift[sid] ?? 0) - amt;
        }
      }
      return netByShift;
    } catch (e, st) {
      debugPrint('CloudReportsService.getCajaMovementNetByShiftIds: $e');
      debugPrint('$st');
      return {};
    }
  }

  static bool _isSameLocalDay(DateTime timestamp, DateTime day) {
    final local = timestamp.toLocal();
    return local.year == day.year && local.month == day.month && local.day == day.day;
  }

  static bool _inLocalDateRange(DateTime timestamp, DateTime start, DateTime end) {
    final local = timestamp.toLocal();
    final startDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return !local.isBefore(startDay) && !local.isAfter(endOfDay);
  }

  /// Ventas del día en nube agrupadas por turno (web / sin Drift).
  static Future<List<ShiftSalesRow>> getQuickSalesByShiftForDay(DateTime day) async {
    if (!isAvailable) return [];
    try {
      final client = SupabaseService.instance.client;
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final salesRes = await client
          .from('sales')
          .select('shift_id, total_amount, date')
          .isFilter('cancelled_at', null)
          .gte('date', start.toUtc().toIso8601String())
          .lte('date', end.toUtc().toIso8601String());
      final salesList = salesRes as List<dynamic>? ?? [];
      final totals = <int, ({int count, double total})>{};
      for (final row in salesList) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final date = _dt(m['date']);
        if (date != null && !_isSameLocalDay(date, day)) continue;
        final shiftId = _int(m['shift_id']);
        final amount = _d(m['total_amount']);
        final prev = totals[shiftId] ?? (count: 0, total: 0.0);
        totals[shiftId] = (count: prev.count + 1, total: prev.total + amount);
      }
      if (totals.isEmpty) return [];

      final shiftIds = totals.keys.where((id) => id > 0).toList();
      final shiftMeta = <int, ({DateTime start, DateTime? end})>{};
      if (shiftIds.isNotEmpty) {
        final shiftsRes = await client.from('shifts').select('id, start_time, end_time').inFilter('id', shiftIds);
        for (final row in shiftsRes as List<dynamic>? ?? []) {
          final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
          final id = _int(m['id']);
          shiftMeta[id] = (start: _dt(m['start_time']) ?? start, end: _dt(m['end_time']));
        }
      }

      final rows = totals.entries.map((e) {
        final meta = shiftMeta[e.key];
        return ShiftSalesRow(
          shiftId: e.key,
          startTime: meta?.start ?? start,
          endTime: meta?.end,
          saleCount: e.value.count,
          totalAmount: e.value.total,
        );
      }).toList();
      rows.sort((a, b) => a.startTime.compareTo(b.startTime));
      return rows;
    } catch (e, st) {
      debugPrint('CloudReportsService.getQuickSalesByShiftForDay: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Distribución por categoría del día en nube.
  static Future<List<CategorySalesRow>> getQuickCategoryDistributionForDay(DateTime day) async {
    if (!isAvailable) return [];
    try {
      final client = SupabaseService.instance.client;
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
      dynamic salesRes;
      try {
        salesRes = await client
            .from('sales')
            .select('date, sale_items(product_id, quantity, unit_price)')
            .isFilter('cancelled_at', null)
            .gte('date', start.toUtc().toIso8601String())
            .lte('date', end.toUtc().toIso8601String());
      } catch (_) {
        return [];
      }
      final prodRes = await client.from('products').select('id, category_id, categories(name)');
      final productToCategory = <int, ({int? catId, String name})>{};
      for (final p in prodRes as List<dynamic>? ?? []) {
        final m = Map<String, dynamic>.from(p as Map<dynamic, dynamic>);
        final id = _int(m['id']);
        final catIdRaw = m['category_id'];
        final catId = catIdRaw == null ? null : _int(catIdRaw);
        final nested = m['categories'];
        String name = 'Sin categoría';
        if (nested is Map) {
          final catMap = Map<String, dynamic>.from(nested);
          final n = catMap['name'] as String?;
          if (n != null && n.trim().isNotEmpty) name = n;
        }
        productToCategory[id] = (catId: catId, name: name);
      }

      final byCat = <int?, ({String name, double revenue})>{};
      for (final row in salesRes as List<dynamic>? ?? []) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final date = _dt(m['date']);
        if (date != null && !_isSameLocalDay(date, day)) continue;
        final items = m['sale_items'];
        if (items is! List) continue;
        for (final itemRaw in items) {
          final item = Map<String, dynamic>.from(itemRaw as Map<dynamic, dynamic>);
          final pid = _int(item['product_id']);
          final qty = _d(item['quantity']);
          final price = _d(item['unit_price']);
          final rev = qty * price;
          final cat = productToCategory[pid] ?? (catId: null, name: 'Sin categoría');
          final prev = byCat[cat.catId] ?? (name: cat.name, revenue: 0.0);
          byCat[cat.catId] = (name: prev.name, revenue: prev.revenue + rev);
        }
      }

      final list = byCat.entries
          .map((e) => CategorySalesRow(
                categoryId: e.key,
                categoryName: e.value.name,
                revenue: e.value.revenue,
              ))
          .toList();
      list.sort((a, b) => b.revenue.compareTo(a.revenue));
      return list;
    } catch (e, st) {
      debugPrint('CloudReportsService.getQuickCategoryDistributionForDay: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Top productos en un rango (nube).
  static Future<List<ProductSalesRow>> getQuickTopProductsByDateRange({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    if (!isAvailable) return [];
    try {
      final remote = await SalesSyncService.getRemoteSales();
      final byProduct = <String, ({double qty, double revenue})>{};
      for (final s in remote) {
        if (!_inLocalDateRange(s.createdAt, start, end)) continue;
        for (final item in s.items) {
          final rev = item.quantity * item.unitPrice;
          final prev = byProduct[item.productName] ?? (qty: 0.0, revenue: 0.0);
          byProduct[item.productName] = (qty: prev.qty + item.quantity, revenue: prev.revenue + rev);
        }
      }
      final list = byProduct.entries
          .map((e) => ProductSalesRow(
                productName: e.key,
                quantitySold: e.value.qty,
                revenue: e.value.revenue,
              ))
          .toList();
      list.sort((a, b) => b.revenue.compareTo(a.revenue));
      return list.take(limit).toList();
    } catch (e, st) {
      debugPrint('CloudReportsService.getQuickTopProductsByDateRange: $e');
      debugPrint('$st');
      return [];
    }
  }
}
