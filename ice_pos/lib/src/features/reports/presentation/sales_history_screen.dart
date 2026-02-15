import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _salesHistoryStreamProvider =
    StreamProvider<List<SaleWithItems>>((ref) {
  return ref.watch(posRepositoryProvider).watchSalesHistory();
});

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(_salesHistoryStreamProvider);

    return Scaffold(
      body: salesAsync.when(
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
                            'Total Sales Today',
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
                    child: Text('No sales yet'),
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
      ),
    );
  }
}
