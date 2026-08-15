import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/services/web_notifications.dart';
import 'package:ice_pos/src/core/services/web_push_subscription.dart';
import 'package:ice_pos/src/features/tasks/data/staff_tasks_providers.dart';
import 'package:ice_pos/src/core/services/fcm_push_service.dart';
import 'package:ice_pos/src/features/pos/presentation/pending_cashier_approvals_screen.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_invasive_popup.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_my_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastDueCountKey = 'staff_tasks_last_notified_due_count';

/// Avisos de tareas vencidas: push web, notificación en navegador y diálogo en app nativa.
class StaffTasksNotificationBootstrap extends ConsumerStatefulWidget {
  const StaffTasksNotificationBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StaffTasksNotificationBootstrap> createState() =>
      _StaffTasksNotificationBootstrapState();
}

class _StaffTasksNotificationBootstrapState
    extends ConsumerState<StaffTasksNotificationBootstrap>
    with WidgetsBindingObserver {
  DateTime? _lastPoll;
  var _lastDueCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FcmPushService.instance.onOpenRoute = _onFcmRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePoll());
  }

  void _onFcmRoute(String route) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    switch (route) {
      case 'staff_tasks':
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const StaffTasksMyScreen()),
        );
      case 'pending_approvals':
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const PendingCashierApprovalsScreen()),
        );
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedulePoll();
    }
  }

  void _schedulePoll() {
    if (!StaffTasksCloudService.isEnabled) return;
    final now = DateTime.now();
    if (_lastPoll != null && now.difference(_lastPoll!) < const Duration(seconds: 45)) {
      return;
    }
    _lastPoll = now;
    ref.read(staffTasksRefreshProvider.notifier).state++;
    ref.read(staffTasksDueRefreshProvider.notifier).state++;
    if (ref.read(userRoleProvider) == UserRole.admin) {
      unawaited(StaffTasksCloudService.processDueScheduledNotifications());
    }
    unawaited(StaffTasksCloudService.ensureTodayOccurrences());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(staffTasksWebPollProvider);

    if (kIsWeb && StaffTasksCloudService.isEnabled) {
      ref.listen<AsyncValue<int>>(dueStaffTasksCountProvider, (previous, next) {
        final count = next.asData?.value ?? 0;
        if (count > _lastDueCount && count > 0) {
          unawaited(webNotifications.showStaffTasksDueNotification(count));
        }
        if (count == 0) {
          unawaited(() async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_kLastDueCountKey, 0);
          }());
        }
        _lastDueCount = count;
      });

      unawaited(webNotifications.requestPermissionIfNeeded());
      unawaited(() async {
        if (!SupabaseService.isInitialized) return;
        final storeId = await StoreScope.getActiveStoreId();
        final userId = SupabaseService.instance.client.auth.currentUser?.id;
        await webPushSubscriptionService.ensureSubscribed(
          storeId: storeId,
          userId: userId,
        );
      }());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        const StaffTasksInvasivePopup(),
      ],
    );
  }
}
