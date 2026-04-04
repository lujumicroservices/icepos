import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/category_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/operation_logs_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/product_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/supply_management_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_reconciliation_screen.dart';
import 'package:ice_pos/src/features/movements/presentation/movements_screen.dart';
import 'package:ice_pos/src/features/monitoring/presentation/shift_close_events_screen.dart';
import 'package:ice_pos/src/features/monitoring/presentation/temperature_history_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/reports_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';

/// Inicio web para administradores: cuadrícula de accesos a los módulos más usados.
class WebAdminHomeScreen extends ConsumerWidget {
  const WebAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;

    final tiles = <_WebModule>[
      _WebModule(
        title: l10n.categoryManagement,
        icon: Icons.category_rounded,
        color: scheme.primaryContainer,
        onIconColor: scheme.onPrimaryContainer,
        builder: (_) => const CategoryManagementScreen(),
      ),
      _WebModule(
        title: l10n.productManagement,
        icon: Icons.restaurant_menu_rounded,
        color: scheme.secondaryContainer,
        onIconColor: scheme.onSecondaryContainer,
        builder: (_) => const ProductManagementScreen(),
      ),
      _WebModule(
        title: l10n.supplyManagement,
        icon: Icons.inventory_2_rounded,
        color: scheme.tertiaryContainer,
        onIconColor: scheme.onTertiaryContainer,
        builder: (_) => const SupplyManagementScreen(),
      ),
      _WebModule(
        title: l10n.salesHistory,
        icon: Icons.history_rounded,
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        onIconColor: scheme.onPrimaryContainer,
        builder: (_) => const SalesHistoryScreen(),
      ),
      _WebModule(
        title: l10n.reports,
        icon: Icons.analytics_rounded,
        color: scheme.secondaryContainer.withValues(alpha: 0.75),
        onIconColor: scheme.onSecondaryContainer,
        builder: (_) => const ReportsScreen(),
      ),
      _WebModule(
        title: l10n.inventoryReconciliation,
        icon: Icons.fact_check_rounded,
        color: scheme.surfaceContainerHighest,
        onIconColor: scheme.onSurfaceVariant,
        builder: (_) => const InventoryReconciliationScreen(),
      ),
      _WebModule(
        title: l10n.bundleManagement,
        icon: Icons.local_offer_rounded,
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        onIconColor: scheme.onPrimaryContainer,
        builder: (_) => const BundleManagementScreen(),
      ),
      _WebModule(
        title: l10n.movements,
        icon: Icons.swap_horiz_rounded,
        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
        onIconColor: scheme.onTertiaryContainer,
        builder: (_) => const MovementsScreen(),
      ),
      _WebModule(
        title: l10n.temperatureHistory,
        icon: Icons.thermostat_rounded,
        color: Colors.lightBlue.shade50,
        onIconColor: Colors.blue.shade800,
        builder: (_) => const TemperatureHistoryScreen(),
      ),
      if (CloudSyncService.isEnabled)
        _WebModule(
          title: l10n.cloudPosDiagnosticsTitle,
          icon: Icons.point_of_sale_outlined,
          color: scheme.tertiaryContainer.withValues(alpha: 0.85),
          onIconColor: scheme.onTertiaryContainer,
          builder: (_) => const ShiftCloseEventsScreen(),
        ),
      _WebModule(
        title: l10n.operationLogTitle,
        icon: Icons.bug_report_outlined,
        color: scheme.errorContainer.withValues(alpha: 0.65),
        onIconColor: scheme.onErrorContainer,
        builder: (_) => const OperationLogsScreen(),
      ),
    ];

    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(l10n: l10n, scheme: scheme),
                  const SizedBox(height: 28),
                  Text(
                    l10n.webQuickAccess,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cols = w >= 1000
                          ? 4
                          : w >= 640
                              ? 3
                              : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: w >= 900 ? 1.12 : 1.0,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (context, i) {
                          final m = tiles[i];
                          return _ModuleTile(
                            module: m,
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: m.builder,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebModule {
  const _WebModule({
    required this.title,
    required this.icon,
    required this.color,
    required this.onIconColor,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color onIconColor;
  final WidgetBuilder builder;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.l10n,
    required this.scheme,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.dashboard_customize_rounded, size: 56, color: scheme.onPrimaryContainer),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.webAdminHomeTitle,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.webAdminHomeSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.onTap,
  });

  final _WebModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: module.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, size: 28, color: module.onIconColor),
              ),
              const Spacer(),
              Text(
                module.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
