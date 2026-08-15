import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_provider.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/web_notifications.dart';
import 'package:ice_pos/src/core/services/web_push_subscription.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/features/home/presentation/home_drawer.dart';
import 'package:ice_pos/src/features/home/presentation/web_admin_home_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pending_cashier_approvals_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_quick_report_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_my_screen.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_pending_alert_icon.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// So we only run sync once after login (RLS may require session).
final _hasSyncedAfterLoginProvider = StateProvider<bool>((ref) => false);

void _schedulePostAuthCatalogSync(WidgetRef ref, BuildContext context) {
  ref.read(_hasSyncedAfterLoginProvider.notifier).state = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final db = ref.read(appDatabaseProvider);
    if (ref.read(catalogInitialSyncCompletedProvider)) {
      if (db != null) {
        await CloudSyncService.reconcileLocalOpenShiftsWithCloud(db);
      }
      ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
      return;
    }
    final err = await CloudSyncService.syncFromCloud(db);
    if (db != null && err == null) {
      await CloudSyncService.reconcileLocalOpenShiftsWithCloud(db);
    }
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
    if (context.mounted && err != null) {
      final loc = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.syncError}: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

/// Error from sync at startup (read once from prefs and show in UI).
final _startupSyncErrorProvider = FutureProvider<String?>((ref) => CloudSyncService.takeStartupSyncError());

/// Web admin: asks notification permission and notifies when pending approvals count increases.
final _webPendingApprovalsNotifierProvider = Provider<void>((ref) {
  if (!kIsWeb) return;
  final role = ref.watch(userRoleProvider);
  if (role != UserRole.admin) return;
  var lastCount = 0;
  ref.listen<AsyncValue<List<PendingCashierApprovalItem>>>(
    pendingCashierApprovalsUiProvider,
    (previous, next) {
      final count = next.asData?.value.length ?? 0;
      if (count > lastCount && count > 0) {
        unawaited(webNotifications.showPendingApprovalsNotification(count));
      }
      lastCount = count;
    },
  );
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
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(_webPendingApprovalsNotifierProvider);
    ref.listen<AsyncValue<String?>>(_startupSyncErrorProvider, (prev, next) {
      next.whenData((err) {
        if (err != null && err.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sincronización al arranque: $err'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 8),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              ref.invalidate(_startupSyncErrorProvider);
            }
          });
        }
      });
    });
    // Sync once after login (Supabase RLS may require authenticated session to read).
    ref.listen(userRoleProvider, (prev, role) {
      if (CloudSyncService.isEnabled &&
          ConnectivityService.instance.isConnected &&
          !ref.read(_hasSyncedAfterLoginProvider)) {
        _schedulePostAuthCatalogSync(ref, context);
      }
    });
    ref.listen(connectivityStreamProvider, (prev, next) {
      next.whenData((online) {
        if (!online || !CloudSyncService.isEnabled) return;
        if (ref.read(_hasSyncedAfterLoginProvider)) return;
        _schedulePostAuthCatalogSync(ref, context);
      });
    });
    final role = ref.watch(userRoleProvider);
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final List<Widget> screens;
    if (kIsWeb) {
      screens = role == UserRole.admin
          ? [const WebAdminHomeScreen()]
          : StaffTasksCloudService.isEnabled
              ? [const StaffTasksMyScreen()]
              : [const _WebEmployeePlaceholder()];
    } else if (role == UserRole.admin) {
      screens = const [
        PosScreen(),
        InventoryScreen(),
        SalesQuickReportScreen(),
        SalesHistoryScreen(),
      ];
    } else {
      screens = const [
        PosScreen(),
        SalesHistoryScreen(onlyToday: true),
      ];
    }
    final tabCount = screens.length;
    final effectiveIndex = selectedIndex.clamp(0, tabCount - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(effectiveIndex, role == UserRole.employee, l10n, isWeb: kIsWeb)),
        actions: [
          if (StaffTasksCloudService.isEnabled && role != UserRole.admin)
            const StaffTasksPendingAlertIcon(),
        ],
      ),
      drawer: const HomeDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ref.watch(connectivityStreamProvider).when(
                data: (online) => online
                    ? const SizedBox.shrink()
                    : Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off,
                                size: 20,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.offlineBanner,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
          Expanded(
            child: IndexedStack(
              index: effectiveIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: tabCount < 2
          ? null
          : _HomeBottomNav(
              effectiveIndex: effectiveIndex,
              role: role,
              l10n: l10n,
            ),
    );
  }

  static String _titleForIndex(
    int index,
    bool isEmployee,
    AppLocalizations l10n, {
    bool isWeb = false,
  }) {
    if (isWeb) {
      if (isEmployee) {
        return StaffTasksCloudService.isEnabled ? l10n.staffTasksMyTitle : l10n.appTitle;
      }
      return index == 0 ? l10n.webAdminHomeTitle : l10n.appTitle;
    }
    if (isEmployee) {
      switch (index) {
        case 0:
          return l10n.pointOfSale;
        case 1:
          return l10n.salesToday;
        default:
          return l10n.appTitle;
      }
    }
    switch (index) {
      case 0:
        return l10n.pointOfSale;
      case 1:
        return l10n.inventory;
      case 2:
        return l10n.quickSalesSummaryTitle;
      case 3:
        return l10n.salesHistory;
      default:
        return l10n.appTitle;
    }
  }
}

/// Barra inferior con contraste claro (iconos y etiquetas visibles).
class _HomeBottomNav extends ConsumerWidget {
  const _HomeBottomNav({
    required this.effectiveIndex,
    required this.role,
    required this.l10n,
  });

  final int effectiveIndex;
  final UserRole role;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (kIsWeb) {
      if (role == UserRole.admin) {
        return NavigationBar(
          selectedIndex: effectiveIndex.clamp(0, 0),
          onDestinationSelected: (i) => ref.read(selectedTabIndexProvider.notifier).state = i,
          backgroundColor: scheme.surfaceContainer,
          indicatorColor: scheme.primaryContainer,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category),
              label: l10n.categoryManagement,
            ),
          ],
        );
      }
      return NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        backgroundColor: scheme.surfaceContainer,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.appTitle,
          ),
        ],
      );
    }

    final destinations = role == UserRole.employee
        ? [
            NavigationDestination(
              icon: const Icon(Icons.point_of_sale_outlined),
              selectedIcon: const Icon(Icons.point_of_sale),
              label: l10n.pointOfSale,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: l10n.salesToday,
            ),
          ]
        : [
            NavigationDestination(
              icon: const Icon(Icons.point_of_sale_outlined),
              selectedIcon: const Icon(Icons.point_of_sale),
              label: l10n.pointOfSale,
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: l10n.inventory,
            ),
            NavigationDestination(
              icon: const Icon(Icons.summarize_outlined),
              selectedIcon: const Icon(Icons.summarize),
              label: l10n.quickSalesSummaryTitle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: l10n.salesHistory,
            ),
          ];

    return NavigationBar(
      selectedIndex: effectiveIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: (index) {
        ref.read(selectedTabIndexProvider.notifier).state = index;
      },
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: destinations,
    );
  }
}

class _WebEmployeePlaceholder extends StatelessWidget {
  const _WebEmployeePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Accede desde la app en el mostrador para ventas e inventario.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 16),
        ),
      ),
    );
  }
}
