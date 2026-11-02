import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/monitoring/presentation/temperature_sensor_labels.dart';

class TemperatureAlertSetting {
  const TemperatureAlertSetting({
    required this.freezerKey,
    required this.minC,
    required this.maxC,
    required this.staleMinutes,
    required this.enabled,
    required this.notifyCooldownMinutes,
  });

  final String freezerKey;
  final double minC;
  final double maxC;
  final int staleMinutes;
  final bool enabled;
  final int notifyCooldownMinutes;

  TemperatureAlertSetting copyWith({
    double? minC,
    double? maxC,
    int? staleMinutes,
    bool? enabled,
    int? notifyCooldownMinutes,
  }) {
    return TemperatureAlertSetting(
      freezerKey: freezerKey,
      minC: minC ?? this.minC,
      maxC: maxC ?? this.maxC,
      staleMinutes: staleMinutes ?? this.staleMinutes,
      enabled: enabled ?? this.enabled,
      notifyCooldownMinutes: notifyCooldownMinutes ?? this.notifyCooldownMinutes,
    );
  }

  static TemperatureAlertSetting? fromJson(Map<String, dynamic> row) {
    final key = row['freezer_key']?.toString();
    if (key == null || key.isEmpty) return null;
    final min = row['min_c'];
    final max = row['max_c'];
    final minC = min is num ? min.toDouble() : double.tryParse('$min');
    final maxC = max is num ? max.toDouble() : double.tryParse('$max');
    if (minC == null || maxC == null) return null;
    final stale = row['stale_minutes'];
    final cooldown = row['notify_cooldown_minutes'];
    return TemperatureAlertSetting(
      freezerKey: key,
      minC: minC,
      maxC: maxC,
      staleMinutes: stale is int ? stale : int.tryParse('$stale') ?? 15,
      enabled: row['enabled'] == true,
      notifyCooldownMinutes:
          cooldown is int ? cooldown : int.tryParse('$cooldown') ?? 15,
    );
  }

  Map<String, dynamic> toUpsertJson() => {
        'freezer_key': freezerKey,
        'min_c': minC,
        'max_c': maxC,
        'stale_minutes': staleMinutes,
        'enabled': enabled,
        'notify_cooldown_minutes': notifyCooldownMinutes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

enum TemperatureAlertKind { belowMin, aboveMax, stale }

class TemperatureAlert {
  const TemperatureAlert({
    required this.sensorId,
    required this.freezerKey,
    required this.kind,
    required this.temperatureC,
    required this.readAt,
    required this.setting,
  });

  final String sensorId;
  final String freezerKey;
  final TemperatureAlertKind kind;
  final double? temperatureC;
  final DateTime? readAt;
  final TemperatureAlertSetting setting;
}

class TemperatureAlertSettingsService {
  TemperatureAlertSettingsService._();

  static String freezerKeyForSensor(String? sensorId) {
    if (TemperatureSensorLabels.belongsToFreezer1(sensorId)) return 'freezer1';
    if (TemperatureSensorLabels.belongsToFreezer2(sensorId)) return 'freezer2';
    return 'freezer2';
  }

  static Future<List<TemperatureAlertSetting>> fetchAll() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final res = await SupabaseService.instance.client
          .from('temperature_alert_settings')
          .select()
          .order('freezer_key');
      final list = List<dynamic>.from(res as List);
      return list
          .map((e) => TemperatureAlertSetting.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .whereType<TemperatureAlertSetting>()
          .toList();
    } catch (e, st) {
      debugPrint('TemperatureAlertSettingsService.fetchAll: $e\n$st');
      return [];
    }
  }

  static Future<void> upsert(TemperatureAlertSetting setting) async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Supabase not initialized');
    }
    await SupabaseService.instance.client
        .from('temperature_alert_settings')
        .upsert(setting.toUpsertJson(), onConflict: 'freezer_key');
  }

  /// Evaluate latest readings against settings (client-side banner).
  static List<TemperatureAlert> evaluate({
    required List<TemperatureAlertSetting> settings,
    required List<({String sensorId, double temperatureC, DateTime readAt})>
        latest,
    DateTime? now,
  }) {
    final byKey = {for (final s in settings) s.freezerKey: s};
    final n = now ?? DateTime.now();
    final out = <TemperatureAlert>[];
    for (final row in latest) {
      final key = freezerKeyForSensor(row.sensorId);
      final s = byKey[key];
      if (s == null || !s.enabled) continue;
      final ageMin = n.difference(row.readAt).inMinutes;
      if (ageMin >= s.staleMinutes) {
        out.add(TemperatureAlert(
          sensorId: row.sensorId,
          freezerKey: key,
          kind: TemperatureAlertKind.stale,
          temperatureC: row.temperatureC,
          readAt: row.readAt,
          setting: s,
        ));
        continue;
      }
      if (row.temperatureC < s.minC) {
        out.add(TemperatureAlert(
          sensorId: row.sensorId,
          freezerKey: key,
          kind: TemperatureAlertKind.belowMin,
          temperatureC: row.temperatureC,
          readAt: row.readAt,
          setting: s,
        ));
      } else if (row.temperatureC > s.maxC) {
        out.add(TemperatureAlert(
          sensorId: row.sensorId,
          freezerKey: key,
          kind: TemperatureAlertKind.aboveMax,
          temperatureC: row.temperatureC,
          readAt: row.readAt,
          setting: s,
        ));
      }
    }
    return out;
  }
}
