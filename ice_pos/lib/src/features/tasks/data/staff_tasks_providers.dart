import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:ice_pos/src/core/auth/auth_repository.dart';
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/tasks/domain/staff_task.dart';

/// Invalidates admin + my task lists (e.g. after create, edit, respond).
final staffTasksRefreshProvider = StateProvider<int>((ref) => 0);

/// Invalidates due-count badge only (lighter than reloading full lists).
final staffTasksDueRefreshProvider = StateProvider<int>((ref) => 0);

void refreshStaffTasks(WidgetRef ref) {
  ref.read(staffTasksRefreshProvider.notifier).state++;
  ref.read(staffTasksDueRefreshProvider.notifier).state++;
}

/// Abre el popup invasivo de tareas (p. ej. tras posponer o desde el icono de aviso).
final staffTasksInvasiveOpenProvider = StateProvider<bool>((ref) => false);

void openStaffTasksInvasivePopup(WidgetRef ref) {
  ref.read(staffTasksInvasiveOpenProvider.notifier).state = true;
}

void closeStaffTasksInvasivePopup(WidgetRef ref) {
  ref.read(staffTasksInvasiveOpenProvider.notifier).state = false;
}

Future<String?> _currentUserKey(Ref ref) async {
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

final staffTasksAdminProvider = FutureProvider<List<StaffTaskAdminRow>>((ref) async {
  ref.watch(staffTasksRefreshProvider);
  if (!StaffTasksCloudService.isEnabled) return [];
  await StaffTasksCloudService.ensureTodayOccurrences();
  return StaffTasksCloudService.fetchAdminTasks();
});

final myStaffTasksProvider = FutureProvider<List<StaffTaskForUser>>((ref) async {
  ref.watch(staffTasksRefreshProvider);
  if (!StaffTasksCloudService.isEnabled) return [];
  await StaffTasksCloudService.ensureTodayOccurrences();
  final userKey = await _currentUserKey(ref);
  if (userKey == null) return [];
  return StaffTasksCloudService.fetchTasksForUser(userId: userKey);
});

final dueStaffTasksCountProvider = FutureProvider<int>((ref) async {
  ref.watch(staffTasksRefreshProvider);
  ref.watch(staffTasksDueRefreshProvider);
  if (!StaffTasksCloudService.isEnabled) return 0;
  final userKey = await _currentUserKey(ref);
  if (userKey == null) return 0;
  return StaffTasksCloudService.countDuePendingForUser(userId: userKey);
});

/// En web, refresca solo el conteo de tareas vencidas cada 5 min (no recarga listas).
final staffTasksWebPollProvider = Provider<void>((ref) {
  if (!kIsWeb || !StaffTasksCloudService.isEnabled) return;
  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    ref.read(staffTasksDueRefreshProvider.notifier).state++;
  });
  ref.onDispose(timer.cancel);
});
