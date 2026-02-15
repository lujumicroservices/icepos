import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

/// Dialog for selecting product modifiers (e.g., ice cream flavors).
class ProductModifierDialog extends StatefulWidget {
  const ProductModifierDialog({
    super.key,
    required this.product,
    required this.modifierGroups,
  });

  final Product product;
  final List<ModifierGroupWithOptions> modifierGroups;

  @override
  State<ProductModifierDialog> createState() => _ProductModifierDialogState();
}

class _ProductModifierDialogState extends State<ProductModifierDialog> {
  /// Per-group: list of selected ModifierOptions (duplicates allowed for count).
  late List<List<ModifierOption>> _selections;

  @override
  void initState() {
    super.initState();
    _selections = List.generate(
      widget.modifierGroups.length,
      (_) => [],
    );
  }

  bool get _isValid {
    for (var i = 0; i < widget.modifierGroups.length; i++) {
      final group = widget.modifierGroups[i].group;
      final count = _selections[i].length;
      if (count < group.minSelection || count > group.maxSelection) {
        return false;
      }
    }
    return true;
  }

  List<ModifierOption> get _allSelectedModifiers =>
      _selections.expand((s) => s).toList();

  void _increment(int groupIndex, ModifierOptionWithSupply optionWithSupply) {
    setState(() {
      final group = widget.modifierGroups[groupIndex].group;
      final current = _selections[groupIndex];
      if (current.length < group.maxSelection) {
        _selections[groupIndex] = [...current, optionWithSupply.option];
      }
    });
  }

  void _decrement(int groupIndex, ModifierOptionWithSupply optionWithSupply) {
    setState(() {
      final current = _selections[groupIndex];
      final idx = current.indexWhere((o) => o.id == optionWithSupply.option.id);
      if (idx >= 0) {
        final next = [...current];
        next.removeAt(idx);
        _selections[groupIndex] = next;
      }
    });
  }

  int _count(int groupIndex, int optionId) =>
      _selections[groupIndex].where((o) => o.id == optionId).length;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${widget.product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: widget.modifierGroups.length,
                  itemBuilder: (context, groupIndex) {
                    final groupWithOptions = widget.modifierGroups[groupIndex];
                    final group = groupWithOptions.group;
                    final selectedCount = _selections[groupIndex].length;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$selectedCount / ${group.maxSelection}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: selectedCount >= group.minSelection
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...groupWithOptions.options.map(
                              (opt) => _OptionRow(
                                supplyName: opt.supplyName,
                                priceExtra: opt.option.priceExtra,
                                count: _count(groupIndex, opt.option.id),
                                maxCount: group.maxSelection -
                                    _selections[groupIndex].length +
                                    _count(groupIndex, opt.option.id),
                                onIncrement: () =>
                                    _increment(groupIndex, opt),
                                onDecrement: () =>
                                    _decrement(groupIndex, opt),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isValid
                          ? () => Navigator.of(context).pop(_allSelectedModifiers)
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add to Cart',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.supplyName,
    required this.priceExtra,
    required this.count,
    required this.maxCount,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String supplyName;
  final double priceExtra;
  final int count;
  final int maxCount;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplyName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (priceExtra > 0)
                  Text(
                    '+\$${priceExtra.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                onPressed: count > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove, size: 18),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: maxCount > 0 ? onIncrement : null,
                icon: const Icon(Icons.add, size: 18),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
