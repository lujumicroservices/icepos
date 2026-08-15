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



class StaffTasksMyScreen extends ConsumerWidget {

  const StaffTasksMyScreen({super.key});



  static String _fmt(DateTime dt) =>

      DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());



  static String _statusLabel(AppLocalizations l10n, StaffTaskForUser item) {
    switch (item.displayStatus) {
      case StaffTaskDisplayStatus.completed:
        return l10n.staffTaskStatusDone;
      case StaffTaskDisplayStatus.omitted:
        return l10n.staffTaskMarkOmitted;
      case StaffTaskDisplayStatus.inProgress:
        return l10n.staffTaskStatusInProgress;
      case StaffTaskDisplayStatus.pending:
        return l10n.staffTaskStatusPending;
      case StaffTaskDisplayStatus.scheduled:
        return l10n.staffTaskStatusScheduled;
    }
  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final l10n = ref.watch(appLocalizationsProvider);

    final async = ref.watch(myStaffTasksProvider);

    final enabled = StaffTasksCloudService.isEnabled;



    return Scaffold(

      appBar: AppBar(

        title: Text(

          l10n.staffTasksMyTitle,

          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),

        ),

      ),

      body: !enabled

          ? Center(

              child: Padding(

                padding: const EdgeInsets.all(24),

                child: Text(l10n.staffTaskCloudRequired, textAlign: TextAlign.center),

              ),

            )

          : async.when(

              loading: () => const Center(child: CircularProgressIndicator()),

              error: (e, _) => Center(child: Text(e.toString())),

              data: (items) {

                final sorted = [...items]

                  ..sort((a, b) {

                    int rank(StaffTaskForUser x) {
                      switch (x.displayStatus) {
                        case StaffTaskDisplayStatus.pending:
                        case StaffTaskDisplayStatus.inProgress:
                          return 0;
                        case StaffTaskDisplayStatus.scheduled:
                          return 1;
                        case StaffTaskDisplayStatus.completed:
                        case StaffTaskDisplayStatus.omitted:
                          return 2;
                      }
                    }



                    final ra = rank(a);

                    final rb = rank(b);

                    if (ra != rb) return ra.compareTo(rb);

                    return a.task.scheduledAt.compareTo(b.task.scheduledAt);

                  });



                if (sorted.isEmpty) {

                  return Center(child: Text(l10n.staffTaskNoTasks));

                }



                return RefreshIndicator(

                  onRefresh: () async {

                    ref.invalidate(myStaffTasksProvider);

                    ref.invalidate(dueStaffTasksCountProvider);

                    await ref.read(myStaffTasksProvider.future);

                  },

                  child: ListView.builder(

                    padding: const EdgeInsets.symmetric(vertical: 8),

                    itemCount: sorted.length,

                    itemBuilder: (context, index) {

                      final item = sorted[index];

                      final t = item.task;

                      final scheme = Theme.of(context).colorScheme;

                      IconData icon;

                      Color? iconColor;

                      switch (item.displayStatus) {
                        case StaffTaskDisplayStatus.completed:
                          icon = Icons.check_circle_outline;
                          iconColor = Colors.green.shade700;
                        case StaffTaskDisplayStatus.omitted:
                          icon = Icons.block;
                          iconColor = scheme.outline;
                        case StaffTaskDisplayStatus.inProgress:
                          icon = Icons.play_circle_outline;
                          iconColor = scheme.primary;
                        case StaffTaskDisplayStatus.pending:
                          icon = Icons.assignment_late_outlined;
                          iconColor = scheme.error;
                        case StaffTaskDisplayStatus.scheduled:
                          icon = Icons.schedule_outlined;
                          iconColor = scheme.tertiary;
                      }



                      return ListTile(

                        leading: Icon(icon, color: iconColor),

                        title: Text(

                          t.title,

                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),

                        ),

                        subtitle: Text(

                          [

                            _fmt(t.scheduledAt),

                            _statusLabel(l10n, item),

                            if (item.comment != null && item.comment!.isNotEmpty)

                              item.comment!,

                          ].join('\n'),

                          style: GoogleFonts.inter(

                            fontSize: 13,

                            color: scheme.onSurfaceVariant,

                          ),

                        ),

                        onTap: () => _openRespondSheet(context, ref, l10n, item),

                      );

                    },

                  ),

                );

              },

            ),

    );

  }



  Future<void> _openRespondSheet(

    BuildContext context,

    WidgetRef ref,

    AppLocalizations l10n,

    StaffTaskForUser item,

  ) async {

    final commentCtrl = TextEditingController(text: item.comment ?? '');

    final t = item.task;



    await showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      builder: (ctx) {

        return Padding(

          padding: EdgeInsets.only(

            left: 20,

            right: 20,

            top: 20,

            bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Text(

                t.title,

                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),

              ),

              if (t.description != null && t.description!.isNotEmpty) ...[

                const SizedBox(height: 8),

                Text(t.description!, style: GoogleFonts.inter(fontSize: 15)),

              ],

              const SizedBox(height: 8),

              Text(

                '${l10n.staffTaskDue}: ${_fmt(t.scheduledAt)}',

                style: GoogleFonts.inter(

                  fontSize: 14,

                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,

                ),

              ),

              const SizedBox(height: 16),

              if (t.isActive && item.isDue && !item.isDone && !item.isSkipped) ...[

                if (item.isPending)

                  FilledButton.tonalIcon(

                    onPressed: () => _respond(

                      context,

                      ref,

                      item,

                      StaffTaskResponseStatus.inProgress,

                      null,

                    ),

                    icon: const Icon(Icons.play_arrow),

                    label: Text(l10n.staffTaskMarkInProgress),

                  ),

                if (item.isPending) const SizedBox(height: 8),

                FilledButton.icon(

                  onPressed: () => _respond(

                    context,

                    ref,

                    item,

                    StaffTaskResponseStatus.done,

                    commentCtrl.text,

                  ),

                  icon: const Icon(Icons.check),

                  label: Text(l10n.staffTaskMarkDone),

                ),

                const SizedBox(height: 8),

                OutlinedButton.icon(

                  onPressed: () => _respondOmit(context, ref, item),

                  icon: const Icon(Icons.block),

                  label: Text(l10n.staffTaskMarkOmitted),

                ),

              ] else if (item.displayStatus == StaffTaskDisplayStatus.scheduled) ...[
                Text(
                  l10n.staffTaskStatusScheduled,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.staffTaskScheduledAt,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else

                Text(

                  _statusLabel(l10n, item),

                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),

                ),

              if (item.comment != null && item.comment!.isNotEmpty) ...[

                const SizedBox(height: 12),

                Text(

                  '${l10n.staffTaskComment}: ${item.comment}',

                  style: GoogleFonts.inter(fontSize: 14),

                ),

              ],

            ],

          ),

        );

      },

    );

    commentCtrl.dispose();

  }



  Future<void> _respondOmit(

    BuildContext context,

    WidgetRef ref,

    StaffTaskForUser item,

  ) async {

    final l10n = ref.read(appLocalizationsProvider);

    final ctrl = TextEditingController();

    final comment = await showDialog<String>(

      context: context,

      builder: (ctx) => AlertDialog(

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

      ),

    );

    ctrl.dispose();

    if (comment == null) return;

    await _respond(

      context,

      ref,

      item,

      StaffTaskResponseStatus.skipped,

      comment,

    );

  }



  Future<void> _respond(

    BuildContext context,

    WidgetRef ref,

    StaffTaskForUser item,

    String status,

    String? comment,

  ) async {

    final userKey = await _currentUserKey(ref);

    if (userKey == null) return;

    try {

      await StaffTasksCloudService.respondToTask(

        taskId: item.task.id,

        userId: userKey,

        status: status,

        comment: comment,

      );

      refreshStaffTasks(ref);

      if (context.mounted) {

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(_snackForStatus(ref.read(appLocalizationsProvider), status)),

          ),

        );

      }

    } on OfflineMasterWriteException {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(ref.read(appLocalizationsProvider).offlineRequiresInternet)),

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

    }

  }



  static String _snackForStatus(AppLocalizations l10n, String status) {

    switch (status) {

      case StaffTaskResponseStatus.inProgress:

        return l10n.staffTaskStatusInProgress;

      case StaffTaskResponseStatus.done:

        return l10n.staffTaskMarkDone;

      case StaffTaskResponseStatus.skipped:

        return l10n.staffTaskMarkOmitted;

      default:

        return l10n.staffTaskSaved;

    }

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

