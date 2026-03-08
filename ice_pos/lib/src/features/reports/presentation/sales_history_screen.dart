import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  int _segmentIndex = 0; // 0 = local, 1 = cloud

  static double _totalSalesToday(List<SaleWithItems> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sales
        .where((s) {
          final saleDate =
              DateTime(s.sale.date.year, s.sale.date.month, s.sale.date.day);
          return saleDate == today;
        })
        .fold(0.0, (sum, s) => sum + s.sale.totalAmount);
  }

  static double _totalRemoteToday(List<RemoteSale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sales
        .where((s) {
          final d = s.createdAt;
          final saleDate = DateTime(d.year, d.month, d.day);
          return saleDate == today;
        })
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(_salesHistoryStreamProvider);
    final syncAvailable = SalesSyncService.isAvailable;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (syncAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Este dispositivo')),
                  ButtonSegment(value: 1, label: Text('En la nube')),
                ],
                selected: {_segmentIndex},
                onSelectionChanged: (s) => setState(() => _segmentIndex = s.first),
              ),
            ),
          Expanded(
            child: _segmentIndex == 0
                ? _buildLocalBody(salesAsync)
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

  Widget _buildLocalBody(AsyncValue<List<SaleWithItems>> salesAsync) {
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
          final totalToday = _totalSalesToday(sales);

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
              if (sales.isEmpty)
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
                        final saleWithItems = sales[index];
                        final sale = saleWithItems.sale;
                        final timeStr =
                            '${sale.date.hour.toString().padLeft(2, '0')}:${sale.date.minute.toString().padLeft(2, '0')}';

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
                            children: saleWithItems.items
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    title: Text(
                                      '${item.quantity.toStringAsFixed(0)}x ${item.productName} @ \$${item.priceAtSale.toStringAsFixed(2)}',
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
          );
        },
    );
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
                        final timeStr =
                            '${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}';
                        final dateStr =
                            '${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year}';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            title: Text(
                              '$dateStr $timeStr — \$${sale.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: Text(
                              sale.paymentMethod,
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
