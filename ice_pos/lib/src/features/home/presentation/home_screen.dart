import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/database/seeder.dart';
import 'package:ice_pos/src/core/services/app_update_service.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/category_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/product_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/supply_management_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_screen.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/close_shift_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/printer_setup_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    PosScreen(),
    InventoryScreen(),
    SalesHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(selectedIndex, l10n)),
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
                      if (CloudSyncService.isEnabled) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    await SupabaseService.instance.client
                                        .from('categories')
                                        .select('id')
                                        .limit(1);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.connectionOk),
                                          backgroundColor: Colors.green.shade700,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
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
                                icon: const Icon(Icons.wifi_find, size: 18),
                                label: Text(l10n.testConnection),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => PopScope(
                                      canPop: false,
                                      child: AlertDialog(
                                        content: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(l10n.syncingFromCloud),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  final db = ref.read(appDatabaseProvider);
                                  final err = await CloudSyncService.syncFromCloud(db);
                                  if (context.mounted) Navigator.of(context).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err == null
                                              ? l10n.syncSuccess
                                              : '${l10n.syncError}: $err',
                                        ),
                                        backgroundColor: err != null ? Theme.of(context).colorScheme.error : Colors.green.shade700,
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: err != null ? 5 : 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.cloud_download, size: 18),
                                label: Text(l10n.sync),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                final release = await checkForUpdate();
                if (!context.mounted) return;
                if (release != null) {
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
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(l10n.download),
                          ),
                      ],
                    ),
                  );
                } else {
                  String msg = 'Ya tienes la última versión.';
                  if (!SupabaseService.isInitialized) {
                    msg = 'Nube no configurada. No se puede comprobar actualizaciones.';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
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
            if (CloudSyncService.isEnabled)
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: Text(l10n.sendToCloud),
                subtitle: Text(l10n.sendToCloudSubtitle),
                onTap: () async {
                  Navigator.pop(context);
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
                          Text(l10n.sendingToCloud),
                        ],
                      ),
                    ),
                  );
                  final db = ref.read(appDatabaseProvider);
                  String? err = await CloudSyncService.pushToCloud(db);
                  if (context.mounted) Navigator.of(context).pop();
                  if (err != null && err.contains('No hay categorías locales') && context.mounted) {
                    final cloudEmpty = await CloudSyncService.isCloudEmpty();
                    if (!cloudEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La nube ya tiene datos. Usa Sincronizar para obtener el menú en este dispositivo.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final loadFirst = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sin categorías locales'),
                        content: const Text(
                          'No hay categorías en este dispositivo y la nube está vacía. '
                          '¿Cargar el menú desde JSON y luego enviar a la nube? (Solo el primer dispositivo debe hacerlo.)',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sí, cargar y enviar'),
                          ),
                        ],
                      ),
                    );
                    if (loadFirst != true || !context.mounted) return;
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
                            Text(l10n.loadingMenuAndSending),
                          ],
                        ),
                      ),
                    );
                    final seeder = DatabaseSeeder(db);
                    try {
                      await seeder.seedMenuReyesNievesForce();
                      await seeder.seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
                    } catch (e) {
                      if (context.mounted) Navigator.of(context).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al cargar menú: $e'),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                      return;
                    }
                    if (!context.mounted) return;
                    err = await CloudSyncService.pushToCloud(db);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err == null ? 'Datos enviados a la nube' : 'Error: $err'),
                        backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.loadMenuFromJson),
              subtitle: Text(l10n.loadMenuFromJsonSubtitle),
              onTap: () async {
                Navigator.pop(context);
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
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
        items: [
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

  static String _titleForIndex(int index, AppLocalizations l10n) {
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
