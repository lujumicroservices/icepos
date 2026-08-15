/// Tarea programada para personal (nube).
class StaffTask {
  const StaffTask({
    required this.id,
    required this.storeId,
    required this.title,
    this.description,
    required this.scheduledAt,
    required this.notifyAt,
    this.notificationSentAt,
    required this.createdAt,
    this.createdByUserId,
    this.createdByUsername,
    this.cancelledAt,
    this.templateId,
  });

  final int id;
  final int storeId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final DateTime notifyAt;
  final DateTime? notificationSentAt;
  final DateTime createdAt;
  final String? createdByUserId;
  final String? createdByUsername;
  final DateTime? cancelledAt;
  /// Set when this row was generated from [StaffTaskTemplate].
  final int? templateId;

  bool get isCancelled => cancelledAt != null;
  bool get isActive => !isCancelled;
}

/// Estados de respuesta del empleado a una tarea.
abstract final class StaffTaskResponseStatus {
  static const pending = 'pending';
  static const inProgress = 'in_progress';
  static const done = 'done';
  static const skipped = 'skipped';
}

/// Tarea con la respuesta del usuario actual (vista empleado).
class StaffTaskForUser {
  const StaffTaskForUser({
    required this.task,
    required this.responseStatus,
    this.comment,
    this.respondedAt,
  });

  final StaffTask task;
  /// pending | in_progress | done | skipped
  final String responseStatus;
  final String? comment;
  final DateTime? respondedAt;

  bool get isPending => responseStatus == StaffTaskResponseStatus.pending;
  bool get isInProgress => responseStatus == StaffTaskResponseStatus.inProgress;
  bool get isDone => responseStatus == StaffTaskResponseStatus.done;
  bool get isSkipped => responseStatus == StaffTaskResponseStatus.skipped;

  bool get isDue => !task.isCancelled && !DateTime.now().isBefore(task.scheduledAt);

  /// Hoy pero aún no llega la hora programada.
  bool get isScheduled => task.isActive && isPending && !isDue;

  /// Pendiente o en progreso y ya venció la hora programada.
  bool get needsAttention =>
      task.isActive && isDue && (isPending || isInProgress);

  /// Estado mostrado al empleado (incluye programada antes de vencer).
  StaffTaskDisplayStatus get displayStatus {
    if (isDone) return StaffTaskDisplayStatus.completed;
    if (isSkipped) return StaffTaskDisplayStatus.omitted;
    if (isInProgress) return StaffTaskDisplayStatus.inProgress;
    if (isDue) return StaffTaskDisplayStatus.pending;
    return StaffTaskDisplayStatus.scheduled;
  }
}

/// Estado visual de una tarea para el empleado.
enum StaffTaskDisplayStatus {
  scheduled,
  pending,
  inProgress,
  completed,
  omitted,
}

/// Resumen para admin (conteos de respuestas).
class StaffTaskAdminRow {
  const StaffTaskAdminRow({
    this.task,
    this.template,
    required this.doneCount,
    required this.skippedCount,
    required this.pendingCount,
    required this.inProgressCount,
  }) : assert(task != null || template != null);

  /// Ocurrencia puntual o la de hoy para una plantilla repetitiva.
  final StaffTask? task;
  /// Configuración repetitiva (una fila en admin aunque sea diaria).
  final StaffTaskTemplate? template;
  final int doneCount;
  final int skippedCount;
  final int pendingCount;
  final int inProgressCount;

  bool get isRecurring => template != null;

  String get title => template?.title ?? task!.title;

  String? get description => template?.description ?? task?.description;

  bool get isActive => template?.isActive ?? task!.isActive;
}

/// Respuesta de un empleado a una ocurrencia de tarea (admin).
class StaffTaskResponseRow {
  const StaffTaskResponseRow({
    required this.taskId,
    required this.userId,
    required this.status,
    this.comment,
    this.respondedAt,
  });

  final int taskId;
  final String userId;
  final String status;
  final String? comment;
  final DateTime? respondedAt;

  bool get isPending => status == StaffTaskResponseStatus.pending;
  bool get isInProgress => status == StaffTaskResponseStatus.inProgress;
  bool get isDone => status == StaffTaskResponseStatus.done;
  bool get isSkipped => status == StaffTaskResponseStatus.skipped;

  String displayUserLabel() {
    if (userId.startsWith('local:')) return userId.substring(6);
    if (userId.length <= 12) return userId;
    return '${userId.substring(0, 8)}…';
  }
}

/// Plantilla de tarea repetitiva (genera ocurrencias en staff_tasks).
class StaffTaskTemplate {
  const StaffTaskTemplate({
    required this.id,
    required this.storeId,
    required this.title,
    this.description,
    required this.scheduledTime, // HH:mm:ss
    required this.notifyMinutesBefore,
    required this.recurrenceKind, // daily | weekly
    required this.weekdays, // 1..7 (Mon..Sun)
    required this.isActive,
  });

  final int id;
  final int storeId;
  final String title;
  final String? description;
  final String scheduledTime;
  final int notifyMinutesBefore;
  final String recurrenceKind;
  final List<int> weekdays;
  final bool isActive;
}
