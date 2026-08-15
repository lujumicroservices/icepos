import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_reports_service.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:intl/intl.dart';

final _todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 0 = este dispositivo, 1 = nube.
final _quickReportSourceProvider = StateProvider<int>((ref) => 0);

bool _useCloudForQuickReport(Ref ref) {
  final hasLocal = ref.watch(posRepositoryProvider) != null;
  if (!hasLocal) return true;
  return ref.watch(_quickReportSourceProvider) == 1;
}

Future<List<ShiftSalesRow>> _shiftSalesForDay(
  Ref ref,
  DateTime day, {
  required bool useCloud,
}) async {
  if (useCloud) return CloudReportsService.getQuickSalesByShiftForDay(day);
  return ref.read(posRepositoryProvider)!.getSalesByShiftForDay(day);
}

Future<List<CategorySalesRow>> _categoryDistForDay(
  Ref ref,
  DateTime day, {
  required bool useCloud,
}) async {
  if (useCloud) return CloudReportsService.getQuickCategoryDistributionForDay(day);
  return ref.read(posRepositoryProvider)!.getCategoryDistributionForDay(day);
}

Future<List<ProductSalesRow>> _topProductsForRange(
  Ref ref, {
  required DateTime start,
  required DateTime end,
  required bool useCloud,
}) async {
  if (useCloud) {
    return CloudReportsService.getQuickTopProductsByDateRange(start: start, end: end, limit: 10);
  }
  return ref.read(posRepositoryProvider)!.getTopProductsByDateRange(start: start, end: end, limit: 10);
}

final _shiftSalesTodayProvider = FutureProvider.autoDispose<List<ShiftSalesRow>>((ref) async {
  final day = ref.watch(_todayProvider);
  final useCloud = _useCloudForQuickReport(ref);
  if (useCloud && !SalesSyncService.isAvailable) return [];
  return _shiftSalesForDay(ref, day, useCloud: useCloud);
});

final _categoryDistTodayProvider =
    FutureProvider.autoDispose<List<CategorySalesRow>>((ref) async {
  final day = ref.watch(_todayProvider);
  final useCloud = _useCloudForQuickReport(ref);
  if (useCloud && !SalesSyncService.isAvailable) return [];
  return _categoryDistForDay(ref, day, useCloud: useCloud);
});

final _topTodayProvider = FutureProvider.autoDispose<List<ProductSalesRow>>((ref) async {
  final day = ref.watch(_todayProvider);
  final useCloud = _useCloudForQuickReport(ref);
  if (useCloud && !SalesSyncService.isAvailable) return [];
  return _topProductsForRange(ref, start: day, end: day, useCloud: useCloud);
});

final _top7Provider = FutureProvider.autoDispose<List<ProductSalesRow>>((ref) async {
  final day = ref.watch(_todayProvider);
  final start = day.subtract(const Duration(days: 6));
  final useCloud = _useCloudForQuickReport(ref);
  if (useCloud && !SalesSyncService.isAvailable) return [];
  return _topProductsForRange(ref, start: start, end: day, useCloud: useCloud);
});

final _top30Provider = FutureProvider.autoDispose<List<ProductSalesRow>>((ref) async {
  final day = ref.watch(_todayProvider);
  final start = day.subtract(const Duration(days: 29));
  final useCloud = _useCloudForQuickReport(ref);
  if (useCloud && !SalesSyncService.isAvailable) return [];
  return _topProductsForRange(ref, start: start, end: day, useCloud: useCloud);
});
class SalesQuickReportScreen extends ConsumerWidget {
  const SalesQuickReportScreen({super.key});

  static String _money(num v) => NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final hasLocalPos = ref.watch(posRepositoryProvider) != null;
    final cloudAvailable = SalesSyncService.isAvailable;
    final useCloud = !hasLocalPos || ref.watch(_quickReportSourceProvider) == 1;
    final shiftAsync = ref.watch(_shiftSalesTodayProvider);
    final catAsync = ref.watch(_categoryDistTodayProvider);
    final topToday = ref.watch(_topTodayProvider);
    final top7 = ref.watch(_top7Provider);
    final top30 = ref.watch(_top30Provider);

    Widget? cloudHint;
    if (useCloud && !cloudAvailable) {
      cloudHint = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          l10n.syncEnvHint,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    } else if (useCloud && !hasLocalPos) {
      cloudHint = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          l10n.inCloud,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_shiftSalesTodayProvider);
        ref.invalidate(_categoryDistTodayProvider);
        ref.invalidate(_topTodayProvider);
        ref.invalidate(_top7Provider);
        ref.invalidate(_top30Provider);
        await Future.wait([
          ref.read(_shiftSalesTodayProvider.future),
          ref.read(_categoryDistTodayProvider.future),
          ref.read(_topTodayProvider.future),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.quickSalesSummaryTitle,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (cloudAvailable && hasLocalPos) ...[
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.thisDevice)),
                ButtonSegment(value: 1, label: Text(l10n.inCloud)),
              ],
              selected: {ref.watch(_quickReportSourceProvider)},
              onSelectionChanged: (s) {
                ref.read(_quickReportSourceProvider.notifier).state = s.first;
              },
            ),
          ],
          if (cloudHint != null) cloudHint,
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.quickSalesByShift,
            child: shiftAsync.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Text(e.toString()),
              data: (rows) {
                final total = rows.fold<double>(0, (s, r) => s + r.totalAmount);
                if (rows.isEmpty) {
                  return Text(l10n.quickNoData);
                }
                return Column(
                  children: [
                    _KeyValueLine(label: l10n.totalSales, value: _money(total)),
                    const Divider(height: 24),
                    ...rows.map(
                      (r) => _KeyValueLine(
                        label: '${l10n.movementShiftLabel(r.shiftId)} · ${r.saleCount} ${l10n.numberOfSales.toLowerCase()}',
                        value: _money(r.totalAmount),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.quickCategoryDistribution,
            child: catAsync.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Text(e.toString()),
              data: (rows) {
                final total = rows.fold<double>(0, (s, r) => s + r.revenue);
                if (rows.isEmpty) return Text(l10n.quickNoData);
                return Column(
                  children: rows.take(10).map((r) {
                    final pct = total <= 0 ? 0 : (r.revenue / total * 100);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.categoryName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}% · ${_money(r.revenue)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: total <= 0 ? 0 : r.revenue / total),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.quickTopProductsToday,
            child: topToday.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Text(e.toString()),
              data: (rows) => _TopProductsList(rows: rows),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.quickTopProducts7d,
            child: top7.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Text(e.toString()),
              data: (rows) => _TopProductsList(rows: rows),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.quickTopProducts30d,
            child: top30.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Text(e.toString()),
              data: (rows) => _TopProductsList(rows: rows),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13))),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.rows});
  final List<ProductSalesRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        refL10n(context).quickNoData,
        style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: rows.map((r) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(r.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'x${r.quantitySold.toStringAsFixed(0)}',
            style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: Text(
            SalesQuickReportScreen._money(r.revenue),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }

  AppLocalizations refL10n(BuildContext context) =>
      ProviderScope.containerOf(context).read(appLocalizationsProvider);
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

