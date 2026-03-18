import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

const _units = ['kg', 'lt', 'pz', 'pcs', 'g', 'ml'];

final _suppliesGroupedProvider =
    FutureProvider<List<({String name, List<Supply> supplies})>>((ref) {
  return ref.read(posRepositoryProvider).getSuppliesGroupedByCategory();
});

final _supplyCategoryNamesProvider = FutureProvider<List<String>>((ref) {
  return ref.read(posRepositoryProvider).getSupplyCategoryNames();
});

class SupplyManagementScreen extends ConsumerWidget {
  const SupplyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(_suppliesGroupedProvider);

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
      body: groupedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
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
        ),
        data: (sections) {
          if (sections.isEmpty) {
            return Center(
              child: Text(
                'No hay insumos. Toca + para agregar.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final section in sections) ...[
                _SectionHeader(name: section.name, count: section.supplies.length),
                ...section.supplies.map(
                  (supply) => _SupplyTile(
                    supply: supply,
                    onTap: () => _showSupplyDialog(context: context, ref: ref, supply: supply),
                    onDismiss: () async {
                      await ref.read(posRepositoryProvider).deleteSupply(supply.id);
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
    showDialog<void>(
      context: context,
      builder: (ctx) => _SupplyFormDialog(
        supply: supply,
        categoryNames: ref.read(_supplyCategoryNamesProvider).value ?? [],
        onSave: (name, unit, costPerUnit, reorderPoint, category) async {
          await ref.read(posRepositoryProvider).saveSupply(
                id: supply?.id,
                name: name,
                unit: unit,
                costPerUnit: costPerUnit,
                reorderPoint: reorderPoint,
                category: category?.trim().isEmpty == true ? null : category?.trim(),
              );
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
    required this.onTap,
    required this.onDismiss,
  });

  final Supply supply;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final isLowStock = supply.currentStock <= supply.reorderPoint;

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
          '${supply.currentStock.toStringAsFixed(1)} ${supply.unit}'
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
    required this.categoryNames,
    required this.onSave,
  });

  final Supply? supply;
  final List<String> categoryNames;
  final Future<void> Function(
    String name,
    String unit,
    double costPerUnit,
    double reorderPoint,
    String? category,
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
    _selectedUnit = widget.supply?.unit ?? _units.first;
    if (!_units.contains(_selectedUnit)) _selectedUnit = _units.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _reorderController.dispose();
    _categoryController.dispose();
    super.dispose();
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

    setState(() => _isSaving = true);
    await widget.onSave(name, _selectedUnit, cost, reorder, categoryOrNull);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: const InputDecoration(
                labelText: 'Unidad',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUnit,
                  isExpanded: true,
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedUnit = v ?? _units.first),
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
