import 'package:ice_pos/src/core/l10n/app_localizations.dart';

/// Friendly labels for known [sensor_id] suffixes from `temperature_readings`.
///
/// - IDs ending with `79d` → freezer 1 (right)
/// - IDs ending with `0a6` (zero-a-six) → freezer 1 (left)
/// - IDs ending with `acb` → freezer 2 (left)
/// - Anything else (non-empty) → unknown label (show raw id in UI if needed later)
class TemperatureSensorLabels {
  TemperatureSensorLabels._();

  /// Congelador 1: sensores terminados en `79d` o `0a6`.
  static bool belongsToFreezer1(String? sensorId) {
    final s = sensorId?.trim() ?? '';
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    return lower.endsWith('79d') || lower.endsWith('0a6');
  }

  /// Congelador 2: cualquier otro id no vacío (p. ej. `acb`) que no sea de cong. 1.
  static bool belongsToFreezer2(String? sensorId) {
    final s = sensorId?.trim() ?? '';
    if (s.isEmpty) return false;
    return !belongsToFreezer1(sensorId);
  }

  static String displayName(String? sensorId, AppLocalizations l10n) {
    final s = sensorId?.trim() ?? '';
    if (s.isEmpty) return l10n.temperatureUnknownSensor;
    final lower = s.toLowerCase();
    if (lower.endsWith('79d')) return l10n.temperatureSensorFreezer1Right;
    if (lower.endsWith('0a6')) return l10n.temperatureSensorFreezer1Left;
    if (lower.endsWith('acb')) return l10n.temperatureSensorFreezer2Left;
    return '${l10n.temperatureUnknownSensor} ($s)';
  }

  /// Stable legend order: cong.1 izq → cong.1 der → cong.2 izq → otros.
  static int sortPriority(String rawKey) {
    final lower = rawKey.toLowerCase();
    if (lower.endsWith('0a6')) return 0;
    if (lower.endsWith('79d')) return 1;
    if (lower.endsWith('acb')) return 2;
    return 3;
  }

  /// Color index aligned with [sortPriority] (0..3).
  static int colorIndex(String rawKey) => sortPriority(rawKey);
}
