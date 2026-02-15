import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

const _units = ['kg', 'lt', 'pz', 'pcs', 'g', 'ml'];

final _suppliesStreamProvider = StreamProvider<List<Supply>>((ref) {
  return ref.watch(posRepositoryProvider).watchSupplies();
});

class SupplyManagementScreen extends ConsumerWidget {
  const SupplyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(_suppliesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Supply Management',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: suppliesAsync.when(
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
                  'Error loading supplies',
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
        data: (supplies) {
          if (supplies.isEmpty) {
            return Center(
              child: Text(
                'No supplies. Tap + to add.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: supplies.length,
            itemBuilder: (context, index) {
              final supply = supplies[index];
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
                      title: const Text('Delete Supply'),
                      content: Text(
                        'Delete "${supply.name}"? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  await ref.read(posRepositoryProvider).deleteSupply(supply.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted ${supply.name}')),
                    );
                  }
                },
                child: ListTile(
                  onTap: () => _showSupplyDialog(
                    context: context,
                    ref: ref,
                    supply: supply,
                  ),
                  title: Text(
                    supply.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${supply.currentStock.toStringAsFixed(1)} ${supply.unit}'
                    '${supply.reorderPoint > 0 ? ' · Reorder at ${supply.reorderPoint}' : ''}',
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
            },
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
        onSave: (name, unit, costPerUnit, reorderPoint) async {
          await ref.read(posRepositoryProvider).saveSupply(
                id: supply?.id,
                name: name,
                unit: unit,
                costPerUnit: costPerUnit,
                reorderPoint: reorderPoint,
              );
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(supply == null ? 'Supply created' : 'Supply updated'),
              ),
            );
          }
        },
      ),
    );
  }
}

class _SupplyFormDialog extends StatefulWidget {
  const _SupplyFormDialog({
    this.supply,
    required this.onSave,
  });

  final Supply? supply;
  final Future<void> Function(
    String name,
    String unit,
    double costPerUnit,
    double reorderPoint,
  ) onSave;

  @override
  State<_SupplyFormDialog> createState() => _SupplyFormDialogState();
}

class _SupplyFormDialogState extends State<_SupplyFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  late final TextEditingController _reorderController;
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
    _selectedUnit = widget.supply?.unit ?? _units.first;
    if (!_units.contains(_selectedUnit)) _selectedUnit = _units.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final cost = double.tryParse(_costController.text);
    if (cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid cost per unit')),
      );
      return;
    }

    final reorder = double.tryParse(_reorderController.text) ?? 0;

    setState(() => _isSaving = true);
    await widget.onSave(name, _selectedUnit, cost, reorder);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supply == null ? 'New Supply' : 'Edit Supply'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: widget.supply == null,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Unit',
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
                labelText: 'Cost per Unit',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reorderController,
              decoration: const InputDecoration(
                labelText: 'Reorder Point (alert threshold)',
                border: OutlineInputBorder(),
                hintText: '0 = no alert',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
