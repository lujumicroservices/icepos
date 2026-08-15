import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart'
    show OfflineMasterWriteException;
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';

final _discountCatalogRefreshProvider = StateProvider<int>((ref) => 0);

final _discountsAdminProvider = FutureProvider<List<Discount>>((ref) async {
  ref.watch(_discountCatalogRefreshProvider);
  ref.watch(posCategoriesRefreshProvider);
  final pos = ref.watch(posRepositoryProvider);
  if (pos != null) return pos.getAllDiscountsAdmin();
  return CloudSyncService.fetchDiscountsFromCloud();
});

/// Admin: create and edit percentage discounts (e.g. students 10%) shown at the register.
class DiscountCatalogScreen extends ConsumerWidget {
  const DiscountCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(_discountsAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.discountCatalogTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (discounts) {
          if (discounts.isEmpty) {
            return Center(
              child: Text(
                l10n.discountCatalogEmpty,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
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
              return ListTile(
                onTap: () => _openEditor(context, ref, l10n, existing: d),
                title: Text(
                  d.description,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  [
                    '${(d.percentage * 100).toStringAsFixed(0)}%',
                    d.code,
                    if (!d.isActive) l10n.discountInactiveLabel,
                  ].join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, l10n, d),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref, l10n),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    Discount? existing,
  }) async {
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.description ?? '');
    final pctController = TextEditingController(
      text: existing != null ? (existing.percentage * 100).toStringAsFixed(0) : '10',
    );
    var isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? l10n.discountCatalogTitle : l10n.discounts),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: l10n.discountCode,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.discountDisplayNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctController,
                  decoration: InputDecoration(
                    labelText: l10n.percentageHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.discountShowAtRegister, style: GoogleFonts.inter(fontSize: 14)),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.discountSave),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    final code = codeController.text.trim();
    final name = nameController.text.trim();
    final pct = double.tryParse(pctController.text.trim());
    if (code.isEmpty || pct == null || pct <= 0 || pct > 100) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.discountCode}: ${l10n.percentageHint} (1–100)',
            ),
          ),
        );
      }
      return;
    }

    try {
      final pos = ref.read(posRepositoryProvider);
      if (pos != null) {
        await pos.saveDiscountCatalog(
          id: existing?.id,
          code: code,
          percentage: pct / 100,
          description: name,
          isActive: isActive,
        );
      } else {
        if (existing == null) {
          final (err, _) = await CloudSyncService.insertDiscountToCloud(
            code: code,
            percentage: pct / 100,
            description: name,
            isActive: isActive,
          );
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            return;
          }
        } else {
          final err = await CloudSyncService.upsertDiscountToCloud(
            id: existing.id,
            code: code,
            percentage: pct / 100,
            description: name.isEmpty ? 'Discount' : name,
            isActive: isActive,
          );
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            return;
          }
        }
      }
      ref.read(_discountCatalogRefreshProvider.notifier).state++;
      ref.read(posCategoriesRefreshProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discountCatalogSaved)),
        );
      }
    } on OfflineMasterWriteException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Discount d,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discountDeleteConfirmTitle),
        content: Text(d.description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.discountDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final pos = ref.read(posRepositoryProvider);
      if (pos != null) {
        await pos.deleteDiscountCatalog(d.id);
      } else {
        final err = await CloudSyncService.deleteDiscountFromCloud(d.id);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          return;
        }
      }
      ref.read(_discountCatalogRefreshProvider.notifier).state++;
      ref.read(posCategoriesRefreshProvider.notifier).state++;
    } on OfflineMasterWriteException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
