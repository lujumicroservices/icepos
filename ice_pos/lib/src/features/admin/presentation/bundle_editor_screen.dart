import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _allProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(posRepositoryProvider).watchAllProducts();
});

class BundleEditorScreen extends ConsumerStatefulWidget {
  const BundleEditorScreen({
    super.key,
    this.bundleId,
    this.initialName,
    this.initialPrice,
    this.initialProductIds = const [],
  });

  final int? bundleId;
  final String? initialName;
  final double? initialPrice;
  final List<({int productId, double quantity})>? initialProductIds;

  @override
  ConsumerState<BundleEditorScreen> createState() => _BundleEditorScreenState();
}

class _BundleEditorScreenState extends ConsumerState<BundleEditorScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _selectedProducts = <int, double>{}; // productId -> quantity
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _priceController.text = widget.initialPrice?.toStringAsFixed(2) ?? '';
    for (final p in widget.initialProductIds ?? []) {
      _selectedProducts[p.productId] = p.quantity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _showQtyDialog(BuildContext context, Product product, double current) async {
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity for ${product.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = double.tryParse(controller.text);
              if (n != null && n > 0) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedProducts[product.id] = result);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final price = double.tryParse(_priceController.text);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one product')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(posRepositoryProvider).saveBundle(
            id: widget.bundleId,
            name: name,
            price: price,
            productItems: _selectedProducts.entries
                .map((e) => (productId: e.key, quantity: e.value))
                .toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bundle saved')),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_allProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundleId == null ? 'New Bundle' : 'Edit Bundle'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Text(
                'No products. Add products first.',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Bundle Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Desayuno Ejecutivo',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Fixed Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
                Text(
                  'Products in Bundle',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...products.map((product) {
                  final isSelected = _selectedProducts.containsKey(product.id);
                  final qty = _selectedProducts[product.id] ?? 1.0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      title: Text(
                        product.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: isSelected
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: InkWell(
                                onTap: () => _showQtyDialog(context, product, qty),
                                child: Row(
                                  children: [
                                    Text(
                                      'Qty: ${qty.toStringAsFixed(qty == qty.round() ? 0 : 1)}',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : null,
                      secondary: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedProducts[product.id] = 1.0;
                          } else {
                            _selectedProducts.remove(product.id);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
