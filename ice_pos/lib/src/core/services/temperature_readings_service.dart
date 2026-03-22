import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

/// One row from `public.temperature_readings`.
class TemperatureReading {
  const TemperatureReading({
    required this.id,
    required this.temperatureC,
    required this.createdAt,
    this.sensorId,
  });

  final int id;
  final double temperatureC;
  final DateTime createdAt;
  final String? sensorId;

  static TemperatureReading? fromJson(Map<String, dynamic> row) {
    final id = row['id'];
    final idInt = id is int ? id : (id is num ? id.toInt() : int.tryParse('$id'));
    if (idInt == null) return null;
    final temp = row['temperature_c'];
    final t = temp is num ? temp.toDouble() : double.tryParse('$temp');
    if (t == null) return null;
    final created = row['created_at'];
    final dt = created is String
        ? DateTime.tryParse(created)
        : (created == null ? null : DateTime.tryParse(created.toString()));
    if (dt == null) return null;
    final sid = row['sensor_id'];
    return TemperatureReading(
      id: idInt,
      temperatureC: t,
      createdAt: dt.isUtc ? dt.toLocal() : dt,
      sensorId: sid is String ? (sid.isEmpty ? null : sid) : sid?.toString(),
    );
  }
}

/// Reads freezer / sensor history from Supabase.
class TemperatureReadingsService {
  TemperatureReadingsService._();

  /// [since] inclusive lower bound in local time (converted to UTC for query).
  ///
  /// Paginates with [pageSize] rows per request. PostgREST often caps responses
  /// (~1000 rows); without paging, only the newest page is returned (e.g. "today"
  /// only for 7d/30d views when sampling is frequent).
  static Future<List<TemperatureReading>> fetchReadings({
    required DateTime since,
    String? sensorId,
    int pageSize = 1000,
    int maxRows = 500000,
  }) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final sinceUtc = since.toUtc().toIso8601String();
      final out = <TemperatureReading>[];
      var offset = 0;

      while (out.length < maxRows) {
        dynamic q = client
            .from('temperature_readings')
            .select('id,temperature_c,created_at,sensor_id')
            .gte('created_at', sinceUtc);
        if (sensorId != null && sensorId.trim().isNotEmpty) {
          q = q.eq('sensor_id', sensorId.trim());
        }
        final end = offset + pageSize - 1;
        final dynamic res = await q
            .order('created_at', ascending: true)
            .range(offset, end);
        final list = List<dynamic>.from(res as List);
        if (list.isEmpty) break;
        for (final raw in list) {
          final m = Map<String, dynamic>.from(raw as Map);
          final r = TemperatureReading.fromJson(m);
          if (r != null) out.add(r);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }

      if (out.length >= maxRows) {
        debugPrint(
          'TemperatureReadingsService.fetchReadings: truncated at maxRows=$maxRows',
        );
      }

      return out;
    } catch (e, st) {
      debugPrint('TemperatureReadingsService.fetchReadings: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Distinct non-null sensor_id values (recent rows only).
  static Future<List<String>> fetchDistinctSensorIds({int sampleLimit = 2000}) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final client = SupabaseService.instance.client;
      final res = await client
          .from('temperature_readings')
          .select('sensor_id')
          .order('created_at', ascending: false)
          .limit(sampleLimit);
      final list = List<dynamic>.from(res as List);
      final set = <String>{};
      for (final raw in list) {
        final row = Map<String, dynamic>.from(raw as Map);
        final sid = row['sensor_id'];
        if (sid is String && sid.trim().isNotEmpty) set.add(sid.trim());
      }
      final out = set.toList()..sort();
      return out;
    } catch (e, st) {
      debugPrint('TemperatureReadingsService.fetchDistinctSensorIds: $e');
      debugPrint('$st');
      return [];
    }
  }
}
