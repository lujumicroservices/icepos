import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/sales_sync_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _salesHistoryStreamProvider =
    StreamProvider<List<SaleWithItems>>((ref) {
  return ref.watch(posRepositoryProvider).watchSalesHistory();
});

final _remoteSalesProvider =
    FutureProvider<List<RemoteSale>>((ref) async {
  return SalesSyncService.getRemoteSales();
});

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key, this.onlyToday = false});

  /// Si es true (modo empleado), solo se muestran las ventas del día.
  final bool onlyToday;

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  int _segmentIndex = 0; // 0 = local, 1 = cloud

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static List<SaleWithItems> _filterToToday(List<SaleWithItems> sales) {
    final today = _today;
    return sales
        .where((s) {
          final local = s.sale.date.toLocal();
          final saleDate = DateTime(local.year, local.month, local.day);
          return saleDate == today;
        })
        .toList();
  }

  static double _totalSalesToday(List<SaleWithItems> sales) {
    final today = _today;
    return sales
        .where((s) {
          final local = s.sale.date.toLocal();
          final saleDate = DateTime(local.year, local.month, local.day);
          return saleDate == today;
        })
        .fold(0.0, (sum, s) => sum + s.sale.totalAmount);
  }

  static double _totalRemoteToday(List<RemoteSale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sales
        .where((s) {
          final local = s.createdAt.toLocal();
          final saleDate = DateTime(local.year, local.month, local.day);
          return saleDate == today;
        })
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(_salesHistoryStreamProvider);
    final syncAvailable = SalesSyncService.isAvailable && !widget.onlyToday;
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (syncAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.thisDevice)),
                  ButtonSegment(value: 1, label: Text(l10n.inCloud)),
                ],
                selected: {_segmentIndex},
                onSelectionChanged: (s) => setState(() => _segmentIndex = s.first),
              ),
            ),
          Expanded(
            child: _segmentIndex == 0
                ? _buildLocalBody(salesAsync, ref.watch(userRoleProvider))
                : syncAvailable
                    ? _buildCloudBody(ref)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Configura Supabase en .env para ver ventas en la nube.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBody(AsyncValue<List<SaleWithItems>> salesAsync, UserRole? role) {
    return salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading sales history',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        data: (sales) {
          final list =
              widget.onlyToday ? _filterToToday(sales) : sales;
          final totalToday = _totalSalesToday(list);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total ventas hoy (este dispositivo)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${totalToday.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (list.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No hay ventas aún'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final saleWithItems = list[index];
                        final sale = saleWithItems.sale;
                        final dateLocal = sale.date.toLocal();
                        final timeStr =
                            '${dateLocal.hour.toString().padLeft(2, '0')}:${dateLocal.minute.toString().padLeft(2, '0')}';

                        final l10n = ref.watch(appLocalizationsProvider);
                        final children = <Widget>[
                          ...saleWithItems.items
                              .map(
                                (item) => ListTile(
                                  dense: true,
                                  title: Text(
                                    '${item.quantity.toStringAsFixed(0)}x ${item.productName} @ \$${item.priceAtSale.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                ),
                              ),
                          if (role == UserRole.admin)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                              title: Text(
                                l10n.cancelSale,
                                style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.error),
                              ),
                              onTap: () => _confirmCancelSale(context, sale.id, l10n),
                            ),
                        ];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            title: Text(
                              '$timeStr — \$${sale.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              sale.paymentMethod,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            children: children,
                          ),
                        );
                      },
                      childCount: list.length,
                    ),
                  ),
                ),
            ],
          );
        },
    );
  }

  Future<void> _confirmCancelSale(BuildContext context, int saleId, dynamic l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelSaleConfirmTitle),
        content: Text(l10n.cancelSaleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.cancelSale),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(posRepositoryProvider).deleteSale(saleId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saleCancelled),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCloudBody(WidgetRef ref) {
    final remoteAsync = ref.watch(_remoteSalesProvider);
    return remoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Error al cargar ventas en la nube', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_remoteSalesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (sales) {
        final totalToday = _totalRemoteToday(sales);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_remoteSalesProvider);
            await ref.read(_remoteSalesProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total ventas hoy (todos los dispositivos)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${totalToday.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (sales.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No hay ventas en la nube aún')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sale = sales[index];
                        final local = sale.createdAt.toLocal();
                        final timeStr =
                            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                        final dateStr =
                            '${local.day}/${local.month}/${local.year}';
                        final deviceLabel = sale.deviceName ??
                            (sale.deviceId != null
                                ? 'ID: ${sale.deviceId!.length > 8 ? '${sale.deviceId!.substring(0, 8)}…' : sale.deviceId}'
                                : null);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            title: Text(
                              '$dateStr $timeStr — \$${sale.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: Text(
                              [sale.paymentMethod, if (deviceLabel != null) deviceLabel]
                                  .join(' · '),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            children: sale.items
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    title: Text(
                                      '${item.quantity.toStringAsFixed(0)}x ${item.productName} @ \$${item.unitPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                      childCount: sales.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
