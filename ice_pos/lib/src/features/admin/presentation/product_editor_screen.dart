import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

final _suppliesStreamProvider = StreamProvider<List<Supply>>((ref) {
  return ref.watch(posRepositoryProvider).watchSupplies();
});

/// Recipe item for editing (supply + quantity).
class _RecipeItem {
  _RecipeItem({
    required this.supplyId,
    required this.quantity,
    this.supplyName,
    this.supplyUnit,
  });

  int supplyId;
  double quantity;
  String? supplyName;
  String? supplyUnit;
}

/// Modifier option for editing.
class _ModifierOptionItem {
  _ModifierOptionItem({
    required this.supplyId,
    required this.quantityDeducted,
    this.priceExtra = 0,
    this.supplyName,
    this.supplyUnit,
  });

  int supplyId;
  double quantityDeducted;
  double priceExtra;
  String? supplyName;
  String? supplyUnit;
}

/// Modifier group for editing.
class _ModifierGroupItem {
  _ModifierGroupItem({
    required this.name,
    required this.minSelection,
    required this.maxSelection,
    this.options = const [],
  });

  String name;
  int minSelection;
  int maxSelection;
  List<_ModifierOptionItem> options;
}

class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<ProductEditorScreen> createState() =>
      _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  List<_RecipeItem> _recipeItems = [];
  List<_ModifierGroupItem> _modifierGroups = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProduct();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (widget.productId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final repo = ref.read(posRepositoryProvider);
    final product = await repo.getProduct(widget.productId!);
    if (product == null || !mounted) return;

    _nameController.text = product.name;
    _priceController.text = product.price.toStringAsFixed(2);

    final recipes = await repo.getRecipesForProduct(widget.productId!);
    _recipeItems = recipes
        .map(
          (r) => _RecipeItem(
            supplyId: r.recipe.supplyId,
            quantity: r.recipe.quantityRequired,
            supplyName: r.supply.name,
            supplyUnit: r.supply.unit,
          ),
        )
        .toList();

    final groups = await repo.getModifierGroupsForProduct(widget.productId!);
    _modifierGroups = groups
        .map(
          (g) => _ModifierGroupItem(
            name: g.group.name,
            minSelection: g.group.minSelection,
            maxSelection: g.group.maxSelection,
            options: g.options
                .map(
                  (o) => _ModifierOptionItem(
                    supplyId: o.option.supplyId,
                    quantityDeducted: o.option.quantityDeducted,
                    priceExtra: o.option.priceExtra,
                    supplyName: o.supplyName,
                    supplyUnit: o.supplyUnit,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    if (mounted) setState(() => _isLoading = false);
  }

  double _computeBaseCost(List<Supply> supplies) {
    var cost = 0.0;
    for (final item in _recipeItems) {
      final supply = supplies.where((s) => s.id == item.supplyId).firstOrNull;
      if (supply != null) {
        cost += item.quantity * supply.costPerUnit;
      }
    }
    return cost;
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

    setState(() => _isSaving = true);
    try {
      await ref.read(posRepositoryProvider).saveProduct(
            productId: widget.productId,
            name: name,
            price: price,
            recipeItems: _recipeItems
                .map((r) => (supplyId: r.supplyId, quantityRequired: r.quantity))
                .toList(),
            modifierGroups: _modifierGroups
                .map(
                  (g) => (
                    name: g.name,
                    minSelection: g.minSelection,
                    maxSelection: g.maxSelection,
                    options: g.options
                        .map(
                          (o) => (
                            supplyId: o.supplyId,
                            quantityDeducted: o.quantityDeducted,
                            priceExtra: o.priceExtra,
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved')),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Editor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'New Product' : 'Edit Product'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Fixed Recipe'),
            Tab(text: 'Modifiers'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _BasicInfoTab(
            nameController: _nameController,
            priceController: _priceController,
          ),
          _FixedRecipeTab(
            recipeItems: _recipeItems,
            suppliesAsync: ref.watch(_suppliesStreamProvider),
            baseCost: ref.watch(_suppliesStreamProvider).when(
                  data: _computeBaseCost,
                  loading: () => 0.0,
                  error: (_, __) => 0.0,
                ),
            onAdd: () => _showAddRecipeDialog(context),
            onRemove: (index) => setState(() => _recipeItems.removeAt(index)),
          ),
          _ModifiersTab(
            modifierGroups: _modifierGroups,
            suppliesAsync: ref.watch(_suppliesStreamProvider),
            onAddGroup: () => _showAddModifierGroupDialog(context),
            onEditGroup: (index) =>
                _showEditModifierGroupDialog(context, index),
            onRemoveGroup: (index) =>
                setState(() => _modifierGroups.removeAt(index)),
            onAddOption: (groupIndex) =>
                _showAddModifierOptionDialog(context, groupIndex),
            onRemoveOption: (groupIndex, optionIndex) => setState(() {
                  _modifierGroups[groupIndex].options.removeAt(optionIndex);
                }),
          ),
        ],
      ),
    );
  }

  void _showAddRecipeDialog(BuildContext context) async {
    final supplies = await ref.read(posRepositoryProvider).getSupplies();
    if (!mounted || supplies.isEmpty) return;

    Supply? selectedSupply = supplies.first;
    final qtyController = TextEditingController(text: '1');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Supply',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Supply>(
                    value: selectedSupply,
                    isExpanded: true,
                    items: supplies
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (s) =>
                        setDialogState(() => selectedSupply = s),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedSupply == null) return;
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSupply != null && mounted) {
      final qty = double.tryParse(qtyController.text) ?? 1;
      setState(() {
        _recipeItems.add(_RecipeItem(
          supplyId: selectedSupply!.id,
          quantity: qty,
          supplyName: selectedSupply!.name,
          supplyUnit: selectedSupply!.unit,
        ));
      });
    }
  }

  void _showAddModifierGroupDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final minController = TextEditingController(text: '0');
    final maxController = TextEditingController(text: '3');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Modifier Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                hintText: 'e.g. Sabores Vaso Chico',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minController,
              decoration: const InputDecoration(
                labelText: 'Min Selection',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              decoration: const InputDecoration(
                labelText: 'Max Selection',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              final min = int.tryParse(minController.text) ?? 0;
              final max = int.tryParse(maxController.text) ?? 3;
              if (max < min) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _modifierGroups.add(_ModifierGroupItem(
          name: nameController.text.trim(),
          minSelection: int.tryParse(minController.text) ?? 0,
          maxSelection: int.tryParse(maxController.text) ?? 3,
        ));
      });
    }
  }

  void _showEditModifierGroupDialog(BuildContext context, int index) async {
    final group = _modifierGroups[index];
    final nameController = TextEditingController(text: group.name);
    final minController =
        TextEditingController(text: group.minSelection.toString());
    final maxController =
        TextEditingController(text: group.maxSelection.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Modifier Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minController,
              decoration: const InputDecoration(
                labelText: 'Min Selection',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              decoration: const InputDecoration(
                labelText: 'Max Selection',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _modifierGroups[index] = _ModifierGroupItem(
          name: nameController.text.trim(),
          minSelection: int.tryParse(minController.text) ?? 0,
          maxSelection: int.tryParse(maxController.text) ?? 3,
          options: group.options,
        );
      });
    }
  }

  void _showAddModifierOptionDialog(BuildContext context, int groupIndex) async {
    final supplies = await ref.read(posRepositoryProvider).getSupplies();
    if (!mounted || supplies.isEmpty) return;

    Supply? selectedSupply = supplies.first;
    final qtyController = TextEditingController(text: '0.050');
    final priceController = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Modifier Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Supply',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Supply>(
                    value: selectedSupply,
                    isExpanded: true,
                    items: supplies
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (s) =>
                        setDialogState(() => selectedSupply = s),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity Deducted (per selection)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 0.050',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Extra Price (optional)',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedSupply == null) return;
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSupply != null && mounted) {
      final qty = double.tryParse(qtyController.text) ?? 0.05;
      final price = double.tryParse(priceController.text) ?? 0;
      setState(() {
        _modifierGroups[groupIndex].options.add(_ModifierOptionItem(
          supplyId: selectedSupply!.id,
          quantityDeducted: qty,
          priceExtra: price,
          supplyName: selectedSupply!.name,
          supplyUnit: selectedSupply!.unit,
        ));
      });
    }
  }
}

class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({
    required this.nameController,
    required this.priceController,
  });

  final TextEditingController nameController;
  final TextEditingController priceController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: priceController,
            decoration: const InputDecoration(
              labelText: 'Price',
              border: OutlineInputBorder(),
              prefixText: '\$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }
}

class _FixedRecipeTab extends StatelessWidget {
  const _FixedRecipeTab({
    required this.recipeItems,
    required this.suppliesAsync,
    required this.baseCost,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_RecipeItem> recipeItems;
  final AsyncValue<List<Supply>> suppliesAsync;
  final double baseCost;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Base Cost',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '\$${baseCost.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (recipeItems.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No ingredients. Tap Add to add.')),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = recipeItems[index];
                return ListTile(
                  title: Text(item.supplyName ?? 'Supply #${item.supplyId}'),
                  subtitle: Text(
                    '${item.quantity} ${item.supplyUnit ?? 'units'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onRemove(index),
                  ),
                );
              },
              childCount: recipeItems.length,
            ),
          ),
      ],
    );
  }
}

class _ModifiersTab extends StatelessWidget {
  const _ModifiersTab({
    required this.modifierGroups,
    required this.suppliesAsync,
    required this.onAddGroup,
    required this.onEditGroup,
    required this.onRemoveGroup,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  final List<_ModifierGroupItem> modifierGroups;
  final AsyncValue<List<Supply>> suppliesAsync;
  final VoidCallback onAddGroup;
  final void Function(int index) onEditGroup;
  final void Function(int index) onRemoveGroup;
  final void Function(int groupIndex) onAddOption;
  final void Function(int groupIndex, int optionIndex) onRemoveOption;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modifier Groups',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onAddGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Group'),
                ),
              ],
            ),
          ),
        ),
        if (modifierGroups.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'No modifier groups. Tap Add Group (e.g. Sabores Vaso Chico).',
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, groupIndex) {
                final group = modifierGroups[groupIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: ExpansionTile(
                    title: Text(
                      group.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Min: ${group.minSelection}, Max: ${group.maxSelection}',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => onEditGroup(groupIndex),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onRemoveGroup(groupIndex),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () => onAddOption(groupIndex),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Option'),
                            ),
                            ...group.options.asMap().entries.map((e) {
                              final opt = e.value;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  opt.supplyName ?? 'Supply #${opt.supplyId}',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${opt.quantityDeducted} ${opt.supplyUnit ?? 'units'}${opt.priceExtra > 0 ? ' / +\$${opt.priceExtra.toStringAsFixed(2)}' : ''}',
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      onRemoveOption(groupIndex, e.key),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: modifierGroups.length,
            ),
          ),
      ],
    );
  }
}
