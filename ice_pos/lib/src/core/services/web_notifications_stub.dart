class WebNotificationsService {
  const WebNotificationsService();

  Future<void> requestPermissionIfNeeded() async {}

  Future<void> showStaffTasksDueNotification(int dueCount) async {}

  Future<void> showPendingApprovalsNotification(int pendingCount) async {}
}

