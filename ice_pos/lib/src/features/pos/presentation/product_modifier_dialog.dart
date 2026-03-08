import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

/// Result of the modifier dialog: selected modifiers and quantity (e.g. piezas for bolis).
class ModifierDialogResult {
  const ModifierDialogResult({
    required this.modifiers,
    this.quantity = 1,
  });
  final List<ModifierOption> modifiers;
  final double quantity;
}

/// Dialog for selecting product modifiers (e.g., ice cream flavors) and optional quantity.
class ProductModifierDialog extends StatefulWidget {
  const ProductModifierDialog({
    super.key,
    required this.product,
    required this.modifierGroups,
    this.showQuantitySelector = true,
  });

  final Product product;
  final List<ModifierGroupWithOptions> modifierGroups;
  /// When true, shows a "Cantidad (piezas)" stepper so operator can add multiple units at once.
  final bool showQuantitySelector;

  @override
  State<ProductModifierDialog> createState() => _ProductModifierDialogState();
}

class _ProductModifierDialogState extends State<ProductModifierDialog> {
  /// Per-group: list of selected ModifierOptions (duplicates allowed for count).
  late List<List<ModifierOption>> _selections;
  double _quantity = 1;

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

  /// Derives subgroup (e.g. "Regular", "Light") and short display name from supply name.
  static ({String? subgroup, String displayName}) _subgroupAndName(String supplyName) {
    if (supplyName.startsWith('Boli Regular - ')) {
      return (subgroup: 'Regular', displayName: supplyName.replaceFirst('Boli Regular - ', ''));
    }
    if (supplyName.startsWith('Boli Light - ')) {
      return (subgroup: 'Light', displayName: supplyName.replaceFirst('Boli Light - ', ''));
    }
    if (supplyName.startsWith('Paleta Agua - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Paleta Agua - ', ''));
    }
    if (supplyName.startsWith('Paleta Forrada - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Paleta Forrada - ', ''));
    }
    if (supplyName.startsWith('Nieve AGUA - ')) {
      return (subgroup: 'AGUA', displayName: supplyName.replaceFirst('Nieve AGUA - ', ''));
    }
    if (supplyName.startsWith('Nieve LECHE - ')) {
      return (subgroup: 'LECHE', displayName: supplyName.replaceFirst('Nieve LECHE - ', ''));
    }
    if (supplyName.startsWith('Nieve CREMA - ')) {
      return (subgroup: 'CREMA', displayName: supplyName.replaceFirst('Nieve CREMA - ', ''));
    }
    if (supplyName.startsWith('Nieve LIGHT - ')) {
      return (subgroup: 'LIGHT', displayName: supplyName.replaceFirst('Nieve LIGHT - ', ''));
    }
    if (supplyName.startsWith('Malteada - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Malteada - ', ''));
    }
    return (subgroup: null, displayName: supplyName);
  }

  String _buttonLabel() {
    if (widget.modifierGroups.length == 1 &&
        widget.modifierGroups.first.group.maxSelection > 1) {
      final n = _allSelectedModifiers.length;
      return n > 0 ? 'Agregar ($n)' : 'Add to Cart';
    }
    if (widget.showQuantitySelector && _quantity > 1) {
      return 'Agregar al carrito (${_quantity.round()})';
    }
    return 'Add to Cart';
  }

  List<Widget> _buildOptionsWithSubgroups(
    int groupIndex,
    List<ModifierOptionWithSupply> options,
    int maxSelection,
  ) {
    final selections = _selections[groupIndex];
    final currentTotal = selections.length;
    final widgets = <Widget>[];
    String? lastSubgroup;
    for (final opt in options) {
      final parsed = _subgroupAndName(opt.supplyName);
      if (parsed.subgroup != null && parsed.subgroup != lastSubgroup) {
        lastSubgroup = parsed.subgroup;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              parsed.subgroup!,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      } else if (parsed.subgroup == null && lastSubgroup != null) {
        lastSubgroup = null;
      }
      widgets.add(
        _OptionRow(
          supplyName: parsed.displayName,
          priceExtra: opt.option.priceExtra,
          count: _count(groupIndex, opt.option.id),
          maxCount: maxSelection - currentTotal + _count(groupIndex, opt.option.id),
          onIncrement: () => _increment(groupIndex, opt),
          onDecrement: () => _decrement(groupIndex, opt),
        ),
      );
    }
    return widgets;
  }

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
                            ..._buildOptionsWithSubgroups(
                              groupIndex,
                              groupWithOptions.options,
                              group.maxSelection,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.showQuantitySelector &&
                  !(widget.modifierGroups.length == 1 &&
                      widget.modifierGroups.first.group.maxSelection > 1)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cantidad (piezas)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filled(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity -= 1)
                                : null,
                            icon: const Icon(Icons.remove, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(10),
                              minimumSize: const Size(44, 44),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _quantity.toInt().toString(),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: _quantity < 99
                                ? () => setState(() => _quantity += 1)
                                : null,
                            icon: const Icon(Icons.add, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(10),
                              minimumSize: const Size(44, 44),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isValid
                          ? () {
                              // Boli-style: each selected modifier = one piece (min != max).
                              // Nieves-style: N selections = one item with N flavor choices (min == max).
                              final g = widget.modifierGroups.length == 1
                                  ? widget.modifierGroups.first.group
                                  : null;
                              final quantityIsPiezas = g != null &&
                                  g.maxSelection > 1 &&
                                  g.minSelection != g.maxSelection;
                              final totalPiezas = quantityIsPiezas
                                  ? _allSelectedModifiers.length.toDouble()
                                  : _quantity;
                              Navigator.of(context).pop(
                                ModifierDialogResult(
                                  modifiers: _allSelectedModifiers,
                                  quantity: totalPiezas,
                                ),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _buttonLabel(),
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
