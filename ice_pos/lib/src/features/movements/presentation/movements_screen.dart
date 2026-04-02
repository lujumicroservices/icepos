import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _filterAccountProvider = StateProvider<String?>((ref) => null);

/// Supabase-backed list when there is no local Drift DB (web).
final _cloudMovementsProvider =
    FutureProvider.autoDispose<List<Movement>>((ref) async {
  final filter = ref.watch(_filterAccountProvider);
  return CloudSyncService.fetchMovementsFromCloud(account: filter);
});

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final filterAccount = ref.watch(_filterAccountProvider);
    final pos = ref.watch(posRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.movements),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onSelected: (v) => ref.read(_filterAccountProvider.notifier).state = v,
            itemBuilder: (context) => [
              PopupMenuItem(value: null, child: Text(l10n.total)),
              PopupMenuItem(value: 'CAJA', child: Text(l10n.accountCash)),
              PopupMenuItem(value: 'BANCO', child: Text(l10n.accountBank)),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.movementsSubtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: pos != null
                ? _MovementsDriftBody(
                    filterAccount: filterAccount,
                    l10n: l10n,
                  )
                : _MovementsCloudBody(l10n: l10n),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMovementDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addMovement),
      ),
    );
  }
}

class _MovementsDriftBody extends ConsumerWidget {
  const _MovementsDriftBody({
    required this.filterAccount,
    required this.l10n,
  });

  final String? filterAccount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream =
        ref.watch(posRepositoryProvider)!.watchMovements(account: filterAccount);
    return StreamBuilder<List<Movement>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${l10n.error}: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _MovementListView(list: snapshot.data!, l10n: l10n);
      },
    );
  }
}

class _MovementsCloudBody extends ConsumerWidget {
  const _MovementsCloudBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cloudMovementsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_cloudMovementsProvider);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${l10n.error}: $e',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (list) => _MovementListView(list: list, l10n: l10n),
      ),
    );
  }
}

class _MovementListView extends StatelessWidget {
  const _MovementListView({
    required this.list,
    required this.l10n,
  });

  final List<Movement> list;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No hay movimientos',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        final isEntrada = m.type == 'ENTRADA';
        final dateLocal = m.date.toLocal();
        final dateStr =
            '${dateLocal.day}/${dateLocal.month}/${dateLocal.year} ${dateLocal.hour.toString().padLeft(2, '0')}:${dateLocal.minute.toString().padLeft(2, '0')}';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEntrada ? Colors.green.shade100 : Colors.orange.shade100,
              child: Icon(
                isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                color: isEntrada ? Colors.green.shade800 : Colors.orange.shade800,
                size: 22,
              ),
            ),
            title: Text(
              m.reason,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            subtitle: Text(
              '$dateStr · ${m.account == 'CAJA' ? l10n.accountCash : l10n.accountBank}',
              style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            trailing: Text(
              '${isEntrada ? '+' : '-'}\$${m.amount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isEntrada ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showAddMovementDialog(BuildContext context, WidgetRef ref) async {
  final l10n = ref.read(appLocalizationsProvider);
  final repo = ref.read(posRepositoryProvider);
  final shift = repo != null ? await repo.getCurrentShift() : null;

  if (!context.mounted) return;
  final type = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.addMovement),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_downward, color: Colors.green),
            title: Text(l10n.entry),
            onTap: () => Navigator.pop(ctx, 'ENTRADA'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.orange),
            title: Text(l10n.exit),
            onTap: () => Navigator.pop(ctx, 'SALIDA'),
          ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return;

  final reasonController = TextEditingController();
  final amountController = TextEditingController();
  String account = 'CAJA';

  final result = await showDialog<({String reason, double amount, String account})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(type == 'ENTRADA' ? l10n.entry : l10n.exit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: l10n.concept,
                    hintText: 'Ej. Transferencia recibida, Retiro para banco',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'CAJA', label: Text(l10n.accountCash)),
                    ButtonSegment(value: 'BANCO', label: Text(l10n.accountBank)),
                  ],
                  selected: {account},
                  onSelectionChanged: (s) => setState(() => account = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Indica el concepto')));
                  return;
                }
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Monto inválido')));
                  return;
                }
                Navigator.pop(ctx, (reason: reasonController.text.trim(), amount: amount, account: account));
              },
              child: Text(l10n.apply),
            ),
          ],
        );
      },
    ),
  );

  if (result == null || !context.mounted) return;

  final shiftId = result.account == 'CAJA' && shift != null ? shift.id : null;

  try {
    if (repo != null) {
      await repo.insertMovement(
        type: type,
        account: result.account,
        amount: result.amount,
        reason: result.reason,
        shiftId: shiftId,
      );
    } else {
      final err = await CloudSyncService.insertMovementToCloud(
        type: type,
        account: result.account,
        amount: result.amount,
        reason: result.reason,
        shiftId: shiftId,
      );
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
        );
        return;
      }
      ref.invalidate(_cloudMovementsProvider);
    }
  } on OfflineMasterWriteException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${type == 'ENTRADA' ? l10n.entry : l10n.exit} registrada')),
  );
}
