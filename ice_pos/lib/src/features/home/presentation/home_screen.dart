import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(selectedIndex)),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1E88E5)),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                                  CloudSyncService.isEnabled ? 'Nube activa' : 'Nube no configurada',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CloudSyncService.isEnabled
                                      ? 'Sincronización con Supabase'
                                      : 'Configura SUPABASE_URL y SUPABASE_ANON_KEY en .env',
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
                                          content: const Text('Conexión con la nube OK'),
                                          backgroundColor: Colors.green.shade700,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error de conexión: $e'),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.wifi_find, size: 18),
                                label: const Text('Probar conexión'),
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
                                    builder: (ctx) => const AlertDialog(
                                      content: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 16),
                                          Text('Sincronizando desde la nube...'),
                                        ],
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
                                              ? 'Sincronización correcta. Datos locales actualizados desde la nube.'
                                              : 'Error al sincronizar: $err',
                                        ),
                                        backgroundColor: err != null ? Theme.of(context).colorScheme.error : Colors.green.shade700,
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: err != null ? 5 : 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.cloud_download, size: 18),
                                label: const Text('Sincronizar'),
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
              title: const Text('Supply Management'),
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
              title: const Text('Product Management'),
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
              title: const Text('Category Management'),
              subtitle: const Text('Add, edit categories; assign products'),
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
              title: const Text('Bundle Management'),
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
              title: const Text('Close Shift'),
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
              title: const Text('Comprobar actualización'),
              subtitle: const Text('Ver si hay nueva versión de la app'),
              onTap: () async {
                Navigator.pop(context);
                final release = await checkForUpdate();
                if (!context.mounted) return;
                if (release != null) {
                  final openUrl = release.downloadUrl != null;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Actualización disponible'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Versión ${release.version} (build ${release.buildNumber})'),
                            if (release.messageEs != null) ...[
                              const SizedBox(height: 8),
                              Text(release.messageEs!),
                            ],
                            if (openUrl)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'Pulsa "Descargar" para abrir el enlace e instalar la nueva versión.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Más tarde'),
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
                            label: const Text('Descargar'),
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
              title: const Text('Impresora'),
              subtitle: const Text('Configurar impresora Bluetooth'),
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
                title: const Text('Enviar datos a la nube'),
                subtitle: const Text('La nube será la fuente de verdad'),
                onTap: () async {
                  Navigator.pop(context);
                  final db = ref.read(appDatabaseProvider);
                  String? err = await CloudSyncService.pushToCloud(db);
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
                    final seeder = DatabaseSeeder(db);
                    try {
                      await seeder.seedMenuReyesNievesForce();
                      await seeder.seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
                      await seeder.seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
                    } catch (e) {
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
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err == null ? 'Datos enviados a la nube' : 'Error: $err'),
                        backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload menu from JSON'),
              subtitle: const Text('Solo cuando la nube está vacía. Si la nube tiene datos, usa Sincronizar.'),
              onTap: () async {
                Navigator.pop(context);
                if (CloudSyncService.isEnabled) {
                  final cloudEmpty = await CloudSyncService.isCloudEmpty();
                  if (!cloudEmpty && context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cargar desde JSON no permitido'),
                        content: const Text(
                          'La nube ya tiene datos. Para que todos los dispositivos tengan los mismos IDs, '
                          'solo se puede cargar desde JSON cuando la nube está vacía (dispositivo maestro la primera vez). '
                          'En este dispositivo usa Sincronizar para obtener el menú.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Entendido'),
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
                    title: const Text('Reload menu?'),
                    content: const Text(
                      'This will delete all categories and products that belong to a category, '
                      'then reload from menu_reyes_nieves.json. Products without a category (e.g. samples) are kept.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reload'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                final db = ref.read(appDatabaseProvider);
                final seeder = DatabaseSeeder(db);
                try {
                  await seeder.seedMenuReyesNievesForce();
                  await seeder.seedProductWithModifiersFromJson('assets/data/bolis_modifiers.json');
                  await seeder.seedProductsWithModifiersFromJson('assets/data/paletas_modifiers.json');
                  await seeder.seedProductsWithModifiersFromJson('assets/data/nieves_modifiers.json');
                  await seeder.seedProductsWithModifiersFromJson('assets/data/bebidas_leche_modifiers.json');
                  await seeder.seedProductsWithModifiersFromJson('assets/data/malteadas_modifiers.json');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menú recargado (Bolis, Paletas, Nieves, Malteadas)')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al recargar: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  static String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Point of Sale';
      case 1:
        return 'Inventory';
      case 2:
        return 'Sales History';
      default:
        return 'ICE POS';
    }
  }
}
