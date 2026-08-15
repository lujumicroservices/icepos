import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/cashier_approval_policy.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/config/register_scope.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashController = TextEditingController();
  final _debitController = TextEditingController();
  final _creditController = TextEditingController();
  final _notesController = TextEditingController();

  Shift? _shift;
  ShiftTotalsForClosure? _totals;
  /// true = resumen final (con detalle y discrepancias). Desde ahí puede Volver o Cerrar corte.
  bool _showSummary = false;
  double _declaredCash = 0;
  double _declaredDebit = 0;
  double _declaredCredit = 0;
  /// Non-null solo después de haber cerrado el corte (pantalla muestra "Listo").
  ShiftClosureResult? _result;
  bool _isLoading = false;
  /// True until the first [getCurrentShift] (and totals) load finishes.
  bool _isLoadingShift = true;
  String? _error;
  _CloudCloseDiagnostics? _cloudDiag;
  /// Clave `shifts.id` en Supabase para el turno mostrado en diagnóstico nube.
  int? _cloudContextSupabaseShiftKey;
  /// Tras cerrar, [_shift] es null pero el resumen sigue mostrando ids del turno cerrado.
  int? _closedShiftCloudIdForSummary;
  /// Ventas locales del turno excluidas por estar canceladas en nube.
  int _cloudCancelledAppliedCount = 0;
  StreamSubscription<List<PendingCashierApproval>>? _pendingApprovalsSub;
  bool _isAwaitingShiftCloseApproval = false;
  bool _isShiftCloseApproved = false;
  DateTime? _shiftCloseApprovedAt;
  DateTime? _shiftCloseRejectedAt;
  int? _awaitingShiftCloseId;

  @override
  void initState() {
    super.initState();
    _startPendingApprovalsMonitor();
    _loadCurrentShift();
  }

  void _startPendingApprovalsMonitor() {
    final repo = ref.read(posRepositoryProvider);
    if (repo == null) return;
    _pendingApprovalsSub = repo.watchPendingCashierApprovals().listen((rows) {
      final targetShiftId = _awaitingShiftCloseId ?? _shift?.id;
      PendingCashierApproval? trackedRow;
      if (targetShiftId != null) {
        for (final row in rows) {
          if (row.kind != 'shift_close') continue;
          try {
            final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
            if ((payload['shiftId'] as num?)?.toInt() == targetShiftId) {
              trackedRow = row;
              break;
            }
          } catch (_) {}
        }
      }
      final hasPendingShiftClose = trackedRow != null;
      final payload = trackedRow != null
          ? (jsonDecode(trackedRow.payloadJson) as Map<String, dynamic>)
          : null;
      final approved = payload?['approvalStatus'] == 'approved';
      DateTime? approvedAt;
      if (approved) {
        final raw = payload?['approvedAt'];
        if (raw is String) {
          approvedAt = DateTime.tryParse(raw)?.toLocal();
        }
      }
      if (!mounted) return;
      final wasAwaiting = _isAwaitingShiftCloseApproval;
      if (wasAwaiting != hasPendingShiftClose) {
        setState(() {
          _isAwaitingShiftCloseApproval = hasPendingShiftClose;
          if (!hasPendingShiftClose) {
            if (!_isShiftCloseApproved && _awaitingShiftCloseId != null) {
              _shiftCloseRejectedAt = DateTime.now();
            }
            _awaitingShiftCloseId = null;
          }
        });
      }
      if (_isShiftCloseApproved != approved || _shiftCloseApprovedAt != approvedAt) {
        setState(() {
          _isShiftCloseApproved = approved;
          _shiftCloseApprovedAt = approvedAt;
          if (approved) _shiftCloseRejectedAt = null;
        });
      }
      if (!wasAwaiting && approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud aprobada. Ya puedes finalizar el corte.')),
        );
      } else if (wasAwaiting && !hasPendingShiftClose && !_isShiftCloseApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada por administrador.')),
        );
      }
    });
  }

  Future<void> _loadCurrentShift() async {
    if (mounted) {
      setState(() => _isLoadingShift = true);
    }
    try {
      final shift = await ref.read(posRepositoryProvider)!.getCurrentShift();
      if (!mounted) return;
      if (shift != null && CloudSyncService.isEnabled) {
        final db = ref.read(appDatabaseProvider);
        if (db != null) {
          await CloudSyncService.pullMovementsForShift(db, shift);
        }
      }
      if (!mounted) return;
      ShiftTotalsForClosure? totals;
      var cloudCancelledApplied = 0;
      if (shift != null) {
        totals = await ref.read(posRepositoryProvider)!.getShiftTotalsForClosure(shift.id);
        if (CloudSyncService.isEnabled && ConnectivityService.instance.isConnected) {
          cloudCancelledApplied = await ref
              .read(posRepositoryProvider)!
              .countCloudCancelledSalesAppliedToLocalShift(shift.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _shift = shift;
        _totals = totals;
        _error = null;
        _cloudDiag = null;
        _cloudContextSupabaseShiftKey =
            shift != null ? CloudSyncService.supabaseShiftId(shift) : null;
        _cloudCancelledAppliedCount = cloudCancelledApplied;
        if (shift != null) _closedShiftCloudIdForSummary = null;
      });
      if (shift != null && CloudSyncService.isEnabled) {
        await _refreshCloudDiagnostics(shift.id);
      } else if (mounted) {
        setState(() => _cloudDiag = null);
      }
    } finally {
      if (mounted) setState(() => _isLoadingShift = false);
    }
  }

  Future<void> _refreshCloudDiagnostics(int localShiftId) async {
    if (!CloudSyncService.isEnabled) return;
    if (!ConnectivityService.instance.isConnected) {
      if (mounted) {
        setState(() => _cloudDiag = const _CloudCloseDiagnostics(skippedNoNetwork: true));
      }
      return;
    }
    try {
      var supabaseKey = localShiftId;
      final db = ref.read(appDatabaseProvider);
      if (db != null) {
        final sh = await (db.select(db.shifts)..where((s) => s.id.equals(localShiftId)))
            .getSingleOrNull();
        if (sh != null) {
          supabaseKey = CloudSyncService.supabaseShiftId(sh);
        }
      }
      final device = await DeviceIdService.getDeviceInfo();
      final storeId = await StoreScope.getActiveStoreId();
      final row = await CloudSyncService.fetchShiftByIdFromCloud(supabaseKey);
      final open = await CloudSyncService.fetchOpenShiftForDeviceCloud(
        device.deviceId,
        storeId: storeId,
      );
      if (!mounted) return;
      setState(() {
        _cloudDiag = _CloudCloseDiagnostics(rowForLocalId: row, openForDevice: open);
        _cloudContextSupabaseShiftKey = supabaseKey;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cloudDiag = _CloudCloseDiagnostics(queryError: e.toString());
      });
    }
  }

  @override
  void dispose() {
    _pendingApprovalsSub?.cancel();
    _cashController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitToSummary() async {
    final l10n = ref.read(appLocalizationsProvider);
    final cash = parseDecimal(_cashController.text);
    if (cash == null || cash < 0) {
      setState(() => _error = l10n.validAmount);
      return;
    }
    final debit = parseDecimal(_debitController.text);
    final credit = parseDecimal(_creditController.text);
    if (debit == null || credit == null || debit < 0 || credit < 0) {
      setState(() => _error = l10n.cardDeclaredRequired);
      return;
    }
    setState(() {
      _error = null;
      _declaredCash = cash;
      _declaredDebit = debit;
      _declaredCredit = credit;
      _showSummary = true;
    });
    final sid = _shift?.id;
    if (sid != null && CloudSyncService.isEnabled) {
      await _refreshCloudDiagnostics(sid);
    }
  }

  void _goBackToForm() {
    setState(() => _showSummary = false);
  }

  Future<void> _showAdjustStartingFundDialog(AppLocalizations l10n) async {
    if (_shift == null) return;
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajustar fondo inicial'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Efectivo que había en caja al iniciar este turno (o el monto actual si no hubo ventas).',
                style: GoogleFonts.inter(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Fondo inicial (\$)',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final v = parseDecimal(controller.text);
                if (v != null && v >= 0) Navigator.pop(ctx, v);
              },
              child: Text(l10n.apply),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted) return;
    if (result != null && _shift != null) {
      await ref.read(posRepositoryProvider)!.updateShiftStartingFund(_shift!.id, result);
      await _loadCurrentShift();
    }
  }

  /// Returns starting fund amount, or null if cancelled.
  Future<double?> _showOpenShiftStartingFundDialog(
    AppLocalizations l10n, {
    double? suggestedAmount,
  }) async {
    final controller = TextEditingController(
      text: suggestedAmount != null && suggestedAmount >= 0
          ? suggestedAmount.toStringAsFixed(2)
          : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.openShiftStartingFundTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.openShiftStartingFundBody,
                style: GoogleFonts.inter(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: l10n.totalCashInDrawer,
                  border: const OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final v = parseDecimal(controller.text);
                if (v != null && v >= 0) Navigator.pop(ctx, v);
              },
              child: Text(l10n.apply),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  /// Opens a new shift after asking for starting fund. Optionally leaves the post-close summary.
  Future<void> _promptAndOpenShift(
    AppLocalizations l10n, {
    bool clearClosureSummary = false,
    double? suggestedStartingFund,
  }) async {
    final fund = await _showOpenShiftStartingFundDialog(
      l10n,
      suggestedAmount: suggestedStartingFund,
    );
    if (!mounted || fund == null) return;
    if (clearClosureSummary) {
      setState(() {
        _result = null;
        _showSummary = false;
      });
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(posRepositoryProvider)!.startShift(fund);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    await _loadCurrentShift();
  }

  /// Lista turnos abiertos en nube para el cajón activo y enlaza el elegido (p. ej. tras reinstalar).
  Future<void> _continueShiftFromCloud(AppLocalizations l10n) async {
    if (!CloudSyncService.isEnabled || !ConnectivityService.instance.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineRequiresInternet)),
        );
      }
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.continueOpenShiftLoading)),
          ],
        ),
      ),
    );
    final storeId = await StoreScope.getActiveStoreId();
    final registerId = await RegisterScope.getActiveRegisterId();
    final open = await CloudSyncService.fetchOpenShiftsForRegisterCloud(
      storeId: storeId,
      registerId: registerId,
    );
    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;
    if (open.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.continueOpenShiftEmpty)),
      );
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final chosen = await showDialog<CloudShiftSummary>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.continueOpenShiftTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in open)
                ListTile(
                  title: Text(
                    l10n.continueOpenShiftLine(
                      s.registerLabel ?? '${l10n.posRegisterTitle} #${s.registerId ?? registerId}',
                      '${s.id}',
                      s.startTime.toLocal().toString().substring(0, 16),
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  subtitle: s.deviceName != null
                      ? Text(s.deviceName!, style: GoogleFonts.inter(fontSize: 12))
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final err = await ref.read(posRepositoryProvider)!.adoptOpenShiftFromCloud(chosen);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: scheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    await _loadCurrentShift();
  }

  Future<void> _confirmCloseCut() async {
    if (_shift == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final l10n = ref.read(appLocalizationsProvider);
    final role = ref.read(userRoleProvider);
    final repo = ref.read(posRepositoryProvider)!;
    if (role == UserRole.employee &&
        _totals != null &&
        cashShortageRequiresAdminApproval(
          _declaredCash - _totals!.expectedCashInDrawer,
        ) &&
        !_isShiftCloseApproved) {
      try {
        await repo.enqueuePendingShiftClose(
          shiftId: _shift!.id,
          declaredCash: _declaredCash,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          expectedCash: _totals!.expectedCashInDrawer,
          difference: _declaredCash - _totals!.expectedCashInDrawer,
          cloudShiftId:
              CloudSyncService.isEnabled ? CloudSyncService.supabaseShiftId(_shift!) : null,
        );
      } on StateError catch (e) {
        if (mounted) {
          if (e.message == 'pending_shift_close_exists') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.pendingApprovalDuplicateShiftClose)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message)),
            );
          }
          setState(() => _isLoading = false);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pendingApprovalQueued)),
        );
        setState(() {
          _isLoading = false;
          _isAwaitingShiftCloseApproval = true;
          _isShiftCloseApproved = false;
          _shiftCloseApprovedAt = null;
          _shiftCloseRejectedAt = null;
          _awaitingShiftCloseId = _shift?.id;
        });
      }
      return;
    }
    try {
      final result = await repo.performCloseShift(
            shiftId: _shift!.id,
            declaredCash: _declaredCash,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (mounted) {
        await repo.clearPendingShiftCloseForShift(_shift!.id);
        try {
          // Id del nuevo turno = max(id) en Supabase + 1 (ver [PosRepository.startShift]).
          await repo.startShift(_declaredCash);
        } catch (e) {
          if (mounted) {
            setState(() {
              _closedShiftCloudIdForSummary = CloudSyncService.supabaseShiftId(_shift!);
              _result = result;
              _isLoading = false;
              _shift = null;
              _error =
                  'El corte se guardó, pero no se pudo abrir el siguiente turno: $e\n'
                  'Usa «Abrir turno» en esta pantalla cuando estés listo.';
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _closedShiftCloudIdForSummary = CloudSyncService.supabaseShiftId(_shift!);
          _result = result;
          _isLoading = false;
          _shift = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.closeShift,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (CloudSyncService.isEnabled && _shift != null && _result == null)
            IconButton(
              tooltip: l10n.reload,
              onPressed: _isLoading
                  ? null
                  : () async {
                      await _loadCurrentShift();
                    },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _showSummary
          ? _buildSummary(l10n)
          : _buildForm(l10n),
    );
  }

  Widget _buildShiftContextCard(
    AppLocalizations l10n, {
    required int localShiftId,
    required int cloudShiftId,
    DateTime? shiftStart,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              CloudSyncService.isEnabled
                  ? l10n.closeShiftTurnIdsLocalCloud(localShiftId, cloudShiftId)
                  : l10n.closeShiftTurnIdLine(localShiftId),
              style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (shiftStart != null) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.openingTime}: ${shiftStart.toLocal()}',
                style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
            if (CloudSyncService.isEnabled) ...[
              const SizedBox(height: 8),
              Text(
                l10n.closeShiftTurnIdHint,
                style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloudShiftStatus(AppLocalizations l10n, {required int localShiftId}) {
    if (!CloudSyncService.isEnabled || _result != null) {
      return const SizedBox.shrink();
    }
    final supabaseKey =
        _cloudContextSupabaseShiftKey ??
            (_shift?.id == localShiftId ? CloudSyncService.supabaseShiftId(_shift!) : localShiftId);
    final scheme = Theme.of(context).colorScheme;
    final d = _cloudDiag;
    if (d == null) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.closeShiftCloudLoading,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (d.skippedNoNetwork) {
      return _cloudStatusBox(
        l10n,
        l10n.closeShiftCloudNoNetwork,
        Icons.wifi_off_rounded,
        scheme.onSurfaceVariant,
      );
    }
    if (d.queryError != null) {
      return _cloudStatusBox(
        l10n,
        l10n.closeShiftCloudQueryError(d.queryError!),
        Icons.error_outline,
        Colors.orange.shade900,
        background: Colors.orange.shade50,
        border: Colors.orange.shade300,
      );
    }
    final row = d.rowForLocalId;
    final open = d.openForDevice;
    if (row != null && row.endTime != null) {
      return _cloudStatusBox(
        l10n,
        l10n.closeShiftCloudAlreadyClosed(row.endTime!.toLocal().toString()),
        Icons.warning_amber_rounded,
        Colors.red.shade900,
        background: Colors.red.shade50,
        border: Colors.red.shade300,
      );
    }
    if (row == null) {
      var msg = l10n.closeShiftCloudRowMissing;
      if (open != null) {
        msg =
            '${l10n.closeShiftCloudRowMissing}\n\n${l10n.closeShiftCloudOpenMismatch('$localShiftId (${l10n.supabaseIdShort}: $supabaseKey)', '${open.id}')}';
      }
      return _cloudStatusBox(
        l10n,
        msg,
        Icons.cloud_off_outlined,
        Colors.deepOrange.shade900,
        background: Colors.deepOrange.shade50,
        border: Colors.deepOrange.shade300,
      );
    }
    if (open != null && open.id != supabaseKey) {
      return _cloudStatusBox(
        l10n,
        l10n.closeShiftCloudOpenMismatch(
          '$localShiftId (${l10n.supabaseIdShort}: $supabaseKey)',
          '${open.id}',
        ),
        Icons.phonelink_setup,
        Colors.deepOrange.shade900,
        background: Colors.deepOrange.shade50,
        border: Colors.deepOrange.shade300,
      );
    }
    if (open != null && open.id == supabaseKey) {
      return _cloudStatusBox(
        l10n,
        l10n.closeShiftCloudAligned,
        Icons.check_circle_outline,
        Colors.green.shade800,
        background: Colors.green.shade50,
        border: Colors.green.shade300,
      );
    }
    return _cloudStatusBox(
      l10n,
      l10n.closeShiftCloudNoOpenForDevice,
      Icons.cloud_queue,
      scheme.onSurfaceVariant,
    );
  }

  Widget _cloudStatusBox(
    AppLocalizations l10n,
    String message,
    IconData icon,
    Color foreground, {
    Color? background,
    Color? border,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final bd = border ?? scheme.outlineVariant;
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: bd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.closeShiftCloudSectionTitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: scheme.onSurface,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOpenShiftState(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.closeShiftNoOpen,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.closeShiftNoOpenHint,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isLoading || _isLoadingShift ? null : () => _promptAndOpenShift(l10n),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(l10n.openShiftButton),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (CloudSyncService.isEnabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading || _isLoadingShift ? null : () => _continueShiftFromCloud(l10n),
              icon: const Icon(Icons.cloud_sync_outlined),
              label: Text(l10n.continueOpenShiftButton),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    final t = _totals;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: Colors.red.shade800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_isLoadingShift)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_shift == null)
            _buildNoOpenShiftState(l10n)
          else if (t == null)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else ...[
            _buildShiftContextCard(
              l10n,
              localShiftId: _shift!.id,
              cloudShiftId: CloudSyncService.supabaseShiftId(_shift!),
              shiftStart: _shift!.startTime,
            ),
            const SizedBox(height: 12),
            _buildCloudShiftStatus(l10n, localShiftId: _shift!.id),
            const SizedBox(height: 16),
            if (_cloudCancelledAppliedCount > 0) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.45),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.closeShiftCloudCancelledApplied(
                            _cloudCancelledAppliedCount,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (t.expectedCashInDrawer == 0) ...[
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '¿Reinstalaste la app?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Si no hay ventas en este turno pero sí efectivo en caja, ajusta el fondo inicial para poder hacer el corte correctamente.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAdjustStartingFundDialog(l10n),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Ajustar fondo inicial'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.expectedCashInDrawer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${t.expectedCashInDrawer.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Fondo inicial + ventas efectivo + entradas - salidas',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.enterCountedAmounts,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              decoration: InputDecoration(
                labelText: l10n.totalCashInDrawer,
                hintText: l10n.totalCashInDrawerHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _debitController,
              decoration: InputDecoration(
                labelText: l10n.salesDebit,
                hintText: l10n.cardTerminalHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _creditController,
              decoration: InputDecoration(
                labelText: l10n.salesCredit,
                hintText: l10n.cardTerminalHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.salesTransfer,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
                filled: true,
              ),
              child: Text(
                t.transferSales.toStringAsFixed(2),
                style: GoogleFonts.inter(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitToSummary,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.next,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Resumen final: mismo detalle y discrepancias. Si aún no se cerró, muestra Volver + Cerrar corte; si ya se cerró, Imprimir + Listo.
  Widget _buildSummary(AppLocalizations l10n) {
    final closed = _result != null;
    final t = _totals;
    final r = _result;

    double cashSales;
    double cardSales;
    double transferSales;
    double totalSales;
    double startingFund;
    double movementsCajaNet;
    double expectedCash;
    double declaredCash;
    double difference;

    if (r != null) {
      cashSales = r.cashSales;
      cardSales = r.cardSales;
      transferSales = r.transferSales;
      totalSales = r.totalSales;
      startingFund = r.startingFund;
      movementsCajaNet = r.movementsCajaNet;
      expectedCash = r.closure.systemExpectedCash;
      declaredCash = r.closure.declaredCash;
      difference = r.closure.difference;
    } else if (t != null) {
      cashSales = t.cashSales;
      cardSales = t.cardSales;
      transferSales = t.transferSales;
      totalSales = t.totalSales;
      startingFund = t.startingFund;
      movementsCajaNet = t.movementsCajaNet;
      expectedCash = t.expectedCashInDrawer;
      declaredCash = _declaredCash;
      difference = _declaredCash - t.expectedCashInDrawer;
    } else {
      return const Center(child: CircularProgressIndicator());
    }

    final cashBalanced = difference.abs() < 0.01;
    final cardMismatch = !closed && t != null &&
        (_declaredDebit + _declaredCredit - (t.debitSales + t.creditSales)).abs() >= 0.01;
    final isBalanced = cashBalanced && !cardMismatch;
    final bannerLocalId = _result?.closure.shiftId ?? _shift?.id;
    final bannerCloudId = _shift != null
        ? CloudSyncService.supabaseShiftId(_shift!)
        : (_closedShiftCloudIdForSummary ?? bannerLocalId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.closureSummary,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (bannerLocalId != null) ...[
            _buildShiftContextCard(
              l10n,
              localShiftId: bannerLocalId,
              cloudShiftId: bannerCloudId ?? bannerLocalId,
              shiftStart: _shift?.startTime,
            ),
            const SizedBox(height: 12),
            _buildCloudShiftStatus(l10n, localShiftId: bannerLocalId),
            const SizedBox(height: 20),
          ],
          Text(
            'Ventas por forma de pago',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: l10n.cash, value: '\$${cashSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.card, value: '\$${cardSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.transfer, value: '\$${transferSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.total, value: '\$${totalSales.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          Text(
            'Caja',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Fondo inicial', value: '\$${startingFund.toStringAsFixed(2)}'),
          _SummaryRow(
            label: l10n.movementsCajaNetLabel,
            value: movementsCajaNet >= 0
                ? '+\$${movementsCajaNet.toStringAsFixed(2)}'
                : '-\$${movementsCajaNet.abs().toStringAsFixed(2)}',
          ),
          const Divider(height: 32),
          if (!closed && t != null) ...[
            Text(
              'Cantidades declaradas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _SummaryRow(label: l10n.totalCashInDrawer, value: '\$${_declaredCash.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesDebit, value: '\$${_declaredDebit.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesCredit, value: '\$${_declaredCredit.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesTransfer, value: '\$${t.transferSales.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _SummaryRow(label: l10n.cardSalesSystem, value: '\$${(t.debitSales + t.creditSales).toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.cardDeclared, value: '\$${(_declaredDebit + _declaredCredit).toStringAsFixed(2)}'),
            if ((_declaredDebit + _declaredCredit - (t.debitSales + t.creditSales)).abs() >= 0.01) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cardMismatchTitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.cardMismatchMessage,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          _SummaryRow(label: 'Esperado en caja', value: '\$${expectedCash.toStringAsFixed(2)}'),
          _SummaryRow(label: 'Declarado (efectivo)', value: '\$${declaredCash.toStringAsFixed(2)}'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanced ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Center(
              child: Text(
                isBalanced
                    ? l10n.closureCorrect
                    : cardMismatch && cashBalanced
                        ? l10n.closureIncorrectCardOnly
                        : cardMismatch && !cashBalanced
                            ? l10n.closureIncorrectCashAndCard.replaceAll(
                                '{amount}',
                                '\$${difference.abs().toStringAsFixed(2)}',
                              )
                            : l10n.differenceInCash.replaceAll(
                                '{amount}',
                                '\$${difference.abs().toStringAsFixed(2)}',
                              ),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!closed) ...[
            const SizedBox(height: 24),
            if (_isAwaitingShiftCloseApproval) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.pendingApprovalQueued,
                        style: GoogleFonts.inter(
                          color: Colors.amber.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isShiftCloseApproved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Colors.green.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _shiftCloseApprovedAt == null
                            ? 'Aprobada por administrador. Puedes terminar el corte.'
                            : 'Aprobada por administrador (${_shiftCloseApprovedAt!.day.toString().padLeft(2, '0')}/${_shiftCloseApprovedAt!.month.toString().padLeft(2, '0')} ${_shiftCloseApprovedAt!.hour.toString().padLeft(2, '0')}:${_shiftCloseApprovedAt!.minute.toString().padLeft(2, '0')}). Puedes terminar el corte.',
                        style: GoogleFonts.inter(
                          color: Colors.green.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_shiftCloseRejectedAt != null && !_isAwaitingShiftCloseApproval && !_isShiftCloseApproved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Solicitud rechazada. Ajusta y vuelve a solicitar aprobación.',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.red.shade800, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _goBackToForm,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.goBack),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_isLoading || (_isAwaitingShiftCloseApproval && !_isShiftCloseApproved))
                        ? null
                        : _confirmCloseCut,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(l10n.closeCut),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Imprimir corte'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.done),
            ),
          ],
        ],
      ),
    );
  }
}

/// Resultado de consultar Supabase para el cierre (turno por id local vs turno abierto del dispositivo).
class _CloudCloseDiagnostics {
  const _CloudCloseDiagnostics({
    this.rowForLocalId,
    this.openForDevice,
    this.queryError,
    this.skippedNoNetwork = false,
  });

  final CloudShiftSummary? rowForLocalId;
  final CloudShiftSummary? openForDevice;
  final String? queryError;
  final bool skippedNoNetwork;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
