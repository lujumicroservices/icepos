import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/platform_orders_service.dart';

class PlatformOrdersScreen extends ConsumerStatefulWidget {
  const PlatformOrdersScreen({super.key});

  @override
  ConsumerState<PlatformOrdersScreen> createState() => _PlatformOrdersScreenState();
}

class _PlatformOrdersScreenState extends ConsumerState<PlatformOrdersScreen> {
  DateTime _selectedDay = DateTime.now();
  Future<List<PlatformOrderRow>>? _loadFuture;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    if (CloudSyncService.isEnabled) {
      _loadFuture = PlatformOrdersService.fetchUberEatsForDay(_selectedDay);
    } else {
      _loadFuture = Future.value([]);
    }
  }

  Future<void> _reload() async {
    if (!CloudSyncService.isEnabled) {
      if (mounted) setState(() => _loadFuture = Future.value([]));
      return;
    }
    final f = PlatformOrdersService.fetchUberEatsForDay(_selectedDay);
    if (mounted) setState(() => _loadFuture = f);
    await f;
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = _dateOnly(picked));
      await _reload();
    }
  }

  String _formatDay(DateTime d) {
    final tag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMEd(tag).format(d);
  }

  String _formatTime(DateTime utc) {
    final tag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(tag).format(utc.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!CloudSyncService.isEnabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.platformOrdersTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.platformOrdersRequiresCloud,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.platformOrdersTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.platformOrdersUberEatsSection,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_today, size: 20),
                  label: Text(_formatDay(_selectedDay)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.platformOrdersByDayHint,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<PlatformOrderRow>>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: scheme.error),
                          const SizedBox(height: 12),
                          Text(
                            l10n.platformOrdersLoadError,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _reload(),
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.reload),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.2,
                        ),
                        Icon(
                          Icons.delivery_dining_outlined,
                          size: 56,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.platformOrdersEmptyUberEats,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.platformOrdersEmptyHint,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final total = rows.fold<double>(0, (s, r) => s + r.totalAmount);
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.platformOrdersDayTotal(rows.length),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final r = rows[index];
                              final summary = (r.displaySummary != null &&
                                      r.displaySummary!.trim().isNotEmpty)
                                  ? r.displaySummary!.trim()
                                  : l10n.platformOrdersNoSummary;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  title: Text(
                                    '${_formatTime(r.orderedAt)} · \$${r.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${r.status} · ${r.externalOrderId}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          summary,
                                          style: GoogleFonts.inter(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: rows.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
