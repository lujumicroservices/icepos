import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/auth_session_provider.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/database/seeder.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/services/app_update_dialogs.dart';
import 'package:ice_pos/src/core/services/app_update_service.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_provider.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/recipe_json_import_service.dart';
import 'package:ice_pos/src/core/services/recipe_report_save.dart';
import 'package:ice_pos/src/core/utils/error_logger.dart';
import 'package:intl/intl.dart';
import 'package:ice_pos/src/core/config/register_scope.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:ice_pos/src/features/home/presentation/catalog_sync_progress_dialog.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/discount_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/category_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/operation_logs_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/product_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/stores_registers_admin_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/supply_management_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_reconciliation_screen.dart';
import 'package:ice_pos/src/features/movements/presentation/movements_screen.dart';
import 'package:ice_pos/src/features/monitoring/presentation/shift_close_events_screen.dart';
import 'package:ice_pos/src/features/monitoring/presentation/temperature_history_screen.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/close_shift_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pending_cashier_approvals_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/pos/presentation/printer_setup_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/platform_orders_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/reports_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_quick_report_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';
import 'package:ice_pos/src/core/services/package_info_provider.dart';
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/features/tasks/data/staff_tasks_providers.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_admin_screen.dart';
import 'package:ice_pos/src/features/tasks/presentation/staff_tasks_my_screen.dart';

/// Encabezado de sección del menú lateral (agrupación).
class DrawerSectionHeader extends StatelessWidget {
  const DrawerSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

List<Widget> _tilesOrEmpty(List<Widget?> candidates) {
  return candidates.whereType<Widget>().toList();
}

/// Menú lateral de [HomeScreen]: agrupado por secciones y mismas reglas que antes.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    ref.watch(posCategoriesRefreshProvider);
    final role = ref.watch(userRoleProvider);
    final hasDriftDatabase = ref.watch(appDatabaseProvider) != null;
    final isAdmin = role == UserRole.admin;

    final children = <Widget>[
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF1E88E5)),
        child: Text(
          l10n.menu,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      DrawerSectionHeader(title: l10n.drawerSectionGeneral),
      ListTile(
        leading: const Icon(Icons.language),
        title: Text(l10n.language),
        subtitle: Text(
          ref.watch(localeProvider).languageCode == 'en' ? l10n.english : l10n.spanish,
        ),
        onTap: () async {
          Navigator.pop(context);
          final chosen = await showDialog<Locale>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.selectLanguage),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.spanish),
                    onTap: () => Navigator.pop(ctx, const Locale('es')),
                  ),
                  ListTile(
                    title: Text(l10n.english),
                    onTap: () => Navigator.pop(ctx, const Locale('en')),
                  ),
                ],
              ),
            ),
          );
          if (chosen != null) {
            await ref.read(localeProvider.notifier).setLocale(chosen);
          }
        },
      ),
      const Divider(height: 1),
    ];

    if (CloudSyncService.isEnabled) {
      children.add(DrawerSectionHeader(title: l10n.drawerSectionDeviceCloud));
      children.addAll(_buildDeviceCloudTiles(context, ref, l10n));
    }

    if (isAdmin) {
      children.add(DrawerSectionHeader(title: l10n.drawerSectionCloudData));
      children.add(_buildCloudStatusCard(context, l10n));
      if (hasDriftDatabase && CloudSyncService.isEnabled) {
        children.add(_buildSyncFromCloudTile(context, ref, l10n));
      }

      void addCatalogSalesOrgSupport() {
        final catalogTiles = _tilesOrEmpty([
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(l10n.categoryManagement),
            subtitle: Text(l10n.categoryManagementSubtitle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const CategoryManagementScreen()),
              );
            },
          ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(l10n.productManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ProductManagementScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.inventory),
              title: Text(l10n.supplyManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SupplyManagementScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text(l10n.bundleManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const BundleManagementScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(l10n.discountManagement),
              subtitle: Text(l10n.discounts),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const DiscountManagementScreen()),
                );
              },
            ),
          if (StaffTasksCloudService.isEnabled)
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: Text(l10n.staffTasksAdminTitle),
              subtitle: Text(l10n.staffTasksSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const StaffTasksAdminScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.inventoryReconciliation),
              subtitle: Text(l10n.inventoryReconciliationSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const InventoryReconciliationScreen()),
                );
              },
            ),
        ]);
        if (catalogTiles.isNotEmpty) {
          children.add(DrawerSectionHeader(title: l10n.drawerSectionCatalog));
          children.addAll(catalogTiles);
        }

        final salesTiles = _tilesOrEmpty([
          if (isSupabaseOnlyBackend && CloudSyncService.isEnabled)
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: Text(l10n.quickSalesSummaryTitle),
              subtitle: Text(l10n.reportsSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SalesQuickReportScreen()),
                );
              },
            ),
          if (isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.salesHistory),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SalesHistoryScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.movements),
              subtitle: Text(l10n.movementsSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const MovementsScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text(l10n.reports),
              subtitle: Text(l10n.reportsSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
                );
              },
            ),
          if (CloudSyncService.isEnabled)
            ListTile(
              leading: const Icon(Icons.delivery_dining_outlined),
              title: Text(l10n.platformOrdersTitle),
              subtitle: Text(l10n.platformOrdersSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const PlatformOrdersScreen()),
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.thermostat_outlined),
              title: Text(l10n.temperatureHistory),
              subtitle: Text(l10n.temperatureHistorySubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const TemperatureHistoryScreen()),
                );
              },
            ),
        ]);
        if (salesTiles.isNotEmpty) {
          children.add(DrawerSectionHeader(title: l10n.drawerSectionSalesReports));
          children.addAll(salesTiles);
        }

        final orgTiles = _tilesOrEmpty([
          if (CloudSyncService.isEnabled)
            ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined),
              title: Text(l10n.storesRegistersAdminTitle),
              subtitle: Text(l10n.syncWithSupabase),
              onTap: () {
                Navigator.pop(context);
                if (!ConnectivityService.instance.isConnected) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.offlineRequiresInternet),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const StoresRegistersAdminScreen()),
                );
              },
            ),
        ]);
        if (orgTiles.isNotEmpty) {
          children.add(DrawerSectionHeader(title: l10n.drawerSectionOrganization));
          children.addAll(orgTiles);
        }

        final supportTiles = _tilesOrEmpty([
          if (hasDriftDatabase || CloudSyncService.isEnabled)
            Consumer(
              builder: (context, ref, _) {
                final pending = ref.watch(pendingCashierApprovalsUiProvider);
                final n = pending.asData?.value.length ?? 0;
                return ListTile(
                  leading: Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n', style: const TextStyle(fontSize: 11)),
                    child: const Icon(Icons.how_to_reg_outlined),
                  ),
                  title: Text(l10n.pendingCashierApprovalsTitle),
                  subtitle: Text(
                    n > 0
                        ? l10n.pendingApprovalsDrawerSubtitle(n)
                        : l10n.pendingCashierApprovalsSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PendingCashierApprovalsScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          if (hasDriftDatabase || isSupabaseOnlyBackend)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.operationLogTitle),
              subtitle: Text(l10n.operationLogSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const OperationLogsScreen()),
                );
              },
            ),
          if (CloudSyncService.isEnabled)
            ListTile(
              leading: const Icon(Icons.point_of_sale_outlined),
              title: Text(l10n.cloudPosDiagnosticsTitle),
              subtitle: Text(l10n.shiftCloseDiagnosticsMenuSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ShiftCloseEventsScreen()),
                );
              },
            ),
        ]);
        if (supportTiles.isNotEmpty) {
          children.add(DrawerSectionHeader(title: l10n.drawerSectionSupport));
          children.addAll(supportTiles);
        }
      }

      addCatalogSalesOrgSupport();
    }

    children.add(DrawerSectionHeader(title: l10n.drawerSectionRegisterOps));
    if (StaffTasksCloudService.isEnabled) {
      children.add(
        Consumer(
          builder: (context, ref, _) {
            final due = ref.watch(dueStaffTasksCountProvider);
            final n = due.asData?.value ?? 0;
            return ListTile(
              leading: Badge(
                isLabelVisible: n > 0,
                label: Text('$n', style: const TextStyle(fontSize: 11)),
                child: const Icon(Icons.checklist_rtl_outlined),
              ),
              title: Text(l10n.staffTasksMyTitle),
              subtitle: Text(l10n.staffTasksSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const StaffTasksMyScreen()),
                );
              },
            );
          },
        ),
      );
    }
    if (!isAdmin && hasDriftDatabase) {
      children.add(
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: Text(l10n.movements),
          subtitle: Text(l10n.movementsSubtitle),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MovementsScreen()),
            );
          },
        ),
      );
    }
    if (!kIsWeb) {
      children.add(
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: Text(l10n.closeShift),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CloseShiftScreen()),
            );
          },
        ),
      );
    }
    children.add(
      ListTile(
        leading: const Icon(Icons.system_update),
        title: Text(l10n.checkUpdate),
        subtitle: Text(l10n.checkUpdateSubtitle),
        onTap: () async {
          final rootContext = Navigator.of(context, rootNavigator: true).context;
          Navigator.pop(context);
          final result = await checkForUpdate();
          if (!rootContext.mounted) return;
          await presentCheckUpdateResult(rootContext, l10n, result);
        },
      ),
    );
    if (!kIsWeb) {
      children.add(
        ListTile(
          leading: const Icon(Icons.print),
          title: Text(l10n.printer),
          subtitle: Text(l10n.printerSubtitle),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PrinterSetupScreen()),
            );
          },
        ),
      );
    }

    if (isAdmin && hasDriftDatabase) {
      children.add(DrawerSectionHeader(title: l10n.drawerSectionAdvanced));
      children.addAll(_buildAdvancedTiles(context, ref, l10n));
    }

    children.addAll([
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout),
        title: Text(l10n.logout),
        subtitle: Text(l10n.logoutHint),
        onTap: () async {
          Navigator.pop(context);
          await ref.read(authSessionProvider.notifier).logout();
        },
      ),
      const Divider(height: 1),
      Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(packageInfoProvider);
          return async.when(
            data: (info) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Text(
                '${l10n.versionBuild} ${info.version} (${info.buildNumber})',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      ),
    ]);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
  }

  static List<Widget> _buildDeviceCloudTiles(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return [
      ListTile(
        leading: const Icon(Icons.cloud_upload_outlined),
        title: Text(l10n.registerDeviceToCloudTitle),
        subtitle: Text(l10n.registerDeviceToCloudSubtitle),
        onTap: () async {
          Navigator.pop(context);
          if (!ConnectivityService.instance.isConnected) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.offlineRequiresInternet),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: Text(l10n.syncingFromCloud)),
                ],
              ),
            ),
          );
          final db = ref.read(appDatabaseProvider);
          final err = await CloudSyncService.registerDeviceAndSyncOpenShift(db);
          if (context.mounted) Navigator.of(context).pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err ?? l10n.registerDeviceToCloudOk),
                backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: err != null ? 6 : 3),
              ),
            );
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: Text(l10n.posRegisterTitle),
        subtitle: Text(l10n.posRegisterSubtitle),
        onTap: () async {
          Navigator.pop(context);
          if (!ConnectivityService.instance.isConnected) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.offlineRequiresInternet),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          final storeId = await StoreScope.getActiveStoreId();
          final current = await RegisterScope.getActiveRegisterId();
          final registers = await CloudSyncService.fetchRegistersForStore(storeId);
          if (!context.mounted) return;
          if (registers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.error),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          var selected = registers.firstWhere(
            (r) => r.id == current,
            orElse: () => registers.first,
          );
          final picked = await showDialog<CloudPosRegisterRecord>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setSt) => AlertDialog(
                title: Text(l10n.posRegisterTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.posRegisterChooseHint,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...registers.map(
                      (r) => ListTile(
                        title: Text(r.label),
                        trailing: selected.id == r.id
                            ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                            : null,
                        onTap: () => setSt(() => selected = r),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ),
          );
          if (picked == null || !context.mounted) return;
          await RegisterScope.setActiveRegisterId(picked.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.posRegisterSaved),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ];
  }

  static Widget _buildCloudStatusCard(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    CloudSyncService.isEnabled ? Icons.cloud_done : Icons.cloud_off,
                    size: 28,
                    color: CloudSyncService.isEnabled ? Colors.green.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CloudSyncService.isEnabled ? l10n.cloudActive : l10n.cloudNotConfigured,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CloudSyncService.isEnabled ? l10n.syncWithSupabase : l10n.syncEnvHint,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (CloudSyncService.lastSyncError != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            CloudSyncService.lastSyncError!,
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSyncFromCloudTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final df = DateFormat.yMd().add_jm();
    return ListTile(
      leading: const Icon(Icons.sync),
      title: Text(l10n.syncFromCloud),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ref.watch(connectivityStreamProvider).when(
                  data: (online) => online ? l10n.syncWithSupabase : l10n.offlineRequiresInternet,
                  loading: () => '',
                  error: (_, _) => '',
                ),
          ),
          FutureBuilder<DateTime?>(
            future: CloudSyncService.getLastSuccessfulCatalogSyncTime(),
            builder: (context, snap) {
              final t = snap.data;
              final line = t == null
                  ? l10n.catalogMenuCacheNever
                  : l10n.catalogMenuCacheLastSync(df.format(t.toLocal()));
              return Text(
                line,
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
      ),
      onTap: () async {
        Navigator.pop(context);
        if (!ConnectivityService.instance.isConnected) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.offlineRequiresInternet),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        final db = ref.read(appDatabaseProvider);
        final err = await showCatalogSyncProgressDialog<String?>(
          context: context,
          l10n: l10n,
          run: (report) => CloudSyncService.syncFromCloud(db, onProgress: report),
        );
        ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
        if (err != null) logErrorToConsole(err);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err == null ? l10n.syncSuccess : '${l10n.syncError}: $err'),
              backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: err != null ? 5 : 3),
            ),
          );
        }
      },
    );
  }

  static List<Widget> _buildAdvancedTiles(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return [
      ListTile(
        leading: const Icon(Icons.refresh),
        title: Text(l10n.loadMenuFromJson),
        subtitle: Text(l10n.loadMenuFromJsonSubtitle),
        onTap: () async {
          Navigator.pop(context);
          if (!ConnectivityService.instance.isConnected) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.offlineRequiresInternet),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          if (CloudSyncService.isEnabled) {
            final cloudEmpty = await CloudSyncService.isCloudEmpty();
            if (!cloudEmpty && context.mounted) {
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.loadJsonNotAllowedTitle),
                  content: Text(l10n.loadJsonNotAllowedBody),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.ok),
                    ),
                  ],
                ),
              );
              return;
            }
          }
          if (!context.mounted) return;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.reloadMenuConfirmTitle),
              content: Text(l10n.reloadMenuConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.reload),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 20),
                  Text(l10n.loadingMenuFromJson),
                ],
              ),
            ),
          );
          final db = ref.read(appDatabaseProvider);
          if (db == null) {
            if (context.mounted) Navigator.of(context).pop();
            return;
          }
          final seeder = DatabaseSeeder(db);
          try {
            await seeder.seedMenuReyesNievesForce();
            await seeder.seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
            await seeder.seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
            await seeder.seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
            await seeder.seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
            await seeder.seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
            if (context.mounted) Navigator.of(context).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.menuReloaded),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            logErrorToConsole(e);
            if (context.mounted) Navigator.of(context).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al recargar: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(l10n.importRecipesFromJson),
        subtitle: Text(l10n.importRecipesFromJsonSubtitle),
        onTap: () async {
          Navigator.pop(context);
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.importRecipesConfirmTitle),
              content: Text(l10n.importRecipesConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.apply),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;

          var pushCloud = false;
          if (CloudSyncService.isEnabled) {
            final cloud = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.importRecipesPushCloudTitle),
                content: Text(l10n.importRecipesPushCloudBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.importRecipesPushCloudLocal),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.importRecipesPushCloudYes),
                  ),
                ],
              ),
            );
            pushCloud = cloud == true;
          }

          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: Text(l10n.importingRecipes)),
                ],
              ),
            ),
          );

          final db = ref.read(appDatabaseProvider);
          if (db == null) {
            if (context.mounted) Navigator.of(context).pop();
            return;
          }
          final importer = RecipeJsonImportService(db);
          try {
            final jsonString = await rootBundle.loadString('assets/data/recetas_formato.json');
            final result = await importer.importRecetasFormatoJson(
              jsonString,
              assetLabel: 'assets/data/recetas_formato.json',
              applyChanges: true,
              pushUpdatedProductsToCloud: pushCloud,
            );
            final csv = RecipeImportResult.toCsv(result.rows);
            final savedPath = await saveRecipeImportCsv(csv);
            await Clipboard.setData(ClipboardData(text: csv));

            if (context.mounted) Navigator.of(context).pop();
            if (context.mounted) {
              final buf = StringBuffer()
                ..write(l10n.importRecipesDone)
                ..write(
                  ' ${result.productsUpdated} prod., '
                  '${result.recipeLinesInserted} líneas. ',
                )
                ..write(
                  'Errores/abortados: ${result.productsFailed}. '
                  'Vacíos omitidos: ${result.productsSkippedEmptyJson}. ',
                );
              if (savedPath != null) {
                buf.write('${l10n.importRecipesReportPath} $savedPath');
              } else {
                buf.write(l10n.importRecipesReportClipboard);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(buf.toString()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          } catch (e) {
            logErrorToConsole(e);
            if (context.mounted) Navigator.of(context).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${l10n.error}: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.delete_sweep),
        title: Text(l10n.clearLocalSales),
        subtitle: Text(l10n.clearLocalSalesSubtitle),
        onTap: () async {
          Navigator.pop(context);
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.clearLocalSalesConfirmTitle),
              content: Text(l10n.clearLocalSalesConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.clear),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await ref.read(posRepositoryProvider)!.deleteAllLocalSales();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.clearLocalSalesDone),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      if (CloudSyncService.isEnabled)
        ListTile(
          leading: const Icon(Icons.cloud_download),
          title: Text(l10n.resetAndSync),
          subtitle: Text(l10n.resetAndSyncSubtitle),
          onTap: () async {
            Navigator.pop(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.resetConfirmTitle),
                content: Text(l10n.resetConfirmBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.resetAndSyncButton),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            if (!ConnectivityService.instance.isConnected) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.offlineRequiresInternet),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 20),
                    Text(l10n.resettingAndSyncing),
                  ],
                ),
              ),
            );
            await ref.read(posRepositoryProvider)!.deleteAllLocalData();
            if (!context.mounted) return;
            Navigator.of(context).pop();
            final db = ref.read(appDatabaseProvider);
            final err = await showCatalogSyncProgressDialog<String?>(
              context: context,
              l10n: l10n,
              title: l10n.resettingAndSyncing,
              run: (report) => CloudSyncService.syncFromCloud(db, onProgress: report),
            );
            ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
            if (err != null) logErrorToConsole(err);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err == null ? l10n.resetSuccess : '${l10n.resetError}: $err'),
                  backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: err != null ? 5 : 3),
                ),
              );
            }
          },
        ),
    ];
  }
}
