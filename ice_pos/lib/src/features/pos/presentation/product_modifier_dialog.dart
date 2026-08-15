import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_display.dart';

/// Result of the modifier dialog: selected modifiers and quantity (e.g. piezas for bolis).
class ModifierDialogResult {
  const ModifierDialogResult({
    required this.modifiers,
    this.modifierLabels = const [],
    this.quantity = 1,
  });
  final List<ModifierOption> modifiers;
  final List<String> modifierLabels;
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
  static ({String? subgroup, String displayName}) _subgroupAndName(String supplyName) =>
      ModifierDisplay.parse(supplyName);

  List<String> _labelsForSelectedModifiers() {
    final optionById = <int, String>{};
    for (final g in widget.modifierGroups) {
      for (final opt in g.options) {
        optionById[opt.option.id] = ModifierDisplay.ticketLabel(opt.supplyName);
      }
    }
    return [
      for (final mod in _allSelectedModifiers)
        optionById[mod.id] ?? 'Opción ${mod.id}',
    ];
  }

  bool _useFlavorGrid(ModifierGroupWithOptions groupWithOptions) {
    final names = groupWithOptions.options.map((o) => o.supplyName);
    return names.any((n) => n.startsWith('Boli Regular - ')) ||
        names.any((n) => n.startsWith('Boli Light - ')) ||
        names.any((n) => n.startsWith('Nieve AGUA - ')) ||
        names.any((n) => n.startsWith('Nieve LECHE - ')) ||
        names.any((n) => n.startsWith('Nieve CREMA - ')) ||
        names.any((n) => n.startsWith('Nieve LIGHT - '));
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
          networkImageUrl: opt.option.imageUrl,
          onIncrement: () => _increment(groupIndex, opt),
          onDecrement: () => _decrement(groupIndex, opt),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final hasFlavorGrid = widget.modifierGroups.any(_useFlavorGrid);
    return DraggableScrollableSheet(
      initialChildSize: hasFlavorGrid ? 0.86 : 0.6,
      minChildSize: hasFlavorGrid ? 0.55 : 0.4,
      maxChildSize: 0.95,
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
                            if (_useFlavorGrid(groupWithOptions))
                              _FlavorOptionsGrid(
                                options: groupWithOptions.options,
                                countForOption: (optionId) =>
                                    _count(groupIndex, optionId),
                                maxCountForOption: (optionId) => group.maxSelection -
                                    selectedCount +
                                    _count(groupIndex, optionId),
                                onIncrement: (opt) => _increment(groupIndex, opt),
                                onDecrement: (opt) => _decrement(groupIndex, opt),
                              )
                            else
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
                                  modifierLabels: _labelsForSelectedModifiers(),
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

class _FlavorOptionsGrid extends StatelessWidget {
  const _FlavorOptionsGrid({
    required this.options,
    required this.countForOption,
    required this.maxCountForOption,
    required this.onIncrement,
    required this.onDecrement,
  });

  final List<ModifierOptionWithSupply> options;
  final int Function(int optionId) countForOption;
  final int Function(int optionId) maxCountForOption;
  final void Function(ModifierOptionWithSupply option) onIncrement;
  final void Function(ModifierOptionWithSupply option) onDecrement;

  static ({String? subgroup, String displayName}) _subgroupAndName(String supplyName) {
    if (supplyName.startsWith('Boli Regular - ')) {
      return (subgroup: 'Regular', displayName: supplyName.replaceFirst('Boli Regular - ', ''));
    }
    if (supplyName.startsWith('Boli Light - ')) {
      return (subgroup: 'Light', displayName: supplyName.replaceFirst('Boli Light - ', ''));
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
    return (subgroup: null, displayName: supplyName);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _assetPathForFlavor(String displayName) {
    final slug = _normalize(displayName);
    return 'assets/images/flavors/$slug.png';
  }

  static IconData _iconForFlavor(String normalized) {
    if (normalized.contains('limon')) return Icons.local_bar;
    if (normalized.contains('mango')) return Icons.local_florist;
    if (normalized.contains('chocolate') || normalized.contains('nutella')) return Icons.icecream;
    if (normalized.contains('fresa') || normalized.contains('picafresa')) return Icons.local_pizza;
    if (normalized.contains('coco')) return Icons.eco;
    if (normalized.contains('cafe')) return Icons.coffee;
    if (normalized.contains('uva')) return Icons.grain;
    if (normalized.contains('panditas') || normalized.contains('chicle')) return Icons.toys;
    if (normalized.contains('mazapan') || normalized.contains('nuez') || normalized.contains('pinon')) {
      return Icons.spa;
    }
    if (normalized.contains('oreo') || normalized.contains('comegalletas')) return Icons.cookie;
    if (normalized.contains('rompope') || normalized.contains('vainilla')) return Icons.ac_unit;
    if (normalized.contains('hierbabuena') || normalized.contains('tejuino')) return Icons.grass;
    if (normalized.contains('tamarindo') || normalized.contains('jamaica')) return Icons.local_drink;
    return Icons.icecream_outlined;
  }

  static Color _colorForFlavor(BuildContext context, String normalized) {
    final scheme = Theme.of(context).colorScheme;
    if (normalized.contains('fresa') || normalized.contains('picafresa') || normalized.contains('frutos rojos')) {
      return Colors.pink.shade300;
    }
    if (normalized.contains('mango') || normalized.contains('elote') || normalized.contains('mazapan')) {
      return Colors.amber.shade400;
    }
    if (normalized.contains('chocolate') || normalized.contains('nutella') || normalized.contains('ferrero')) {
      return Colors.brown.shade400;
    }
    if (normalized.contains('limon') || normalized.contains('hierbabuena') || normalized.contains('pepino')) {
      return Colors.green.shade400;
    }
    if (normalized.contains('coco') || normalized.contains('vainilla') || normalized.contains('rompope')) {
      return Colors.teal.shade200;
    }
    if (normalized.contains('uva') || normalized.contains('taro')) {
      return Colors.deepPurple.shade300;
    }
    return scheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ModifierOptionWithSupply>>{};
    for (final opt in options) {
      final parsed = _subgroupAndName(opt.supplyName);
      final key = parsed.subgroup ?? '';
      grouped.putIfAbsent(key, () => []).add(opt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          if (entry.key.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: entry.value.length,
            itemBuilder: (context, idx) {
              final opt = entry.value[idx];
              final parsed = _subgroupAndName(opt.supplyName);
              final normalized = _normalize(parsed.displayName);
              final count = countForOption(opt.option.id);
              final maxCount = maxCountForOption(opt.option.id);
              return _FlavorGridTile(
                name: parsed.displayName,
                priceExtra: opt.option.priceExtra,
                count: count,
                maxCount: maxCount,
                networkImageUrl: opt.option.imageUrl,
                assetPath: _assetPathForFlavor(parsed.displayName),
                icon: _iconForFlavor(normalized),
                color: _colorForFlavor(context, normalized),
                onIncrement: () => onIncrement(opt),
                onDecrement: () => onDecrement(opt),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FlavorGridTile extends StatelessWidget {
  const _FlavorGridTile({
    required this.name,
    required this.priceExtra,
    required this.count,
    required this.maxCount,
    this.networkImageUrl,
    required this.assetPath,
    required this.icon,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String name;
  final double priceExtra;
  final int count;
  final int maxCount;
  final String? networkImageUrl;
  final String assetPath;
  final IconData icon;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  Widget _imageFallback() {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Center(
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAdd = maxCount > 0;
    final net = networkImageUrl?.trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canAdd ? onIncrement : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (net != null && net.isNotEmpty)
                              ? Image.network(
                                  net,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _imageFallback(),
                                )
                              : _imageFallback(),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.inter(
                                color: scheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (priceExtra > 0)
              Text(
                '+\$${priceExtra.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            SizedBox(
              height: 28,
              child: count > 0
                  ? Center(
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                        tooltip: 'Quitar',
                        onPressed: onDecrement,
                        icon: Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.supplyName,
    required this.priceExtra,
    required this.count,
    required this.maxCount,
    this.networkImageUrl,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String supplyName;
  final double priceExtra;
  final int count;
  final int maxCount;
  final String? networkImageUrl;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = networkImageUrl?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              color: scheme.surfaceContainerHighest,
              child: (net != null && net.isNotEmpty)
                  ? Image.network(
                      net,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.icecream, size: 22, color: scheme.outline),
                    )
                  : Icon(Icons.icecream, size: 22, color: scheme.outline),
            ),
          ),
          const SizedBox(width: 10),
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
