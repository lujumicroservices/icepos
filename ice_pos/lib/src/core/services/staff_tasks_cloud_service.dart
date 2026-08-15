import 'package:flutter/foundation.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/tasks/domain/staff_task.dart';

/// CRUD de tareas de personal en Supabase.
class StaffTasksCloudService {
  StaffTasksCloudService._();

  static bool get isEnabled => SupabaseService.isInitialized;

  static DateTime? _lastOccurrenceEnsureAt;
  static Future<void>? _occurrenceEnsureInFlight;

  /// Ensures today's template occurrences exist. Throttled so repeated fetches stay fast.
  static Future<void> ensureTodayOccurrences({bool force = false}) async {
    if (!isEnabled) return;
    if (!force) {
      final last = _lastOccurrenceEnsureAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(minutes: 15)) {
        return;
      }
      if (_occurrenceEnsureInFlight != null) {
        await _occurrenceEnsureInFlight;
        return;
      }
    }
    final run = generateOccurrences(horizonDays: 1);
    _occurrenceEnsureInFlight = run;
    try {
      await run;
      _lastOccurrenceEnsureAt = DateTime.now();
    } finally {
      if (identical(_occurrenceEnsureInFlight, run)) {
        _occurrenceEnsureInFlight = null;
      }
    }
  }

  static StaffTaskTemplate _templateFromRow(Map<String, dynamic> row) {
    final rawWeekdays = row['weekdays'];
    final weekdays = rawWeekdays is List
        ? rawWeekdays.map((e) => (e as num).toInt()).toList()
        : <int>[];
    return StaffTaskTemplate(
      id: (row['id'] as num).toInt(),
      storeId: (row['store_id'] as num).toInt(),
      title: row['title'] as String? ?? '',
      description: row['description'] as String?,
      scheduledTime: row['scheduled_time'] as String? ?? '09:00:00',
      notifyMinutesBefore: (row['notify_minutes_before'] as num?)?.toInt() ?? 15,
      recurrenceKind: row['recurrence_kind'] as String? ?? 'daily',
      weekdays: weekdays,
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  static StaffTask _taskFromRow(Map<String, dynamic> row) {
    DateTime parseDt(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();
    }

    return StaffTask(
      id: (row['id'] as num).toInt(),
      storeId: (row['store_id'] as num).toInt(),
      title: row['title'] as String? ?? '',
      description: row['description'] as String?,
      scheduledAt: parseDt(row['scheduled_at']),
      notifyAt: parseDt(row['notify_at']),
      notificationSentAt: row['notification_sent_at'] == null
          ? null
          : parseDt(row['notification_sent_at']),
      createdAt: parseDt(row['created_at']),
      createdByUserId: row['created_by_user_id'] as String?,
      createdByUsername: row['created_by_username'] as String?,
      cancelledAt: row['cancelled_at'] == null
          ? null
          : parseDt(row['cancelled_at']),
      templateId: row['template_id'] == null
          ? null
          : (row['template_id'] as num).toInt(),
    );
  }

  static ({DateTime start, DateTime end}) _todayLocalBounds() {
    final now = DateTime.now();
    return (
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  /// Wall-clock local time from the device (not UTC).
  static DateTime _asLocalWallClock(DateTime dt) =>
      dt.isUtc ? dt.toLocal() : dt;

  /// Persist local wall-clock as Postgres timestamptz.
  static String _localDateTimeToStorageIso(DateTime local) =>
      _asLocalWallClock(local).toUtc().toIso8601String();

  static String _localDayStartIso(DateTime dayLocal) =>
      _localDateTimeToStorageIso(
        DateTime(dayLocal.year, dayLocal.month, dayLocal.day),
      );

  static String _localDayEndIso(DateTime dayLocal) =>
      _localDateTimeToStorageIso(
        DateTime(dayLocal.year, dayLocal.month, dayLocal.day, 23, 59, 59, 999),
      );

  /// Dart [DateTime.timeZoneOffset] for edge/cron (minutes east of UTC; Mexico ≈ -360).
  static int get deviceTimeZoneOffsetMinutes =>
      DateTime.now().timeZoneOffset.inMinutes;

  static ({DateTime scheduledAt, DateTime notifyAt}) _occurrenceTimesFromTemplate({
    required DateTime dayLocal,
    required String scheduledTime,
    required int notifyMinutesBefore,
  }) {
    final parts = scheduledTime.split(':');
    final h = int.tryParse(parts.elementAtOrNull(0) ?? '9') ?? 9;
    final m = int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0;
    final scheduledAt = DateTime(dayLocal.year, dayLocal.month, dayLocal.day, h, m);
    final notifyAt = scheduledAt.subtract(Duration(minutes: notifyMinutesBefore));
    return (scheduledAt: scheduledAt, notifyAt: notifyAt);
  }

  static Future<Map<int, ({int done, int skipped, int pending, int inProgress})>>
      _responseCountsForTaskIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return {};
    final respRes = await SupabaseService.instance.client
        .from('staff_task_responses')
        .select('task_id, status')
        .inFilter('task_id', ids);
    final counts = <int, ({int done, int skipped, int pending, int inProgress})>{};
    for (final id in ids) {
      counts[id] = (done: 0, skipped: 0, pending: 0, inProgress: 0);
    }
    for (final e in respRes as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final tid = (m['task_id'] as num).toInt();
      final st = m['status'] as String? ?? 'pending';
      final c = counts[tid];
      if (c == null) continue;
      switch (st) {
        case 'done':
          counts[tid] = (
            done: c.done + 1,
            skipped: c.skipped,
            pending: c.pending,
            inProgress: c.inProgress,
          );
        case 'skipped':
          counts[tid] = (
            done: c.done,
            skipped: c.skipped + 1,
            pending: c.pending,
            inProgress: c.inProgress,
          );
        case 'in_progress':
          counts[tid] = (
            done: c.done,
            skipped: c.skipped,
            pending: c.pending,
            inProgress: c.inProgress + 1,
          );
        default:
          counts[tid] = (
            done: c.done,
            skipped: c.skipped,
            pending: c.pending + 1,
            inProgress: c.inProgress,
          );
      }
    }
    return counts;
  }

  /// Admin: plantillas repetitivas (1 fila c/u) + tareas puntuales (sin plantilla).
  static Future<List<StaffTaskAdminRow>> fetchAdminTasks({int? storeId}) async {
    if (!isEnabled) return [];
    final sid = storeId ?? await StoreScope.getActiveStoreId();
    final client = SupabaseService.instance.client;
    final today = _todayLocalBounds();
    final todayStart = _localDayStartIso(today.start);
    final todayEnd = _localDayEndIso(today.end);

    final results = await Future.wait([
      client
          .from('staff_task_templates')
          .select()
          .eq('store_id', sid)
          .eq('is_active', true)
          .order('id', ascending: false)
          .limit(100),
      client
          .from('staff_tasks')
          .select()
          .eq('store_id', sid)
          .isFilter('template_id', null)
          .isFilter('cancelled_at', null)
          .order('scheduled_at', ascending: false)
          .limit(100),
      client
          .from('staff_tasks')
          .select()
          .eq('store_id', sid)
          .not('template_id', 'is', null)
          .isFilter('cancelled_at', null)
          .gte('scheduled_at', todayStart)
          .lte('scheduled_at', todayEnd),
    ]);

    final templates = (results[0] as List<dynamic>)
        .map((e) => _templateFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    final oneOffs = (results[1] as List<dynamic>)
        .map((e) => _taskFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    final todayOccRows = (results[2] as List<dynamic>)
        .map((e) => _taskFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();

    final occByTemplateId = <int, StaffTask>{};
    for (final occ in todayOccRows) {
      final tid = occ.templateId;
      if (tid == null) continue;
      occByTemplateId.putIfAbsent(tid, () => occ);
    }

    final todayOccurrenceIds = occByTemplateId.values.map((t) => t.id).toList();
    final oneOffIds = oneOffs.map((t) => t.id).toList();
    final counts = await _responseCountsForTaskIds([
      ...todayOccurrenceIds,
      ...oneOffIds,
    ]);

    final rows = <StaffTaskAdminRow>[];
    for (final tmpl in templates) {
      final occ = occByTemplateId[tmpl.id];
      final c = occ == null ? null : counts[occ.id];
      rows.add(
        StaffTaskAdminRow(
          template: tmpl,
          task: occ,
          doneCount: c?.done ?? 0,
          skippedCount: c?.skipped ?? 0,
          pendingCount: c?.pending ?? 0,
          inProgressCount: c?.inProgress ?? 0,
        ),
      );
    }

    for (final t in oneOffs) {
      final c = counts[t.id];
      rows.add(
        StaffTaskAdminRow(
          task: t,
          doneCount: c?.done ?? 0,
          skippedCount: c?.skipped ?? 0,
          pendingCount: c?.pending ?? 0,
          inProgressCount: c?.inProgress ?? 0,
        ),
      );
    }

    return rows;
  }

  /// Tareas de hoy para el empleado (con su estado).
  static Future<List<StaffTaskForUser>> fetchTasksForUser({
    required String userId,
    int? storeId,
  }) async {
    if (!isEnabled) return [];
    final sid = storeId ?? await StoreScope.getActiveStoreId();
    final client = SupabaseService.instance.client;
    final today = _todayLocalBounds();
    final tasksRes = await client
        .from('staff_tasks')
        .select()
        .eq('store_id', sid)
        .isFilter('cancelled_at', null)
        .gte('scheduled_at', _localDayStartIso(today.start))
        .lte('scheduled_at', _localDayEndIso(today.end))
        .order('scheduled_at', ascending: true)
        .limit(100);
    final tasks = (tasksRes as List<dynamic>)
        .map((e) => _taskFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (tasks.isEmpty) return [];

    final ids = tasks.map((t) => t.id).toList();
    final respRes = await client
        .from('staff_task_responses')
        .select()
        .eq('user_id', userId)
        .inFilter('task_id', ids);
    final byTask = <int, Map<String, dynamic>>{};
    for (final e in respRes as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      byTask[(m['task_id'] as num).toInt()] = m;
    }

    return tasks.map((t) {
      final r = byTask[t.id];
      final status = r?['status'] as String? ?? 'pending';
      final respondedAt = r?['responded_at'];
      return StaffTaskForUser(
        task: t,
        responseStatus: status,
        comment: r?['comment'] as String?,
        respondedAt: respondedAt == null
            ? null
            : DateTime.tryParse(respondedAt.toString())?.toLocal(),
      );
    }).toList();
  }

  static Future<int> countDuePendingForUser({
    required String userId,
    int? storeId,
  }) async {
    if (!isEnabled) return 0;
    final sid = storeId ?? await StoreScope.getActiveStoreId();
    final client = SupabaseService.instance.client;
    final today = _todayLocalBounds();
    final now = DateTime.now();

    final tasksRes = await client
        .from('staff_tasks')
        .select('id, scheduled_at')
        .eq('store_id', sid)
        .isFilter('cancelled_at', null)
        .gte('scheduled_at', _localDayStartIso(today.start))
        .lte('scheduled_at', _localDayEndIso(today.end));

    final dueTaskIds = <int>[];
    for (final e in tasksRes as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final scheduledAt =
          DateTime.tryParse(m['scheduled_at']?.toString() ?? '')?.toLocal();
      if (scheduledAt == null || now.isBefore(scheduledAt)) continue;
      dueTaskIds.add((m['id'] as num).toInt());
    }
    if (dueTaskIds.isEmpty) return 0;

    final respRes = await client
        .from('staff_task_responses')
        .select('task_id, status')
        .eq('user_id', userId)
        .inFilter('task_id', dueTaskIds);

    final finished = <int>{};
    for (final e in respRes as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final status = m['status'] as String? ?? 'pending';
      if (status == 'done' || status == 'skipped') {
        finished.add((m['task_id'] as num).toInt());
      }
    }

    return dueTaskIds.where((id) => !finished.contains(id)).length;
  }

  static Future<int> createTask({
    required String title,
    String? description,
    required DateTime scheduledAt,
    required DateTime notifyAt,
    String? createdByUserId,
    String? createdByUsername,
    bool sendNotificationNow = false,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) throw StateError('Supabase no configurado');
    final storeId = await StoreScope.getActiveStoreId();
    final client = SupabaseService.instance.client;
    final row = await client
        .from('staff_tasks')
        .insert({
          'store_id': storeId,
          'title': title.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description!.trim(),
          'scheduled_at': _localDateTimeToStorageIso(scheduledAt),
          'notify_at': _localDateTimeToStorageIso(notifyAt),
          'created_by_user_id': createdByUserId,
          'created_by_username': createdByUsername,
        })
        .select('id')
        .single();
    final taskId = (row['id'] as num).toInt();
    // Notify team every time a task is created (FCM + web push).
    // Only set notification_sent_at when this push fulfills the scheduled reminder
    // (otherwise notify-due-staff-tasks must still fire at notify_at).
    final now = DateTime.now();
    final reminderDue = sendNotificationNow || !notifyAt.isAfter(now);
    await _invokeNotifyEdge(
      storeId: storeId,
      taskId: taskId,
      title: title.trim(),
      markReminderDelivered: reminderDue,
    );
    return taskId;
  }

  static Future<void> updateTask({
    required int id,
    required String title,
    String? description,
    required DateTime scheduledAt,
    required DateTime notifyAt,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) return;
    await SupabaseService.instance.client.from('staff_tasks').update({
      'title': title.trim(),
      'description': description?.trim().isEmpty == true ? null : description!.trim(),
      'scheduled_at': _localDateTimeToStorageIso(scheduledAt),
      'notify_at': _localDateTimeToStorageIso(notifyAt),
    }).eq('id', id);
  }

  static Future<void> cancelTask(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) return;
    await SupabaseService.instance.client.from('staff_tasks').update({
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> cancelTemplate(int id) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) return;
    await SupabaseService.instance.client.from('staff_task_templates').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateTemplate({
    required int id,
    required String title,
    String? description,
    required TimeOfDayLike scheduledTime,
    required int notifyMinutesBefore,
    required String recurrenceKind,
    required List<int> weekdays,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) return;
    final hh = scheduledTime.hour.toString().padLeft(2, '0');
    final mm = scheduledTime.minute.toString().padLeft(2, '0');
    final client = SupabaseService.instance.client;
    await client.from('staff_task_templates').update({
      'title': title.trim(),
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'scheduled_time': '$hh:$mm:00',
      'notify_minutes_before': notifyMinutesBefore,
      'recurrence_kind': recurrenceKind,
      'weekdays': recurrenceKind == 'weekly' ? weekdays : <int>[],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);

    final today = _todayLocalBounds();
    final todayTimes = _occurrenceTimesFromTemplate(
      dayLocal: today.start,
      scheduledTime: '$hh:$mm:00',
      notifyMinutesBefore: notifyMinutesBefore,
    );
    await client
        .from('staff_tasks')
        .update({
          'title': title.trim(),
          'description': description?.trim().isEmpty == true ? null : description?.trim(),
          'scheduled_at': _localDateTimeToStorageIso(todayTimes.scheduledAt),
          'notify_at': _localDateTimeToStorageIso(todayTimes.notifyAt),
        })
        .eq('template_id', id)
        .isFilter('cancelled_at', null)
        .gte('scheduled_at', _localDayStartIso(today.start))
        .lte('scheduled_at', _localDayEndIso(today.end));

    await ensureTodayOccurrences(force: true);
  }

  static Future<void> respondToTask({
    required int taskId,
    required String userId,
    required String status,
    String? comment,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) return;
    const allowed = {
      StaffTaskResponseStatus.pending,
      StaffTaskResponseStatus.inProgress,
      StaffTaskResponseStatus.done,
      StaffTaskResponseStatus.skipped,
    };
    if (!allowed.contains(status)) {
      throw ArgumentError('status must be pending, in_progress, done, or skipped');
    }
    if (status == StaffTaskResponseStatus.skipped &&
        (comment == null || comment.trim().isEmpty)) {
      throw ArgumentError('comment required when omitting a task');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.instance.client.from('staff_task_responses').upsert(
      {
        'task_id': taskId,
        'user_id': userId,
        'status': status,
        'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
        'responded_at': status == StaffTaskResponseStatus.pending ? null : now,
        'updated_at': now,
      },
      onConflict: 'task_id,user_id',
    );
  }

  static StaffTaskResponseRow _responseFromRow(Map<String, dynamic> row) {
    DateTime? respondedAt;
    final raw = row['responded_at'];
    if (raw != null) {
      respondedAt = DateTime.tryParse(raw.toString())?.toLocal();
    }
    return StaffTaskResponseRow(
      taskId: (row['task_id'] as num).toInt(),
      userId: row['user_id'] as String? ?? '',
      status: row['status'] as String? ?? StaffTaskResponseStatus.pending,
      comment: row['comment'] as String?,
      respondedAt: respondedAt,
    );
  }

  static Future<List<StaffTaskResponseRow>> fetchResponsesForTask(int taskId) async {
    if (!isEnabled) return [];
    final rows = await SupabaseService.instance.client
        .from('staff_task_responses')
        .select()
        .eq('task_id', taskId)
        .order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => _responseFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Admin: cambia el estado de un empleado y opcionalmente reenvía avisos.
  static Future<void> adminSetResponseStatus({
    required int taskId,
    required String userId,
    required String status,
    String? comment,
    bool resendNotification = true,
  }) async {
    if (!isEnabled) return;

    final existing = await fetchResponsesForTask(taskId);
    final prior = existing.where((r) => r.userId == userId).firstOrNull;
    final priorStatus = prior?.status ?? StaffTaskResponseStatus.pending;

    await respondToTask(
      taskId: taskId,
      userId: userId,
      status: status,
      comment: status == StaffTaskResponseStatus.pending ? null : comment,
    );

    final reopened = _isReopenedStatusChange(from: priorStatus, to: status);
    if (!reopened) return;

    await SupabaseService.instance.client.from('staff_tasks').update({
      'notification_sent_at': null,
    }).eq('id', taskId);

    if (!resendNotification) return;

    final taskRes = await SupabaseService.instance.client
        .from('staff_tasks')
        .select('title')
        .eq('id', taskId)
        .maybeSingle();
    if (taskRes == null) return;
    final title = Map<String, dynamic>.from(taskRes as Map)['title'] as String? ?? 'Tarea';
    await sendTaskNotificationNow(taskId: taskId, title: title);
  }

  static bool _isReopenedStatusChange({required String from, required String to}) {
    const terminal = {StaffTaskResponseStatus.done, StaffTaskResponseStatus.skipped};
    const actionable = {
      StaffTaskResponseStatus.pending,
      StaffTaskResponseStatus.inProgress,
    };
    if (!actionable.contains(to)) return false;
    return terminal.contains(from) ||
        (from == StaffTaskResponseStatus.inProgress &&
            to == StaffTaskResponseStatus.pending);
  }

  static Future<void> sendTaskNotificationNow({
    required int taskId,
    required String title,
  }) async {
    if (!isEnabled) return;
    final storeId = await StoreScope.getActiveStoreId();
    await _invokeNotifyEdge(
      storeId: storeId,
      taskId: taskId,
      title: title,
      markReminderDelivered: true,
    );
  }

  /// Invoca la edge function que envía push de tareas con `notify_at` ya vencido.
  static Future<({int tasksNotified, int pushSent})> processDueScheduledNotifications() async {
    if (!isEnabled) return (tasksNotified: 0, pushSent: 0);
    try {
      final res = await SupabaseService.instance.client.functions.invoke(
        'notify-due-staff-tasks',
        body: <String, dynamic>{},
      );
      final data = res.data;
      if (data is Map) {
        final web = (data['web_sent'] as num?)?.toInt() ?? 0;
        final fcm = (data['fcm_sent'] as num?)?.toInt() ?? 0;
        final legacy = (data['push_sent'] as num?)?.toInt() ?? 0;
        return (
          tasksNotified: (data['tasks_notified'] as num?)?.toInt() ?? 0,
          pushSent: web + fcm + legacy,
        );
      }
    } catch (e, st) {
      debugPrint('StaffTasksCloudService.processDue: $e');
      debugPrint('$st');
    }
    return (tasksNotified: 0, pushSent: 0);
  }

  static Future<void> _invokeNotifyEdge({
    required int storeId,
    required int taskId,
    required String title,
    bool markReminderDelivered = true,
  }) async {
    try {
      await SupabaseService.instance.client.functions.invoke(
        'notify-staff-task',
        body: {
          'store_id': storeId,
          'task_id': taskId,
          'title': title,
        },
      );
      if (markReminderDelivered) {
        await SupabaseService.instance.client.from('staff_tasks').update({
          'notification_sent_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', taskId);
      }
    } catch (e, st) {
      debugPrint('StaffTasksCloudService.notify: $e');
      debugPrint('$st');
    }
  }

  static Future<List<StaffTaskTemplate>> fetchTemplates({int? storeId}) async {
    if (!isEnabled) return [];
    final sid = storeId ?? await StoreScope.getActiveStoreId();
    final rows = await SupabaseService.instance.client
        .from('staff_task_templates')
        .select()
        .eq('store_id', sid)
        .order('id', ascending: false)
        .limit(200);
    return (rows as List<dynamic>)
        .map((e) => _templateFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<int> createRecurringTemplate({
    required String title,
    String? description,
    required TimeOfDayLike scheduledTime,
    required int notifyMinutesBefore,
    required String recurrenceKind, // daily|weekly
    required List<int> weekdays,
    String? createdByUserId,
    String? createdByUsername,
  }) async {
    OfflineWritePolicy.requireOnlineForMasterWrite();
    if (!isEnabled) throw StateError('Supabase no configurado');
    final storeId = await StoreScope.getActiveStoreId();
    final hh = scheduledTime.hour.toString().padLeft(2, '0');
    final mm = scheduledTime.minute.toString().padLeft(2, '0');
    final row = await SupabaseService.instance.client
        .from('staff_task_templates')
        .insert({
          'store_id': storeId,
          'title': title.trim(),
          'description': description?.trim().isEmpty == true ? null : description?.trim(),
          'scheduled_time': '$hh:$mm:00',
          'notify_minutes_before': notifyMinutesBefore,
          'recurrence_kind': recurrenceKind,
          'weekdays': recurrenceKind == 'weekly' ? weekdays : <int>[],
          'created_by_user_id': createdByUserId,
          'created_by_username': createdByUsername,
        })
        .select('id')
        .single();
    final templateId = (row['id'] as num).toInt();
    await ensureTodayOccurrences(force: true);
    return templateId;
  }

  static Future<void> generateOccurrences({int horizonDays = 1}) async {
    if (!isEnabled) return;
    // Always generate on-device so scheduled_time uses local wall-clock, not UTC edge server.
    await _generateOccurrencesClientSide(horizonDays: horizonDays);
  }

  /// Fallback when the edge function is unavailable (web CORS, not deployed, etc.).
  static Future<void> _generateOccurrencesClientSide({required int horizonDays}) async {
    final client = SupabaseService.instance.client;
    final sid = await StoreScope.getActiveStoreId();
    final templates = await fetchTemplates(storeId: sid);
    final active = templates.where((t) => t.isActive).toList();
    if (active.isEmpty) return;

    final today = DateTime.now();
    final day0 = DateTime(today.year, today.month, today.day);
    final horizon = horizonDays.clamp(1, 60);
    final lastDay = day0.add(Duration(days: horizon - 1));
    final rangeStartUtc = _localDayStartIso(day0);
    final rangeEndUtc = _localDayEndIso(lastDay);

    final existingRes = await client
        .from('staff_tasks')
        .select('template_id, scheduled_at')
        .eq('store_id', sid)
        .not('template_id', 'is', null)
        .isFilter('cancelled_at', null)
        .gte('scheduled_at', rangeStartUtc)
        .lte('scheduled_at', rangeEndUtc);

    final existingKeys = <String>{};
    for (final e in existingRes as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final tid = m['template_id'] as num?;
      final scheduledAt =
          DateTime.tryParse(m['scheduled_at']?.toString() ?? '')?.toLocal();
      if (tid == null || scheduledAt == null) continue;
      existingKeys.add('${tid.toInt()}_${scheduledAt.year}'
          '${scheduledAt.month}${scheduledAt.day}');
    }

    final toInsert = <Map<String, dynamic>>[];
    for (final t in active) {
      for (var i = 0; i < horizon; i++) {
        final day = day0.add(Duration(days: i));
        final match = t.recurrenceKind == 'daily' ||
            (t.recurrenceKind == 'weekly' && t.weekdays.contains(day.weekday));
        if (!match) continue;

        final times = _occurrenceTimesFromTemplate(
          dayLocal: day,
          scheduledTime: t.scheduledTime,
          notifyMinutesBefore: t.notifyMinutesBefore,
        );

        // Keep today's occurrence aligned with template local time (fixes legacy UTC rows).
        if (i == 0) {
          await client
              .from('staff_tasks')
              .update({
                'scheduled_at': _localDateTimeToStorageIso(times.scheduledAt),
                'notify_at': _localDateTimeToStorageIso(times.notifyAt),
              })
              .eq('store_id', sid)
              .eq('template_id', t.id)
              .isFilter('cancelled_at', null)
              .gte('scheduled_at', _localDayStartIso(day))
              .lte('scheduled_at', _localDayEndIso(day));
        }

        final key = '${t.id}_${day.year}${day.month}${day.day}';
        if (existingKeys.contains(key)) continue;

        toInsert.add({
          'store_id': t.storeId,
          'title': t.title,
          'description': t.description,
          'scheduled_at': _localDateTimeToStorageIso(times.scheduledAt),
          'notify_at': _localDateTimeToStorageIso(times.notifyAt),
          'created_by_user_id': null,
          'created_by_username': null,
          'template_id': t.id,
        });
        existingKeys.add(key);
      }
    }

    if (toInsert.isEmpty) return;
    await client.from('staff_tasks').insert(toInsert);
  }
}

class TimeOfDayLike {
  const TimeOfDayLike(this.hour, this.minute);
  final int hour;
  final int minute;
}
