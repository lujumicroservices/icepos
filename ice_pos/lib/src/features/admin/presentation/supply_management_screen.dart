import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/constants/supply_units.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/core/widgets/list_search_bar.dart';
import 'package:ice_pos/src/features/admin/data/supply_admin_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';

final _suppliesGroupedProvider =
    FutureProvider<List<({String name, List<Supply> supplies})>>((ref) {
  return ref.read(supplyAdminRepositoryProvider).getSuppliesGroupedByCategory();
});

final _supplyCategoryNamesProvider = FutureProvider<List<String>>((ref) {
  return ref.read(supplyAdminRepositoryProvider).getSupplyCategoryNames();
});

final _adminSupplySearchQueryProvider = StateProvider<String>((ref) => '');

List<({String name, List<Supply> supplies})> _filterSupplySections(
  List<({String name, List<Supply> supplies})> sections,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return sections;
  final out = <({String name, List<Supply> supplies})>[];
  for (final s in sections) {
    final sectionMatches = s.name.toLowerCase().contains(q);
    final filtered = sectionMatches
        ? s.supplies
        : s.supplies
            .where((sup) => sup.name.toLowerCase().contains(q))
            .toList();
    if (filtered.isEmpty) continue;
    out.add((name: s.name, supplies: filtered));
  }
  return out;
}

class SupplyManagementScreen extends ConsumerStatefulWidget {
  const SupplyManagementScreen({super.key});

  @override
  ConsumerState<SupplyManagementScreen> createState() =>
      _SupplyManagementScreenState();
}

class _SupplyManagementScreenState extends ConsumerState<SupplyManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromCloudAndRefresh();
    });
  }

  /// Trae categorías/insumos/recetas desde Supabase para que otro dispositivo vea conciliaciones.
  Future<void> _syncFromCloudAndRefresh() async {
    if (!CloudSyncService.isEnabled) return;
    if (!ConnectivityService.instance.isConnected) return;
    final db = ref.read(appDatabaseProvider);
    if (db != null) {
      final err = await CloudSyncService.syncFromCloud(db);
      if (!mounted) return;
      ref.invalidate(_suppliesGroupedProvider);
      ref.invalidate(_supplyCategoryNamesProvider);
      ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(_suppliesGroupedProvider);
    ref.invalidate(_supplyCategoryNamesProvider);
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
  }

  @override
  Widget build(BuildContext context) {
    final groupedAsync = ref.watch(_suppliesGroupedProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final searchQ = ref.watch(_adminSupplySearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insumos',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListSearchBar(
            queryProvider: _adminSupplySearchQueryProvider,
            hintText: l10n.quickSearchHint,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _syncFromCloudAndRefresh,
              child: groupedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar insumos',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                data: (sections) {
                  if (sections.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No hay insumos. Toca + para agregar.',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final filtered = _filterSupplySections(sections, searchQ);
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.searchNoResults,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      for (final section in filtered) ...[
                        _SectionHeader(name: section.name, count: section.supplies.length),
                        ...section.supplies.map(
                          (supply) => _SupplyTile(
                            supply: supply,
                            l10n: l10n,
                            onTap: () => _showSupplyDialog(context: context, ref: ref, supply: supply),
                            onDismiss: () async {
                              try {
                                await ref.read(supplyAdminRepositoryProvider).deleteSupply(supply.id);
                              } on OfflineMasterWriteException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.message),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                return;
                              }
                              ref.invalidate(_suppliesGroupedProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Eliminado: ${supply.name}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplyDialog(context: context, ref: ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSupplyDialog({
    required BuildContext context,
    required WidgetRef ref,
    Supply? supply,
  }) {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => _SupplyFormDialog(
        supply: supply,
        l10n: l10n,
        categoryNames: ref.read(_supplyCategoryNamesProvider).value ?? [],
        onSave:
            (name, unit, costPerUnit, reorderPoint, category, stockMode, qual) async {
          try {
            await ref.read(supplyAdminRepositoryProvider).saveSupply(
                  id: supply?.id,
                  name: name,
                  unit: unit,
                  costPerUnit: costPerUnit,
                  reorderPoint: reorderPoint,
                  category: category?.trim().isEmpty == true ? null : category?.trim(),
                  stockCountMode: stockMode,
                  qualitativeLevel: qual,
                );
          } on OfflineMasterWriteException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.message),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          ref.invalidate(_suppliesGroupedProvider);
          ref.invalidate(_supplyCategoryNamesProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(supply == null ? 'Insumo creado' : 'Insumo actualizado'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({
    required this.supply,
    required this.l10n,
    required this.onTap,
    required this.onDismiss,
  });

  final Supply supply;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  String _levelLabel(String code) {
    switch (code) {
      case QualitativeLevel.alto:
        return l10n.qualitativeLevelAlto;
      case QualitativeLevel.medio:
        return l10n.qualitativeLevelMedio;
      case QualitativeLevel.bajo:
        return l10n.qualitativeLevelBajo;
      case QualitativeLevel.critico:
      case QualitativeLevel.resurtir:
        return l10n.qualitativeLevelCritico;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLowStock = supply.stockCountMode == StockCountMode.qualitative
        ? (supply.qualitativeLevel == QualitativeLevel.resurtir ||
            supply.qualitativeLevel == QualitativeLevel.critico)
        : supply.reorderPoint > 0 &&
            supply.currentStock <= supply.reorderPoint;

    return Dismissible(
      key: ValueKey(supply.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar insumo'),
            content: Text(
              '¿Eliminar "${supply.name}"? No se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        onTap: onTap,
        title: Text(
          supply.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          supply.stockCountMode == StockCountMode.qualitative
              ? '${l10n.stockCountModeQualitative}: ${supply.qualitativeLevel != null ? _levelLabel(supply.qualitativeLevel!) : '—'}'
              : '${supply.currentStock.toStringAsFixed(1)} ${supply.unit}'
                  '${supply.reorderPoint > 0 ? ' · Reorden en ${supply.reorderPoint}' : ''}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isLowStock
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Text(
          '\$${supply.costPerUnit.toStringAsFixed(2)}/${supply.unit}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SupplyFormDialog extends StatefulWidget {
  const _SupplyFormDialog({
    this.supply,
    required this.l10n,
    required this.categoryNames,
    required this.onSave,
  });

  final Supply? supply;
  final AppLocalizations l10n;
  final List<String> categoryNames;
  final Future<void> Function(
    String name,
    String unit,
    double costPerUnit,
    double reorderPoint,
    String? category,
    String stockCountMode,
    String? qualitativeLevel,
  ) onSave;

  @override
  State<_SupplyFormDialog> createState() => _SupplyFormDialogState();
}

class _SupplyFormDialogState extends State<_SupplyFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  late final TextEditingController _reorderController;
  late final TextEditingController _categoryController;
  late String _selectedUnit;
  late String _stockMode;
  String? _qualitativeLevel;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supply?.name ?? '');
    _costController = TextEditingController(
      text: widget.supply?.costPerUnit.toStringAsFixed(2) ?? '0.00',
    );
    _reorderController = TextEditingController(
      text: widget.supply?.reorderPoint.toStringAsFixed(1) ?? '0',
    );
    _categoryController = TextEditingController(text: widget.supply?.category ?? '');
    _selectedUnit = widget.supply?.unit ?? kSupplyUnitOptions.first;
    if (!kSupplyUnitOptions.contains(_selectedUnit)) {
      _selectedUnit = kSupplyUnitOptions.first;
    }
    _stockMode = widget.supply?.stockCountMode ?? StockCountMode.quantity;
    if (_stockMode != StockCountMode.qualitative) _stockMode = StockCountMode.quantity;
    if (QualitativeLevel.isValid(widget.supply?.qualitativeLevel)) {
      final raw = widget.supply!.qualitativeLevel!;
      _qualitativeLevel = raw == QualitativeLevel.resurtir
          ? QualitativeLevel.critico
          : raw;
    } else {
      _qualitativeLevel = QualitativeLevel.medio;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _reorderController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String _levelLabelFor(String code, AppLocalizations loc) {
    switch (code) {
      case QualitativeLevel.alto:
        return loc.qualitativeLevelAlto;
      case QualitativeLevel.medio:
        return loc.qualitativeLevelMedio;
      case QualitativeLevel.bajo:
        return loc.qualitativeLevelBajo;
      case QualitativeLevel.critico:
      case QualitativeLevel.resurtir:
        return loc.qualitativeLevelCritico;
      default:
        return code;
    }
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }

    final cost = parseDecimal(_costController.text);
    if (cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Costo por unidad inválido')),
      );
      return;
    }

    final reorder = parseDecimal(_reorderController.text) ?? 0;
    final category = _categoryController.text.trim();
    final categoryOrNull = category.isEmpty ? null : category;
    final qual = _stockMode == StockCountMode.qualitative ? _qualitativeLevel : null;

    setState(() => _isSaving = true);
    await widget.onSave(
      name,
      _selectedUnit,
      cost,
      reorder,
      categoryOrNull,
      _stockMode,
      qual,
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.l10n;
    return AlertDialog(
      title: Text(widget.supply == null ? 'Nuevo insumo' : 'Editar insumo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: widget.supply == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Categoría (opcional)',
                hintText: 'Ej. Lácteos, Sabores',
                border: const OutlineInputBorder(),
                suffixIcon: widget.categoryNames.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (v) => _categoryController.text = v,
                        itemBuilder: (_) => widget.categoryNames
                            .map((c) => PopupMenuItem(value: c, child: Text(c)))
                            .toList(),
                      ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: loc.stockCountModeLabel,
                border: const OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _stockMode,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: StockCountMode.quantity,
                      child: Text(loc.stockCountModeQuantity),
                    ),
                    DropdownMenuItem(
                      value: StockCountMode.qualitative,
                      child: Text(loc.stockCountModeQualitative),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _stockMode = v ?? StockCountMode.quantity;
                  }),
                ),
              ),
            ),
            if (_stockMode == StockCountMode.qualitative) ...[
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: loc.reconcileSelectLevel,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _qualitativeLevel ?? QualitativeLevel.medio,
                    isExpanded: true,
                    items: QualitativeLevel.all
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(_levelLabelFor(c, loc)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _qualitativeLevel = v),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Unidad',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUnit,
                  isExpanded: true,
                  items: kSupplyUnitOptions
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _selectedUnit = v ?? kSupplyUnitOptions.first),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Costo por unidad',
                border: OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reorderController,
              decoration: const InputDecoration(
                labelText: 'Punto de reorden (alerta)',
                border: OutlineInputBorder(),
                hintText: '0 = sin alerta',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
