import 'package:flutter/foundation.dart';

import 'package:ice_pos/src/core/services/supabase_service.dart';

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
}
