import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/auth_repository.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart'
    show OfflineMasterWriteException;
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/tasks/data/staff_tasks_providers.dart';
import 'package:ice_pos/src/features/tasks/domain/staff_task.dart';
import 'package:intl/intl.dart';

class StaffTasksAdminScreen extends ConsumerWidget {
  const StaffTasksAdminScreen({super.key});

  static String _fmt(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(staffTasksAdminProvider);
    final enabled = StaffTasksCloudService.isEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.staffTasksAdminTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          if (enabled)
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: l10n.staffTaskSendDueReminders,
              onPressed: () => _sendDueReminders(context, ref, l10n),
            ),
        ],
      ),
      body: !enabled
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.staffTaskCloudRequired,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16),
                ),
              ),
            )
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.staffTaskNoTasks,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(staffTasksAdminProvider);
                    await ref.read(staffTasksAdminProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return _AdminTaskTile(
                        row: row,
                        l10n: l10n,
                        onTap: () => _openEditor(
                          context,
                          ref,
                          l10n,
                          existingTask: row.task,
                          existingTemplate: row.template,
                        ),
                        onNotify: row.isActive
                            ? () => _notifyRow(context, ref, row)
                            : null,
                        onCancel: row.isActive
                            ? () => _cancelRow(context, ref, l10n, row)
                            : null,
                        onResponses: row.isActive
                            ? () => _openResponses(context, ref, l10n, row)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: enabled
          ? FloatingActionButton(
              onPressed: () => _openEditor(context, ref, l10n),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    StaffTask? existingTask,
    StaffTaskTemplate? existingTemplate,
  }) async {
    final existing = existingTask;
    final template = existingTemplate;
    final titleCtrl = TextEditingController(text: template?.title ?? existing?.title ?? '');
    final descCtrl = TextEditingController(text: template?.description ?? existing?.description ?? '');
    var scheduled = existing?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    var notify = existing?.notifyAt ?? scheduled.subtract(const Duration(minutes: 15));
    var notifyNow = false;
    var isRecurring = template != null;
    var recurrenceKind = template?.recurrenceKind ?? 'daily';
    final selectedWeekdays = <int>{
      ...(template?.weekdays ?? [1, 3, 5]),
    };
    var recurringTime = template != null
        ? _timeFromTemplate(template.scheduledTime)
        : TimeOfDay.fromDateTime(scheduled);
    var notifyMinutesBefore = template?.notifyMinutesBefore ?? 15;

    if (template != null && selectedWeekdays.isEmpty) {
      selectedWeekdays.add(1);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            existing == null && template == null ? l10n.staffTaskNew : l10n.staffTaskEdit,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: l10n.staffTaskTitleLabel),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: l10n.staffTaskDescriptionLabel),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                if (!isRecurring) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.staffTaskScheduledAt),
                    subtitle: Text(_fmt(scheduled)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: scheduled,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d == null || !ctx.mounted) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(scheduled),
                      );
                      if (t == null) return;
                      setLocal(() {
                        scheduled = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.staffTaskNotifyAt),
                    subtitle: Text(_fmt(notify)),
                    trailing: const Icon(Icons.notifications_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: notify,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d == null || !ctx.mounted) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(notify),
                      );
                      if (t == null) return;
                      setLocal(() {
                        notify = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                  ),
                ],
                if (existing == null && template == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.staffTaskNotifyNow),
                    value: notifyNow,
                    onChanged: (v) => setLocal(() => notifyNow = v ?? false),
                  ),
                if (existing == null && template == null) ...[
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repetitiva'),
                    subtitle: const Text('Genera tareas automáticamente'),
                    value: isRecurring,
                    onChanged: (v) => setLocal(() => isRecurring = v),
                  ),
                ],
                if (isRecurring) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'daily', label: Text('Cada día')),
                        ButtonSegment(value: 'weekly', label: Text('Semanal')),
                      ],
                      selected: {recurrenceKind},
                      onSelectionChanged: (s) => setLocal(() => recurrenceKind = s.first),
                    ),
                    const SizedBox(height: 8),
                    if (recurrenceKind == 'weekly')
                      Wrap(
                        spacing: 8,
                        children: [
                          (1, 'Lun'),
                          (2, 'Mar'),
                          (3, 'Mié'),
                          (4, 'Jue'),
                          (5, 'Vie'),
                          (6, 'Sáb'),
                          (7, 'Dom'),
                        ].map((e) {
                          final selected = selectedWeekdays.contains(e.$1);
                          return FilterChip(
                            label: Text(e.$2),
                            selected: selected,
                            onSelected: (_) {
                              setLocal(() {
                                if (selected) {
                                  selectedWeekdays.remove(e.$1);
                                } else {
                                  selectedWeekdays.add(e.$1);
                                }
                                if (selectedWeekdays.isEmpty) {
                                  selectedWeekdays.add(1);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hora programada'),
                      subtitle: Text(recurringTime.format(ctx)),
                      trailing: const Icon(Icons.schedule_outlined),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: recurringTime,
                        );
                        if (t == null) return;
                        setLocal(() => recurringTime = t);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text('Recordatorio (minutos antes): $notifyMinutesBefore'),
                    Slider(
                      value: notifyMinutesBefore.toDouble(),
                      min: 0,
                      max: 180,
                      divisions: 36,
                      label: '$notifyMinutesBefore',
                      onChanged: (v) => setLocal(() => notifyMinutesBefore = v.round()),
                    ),
                  ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(l10n.apply),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;

    try {
      final auth = ref.read(authRepositoryProvider);
      String? createdByUserId;
      if (SupabaseService.isInitialized) {
        createdByUserId = SupabaseService.instance.client.auth.currentUser?.id;
      }
      final createdByUsername = await auth.getCurrentUsername();

      if (template != null) {
        await StaffTasksCloudService.updateTemplate(
          id: template.id,
          title: titleCtrl.text,
          description: descCtrl.text,
          scheduledTime: TimeOfDayLike(recurringTime.hour, recurringTime.minute),
          notifyMinutesBefore: notifyMinutesBefore,
          recurrenceKind: recurrenceKind,
          weekdays: selectedWeekdays.toList()..sort(),
        );
      } else if (existing == null) {
        if (isRecurring) {
          await StaffTasksCloudService.createRecurringTemplate(
            title: titleCtrl.text,
            description: descCtrl.text,
            scheduledTime: TimeOfDayLike(recurringTime.hour, recurringTime.minute),
            notifyMinutesBefore: notifyMinutesBefore,
            recurrenceKind: recurrenceKind,
            weekdays: selectedWeekdays.toList()..sort(),
            createdByUserId: createdByUserId,
            createdByUsername: createdByUsername,
          );
        } else {
          await StaffTasksCloudService.createTask(
            title: titleCtrl.text,
            description: descCtrl.text,
            scheduledAt: scheduled,
            notifyAt: notify,
            createdByUserId: createdByUserId,
            createdByUsername: createdByUsername,
            sendNotificationNow: notifyNow,
          );
        }
      } else {
        await StaffTasksCloudService.updateTask(
          id: existing.id,
          title: titleCtrl.text,
          description: descCtrl.text,
          scheduledAt: scheduled,
          notifyAt: notify,
        );
      }
      refreshStaffTasks(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffTaskSaved)),
        );
      }
    } on OfflineMasterWriteException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineRequiresInternet)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static TimeOfDay _timeFromTemplate(String scheduledTime) {
    final parts = scheduledTime.split(':');
    final h = int.tryParse(parts.elementAtOrNull(0) ?? '9') ?? 9;
    final m = int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _recurrenceLabel(StaffTaskTemplate t) {
    final time = _timeFromTemplate(t.scheduledTime);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final at = '$hh:$mm';
    if (t.recurrenceKind == 'weekly') {
      const names = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};
      final days = t.weekdays.map((d) => names[d] ?? '$d').join(', ');
      return 'Semanal ($days) · $at';
    }
    return 'Cada día · $at';
  }

  Future<void> _cancelRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StaffTaskAdminRow row,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.staffTaskCancel),
        content: Text(row.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.staffTaskCancel),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (row.template != null) {
        await StaffTasksCloudService.cancelTemplate(row.template!.id);
      } else if (row.task != null) {
        await StaffTasksCloudService.cancelTask(row.task!.id);
      }
      refreshStaffTasks(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendDueReminders(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      final result = await StaffTasksCloudService.processDueScheduledNotifications();
      refreshStaffTasks(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.staffTaskRemindersResult(result.tasksNotified, result.pushSent),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _notifyRow(BuildContext context, WidgetRef ref, StaffTaskAdminRow row) async {
    try {
      if (row.template != null && row.task == null) {
        await StaffTasksCloudService.ensureTodayOccurrences();
        refreshStaffTasks(ref);
        if (!context.mounted) return;
        final refreshed = await ref.read(staffTasksAdminProvider.future);
        if (!context.mounted) return;
        final match = refreshed.where((r) => r.template?.id == row.template!.id).firstOrNull;
        if (match?.task == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay tarea de hoy para notificar')),
          );
          return;
        }
        await _notifyNow(context, ref, match!.task!);
        return;
      }
      if (row.task != null) {
        await _notifyNow(context, ref, row.task!);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openResponses(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StaffTaskAdminRow row,
  ) async {
    try {
      StaffTask? task = row.task;
      if (task == null && row.template != null) {
        await StaffTasksCloudService.ensureTodayOccurrences();
        refreshStaffTasks(ref);
        if (!context.mounted) return;
        final refreshed = await ref.read(staffTasksAdminProvider.future);
        if (!context.mounted) return;
        final match =
            refreshed.where((r) => r.template?.id == row.template!.id).firstOrNull;
        task = match?.task;
      }
      if (task == null || !context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.staffTaskNoResponsesYet)),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _StaffTaskResponsesSheet(
          task: task!,
          l10n: l10n,
          onChanged: () => refreshStaffTasks(ref),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _notifyNow(BuildContext context, WidgetRef ref, StaffTask task) async {
    try {
      await StaffTasksCloudService.sendTaskNotificationNow(
        taskId: task.id,
        title: task.title,
      );
      refreshStaffTasks(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(appLocalizationsProvider).staffTaskNotifyNow)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _AdminTaskTile extends StatelessWidget {
  const _AdminTaskTile({
    required this.row,
    required this.l10n,
    required this.onTap,
    this.onNotify,
    this.onCancel,
    this.onResponses,
  });

  final StaffTaskAdminRow row;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback? onNotify;
  final VoidCallback? onCancel;
  final VoidCallback? onResponses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tmpl = row.template;
    final t = row.task;
    final responses = '${l10n.staffTaskResponses}: '
        '${l10n.staffTaskStatusDone} ${row.doneCount}, '
        '${l10n.staffTaskStatusInProgress} ${row.inProgressCount}, '
        '${l10n.staffTaskMarkOmitted} ${row.skippedCount}, '
        '${l10n.staffTaskStatusPending} ${row.pendingCount}';

    final String statusLine;
    if (tmpl != null) {
      final todayPart = t != null
          ? ' · Hoy ${StaffTasksAdminScreen._fmt(t.scheduledAt)}'
          : ' · Sin ocurrencia hoy';
      statusLine = 'Repetitiva · ${StaffTasksAdminScreen._recurrenceLabel(tmpl)}$todayPart · $responses';
    } else if (t != null) {
      statusLine = t.isCancelled
          ? l10n.staffTaskCancelled
          : '${l10n.staffTaskDue}: ${StaffTasksAdminScreen._fmt(t.scheduledAt)} · $responses';
    } else {
      statusLine = responses;
    }

    return ListTile(
      onTap: onTap,
      title: Text(
        row.title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          decoration: !row.isActive ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        statusLine,
        style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'notify') onNotify?.call();
          if (v == 'cancel') onCancel?.call();
          if (v == 'responses') onResponses?.call();
        },
        itemBuilder: (ctx) => [
          if (onResponses != null)
            PopupMenuItem(
              value: 'responses',
              child: Text(l10n.staffTaskManageResponses),
            ),
          if (onNotify != null)
            PopupMenuItem(value: 'notify', child: Text(l10n.staffTaskNotifyNow)),
          if (onCancel != null)
            PopupMenuItem(value: 'cancel', child: Text(l10n.staffTaskCancel)),
        ],
      ),
    );
  }
}

class _StaffTaskResponsesSheet extends StatefulWidget {
  const _StaffTaskResponsesSheet({
    required this.task,
    required this.l10n,
    required this.onChanged,
  });

  final StaffTask task;
  final AppLocalizations l10n;
  final VoidCallback onChanged;

  @override
  State<_StaffTaskResponsesSheet> createState() => _StaffTaskResponsesSheetState();
}

class _StaffTaskResponsesSheetState extends State<_StaffTaskResponsesSheet> {
  List<StaffTaskResponseRow>? _rows;
  var _loading = true;
  var _busyUserId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await StaffTasksCloudService.fetchResponsesForTask(widget.task.id);
    if (mounted) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case StaffTaskResponseStatus.done:
        return widget.l10n.staffTaskStatusDone;
      case StaffTaskResponseStatus.skipped:
        return widget.l10n.staffTaskMarkOmitted;
      case StaffTaskResponseStatus.inProgress:
        return widget.l10n.staffTaskStatusInProgress;
      default:
        return widget.l10n.staffTaskStatusPending;
    }
  }

  Future<void> _setStatus(StaffTaskResponseRow row, String status) async {
    String? comment;
    if (status == StaffTaskResponseStatus.skipped) {
      comment = await _askOmitComment();
      if (comment == null) return;
    }
    setState(() => _busyUserId = row.userId);
    try {
      await StaffTasksCloudService.adminSetResponseStatus(
        taskId: widget.task.id,
        userId: row.userId,
        status: status,
        comment: comment,
      );
      widget.onChanged();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.staffTaskAdminStatusUpdated)),
        );
      }
    } on OfflineMasterWriteException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.offlineRequiresInternet)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyUserId = '');
    }
  }

  Future<String?> _askOmitComment() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.l10n.staffTaskMarkOmitted),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: widget.l10n.staffTaskCommentRequired,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: Text(widget.l10n.staffTaskMarkOmitted),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.staffTaskManageResponses,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.task.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows == null || _rows!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.staffTaskNoResponsesYet),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _rows!.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final row = _rows![index];
                  final busy = _busyUserId == row.userId;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.staffTaskEmployee}: ${row.displayUserLabel()}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${l10n.staffTaskAdminChangeStatus}: ${_statusLabel(row.status)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (row.comment != null && row.comment!.isNotEmpty)
                                  Text(
                                    row.comment!,
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            label: Text(l10n.staffTaskStatusPending),
                            onPressed: busy || row.isPending
                                ? null
                                : () => _setStatus(row, StaffTaskResponseStatus.pending),
                          ),
                          ActionChip(
                            label: Text(l10n.staffTaskStatusInProgress),
                            onPressed: busy || row.isInProgress
                                ? null
                                : () => _setStatus(row, StaffTaskResponseStatus.inProgress),
                          ),
                          ActionChip(
                            label: Text(l10n.staffTaskStatusDone),
                            onPressed: busy || row.isDone
                                ? null
                                : () => _setStatus(row, StaffTaskResponseStatus.done),
                          ),
                          ActionChip(
                            label: Text(l10n.staffTaskMarkOmitted),
                            onPressed: busy || row.isSkipped
                                ? null
                                : () => _setStatus(row, StaffTaskResponseStatus.skipped),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
