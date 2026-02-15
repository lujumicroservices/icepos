import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _suppliesStreamProvider = StreamProvider<List<Supply>>((ref) {
  return ref.watch(posRepositoryProvider).watchSupplies();
});

class _RestockDialog extends StatefulWidget {
  const _RestockDialog({
    required this.supply,
    required this.repository,
  });

  final Supply supply;
  final PosRepository repository;

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _costController = TextEditingController(
      text: widget.supply.costPerUnit.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final quantity = double.tryParse(_quantityController.text);
    final cost = double.tryParse(_costController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }
    if (cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cost per unit')),
      );
      return;
    }

    await widget.repository.restockSupply(
      supplyId: widget.supply.id,
      quantity: quantity,
      cost: cost,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Restocked ${widget.supply.name}: +$quantity ${widget.supply.unit}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Restock ${widget.supply.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity to Add',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costController,
            decoration: const InputDecoration(
              labelText: 'New Cost per Unit',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(_suppliesStreamProvider);

    return Scaffold(
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
                  'Error loading inventory',
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
                'No supplies in inventory',
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
              final isLowStock = supply.currentStock < 10;
              final repository = ref.read(posRepositoryProvider);

              return InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => _RestockDialog(
                      supply: supply,
                      repository: repository,
                    ),
                  );
                },
                child: ListTile(
                  title: Text(
                    supply.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${supply.currentStock.toStringAsFixed(1)} ${supply.unit}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isLowStock
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isLowStock ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: Text(
                    '\$${supply.costPerUnit.toStringAsFixed(2)} / ${supply.unit}',
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
    );
  }
}
