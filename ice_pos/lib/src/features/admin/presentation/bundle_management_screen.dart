import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_editor_screen.dart';

final _bundlesProvider = FutureProvider<List<({Bundle bundle, List<BundleItem> bundleItems})>>((ref) async {
  return ref.read(posRepositoryProvider).getBundlesWithItems();
});

class BundleManagementScreen extends ConsumerWidget {
  const BundleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundlesAsync = ref.watch(_bundlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bundle Management',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: bundlesAsync.when(
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
                  'Error loading bundles',
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
        data: (bundles) {
          if (bundles.isEmpty) {
            return Center(
              child: Text(
                'No bundles. Tap + to add.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bundles.length,
            itemBuilder: (context, index) {
              final bw = bundles[index];
              return ListTile(
                onTap: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => BundleEditorScreen(
                        bundleId: bw.bundle.id,
                        initialName: bw.bundle.name,
                        initialPrice: bw.bundle.price,
                        initialProductIds: bw.bundleItems
                            .map((bi) => (productId: bi.productId, quantity: bi.quantityRequired))
                            .toList(),
                      ),
                    ),
                  );
                  ref.invalidate(_bundlesProvider);
                },
                title: Text(
                  bw.bundle.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '\$${bw.bundle.price.toStringAsFixed(2)} • ${bw.bundleItems.length} product(s)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Bundle'),
                        content: Text(
                          'Delete "${bw.bundle.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(posRepositoryProvider).deleteBundle(bw.bundle.id);
                      ref.invalidate(_bundlesProvider);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => const BundleEditorScreen(),
            ),
          );
          ref.invalidate(_bundlesProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
