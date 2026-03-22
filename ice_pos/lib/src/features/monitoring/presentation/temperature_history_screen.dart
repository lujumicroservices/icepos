import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/services/temperature_readings_service.dart';
import 'package:ice_pos/src/features/monitoring/presentation/temperature_sensor_labels.dart';

enum TemperatureRange {
  h24,
  d7,
  d30,
}

/// Filtro por ubicación: todos los sensores del congelador 1 o 2 (según sufijos).
enum TemperatureFreezerFilter {
  all,
  freezer1,
  freezer2,
}

final _temperatureRangeProvider =
    StateProvider<TemperatureRange>((ref) => TemperatureRange.h24);

final _temperatureFreezerFilterProvider =
    StateProvider<TemperatureFreezerFilter>(
        (ref) => TemperatureFreezerFilter.all);

final _temperatureHistoryProvider =
    FutureProvider.autoDispose<List<TemperatureReading>>((ref) async {
  final range = ref.watch(_temperatureRangeProvider);
  final freezer = ref.watch(_temperatureFreezerFilterProvider);
  final since = DateTime.now().subtract(switch (range) {
    TemperatureRange.h24 => const Duration(hours: 24),
    TemperatureRange.d7 => const Duration(days: 7),
    TemperatureRange.d30 => const Duration(days: 30),
  });
  final all = await TemperatureReadingsService.fetchReadings(
    since: since,
    sensorId: null,
  );
  return switch (freezer) {
    TemperatureFreezerFilter.all => all,
    TemperatureFreezerFilter.freezer1 => all
        .where((r) => TemperatureSensorLabels.belongsToFreezer1(r.sensorId))
        .toList(),
    TemperatureFreezerFilter.freezer2 => all
        .where((r) => TemperatureSensorLabels.belongsToFreezer2(r.sensorId))
        .toList(),
  };
});

/// Gráfico de historial de temperatura (congelador) desde Supabase `temperature_readings`.
class TemperatureHistoryScreen extends ConsumerWidget {
  const TemperatureHistoryScreen({super.key});

  static const int _maxChartPoints = 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!SupabaseService.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.temperatureHistory)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.temperatureCloudRequired,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final range = ref.watch(_temperatureRangeProvider);
    final freezerFilter = ref.watch(_temperatureFreezerFilterProvider);
    final historyAsync = ref.watch(_temperatureHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.temperatureHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_temperatureHistoryProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.temperatureHistorySubtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TemperatureRange>(
            segments: [
              ButtonSegment(
                value: TemperatureRange.h24,
                label: Text(l10n.temperatureRange24h),
              ),
              ButtonSegment(
                value: TemperatureRange.d7,
                label: Text(l10n.temperatureRange7d),
              ),
              ButtonSegment(
                value: TemperatureRange.d30,
                label: Text(l10n.temperatureRange30d),
              ),
            ],
            selected: {range},
            onSelectionChanged: (s) {
              ref.read(_temperatureRangeProvider.notifier).state = s.first;
            },
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.temperatureFreezerFilter,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButton<TemperatureFreezerFilter>(
                isExpanded: true,
                value: freezerFilter,
                items: [
                  DropdownMenuItem(
                    value: TemperatureFreezerFilter.all,
                    child: Text(l10n.temperatureFreezerAll),
                  ),
                  DropdownMenuItem(
                    value: TemperatureFreezerFilter.freezer1,
                    child: Text(l10n.temperatureFreezer1),
                  ),
                  DropdownMenuItem(
                    value: TemperatureFreezerFilter.freezer2,
                    child: Text(l10n.temperatureFreezer2),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(_temperatureFreezerFilterProvider.notifier).state = v;
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '${l10n.error}: $e',
                  style: TextStyle(color: scheme.error),
                ),
              ),
              data: (readings) {
                if (readings.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.temperatureNoData,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final groupBySensor = _distinctSensorGroupsCount(readings) > 1;
                final chartData = _prepareChartReadings(
                  readings,
                  groupBySensor: groupBySensor,
                  maxPoints: _maxChartPoints,
                );
                return _TemperatureLineChart(
                  readings: chartData,
                  groupBySensor: groupBySensor,
                  labelForSensor: (rawKey) =>
                      TemperatureSensorLabels.displayName(
                    rawKey.isEmpty ? null : rawKey,
                    l10n,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          historyAsync.maybeWhen(
            data: (readings) {
              if (readings.isEmpty) return const SizedBox.shrink();
              final locale = Localizations.localeOf(context);
              final first = readings.first.createdAt;
              final last = readings.last.createdAt;
              final latest = readings.last;
              final minT = readings.map((r) => r.temperatureC).reduce(
                    (a, b) => a < b ? a : b,
                  );
              final maxT = readings.map((r) => r.temperatureC).reduce(
                    (a, b) => a > b ? a : b,
                  );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.temperatureStats,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('${l10n.temperaturePoints}: ${readings.length}'),
                      Text(
                        l10n.temperatureLastReading(
                          latest.temperatureC.toStringAsFixed(1),
                          _fmtDetailed(latest.createdAt, locale),
                        ),
                      ),
                      Text(
                        '${l10n.temperatureFromTo}: '
                        '${_fmtDetailed(first, locale)} → ${_fmtDetailed(last, locale)}',
                      ),
                      Text(
                        '${l10n.temperatureMinMax}: '
                        '${minT.toStringAsFixed(1)} °C — '
                        '${maxT.toStringAsFixed(1)} °C',
                      ),
                    ],
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static String _fmtDetailed(DateTime d, Locale locale) {
    return DateFormat('yyyy-MM-dd HH:mm', locale.toString()).format(d);
  }

  static int _distinctSensorGroupsCount(List<TemperatureReading> readings) {
    return readings.map((r) => r.sensorId ?? '').toSet().length;
  }

  static List<TemperatureReading> _downsample(
    List<TemperatureReading> data,
    int maxPoints,
  ) {
    if (data.length <= maxPoints) return data;
    final step = (data.length / maxPoints).ceil();
    final out = <TemperatureReading>[];
    for (var i = 0; i < data.length; i += step) {
      out.add(data[i]);
    }
    if (out.last != data.last) out.add(data.last);
    return out;
  }

  /// Con varias series (por sensor), submuestreo por sensor para no mezclar series.
  static List<TemperatureReading> _prepareChartReadings(
    List<TemperatureReading> readings, {
    required bool groupBySensor,
    required int maxPoints,
  }) {
    if (!groupBySensor) {
      return _downsample(readings, maxPoints);
    }
    final groups = <String, List<TemperatureReading>>{};
    for (final r in readings) {
      final k = r.sensorId ?? '';
      groups.putIfAbsent(k, () => []).add(r);
    }
    if (groups.length <= 1) {
      final only = groups.values.first;
      return _downsample(only, maxPoints);
    }
    final perSeries = (maxPoints / groups.length).ceil().clamp(30, 200);
    final out = <TemperatureReading>[];
    for (final e in groups.entries) {
      final sorted = [...e.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      out.addAll(_downsample(sorted, perSeries));
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }
}

/// Colores distinguibles por sensor (ciclo si hay muchos).
const List<Color> _sensorLineColors = [
  Color(0xFF2196F3),
  Color(0xFFE91E63),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFFFF5722),
  Color(0xFF3F51B5),
  Color(0xFF8BC34A),
  Color(0xFFFFC107),
];

double _temperatureAxisYInterval(double minY, double maxY) {
  final r = maxY - minY;
  if (r <= 1.5) return 0.5;
  if (r <= 5) return 1;
  if (r <= 15) return 2;
  if (r <= 40) return 5;
  return 10;
}

class _TemperatureLineChart extends StatelessWidget {
  const _TemperatureLineChart({
    required this.readings,
    required this.groupBySensor,
    required this.labelForSensor,
  });

  final List<TemperatureReading> readings;
  final bool groupBySensor;
  /// [rawSensorKey] is the grouped id string (`''` when [TemperatureReading.sensorId] is null).
  final String Function(String rawSensorKey) labelForSensor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (readings.isEmpty) {
      return const SizedBox.shrink();
    }

    final groups = <String, List<TemperatureReading>>{};
    for (final r in readings) {
      final k = r.sensorId ?? '';
      groups.putIfAbsent(k, () => []).add(r);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final useMultiColor = groupBySensor && groups.length > 1;

    final tMin = readings.map((r) => r.createdAt).reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
    final tMax = readings.map((r) => r.createdAt).reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );
    final rangeMin = tMin;
    double minutesSince(DateTime t) =>
        t.difference(rangeMin).inMicroseconds / 60000000.0;
    final spanMinutes = minutesSince(tMax);
    final useIndexAxis = spanMinutes < 1e-9;

    final temps = readings.map((r) => r.temperatureC).toList();
    var minY = temps.reduce((a, b) => a < b ? a : b) - 1;
    var maxY = temps.reduce((a, b) => a > b ? a : b) + 1;
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final lineBars = <LineChartBarData>[];
    final legend = <({String label, Color color})>[];

    var maxX = 1.0;

    if (useMultiColor) {
      final keys = groups.keys.toList()
        ..sort(
          (a, b) => TemperatureSensorLabels.sortPriority(a)
              .compareTo(TemperatureSensorLabels.sortPriority(b)),
        );
      for (final key in keys) {
        final list = groups[key]!;
        final color = _sensorLineColors[
            TemperatureSensorLabels.colorIndex(key) % _sensorLineColors.length];
        final label = labelForSensor(key);
        legend.add((label: label, color: color));
        final spots = <FlSpot>[];
        for (var j = 0; j < list.length; j++) {
          final r = list[j];
          final x = useIndexAxis ? j.toDouble() : minutesSince(r.createdAt);
          spots.add(FlSpot(x, r.temperatureC));
          if (x > maxX) maxX = x;
        }
        if (spots.isEmpty) continue;
        lineBars.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: list.length <= 40),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    } else {
      final spots = <FlSpot>[];
      final sorted = [...readings]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (var j = 0; j < sorted.length; j++) {
        final r = sorted[j];
        final x = useIndexAxis ? j.toDouble() : minutesSince(r.createdAt);
        spots.add(FlSpot(x, r.temperatureC));
        if (x > maxX) maxX = x;
      }
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: scheme.primary,
          barWidth: 2,
          dotData: FlDotData(show: sorted.length <= 60),
          belowBarData: BarAreaData(
            show: true,
            color: scheme.primary.withValues(alpha: 0.12),
          ),
        ),
      );
    }
    if (maxX < 1) maxX = 1;

    final locale = Localizations.localeOf(context).toString();
    final yInterval = _temperatureAxisYInterval(minY, maxY);

    DateTime xToTime(double x) {
      if (useIndexAxis) {
        final sortedT = [...readings.map((r) => r.createdAt)]..sort();
        if (sortedT.isEmpty) return rangeMin;
        final idx = x.round().clamp(0, sortedT.length - 1);
        return sortedT[idx];
      }
      return rangeMin.add(Duration(microseconds: (x * 60000000).round()));
    }

    String axisTimeLabel(DateTime t) {
      // Two lines: full date + time (readable at any zoom level).
      return '${DateFormat('dd/MM/yyyy', locale).format(t)}\n'
          '${DateFormat('HH:mm', locale).format(t)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (legend.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in legend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.label,
                        style: GoogleFonts.inter(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toStringAsFixed(1)}°',
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxX > 0 ? (maxX / 5).clamp(0.5, double.infinity) : 1,
                    getTitlesWidget: (value, meta) {
                      final t = xToTime(value.toDouble());
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          axisTimeLabel(t),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 10, height: 1.2),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  maxContentWidth: 240,
                  fitInsideHorizontally: true,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final t = xToTime(spot.x);
                      final timeStr =
                          DateFormat('yyyy-MM-dd HH:mm', locale).format(t);
                      final tempStr = spot.y.toStringAsFixed(1);
                      final name = spot.barIndex < legend.length
                          ? legend[spot.barIndex].label
                          : '';
                      final text = name.isEmpty
                          ? '$tempStr °C\n$timeStr'
                          : '$name\n$tempStr °C\n$timeStr';
                      return LineTooltipItem(
                        text,
                        GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: lineBars,
            ),
          ),
        ),
      ],
    );
  }
}
