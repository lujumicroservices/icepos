import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_reports_service.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _dateRangeProvider = StateProvider<({DateTime start, DateTime end})>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return (start: start, end: end);
});

/// Preset period: (start at 00:00:00, end at 23:59:59).
({DateTime start, DateTime end}) _presetRange(String key) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (key) {
    case 'today':
      return (start: today, end: DateTime(now.year, now.month, now.day, 23, 59, 59));
    case 'yesterday':
      final y = today.subtract(const Duration(days: 1));
      return (start: y, end: DateTime(y.year, y.month, y.day, 23, 59, 59));
    case 'this_week':
      final weekday = now.weekday;
      final monday = today.subtract(Duration(days: weekday - 1));
      return (start: monday, end: DateTime(now.year, now.month, now.day, 23, 59, 59));
    case 'last_week':
      final weekday = now.weekday;
      final lastMonday = today.subtract(Duration(days: weekday - 1 + 7));
      final lastSunday = lastMonday.add(const Duration(days: 6));
      return (start: lastMonday, end: DateTime(lastSunday.year, lastSunday.month, lastSunday.day, 23, 59, 59));
    case 'this_month':
      final first = DateTime(now.year, now.month, 1);
      return (start: first, end: DateTime(now.year, now.month, now.day, 23, 59, 59));
    case 'last_month':
      final firstLast = DateTime(now.year, now.month - 1, 1);
      final lastDay = DateTime(now.year, now.month, 0);
      return (start: firstLast, end: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59));
    default:
      return (start: today, end: DateTime(now.year, now.month, now.day, 23, 59, 59));
  }
}

Widget _periodChip(
  BuildContext context,
  WidgetRef ref,
  String label,
  String presetKey,
  ({DateTime start, DateTime end}) currentRange,
) {
  final preset = _presetRange(presetKey);
  final isSelected = preset.start == currentRange.start && preset.end == currentRange.end;
  return FilterChip(
    label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
    selected: isSelected,
    onSelected: (_) {
      ref.read(_dateRangeProvider.notifier).state = preset;
    },
  );
}

final _salesSummaryProvider = FutureProvider.autoDispose<SalesReportSummary?>((ref) async {
  final range = ref.watch(_dateRangeProvider);
  return ref.read(posRepositoryProvider).getSalesReportSummary(start: range.start, end: range.end);
});

final _topProductsProvider = FutureProvider.autoDispose<List<ProductSalesRow>>((ref) async {
  final range = ref.watch(_dateRangeProvider);
  return ref.read(posRepositoryProvider).getTopProductsByDateRange(start: range.start, end: range.end);
});

/// Origen de datos del reporte de ventas: 0 = este dispositivo, 1 = nube.
final _salesReportSourceProvider = StateProvider<int>((ref) => 0);

/// Resumen y top productos desde ventas en la nube (filtradas por rango en hora local).
final _cloudSalesReportProvider = FutureProvider.autoDispose<({SalesReportSummary summary, List<ProductSalesRow> topProducts})>((ref) async {
  final range = ref.watch(_dateRangeProvider);
  final remote = await SalesSyncService.getRemoteSales();
  final startDay = DateTime(range.start.year, range.start.month, range.start.day);
  final endOfDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
  final inRange = remote.where((s) {
    final local = s.createdAt.toLocal();
    return !local.isBefore(startDay) && !local.isAfter(endOfDay);
  }).toList();

  double total = 0;
  double cash = 0, cardDebit = 0, cardCredit = 0, transfer = 0;
  final byProduct = <String, ({double qty, double revenue})>{};
  for (final s in inRange) {
    total += s.totalAmount;
    switch (s.paymentMethod) {
      case 'CASH':
        cash += s.totalAmount;
        break;
      case 'CARD_DEBIT':
        cardDebit += s.totalAmount;
        break;
      case 'CARD_CREDIT':
        cardCredit += s.totalAmount;
        break;
      case 'TRANSFER':
        transfer += s.totalAmount;
        break;
      default:
        cash += s.totalAmount;
    }
    for (final item in s.items) {
      final rev = item.quantity * item.unitPrice;
      final prev = byProduct[item.productName] ?? (qty: 0.0, revenue: 0.0);
      byProduct[item.productName] = (qty: prev.qty + item.quantity, revenue: prev.revenue + rev);
    }
  }
  final summary = SalesReportSummary(
    totalAmount: total,
    saleCount: inRange.length,
    cash: cash,
    cardDebit: cardDebit,
    cardCredit: cardCredit,
    transfer: transfer,
  );
  final topProducts = byProduct.entries
      .map((e) => ProductSalesRow(productName: e.key, quantitySold: e.value.qty, revenue: e.value.revenue))
      .toList();
  topProducts.sort((a, b) => b.revenue.compareTo(a.revenue));
  return (summary: summary, topProducts: topProducts.take(20).toList());
});

final _inventoryReportProvider = FutureProvider.autoDispose<List<InventoryReportRow>>((ref) async {
  return ref.read(posRepositoryProvider).getInventoryReport();
});

final _lowStockProvider = FutureProvider.autoDispose<List<InventoryReportRow>>((ref) async {
  return ref.read(posRepositoryProvider).getLowStockSupplies();
});

final _inventoryLogsProvider = FutureProvider.autoDispose<List<InventoryLogRow>>((ref) async {
  final range = ref.watch(_dateRangeProvider);
  return ref.read(posRepositoryProvider).getInventoryLogsSummary(start: range.start, end: range.end);
});

/// Origen inventario: 0 = este dispositivo, 1 = nube.
final _inventorySourceProvider = StateProvider<int>((ref) => 0);

final _cloudInventoryReportProvider = FutureProvider.autoDispose<List<InventoryReportRow>>((ref) async {
  final list = await CloudReportsService.getCloudSupplies();
  return list
      .map((s) => InventoryReportRow(
            supplyId: s.id,
            supplyName: s.name,
            unit: s.unit,
            currentStock: s.currentStock,
            reorderPoint: s.reorderPoint,
            costPerUnit: s.costPerUnit,
            category: s.category,
          ))
      .toList();
});

final _cloudLowStockProvider = FutureProvider.autoDispose<List<InventoryReportRow>>((ref) async {
  final list = await ref.watch(_cloudInventoryReportProvider.future);
  return list.where((r) => r.currentStock < r.reorderPoint).toList();
});

final _cloudInventoryLogsProvider = FutureProvider.autoDispose<List<InventoryLogRow>>((ref) async {
  final range = ref.watch(_dateRangeProvider);
  final endOfDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
  final list = await CloudReportsService.getCloudInventoryLogs(range.start, endOfDay);
  return list
      .map((l) => InventoryLogRow(
            supplyName: l.supplyName,
            unit: l.unit,
            changeAmount: l.changeAmount,
            reason: l.reason,
            date: l.date,
          ))
      .toList();
});

/// Origen Rayos X: 0 = este dispositivo, 1 = nube.
final _rayosXSourceProvider = StateProvider<int>((ref) => 0);

final _cloudRayosXSummaryProvider = FutureProvider.autoDispose<SalesReportSummary?>((ref) async {
  final day = ref.watch(_rayosXDateProvider);
  final remote = await SalesSyncService.getRemoteSales();
  final startDay = DateTime(day.year, day.month, day.day);
  final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
  final inRange = remote.where((s) {
    final local = s.createdAt.toLocal();
    return !local.isBefore(startDay) && !local.isAfter(endOfDay);
  }).toList();
  double total = 0;
  double cash = 0, cardDebit = 0, cardCredit = 0, transfer = 0;
  for (final s in inRange) {
    total += s.totalAmount;
    switch (s.paymentMethod) {
      case 'CASH':
        cash += s.totalAmount;
        break;
      case 'CARD_DEBIT':
        cardDebit += s.totalAmount;
        break;
      case 'CARD_CREDIT':
        cardCredit += s.totalAmount;
        break;
      case 'TRANSFER':
        transfer += s.totalAmount;
        break;
      default:
        cash += s.totalAmount;
    }
  }
  return SalesReportSummary(
    totalAmount: total,
    saleCount: inRange.length,
    cash: cash,
    cardDebit: cardDebit,
    cardCredit: cardCredit,
    transfer: transfer,
  );
});

final _cloudRayosXClosuresProvider = FutureProvider.autoDispose<List<ClosureDayRow>>((ref) async {
  final day = ref.watch(_rayosXDateProvider);
  final dayStart = DateTime(day.year, day.month, day.day);
  final cloudClosures = await CloudReportsService.getCloudShiftsWithClosures();
  final remoteSales = await SalesSyncService.getRemoteSales();
  final inDay = cloudClosures.where((c) {
    final local = c.closingTime.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    return d == dayStart;
  }).toList();

  final result = <ClosureDayRow>[];
  for (final c in inDay) {
    final startLocal = c.startTime.toLocal();
    final endLocal = c.endTime.toLocal();
    double cash = 0, debit = 0, credit = 0, transfer = 0;
    for (final s in remoteSales) {
      final local = s.createdAt.toLocal();
      if (!local.isBefore(startLocal) && !local.isAfter(endLocal)) {
        switch (s.paymentMethod) {
          case 'CASH':
            cash += s.totalAmount;
            break;
          case 'CARD_DEBIT':
            debit += s.totalAmount;
            break;
          case 'CARD_CREDIT':
            credit += s.totalAmount;
            break;
          case 'TRANSFER':
            transfer += s.totalAmount;
            break;
          default:
            cash += s.totalAmount;
        }
      }
    }
    result.add(ClosureDayRow(
      shiftId: c.shiftId,
      startTime: c.startTime,
      endTime: c.endTime,
      closingTime: c.closingTime,
      startingFund: c.startingFund,
      cashSales: cash,
      cardDebit: debit,
      cardCredit: credit,
      transferSales: transfer,
      expenses: 0,
      systemExpectedCash: c.systemExpectedCash,
      declaredCash: c.declaredCash,
      difference: c.difference,
      notes: c.notes,
    ));
  }
  result.sort((a, b) => a.closingTime.compareTo(b.closingTime));
  return result;
});

/// Fecha seleccionada para el reporte Rayos X del día (por defecto hoy).
final _rayosXDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _rayosXSummaryProvider = FutureProvider.autoDispose<SalesReportSummary?>((ref) async {
  final day = ref.watch(_rayosXDateProvider);
  final start = day;
  final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
  return ref.read(posRepositoryProvider).getSalesReportSummary(start: start, end: end);
});

final _rayosXClosuresProvider = FutureProvider.autoDispose<List<ClosureDayRow>>((ref) async {
  final day = ref.watch(_rayosXDateProvider);
  return ref.read(posRepositoryProvider).getClosuresForDay(day);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.salesReports),
            Tab(text: l10n.inventoryReports),
            Tab(text: l10n.rayosXReport),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SalesReportsTab(l10n: l10n),
          _InventoryReportsTab(l10n: l10n),
          _RayosXTab(l10n: l10n),
        ],
      ),
    );
  }
}

class _SalesReportsTab extends ConsumerWidget {
  const _SalesReportsTab({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_dateRangeProvider);
    final useCloud = ref.watch(_salesReportSourceProvider) == 1;
    final cloudAvailable = SalesSyncService.isAvailable;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_salesSummaryProvider);
        ref.invalidate(_topProductsProvider);
        ref.invalidate(_cloudSalesReportProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cloudAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.thisDevice)),
                    ButtonSegment(value: 1, label: Text(l10n.inCloud)),
                  ],
                  selected: {ref.watch(_salesReportSourceProvider)},
                  onSelectionChanged: (s) => ref.read(_salesReportSourceProvider.notifier).state = s.first,
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.period, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _periodChip(context, ref, l10n.periodToday, 'today', range),
                        _periodChip(context, ref, l10n.periodYesterday, 'yesterday', range),
                        _periodChip(context, ref, l10n.periodThisWeek, 'this_week', range),
                        _periodChip(context, ref, l10n.periodLastWeek, 'last_week', range),
                        _periodChip(context, ref, l10n.periodThisMonth, 'this_month', range),
                        _periodChip(context, ref, l10n.periodLastMonth, 'last_month', range),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: range.start,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                ref.read(_dateRangeProvider.notifier).state = (
                                  start: date,
                                  end: range.end,
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              '${range.start.day}/${range.start.month}/${range.start.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: range.end,
                                firstDate: range.start,
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                ref.read(_dateRangeProvider.notifier).state = (
                                  start: range.start,
                                  end: DateTime(date.year, date.month, date.day, 23, 59, 59),
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              '${range.end.day}/${range.end.month}/${range.end.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            useCloud && cloudAvailable
                ? ref.watch(_cloudSalesReportProvider).when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Center(child: Text('${l10n.errorLoading}: $e')),
                      data: (report) => _buildSummaryCard(report.summary),
                    )
                : ref.watch(_salesSummaryProvider).when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Center(child: Text('${l10n.errorLoading}: $e')),
                      data: (summary) {
                        if (summary == null) return const SizedBox.shrink();
                        return _buildSummaryCard(summary);
                      },
                    ),
            const SizedBox(height: 20),
            Text(l10n.topProductsByRevenue, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            useCloud && cloudAvailable
                ? ref.watch(_cloudSalesReportProvider).when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (report) => _buildTopProductsList(context, report.topProducts),
                    )
                : ref.watch(_topProductsProvider).when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (list) => _buildTopProductsList(context, list),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(SalesReportSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.totalSales, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '\$${summary.totalAmount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${l10n.numberOfSales}: ${summary.saleCount}', style: GoogleFonts.inter(fontSize: 13)),
            const Divider(height: 24),
            Text(l10n.salesByPaymentMethod, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            _row(l10n.cash, summary.cash),
            _row(l10n.debit, summary.cardDebit),
            _row(l10n.credit, summary.cardCredit),
            _row(l10n.transfer, summary.transfer),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsList(BuildContext context, List<ProductSalesRow> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.cartEmpty, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final row = list[i];
          return ListTile(
            title: Text(row.productName, style: GoogleFonts.inter(fontSize: 14)),
            subtitle: Text('${row.quantitySold.toStringAsFixed(0)} ud', style: GoogleFonts.inter(fontSize: 12)),
            trailing: Text(
              '\$${row.revenue.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
          Text('\$${amount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InventoryReportsTab extends ConsumerWidget {
  const _InventoryReportsTab({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCloud = ref.watch(_inventorySourceProvider) == 1;
    final cloudAvailable = CloudReportsService.isAvailable;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_inventoryReportProvider);
        ref.invalidate(_lowStockProvider);
        ref.invalidate(_inventoryLogsProvider);
        ref.invalidate(_cloudInventoryReportProvider);
        ref.invalidate(_cloudLowStockProvider);
        ref.invalidate(_cloudInventoryLogsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cloudAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.thisDevice)),
                    ButtonSegment(value: 1, label: Text(l10n.inCloud)),
                  ],
                  selected: {ref.watch(_inventorySourceProvider)},
                  onSelectionChanged: (s) => ref.read(_inventorySourceProvider.notifier).state = s.first,
                ),
              ),
            ref.watch(useCloud && cloudAvailable ? _cloudLowStockProvider : _lowStockProvider).when(
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => const SizedBox.shrink(),
              data: (lowStock) {
                if (lowStock.isEmpty) return const SizedBox.shrink();
                return Card(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                    title: Text(l10n.lowStockAlert, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text('${lowStock.length} insumos bajo punto de reorden'),
                    onTap: () {},
                  ),
                );
              },
            ),
            if (ref.watch(useCloud && cloudAvailable ? _cloudLowStockProvider : _lowStockProvider).value?.isNotEmpty == true)
              const SizedBox(height: 16),
            Text(l10n.currentStock, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ref.watch(useCloud && cloudAvailable ? _cloudInventoryReportProvider : _inventoryReportProvider).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                final totalValue = list.fold<double>(0, (s, r) => s + r.value);
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(l10n.inventoryValue, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        trailing: Text('\$${totalValue.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: 280,
                        child: ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final r = list[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                r.supplyName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: r.isLowStock ? Theme.of(context).colorScheme.error : null,
                                ),
                              ),
                              subtitle: Text(
                                '${r.currentStock} ${r.unit} · Reorden: ${r.reorderPoint}',
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              trailing: Text('\$${r.value.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(l10n.recentMovements, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ref.watch(useCloud && cloudAvailable ? _cloudInventoryLogsProvider : _inventoryLogsProvider).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('$e')),
              data: (logs) {
                if (logs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Sin movimientos en el período', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  );
                }
                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      final reasonLabel = log.reason == 'SALE'
                          ? l10n.reportSale
                          : log.reason == 'PURCHASE'
                              ? l10n.reportPurchase
                              : l10n.reportWaste;
                      return ListTile(
                        dense: true,
                        title: Text(log.supplyName, style: GoogleFonts.inter(fontSize: 13)),
                        subtitle: Text(
                          () {
                            final d = log.date.toLocal();
                            return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')} · $reasonLabel';
                          }(),
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        trailing: Text(
                          '${log.changeAmount >= 0 ? '+' : ''}${log.changeAmount.toStringAsFixed(2)} ${log.unit}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: log.changeAmount >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RayosXTab extends ConsumerWidget {
  const _RayosXTab({required this.l10n});

  final AppLocalizations l10n;

  static String _timeStr(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(_rayosXDateProvider);
    final useCloud = ref.watch(_rayosXSourceProvider) == 1;
    final cloudAvailable = SalesSyncService.isAvailable;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_rayosXSummaryProvider);
        ref.invalidate(_rayosXClosuresProvider);
        ref.invalidate(_cloudRayosXSummaryProvider);
        ref.invalidate(_cloudRayosXClosuresProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cloudAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.thisDevice)),
                    ButtonSegment(value: 1, label: Text(l10n.inCloud)),
                  ],
                  selected: {ref.watch(_rayosXSourceProvider)},
                  onSelectionChanged: (s) => ref.read(_rayosXSourceProvider.notifier).state = s.first,
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.rayosXSubtitle,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          ref.read(_rayosXDateProvider.notifier).state = date;
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        '${day.day}/${day.month}/${day.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            (useCloud && cloudAvailable ? ref.watch(_cloudRayosXSummaryProvider) : ref.watch(_rayosXSummaryProvider)).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('${l10n.errorLoading}: $e')),
              data: (summary) {
                if (summary == null) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.totalSales, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${summary.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('${l10n.numberOfSales}: ${summary.saleCount}', style: GoogleFonts.inter(fontSize: 13)),
                        const Divider(height: 24),
                        Text(l10n.salesByPaymentMethod, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        _rayosXRow(l10n.cash, summary.cash),
                        _rayosXRow(l10n.debit, summary.cardDebit),
                        _rayosXRow(l10n.credit, summary.cardCredit),
                        _rayosXRow(l10n.transfer, summary.transfer),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(l10n.closuresOfDay, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            (useCloud && cloudAvailable ? ref.watch(_cloudRayosXClosuresProvider) : ref.watch(_rayosXClosuresProvider)).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('$e')),
              data: (closures) {
                if (closures.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.noClosuresThatDay,
                      style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return Column(
                  children: closures.asMap().entries.map((entry) {
                    final i = entry.key + 1;
                    final c = entry.value;
                    final isBalanced = c.difference.abs() < 0.01;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          '${l10n.cutLabel} $i · ${_timeStr(c.startTime)} - ${_timeStr(c.closingTime)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Text(
                          '${l10n.totalSales}: \$${c.totalSales.toStringAsFixed(2)} · ${l10n.declaredCash}: \$${c.declaredCash.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        trailing: Icon(
                          isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: isBalanced ? Colors.green : Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rayosXRow(l10n.openingTime, 0, trailing: _timeStr(c.startTime)),
                                _rayosXRow(l10n.closingTime, 0, trailing: _timeStr(c.closingTime)),
                                const Divider(height: 16),
                                _rayosXRow(l10n.startingFund, c.startingFund),
                                _rayosXRow(l10n.cash, c.cashSales),
                                _rayosXRow(l10n.debit, c.cardDebit),
                                _rayosXRow(l10n.credit, c.cardCredit),
                                _rayosXRow(l10n.transfer, c.transferSales),
                                _rayosXRow(l10n.expenses, -c.expenses),
                                const Divider(height: 16),
                                _rayosXRow(l10n.expectedInDrawer, c.systemExpectedCash),
                                _rayosXRow(l10n.declaredCash, c.declaredCash),
                                _rayosXRow(
                                  l10n.difference,
                                  c.difference,
                                  color: isBalanced ? Colors.green : Theme.of(context).colorScheme.error,
                                ),
                                if (c.notes != null && c.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Notas: ${c.notes}', style: GoogleFonts.inter(fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rayosXRow(String label, double amount, {String? trailing, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
          if (trailing != null)
            Text(trailing, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))
          else
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: color),
            ),
        ],
      ),
    );
  }
}
