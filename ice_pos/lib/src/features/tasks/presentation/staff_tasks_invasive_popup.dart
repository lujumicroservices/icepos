import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/auth_repository.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart'
    show OfflineMasterWriteException;
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/tasks/data/staff_tasks_providers.dart';
import 'package:ice_pos/src/features/tasks/domain/staff_task.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kInvasiveSnoozeKey = 'staff_tasks_invasive_snoozed_until_ms';
const _snoozeDuration = Duration(minutes: 15);

/// Popup invasivo en pantalla principal: tareas pendientes/en progreso del empleado.
class StaffTasksInvasivePopup extends ConsumerStatefulWidget {
  const StaffTasksInvasivePopup({super.key});

  @override
  ConsumerState<StaffTasksInvasivePopup> createState() =>
      _StaffTasksInvasivePopupState();
}

class _StaffTasksInvasivePopupState extends ConsumerState<StaffTasksInvasivePopup> {
  DateTime? _snoozedUntil;
  Timer? _snoozeTimer;
  var _busyTaskId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSnooze());
    _snoozeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final until = _snoozedUntil;
      if (until != null && !DateTime.now().isBefore(until)) {
        setState(() => _snoozedUntil = null);
      }
    });
  }

  @override
  void dispose() {
    _snoozeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kInvasiveSnoozeKey);
    if (ms == null) return;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (DateTime.now().isBefore(until) && mounted) {
      setState(() => _snoozedUntil = until);
    } else {
      await prefs.remove(_kInvasiveSnoozeKey);
    }
  }

  Future<void> _snooze() async {
    final until = DateTime.now().add(_snoozeDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kInvasiveSnoozeKey, until.millisecondsSinceEpoch);
    closeStaffTasksInvasivePopup(ref);
    if (mounted) setState(() => _snoozedUntil = until);
  }

  bool get _isSnoozed {
    final until = _snoozedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  @override
  Widget build(BuildContext context) {
    if (!StaffTasksCloudService.isEnabled) {
      return const SizedBox.shrink();
    }

    if (kIsWeb && ref.watch(userRoleProvider) == UserRole.admin) {
      return const SizedBox.shrink();
    }

    final forceOpen = ref.watch(staffTasksInvasiveOpenProvider);
    if (_isSnoozed && !forceOpen) {
      return const SizedBox.shrink();
    }

    ref.watch(staffTasksRefreshProvider);
    ref.watch(staffTasksDueRefreshProvider);

    final async = ref.watch(myStaffTasksProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final actionable = items.where((t) => t.needsAttention).toList()
          ..sort((a, b) => a.task.scheduledAt.compareTo(b.task.scheduledAt));
        if (actionable.isEmpty) {
          if (forceOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) closeStaffTasksInvasivePopup(ref);
            });
          }
          return const SizedBox.shrink();
        }

        final l10n = ref.watch(appLocalizationsProvider);
        final scheme = Theme.of(context).colorScheme;

        return Material(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
                child: Card(
                  margin: const EdgeInsets.all(20),
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        color: scheme.errorContainer,
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_late,
                              color: scheme.onErrorContainer,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.staffTaskInvasiveTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                  Text(
                                    l10n.staffTaskInvasiveSubtitle(actionable.length),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: actionable.length,
                          separatorBuilder: (_, _) => const Divider(height: 20),
                          itemBuilder: (context, index) {
                            return _TaskActionCard(
                              item: actionable[index],
                              l10n: l10n,
                              busy: _busyTaskId == actionable[index].task.id,
                              onRespond: (status) => _respond(
                                context,
                                actionable[index],
                                status,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _snooze,
                            icon: const Icon(Icons.snooze),
                            label: Text(l10n.staffTaskInvasiveDismiss),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _respond(
    BuildContext context,
    StaffTaskForUser item,
    String status,
  ) async {
    String? comment;
    if (status == StaffTaskResponseStatus.skipped) {
      comment = await _askOmitComment(context);
      if (comment == null) return;
    }

    final userKey = await _currentUserKey(ref);
    if (userKey == null || !mounted) return;

    setState(() => _busyTaskId = item.task.id);
    try {
      await StaffTasksCloudService.respondToTask(
        taskId: item.task.id,
        userId: userKey,
        status: status,
        comment: comment,
      );
      refreshStaffTasks(ref);
    } on OfflineMasterWriteException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(appLocalizationsProvider).offlineRequiresInternet),
          ),
        );
      }
    } on ArgumentError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.toString())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyTaskId = 0);
    }
  }

  Future<String?> _askOmitComment(BuildContext context) async {
    final l10n = ref.read(appLocalizationsProvider);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.staffTaskMarkOmitted),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: l10n.staffTaskCommentRequired,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: Text(l10n.staffTaskMarkOmitted),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }
}

class _TaskActionCard extends StatelessWidget {
  const _TaskActionCard({
    required this.item,
    required this.l10n,
    required this.busy,
    required this.onRespond,
  });

  final StaffTaskForUser item;
  final AppLocalizations l10n;
  final bool busy;
  final ValueChanged<String> onRespond;

  static String _fmt(DateTime dt) =>
      DateFormat('HH:mm').format(dt.toLocal());

  String _statusLabel() {
    switch (item.displayStatus) {
      case StaffTaskDisplayStatus.inProgress:
        return l10n.staffTaskStatusInProgress;
      case StaffTaskDisplayStatus.pending:
        return l10n.staffTaskStatusPending;
      case StaffTaskDisplayStatus.scheduled:
      case StaffTaskDisplayStatus.completed:
      case StaffTaskDisplayStatus.omitted:
        return l10n.staffTaskStatusScheduled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (t.description != null && t.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.description!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.staffTaskDue}: ${_fmt(t.scheduledAt)} · ${_statusLabel()}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (item.isPending)
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => onRespond(StaffTaskResponseStatus.inProgress),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l10n.staffTaskMarkInProgress),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onRespond(StaffTaskResponseStatus.done),
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.staffTaskMarkDone),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => onRespond(StaffTaskResponseStatus.skipped),
              icon: const Icon(Icons.block, size: 18),
              label: Text(l10n.staffTaskMarkOmitted),
            ),
          ],
        ),
      ],
    );
  }
}

Future<String?> _currentUserKey(WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  if (SupabaseService.isInitialized) {
    final uid = SupabaseService.instance.client.auth.currentUser?.id;
    if (uid != null) return uid;
  }
  final username = await auth.getCurrentUsername();
  if (username != null && username.isNotEmpty) return 'local:$username';
  final id = await auth.getCurrentUserId();
  if (id is int) return 'local:$id';
  if (id is String) return id;
  return null;
}
