import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/voice_assistant/presentation/voice_assistant_flow.dart';
import 'package:intl/intl.dart';

final _filterAccountProvider = StateProvider<String?>((ref) => null);

/// Bump after crear/editar en web para recargar la lista en Supabase.
final _cloudMovementsRefreshProvider = StateProvider<int>((ref) => 0);

/// Supabase-backed list when there is no local Drift DB (web).
final _cloudMovementsProvider =
    FutureProvider.autoDispose<List<Movement>>((ref) async {
  ref.watch(_cloudMovementsRefreshProvider);
  final filter = ref.watch(_filterAccountProvider);
  return CloudSyncService.fetchMovementsFromCloud(account: filter);
});

final _pendingMovementApprovalsProvider =
    StreamProvider.autoDispose<List<PendingCashierApproval>>((ref) {
  final pos = ref.watch(posRepositoryProvider);
  if (pos == null) return Stream.value(const <PendingCashierApproval>[]);
  return pos.watchPendingCashierApprovals().map((rows) {
    final filter = ref.read(_filterAccountProvider);
    return rows.where((row) {
      if (row.kind != 'movement') return false;
      if (filter == null) return true;
      try {
        final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        return (payload['account'] as String?) == filter;
      } catch (_) {
        return false;
      }
    }).toList();
  });
});

/// Opción de turno abierto para asociar un movimiento de caja.
class _MovementShiftChoice {
  const _MovementShiftChoice({
    required this.cloudShiftId,
    required this.label,
    this.localShiftId,
  });

  final int cloudShiftId;
  final int? localShiftId;
  final String label;
}

Future<List<_MovementShiftChoice>> _loadMovementShiftChoices(
  PosRepository? repo,
  AppLocalizations l10n,
  String localeTag,
) async {
  final byCloudId = <int, _MovementShiftChoice>{};
  final dateFmt = DateFormat('dd/MM HH:mm', localeTag);

  if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
    final open = await CloudSyncService.fetchOpenShiftsForActiveStore();
    for (final s in open) {
      int? localId;
      if (repo != null) {
        final local = await repo.findOpenLocalShiftForCloudId(s.id);
        localId = local?.id;
      }
      final reg = s.registerLabel ?? '—';
      final started = dateFmt.format(s.startTime.toLocal());
      byCloudId[s.id] = _MovementShiftChoice(
        cloudShiftId: s.id,
        localShiftId: localId,
        label: '$reg · $started · #${s.id}',
      );
    }
  }

  if (repo != null) {
    for (final s in await repo.getOpenShiftsLocal()) {
      final cloudId = CloudSyncService.supabaseShiftId(s);
      final started = dateFmt.format(s.startTime.toLocal());
      final existing = byCloudId[cloudId];
      if (existing == null) {
        byCloudId[cloudId] = _MovementShiftChoice(
          cloudShiftId: cloudId,
          localShiftId: s.id,
          label: '${l10n.movementShiftLabel(cloudId)} · $started',
        );
      } else if (existing.localShiftId == null) {
        byCloudId[cloudId] = _MovementShiftChoice(
          cloudShiftId: cloudId,
          localShiftId: s.id,
          label: existing.label,
        );
      }
    }
  }

  final list = byCloudId.values.toList()
    ..sort((a, b) => b.cloudShiftId.compareTo(a.cloudShiftId));
  return list;
}

Future<_MovementShiftChoice?> _defaultMovementShiftChoice(
  PosRepository? repo,
  List<_MovementShiftChoice> choices,
) async {
  if (choices.isEmpty) return null;
  if (choices.length == 1) return choices.first;
  if (repo == null) return null;
  final cur = await repo.getCurrentShift();
  if (cur == null) return null;
  final cloudId = CloudSyncService.supabaseShiftId(cur);
  for (final c in choices) {
    if (c.localShiftId == cur.id || c.cloudShiftId == cloudId) {
      return c;
    }
  }
  return null;
}

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final filterAccount = ref.watch(_filterAccountProvider);
    final pos = ref.watch(posRepositoryProvider);
    final isAdmin = ref.watch(userRoleProvider) == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.movements),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.mic),
              tooltip: l10n.voiceMicTooltip,
              onPressed: () => startVoiceMovementFlow(
                context,
                ref,
                onCloudRefresh: () {
                  ref.read(_cloudMovementsRefreshProvider.notifier).state++;
                  ref.invalidate(_cloudMovementsProvider);
                },
              ),
            ),
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
                    isAdmin: isAdmin,
                  )
                : _MovementsCloudBody(l10n: l10n, isAdmin: isAdmin),
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
    required this.isAdmin,
  });

  final String? filterAccount;
  final AppLocalizations l10n;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(posRepositoryProvider)!;
    final stream = repo.watchMovements(account: filterAccount);
    final pendingAsync = ref.watch(_pendingMovementApprovalsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await repo.syncMovementsFromCloudIntoLocal(account: filterAccount).timeout(
          const Duration(seconds: 45),
          onTimeout: () {},
        );
      },
      child: StreamBuilder<List<Movement>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${l10n.error}: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final pending = pendingAsync.asData?.value ?? const <PendingCashierApproval>[];
          return _MovementListView(
            list: snapshot.data!,
            l10n: l10n,
            pendingApprovals: pending,
            isAdmin: isAdmin,
            onCancel: isAdmin
                ? (m) => _confirmCancelMovement(context, ref, l10n, m, repo: repo)
                : null,
          );
        },
      ),
    );
  }
}

class _MovementsCloudBody extends ConsumerWidget {
  const _MovementsCloudBody({required this.l10n, required this.isAdmin});

  final AppLocalizations l10n;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cloudMovementsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(_cloudMovementsRefreshProvider.notifier).state++;
        await ref.read(_cloudMovementsProvider.future);
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
        data: (list) => _MovementListView(
          list: list,
          l10n: l10n,
          isAdmin: isAdmin,
          onCancel: isAdmin
              ? (m) => _confirmCancelMovement(context, ref, l10n, m)
              : null,
        ),
      ),
    );
  }
}

class _MovementListView extends StatelessWidget {
  const _MovementListView({
    required this.list,
    required this.l10n,
    this.pendingApprovals = const <PendingCashierApproval>[],
    this.isAdmin = false,
    this.onCancel,
  });

  final List<Movement> list;
  final AppLocalizations l10n;
  final List<PendingCashierApproval> pendingApprovals;
  final bool isAdmin;
  final void Function(Movement movement)? onCancel;

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
      itemCount: list.length + (pendingApprovals.isEmpty ? 0 : 1),
      itemBuilder: (context, i) {
        if (i == 0 && pendingApprovals.isNotEmpty) {
          return _PendingApprovalsMovementsCard(
            pendingApprovals: pendingApprovals,
            l10n: l10n,
          );
        }
        final movementIndex = i - (pendingApprovals.isEmpty ? 0 : 1);
        final m = list[movementIndex];
        final isEntrada = m.type == 'ENTRADA';
        final dateLocal = m.date.toLocal();
        final dateStr =
            '${dateLocal.day}/${dateLocal.month}/${dateLocal.year} ${dateLocal.hour.toString().padLeft(2, '0')}:${dateLocal.minute.toString().padLeft(2, '0')}';
        final accountLabel = m.account == 'CAJA' ? l10n.accountCash : l10n.accountBank;
        final shiftPart = m.shiftId != null ? ' · ${l10n.movementShiftLabel(m.shiftId!)}' : '';
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
              '$dateStr · $accountLabel$shiftPart',
              style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isEntrada ? '+' : '-'}\$${m.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isEntrada ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                if (isAdmin && onCancel != null)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'cancel') onCancel!(m);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'cancel',
                        child: Text(l10n.cancelMovement),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _confirmCancelMovement(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  Movement movement, {
  PosRepository? repo,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.cancelMovement),
      content: Text(l10n.cancelMovementConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.apply)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    String? err;
    if (repo != null) {
      err = await repo.cancelMovement(movement.id);
    } else {
      err = await CloudSyncService.cancelMovementInCloud(movement.id);
      ref.read(_cloudMovementsRefreshProvider.notifier).state++;
    }
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelMovement)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _PendingApprovalsMovementsCard extends StatelessWidget {
  const _PendingApprovalsMovementsCard({
    required this.pendingApprovals,
    required this.l10n,
  });

  final List<PendingCashierApproval> pendingApprovals;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_outlined, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(
                  l10n.pendingApprovalQueued,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final row in pendingApprovals) ...[
              Text(
                _pendingMovementLine(row, l10n),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  static String _pendingMovementLine(PendingCashierApproval row, AppLocalizations l10n) {
    try {
      final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
      final reason = payload['reason'] as String? ?? '';
      final account = payload['account'] as String? ?? '';
      final accountLabel = account == 'BANCO' ? l10n.accountBank : l10n.accountCash;
      return '$accountLabel · \$${amount.toStringAsFixed(2)} · $reason';
    } catch (_) {
      return l10n.pendingApprovalQueued;
    }
  }
}

Future<void> _showAddMovementDialog(BuildContext context, WidgetRef ref) async {
  final l10n = ref.read(appLocalizationsProvider);
  final localeTag = ref.read(localeProvider).languageCode == 'en' ? 'en' : 'es';
  final repo = ref.read(posRepositoryProvider);

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

  final shiftChoices = await _loadMovementShiftChoices(repo, l10n, localeTag);
  if (!context.mounted) return;
  final defaultShift = await _defaultMovementShiftChoice(repo, shiftChoices);
  if (!context.mounted) return;

  final reasonController = TextEditingController();
  final amountController = TextEditingController();
  String account = 'CAJA';
  _MovementShiftChoice? selectedShift = defaultShift;

  final result = await showDialog<
      ({
        String reason,
        double amount,
        String account,
        int? cloudShiftId,
        int? localShiftId,
      })>(
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
                  onSelectionChanged: (s) {
                    setState(() {
                      account = s.first;
                      if (account != 'CAJA') {
                        selectedShift = null;
                      } else if (selectedShift == null && shiftChoices.length == 1) {
                        selectedShift = shiftChoices.first;
                      }
                    });
                  },
                ),
                if (account == 'CAJA' && shiftChoices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.movementLinkShift,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_MovementShiftChoice?>(
                        isExpanded: true,
                        value: selectedShift,
                        items: [
                          DropdownMenuItem<_MovementShiftChoice?>(
                            value: null,
                            child: Text(l10n.movementShiftNone),
                          ),
                          for (final c in shiftChoices)
                            DropdownMenuItem(
                              value: c,
                              child: Text(c.label, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => selectedShift = v),
                      ),
                    ),
                  ),
                ],
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
                final cloudShiftId =
                    account == 'CAJA' ? selectedShift?.cloudShiftId : null;
                final localShiftId =
                    account == 'CAJA' ? selectedShift?.localShiftId : null;
                Navigator.pop(
                  ctx,
                  (
                    reason: reasonController.text.trim(),
                    amount: amount,
                    account: account,
                    cloudShiftId: cloudShiftId,
                    localShiftId: localShiftId,
                  ),
                );
              },
              child: Text(l10n.apply),
            ),
          ],
        );
      },
    ),
  );

  if (result == null || !context.mounted) return;

  final role = ref.read(userRoleProvider);

  try {
    if (repo != null && role == UserRole.employee) {
      final resolved = await repo.resolveMovementShiftForInsert(
        account: result.account,
        pickedLocalShiftId:
            result.account == 'CAJA' ? result.localShiftId : null,
        pickedCloudShiftId:
            result.account == 'CAJA' ? result.cloudShiftId : null,
      );
      await repo.enqueuePendingMovement(
        type: type,
        account: result.account,
        amount: result.amount,
        reason: result.reason,
        shiftId: resolved.localShiftId,
        cloudShiftId: resolved.cloudShiftIdForSync ?? result.cloudShiftId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pendingApprovalQueued)),
        );
      }
      return;
    }
    if (repo != null) {
      final resolved = await repo.resolveMovementShiftForInsert(
        account: result.account,
        pickedLocalShiftId:
            result.account == 'CAJA' ? result.localShiftId : null,
        pickedCloudShiftId:
            result.account == 'CAJA' ? result.cloudShiftId : null,
      );
      await repo.insertMovement(
        type: type,
        account: result.account,
        amount: result.amount,
        reason: result.reason,
        shiftId: resolved.localShiftId,
        cloudShiftIdForSync: resolved.cloudShiftIdForSync,
      );
    } else {
      final (err, _) = await CloudSyncService.insertMovementToCloud(
        type: type,
        account: result.account,
        amount: result.amount,
        reason: result.reason,
        shiftId: result.account == 'CAJA' ? result.cloudShiftId : null,
      );
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
        );
        return;
      }
      ref.read(_cloudMovementsRefreshProvider.notifier).state++;
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
