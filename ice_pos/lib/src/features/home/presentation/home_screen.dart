import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/database/seeder.dart';
import 'package:ice_pos/src/core/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_provider.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/recipe_json_import_service.dart';
import 'package:ice_pos/src/core/services/recipe_report_save.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/operation_logs_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/category_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/product_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/supply_management_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_reconciliation_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_screen.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/pos/presentation/close_shift_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/printer_setup_screen.dart';
import 'package:ice_pos/src/features/movements/presentation/movements_screen.dart';
import 'package:ice_pos/src/features/monitoring/presentation/temperature_history_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/reports_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';
import 'package:ice_pos/src/core/auth/auth_session_provider.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/utils/error_logger.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// So we only run sync once after login (RLS may require session).
final _hasSyncedAfterLoginProvider = StateProvider<bool>((ref) => false);

/// Error from sync at startup (read once from prefs and show in UI).
final _startupSyncErrorProvider = FutureProvider<String?>((ref) => CloudSyncService.takeStartupSyncError());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screensAdmin = [
    PosScreen(),
    InventoryScreen(),
    SalesHistoryScreen(),
  ];

  /// En web solo mostramos pantallas administrativas (sin POS, impresora ni escáner).
  static const _screensAdminWeb = [
    InventoryScreen(),
    SalesHistoryScreen(),
  ];

  static const _screensEmployeeWeb = [
    SalesHistoryScreen(onlyToday: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ref.read(_hasSyncedAfterLoginProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final db = ref.read(appDatabaseProvider);
          final err = await CloudSyncService.syncFromCloud(db);
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
    });
    ref.listen(connectivityStreamProvider, (prev, next) {
      next.whenData((online) {
        if (!online || !CloudSyncService.isEnabled) return;
        if (ref.read(_hasSyncedAfterLoginProvider)) return;
        ref.read(_hasSyncedAfterLoginProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final db = ref.read(appDatabaseProvider);
          final err = await CloudSyncService.syncFromCloud(db);
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
      });
    });
    final role = ref.watch(userRoleProvider);
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final screens = kIsWeb
        ? (role == UserRole.admin ? _screensAdminWeb : _screensEmployeeWeb)
        : (role == UserRole.admin
            ? _screensAdmin
            : [
                const PosScreen(),
                const SalesHistoryScreen(onlyToday: true),
              ]);
    final tabCount = screens.length;
    final effectiveIndex = selectedIndex.clamp(0, tabCount - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(effectiveIndex, role == UserRole.employee, l10n, isWeb: kIsWeb)),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
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
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(
                ref.watch(localeProvider).languageCode == 'en'
                    ? l10n.english
                    : l10n.spanish,
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
            if (role == UserRole.admin) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                  CloudSyncService.isEnabled
                                      ? l10n.syncWithSupabase
                                      : l10n.syncEnvHint,
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
            ),
            if (CloudSyncService.isEnabled)
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(l10n.syncFromCloud),
                subtitle: Text(
                  ref.watch(connectivityStreamProvider).when(
                        data: (online) => online
                            ? l10n.syncWithSupabase
                            : l10n.offlineRequiresInternet,
                        loading: () => '',
                        error: (_, __) => '',
                      ),
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
                          Text(l10n.syncingFromCloud),
                        ],
                      ),
                    ),
                  );
                  final db = ref.read(appDatabaseProvider);
                  final err = await CloudSyncService.syncFromCloud(db);
                  ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
                  if (err != null) logErrorToConsole(err);
                  if (context.mounted) Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          err == null
                              ? l10n.syncSuccess
                              : '${l10n.syncError}: $err',
                        ),
                        backgroundColor:
                            err != null ? Theme.of(context).colorScheme.error : null,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: err != null ? 5 : 3),
                      ),
                    );
                  }
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: Text(l10n.supplyManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SupplyManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.inventoryReconciliation),
              subtitle: Text(l10n.inventoryReconciliationSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const InventoryReconciliationScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(l10n.productManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ProductManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: Text(l10n.categoryManagement),
              subtitle: Text(l10n.categoryManagementSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoryManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text(l10n.bundleManagement),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BundleManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.operationLogTitle),
              subtitle: Text(l10n.operationLogSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OperationLogsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.movements),
              subtitle: Text(l10n.movementsSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MovementsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text(l10n.reports),
              subtitle: Text(l10n.reportsSubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.thermostat_outlined),
              title: Text(l10n.temperatureHistory),
              subtitle: Text(l10n.temperatureHistorySubtitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const TemperatureHistoryScreen(),
                  ),
                );
              },
            ),
            ],
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(l10n.closeShift),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CloseShiftScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.system_update),
              title: Text(l10n.checkUpdate),
              subtitle: Text(l10n.checkUpdateSubtitle),
              onTap: () async {
                Navigator.pop(context);
                final result = await checkForUpdate();
                if (!context.mounted) return;
                switch (result) {
                  case UpdateAvailable(:final info):
                    final release = info;
                    final openUrl = release.downloadUrl != null;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.updateAvailable),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l10n.versionBuild} ${release.version} (build ${release.buildNumber})'),
                            if (release.messageEs != null) ...[
                              const SizedBox(height: 8),
                              Text(release.messageEs!),
                            ],
                            if (openUrl)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  l10n.downloadHint,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l10n.later),
                        ),
                        if (openUrl)
                          FilledButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(release.downloadUrl!);
                              bool opened = false;
                              try {
                                opened = await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                              if (!opened) {
                                try {
                                  opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
                                } catch (_) {}
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (ctx.mounted && !opened) {
                                await Clipboard.setData(ClipboardData(text: release.downloadUrl!));
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.downloadLinkCopied),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(l10n.download),
                          ),
                      ],
                    ),
                  );
                  case AlreadyLatest():
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ya tienes la última versión.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  case CheckUpdateFailed(:final reason):
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(reason),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                }
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.print),
                title: Text(l10n.printer),
                subtitle: Text(l10n.printerSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PrinterSetupScreen(),
                    ),
                  );
                },
              ),
            if (role == UserRole.admin) ...[
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
                final importer = RecipeJsonImportService(db);
                try {
                  final jsonString = await rootBundle
                      .loadString('assets/data/recetas_formato.json');
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
                await ref.read(posRepositoryProvider).deleteAllLocalSales();
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
                  await ref.read(posRepositoryProvider).deleteAllLocalData();
                  final db = ref.read(appDatabaseProvider);
                  final err = await CloudSyncService.syncFromCloud(db);
                  ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
                  if (err != null) logErrorToConsole(err);
                  if (context.mounted) Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          err == null
                              ? l10n.resetSuccess
                              : '${l10n.resetError}: $err',
                        ),
                        backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: err != null ? 5 : 3),
                      ),
                    );
                  }
                },
              ),
            ],
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
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final info = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(
                    '${l10n.versionBuild} ${info.version} (${info.buildNumber})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
                error: (_, __) => const SizedBox.shrink(),
              ),
          Expanded(
            child: IndexedStack(
              index: effectiveIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: effectiveIndex,
        onTap: (index) {
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
        items: role == UserRole.employee
            ? [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.point_of_sale_outlined),
                  activeIcon: const Icon(Icons.point_of_sale),
                  label: l10n.pointOfSale,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  activeIcon: const Icon(Icons.history),
                  label: l10n.salesToday,
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.point_of_sale_outlined),
                  activeIcon: const Icon(Icons.point_of_sale),
                  label: l10n.pointOfSale,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.inventory_2_outlined),
                  activeIcon: const Icon(Icons.inventory_2),
                  label: l10n.inventory,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  activeIcon: const Icon(Icons.history),
                  label: l10n.salesHistory,
                ),
              ],
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
        return index == 0 ? l10n.salesToday : l10n.appTitle;
      }
      switch (index) {
        case 0:
          return l10n.inventory;
        case 1:
          return l10n.salesHistory;
        default:
          return l10n.appTitle;
      }
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
        return l10n.salesHistory;
      default:
        return l10n.appTitle;
    }
  }
}
