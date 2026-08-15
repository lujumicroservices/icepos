// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class WebNotificationsService {
  const WebNotificationsService();

  Future<void> requestPermissionIfNeeded() async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission == 'default') {
      try {
        await html.Notification.requestPermission();
      } catch (_) {}
    }
  }

  Future<void> showStaffTasksDueNotification(int dueCount) async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;
    final title = dueCount == 1
        ? '1 tarea pendiente'
        : '$dueCount tareas pendientes';
    try {
      html.Notification(
        title,
        body: 'Revisa Mis tareas en el menú.',
        tag: 'staff-tasks-due',
      );
    } catch (_) {}
  }

  Future<void> showPendingApprovalsNotification(int pendingCount) async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;
    final title = pendingCount == 1
        ? '1 aprobacion pendiente'
        : '$pendingCount aprobaciones pendientes';
    try {
      html.Notification(
        title,
        body: 'Hay solicitudes de cajero por revisar.',
        tag: 'pending-cashier-approvals',
      );
    } catch (_) {}
  }
}

