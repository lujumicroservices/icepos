import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/pending_cashier_approvals_cloud_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

/// Lista unificada: Drift en caja física o Supabase en web admin.
final pendingCashierApprovalsUiProvider =
    StreamProvider<List<PendingCashierApprovalItem>>((ref) {
  final pos = ref.watch(posRepositoryProvider);
  if (CloudSyncService.isEnabled && pos != null) {
    return _watchMergedPendingApprovals(pos);
  }
  if (CloudSyncService.isEnabled && pos == null) {
    return PendingCashierApprovalsCloudService.watchPendingForActiveStore().map((rows) {
      return rows.map(PendingCashierApprovalItem.fromCloud).toList();
    });
  }
  if (pos != null) {
    return pos.watchPendingCashierApprovals().map(
          (rows) => rows.map(PendingCashierApprovalItem.fromDrift).toList(),
        );
  }
  return Stream.value(const <PendingCashierApprovalItem>[]);
});

Stream<List<PendingCashierApprovalItem>> _watchMergedPendingApprovals(
  PosRepository pos,
) async* {
  while (true) {
    final localRows = await pos.getPendingCashierApprovals();
    final cloudRows = await PendingCashierApprovalsCloudService.fetchPendingForActiveStore();
    final items = <PendingCashierApprovalItem>[
      ...cloudRows.map(PendingCashierApprovalItem.fromCloud),
    ];
    final cloudIds = items
        .map((i) => i.cloudRowId)
        .whereType<String>()
        .toSet();
    for (final row in localRows) {
      final localItem = PendingCashierApprovalItem.fromDrift(row);
      final cloudId = localItem.cloudRowId;
      if (cloudId != null && cloudIds.contains(cloudId)) {
        continue;
      }
      items.add(localItem);
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    yield items;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}

class PendingCashierApprovalItem {
  const PendingCashierApprovalItem({
    required this.busyKey,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.driftRowId,
    this.cloudRowId,
    this.sourceDeviceId,
  });

  final String busyKey;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int? driftRowId;
  final String? cloudRowId;
  final String? sourceDeviceId;

  static PendingCashierApprovalItem fromDrift(PendingCashierApproval row) {
    return PendingCashierApprovalItem(
      busyKey: 'd:${row.id}',
      kind: row.kind,
      payload: jsonDecode(row.payloadJson) as Map<String, dynamic>,
      createdAt: row.createdAt,
      driftRowId: row.id,
      cloudRowId: row.cloudPendingId,
    );
  }

  static PendingCashierApprovalItem fromCloud(CloudPendingCashierApprovalRow row) {
    return PendingCashierApprovalItem(
      busyKey: 'c:${row.id}',
      kind: row.kind,
      payload: row.payload,
      createdAt: row.createdAt,
      cloudRowId: row.id,
      sourceDeviceId: row.deviceId,
    );
  }
}

class PendingCashierApprovalsScreen extends ConsumerStatefulWidget {
  const PendingCashierApprovalsScreen({super.key});

  @override
  ConsumerState<PendingCashierApprovalsScreen> createState() =>
      _PendingCashierApprovalsScreenState();
}

class _PendingCashierApprovalsScreenState
    extends ConsumerState<PendingCashierApprovalsScreen> {
  String? _busyKey;

  String _kindLabel(String kind, AppLocalizations l10n) {
    switch (kind) {
      case 'movement':
        return l10n.pendingApprovalKindMovement;
      case 'sale_cancel':
        return l10n.pendingApprovalKindSaleCancel;
      case 'shift_close':
        return l10n.pendingApprovalKindShiftClose;
      default:
        return kind;
    }
  }

  String _detailText(PendingCashierApprovalItem row, AppLocalizations l10n) {
    final map = row.payload;
    final buf = StringBuffer();
    switch (row.kind) {
      case 'movement':
        final type = map['type'] as String? ?? '';
        final typeLabel =
            type == 'ENTRADA' ? l10n.entry : (type == 'SALIDA' ? l10n.exit : type);
        final account = map['account'] as String? ?? '';
        final accountLabel =
            account == 'CAJA' ? l10n.accountCash : (account == 'BANCO' ? l10n.accountBank : account);
        final amount = (map['amount'] as num?)?.toDouble() ?? 0;
        final reason = map['reason'] as String? ?? '';
        buf.write('$typeLabel · $accountLabel · \$${amount.toStringAsFixed(2)}\n$reason');
        break;
      case 'sale_cancel':
        final id = (map['saleId'] as num?)?.toInt();
        buf.write('${l10n.salesHistory} · id: $id');
        break;
      case 'shift_close':
        final sid = (map['shiftId'] as num?)?.toInt();
        final declared = (map['declaredCash'] as num?)?.toDouble();
        final expected = (map['expectedCash'] as num?)?.toDouble();
        final diff = (map['difference'] as num?)?.toDouble();
        final notes = map['notes'] as String?;
        buf.write('${l10n.closeShift} · ${l10n.pendingApprovalShiftIdLabel}: $sid\n');
        if (declared != null) {
          buf.write('${l10n.cash}: \$${declared.toStringAsFixed(2)}');
        }
        if (expected != null) {
          buf.write(
            '\n${l10n.pendingApprovalExpectedCashLabel}: \$${expected.toStringAsFixed(2)}',
          );
        }
        if (diff != null) {
          buf.write(
            '\n${l10n.pendingApprovalCashDifferenceLabel}: \$${diff.toStringAsFixed(2)}',
          );
        }
        if (notes != null && notes.isNotEmpty) {
          buf.write('\n$notes');
        }
        break;
      default:
        buf.write(jsonEncode(map));
    }
    if (row.sourceDeviceId != null && row.sourceDeviceId!.isNotEmpty) {
      buf.write('\n${l10n.pendingApprovalDeviceLine(row.sourceDeviceId!)}');
    }
    return buf.toString();
  }

  Future<void> _approve(PendingCashierApprovalItem row) async {
    final l10n = ref.read(appLocalizationsProvider);
    setState(() => _busyKey = row.busyKey);
    String? err;
    final repo = ref.read(posRepositoryProvider);
    if (row.driftRowId != null && repo != null) {
      err = await repo.approvePendingCashierApproval(row.driftRowId!);
    } else if (row.cloudRowId != null) {
      err = await PendingCashierApprovalsCloudService.approveFromWeb(row.cloudRowId!);
    } else {
      err = 'approval_not_found';
    }
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reject(PendingCashierApprovalItem row) async {
    final l10n = ref.read(appLocalizationsProvider);
    setState(() => _busyKey = row.busyKey);
    final repo = ref.read(posRepositoryProvider);
    if (row.driftRowId != null && repo != null) {
      await repo.rejectPendingCashierApproval(row.driftRowId!);
    } else if (row.cloudRowId != null) {
      final err = await PendingCashierApprovalsCloudService.rejectFromWeb(row.cloudRowId!);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $err'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _busyKey = null);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busyKey = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pendingApprovalRejectedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(pendingCashierApprovalsUiProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pendingCashierApprovalsTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${l10n.error}: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                l10n.pendingApprovalEmpty,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final row = list[i];
              final local = row.createdAt.toLocal();
              final timeStr =
                  '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              final busy = _busyKey == row.busyKey;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pending_actions_outlined, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _kindLabel(row.kind, l10n),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _detailText(row, l10n),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy ? null : () => _reject(row),
                              child: Text(l10n.pendingApprovalReject),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: busy ? null : () => _approve(row),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(l10n.pendingApprovalApprove),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
