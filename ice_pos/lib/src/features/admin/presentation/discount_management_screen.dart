import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/features/admin/presentation/discount_editor_screen.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/discount_type.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';

final _discountsProvider = FutureProvider<List<Discount>>((ref) async {
  ref.watch(posCategoriesRefreshProvider);
  final pos = ref.watch(posRepositoryProvider);
  if (pos != null) {
    return pos.getDiscounts();
  }
  return CloudSyncService.fetchDiscountsFromCloud();
});

class DiscountManagementScreen extends ConsumerWidget {
  const DiscountManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final discountsAsync = ref.watch(_discountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.discountManagement,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.importEmployeePrices,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => _importEmployeePrices(context, ref, l10n),
          ),
        ],
      ),
      body: discountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ),
        data: (discounts) {
          if (discounts.isEmpty) {
            return Center(
              child: Text(
                l10n.noDiscountsHint,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: discounts.length,
            itemBuilder: (context, index) {
              final d = discounts[index];
              final isEmployee = DiscountType.isEmployee(d.type);
              final subtitle = isEmployee
                  ? l10n.discountTypeEmployee
                  : '${l10n.discountTypePercentage}: ${(d.percentage * 100).toStringAsFixed(0)}%';
              return ListTile(
                leading: Icon(
                  isEmployee ? Icons.badge_outlined : Icons.percent,
                  color: d.isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
                title: Text(
                  d.code,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    decoration:
                        d.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${d.description.isEmpty ? subtitle : d.description} · $subtitle'
                  '${d.isActive ? '' : ' · ${l10n.inactive}'}',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: () => _confirmDelete(context, ref, d, l10n),
                ),
                onTap: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => DiscountEditorScreen(
                        discountId: d.id,
                        initialCode: d.code,
                        initialType: d.type,
                        initialPercentage: d.percentage,
                        initialDescription: d.description,
                        initialIsActive: d.isActive,
                      ),
                    ),
                  );
                  ref.invalidate(_discountsProvider);
                },
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
              builder: (_) => const DiscountEditorScreen(),
            ),
          );
          ref.invalidate(_discountsProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _importEmployeePrices(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final pos = ref.read(posRepositoryProvider);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La importación de precios empleado requiere la app local (Android). En web edita el precio empleado en cada producto.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importEmployeePrices),
        content: Text(l10n.importEmployeePricesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.importAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final n = await pos.applyEmployeePricesFromAsset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importEmployeePricesDone(n))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Discount discount,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDiscount),
        content: Text('${l10n.deleteDiscountConfirm} "${discount.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pos = ref.read(posRepositoryProvider);
    if (pos != null) {
      await pos.deleteDiscount(discount.id);
    } else {
      await CloudSyncService.deleteDiscountFromCloud(discount.id);
    }
    ref.invalidate(_discountsProvider);
  }
}
