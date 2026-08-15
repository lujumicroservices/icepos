import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/features/pos/presentation/checkout_dialog.dart';

class SplitPaymentEntry {
  SplitPaymentEntry({
    this.method = PaymentMethod.cash,
    this.amount = 0,
    this.cardType = CardType.debit,
    this.amountTendered = 0,
  });

  PaymentMethod method;
  double amount;
  CardType cardType;
  double amountTendered;

  Map<String, dynamic> toMap() => {
        'method': method.name,
        'amount': amount,
        if (method == PaymentMethod.card) 'cardType': cardType.name,
        if (method == PaymentMethod.cash && amountTendered > 0)
          'amountTendered': amountTendered,
      };
}

/// Editor for split payments until the cart total is fully covered.
class SplitPaymentEditor extends StatefulWidget {
  const SplitPaymentEditor({
    super.key,
    required this.cartTotal,
    required this.l10n,
    required this.onChanged,
  });

  final double cartTotal;
  final AppLocalizations l10n;
  final VoidCallback onChanged;

  @override
  State<SplitPaymentEditor> createState() => SplitPaymentEditorState();
}

class SplitPaymentEditorState extends State<SplitPaymentEditor> {
  final _entries = <SplitPaymentEntry>[
    SplitPaymentEntry(),
    SplitPaymentEntry(),
  ];

  List<SplitPaymentEntry> get entries => List.unmodifiable(_entries);

  double get paidTotal =>
      _entries.fold<double>(0, (sum, e) => sum + e.amount);

  double get remaining => widget.cartTotal - paidTotal;

  bool get isComplete => widget.cartTotal > 0 && remaining.abs() < 0.009;

  bool get cashTenderedValid {
    for (final e in _entries) {
      if (e.method != PaymentMethod.cash || e.amount <= 0) continue;
      if (e.amountTendered > 0 && e.amountTendered + 0.009 < e.amount) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> toPaymentMaps() =>
      _entries.where((e) => e.amount > 0).map((e) => e.toMap()).toList();

  void _notify() {
    widget.onChanged();
    setState(() {});
  }

  void _addEntry() {
    setState(() => _entries.add(SplitPaymentEntry()));
    _notify();
  }

  void _removeEntry(int index) {
    if (_entries.length <= 2) return;
    setState(() => _entries.removeAt(index));
    _notify();
  }

  void _fillRemaining(int index) {
    final left = remaining + _entries[index].amount;
    if (left <= 0) return;
    setState(() => _entries[index].amount = left);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final remainingColor = remaining.abs() < 0.009
        ? Theme.of(context).colorScheme.primary
        : remaining > 0
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: remainingColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: remainingColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isComplete
                    ? l10n.splitPaymentComplete
                    : remaining > 0
                        ? l10n.splitPaymentRemaining
                        : l10n.splitPaymentOverpaid,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: remainingColor,
                ),
              ),
              Text(
                '\$${remaining.abs().toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: remainingColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _entries.length; i++)
          _SplitPaymentRow(
            key: ValueKey('split_$i'),
            index: i,
            entry: _entries[i],
            l10n: l10n,
            canRemove: _entries.length > 2,
            onRemove: () => _removeEntry(i),
            onFillRemaining: remaining > 0 ? () => _fillRemaining(i) : null,
            onChanged: _notify,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addEntry,
          icon: const Icon(Icons.add),
          label: Text(l10n.addPaymentMethod),
        ),
      ],
    );
  }
}

class _SplitPaymentRow extends StatefulWidget {
  const _SplitPaymentRow({
    super.key,
    required this.index,
    required this.entry,
    required this.l10n,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.onFillRemaining,
  });

  final int index;
  final SplitPaymentEntry entry;
  final AppLocalizations l10n;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback? onFillRemaining;

  @override
  State<_SplitPaymentRow> createState() => _SplitPaymentRowState();
}

class _SplitPaymentRowState extends State<_SplitPaymentRow> {
  late final TextEditingController _amountController;
  late final TextEditingController _tenderedController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.entry.amount > 0 ? widget.entry.amount.toStringAsFixed(2) : '',
    );
    _tenderedController = TextEditingController(
      text: widget.entry.amountTendered > 0
          ? widget.entry.amountTendered.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tenderedController.dispose();
    super.dispose();
  }

  void _syncAmount() {
    widget.entry.amount = parseDecimal(_amountController.text) ?? 0;
    widget.onChanged();
  }

  void _syncTendered() {
    widget.entry.amountTendered = parseDecimal(_tenderedController.text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final e = widget.entry;
    final isEn = l10n.locale.languageCode == 'en';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${l10n.payment} ${widget.index + 1}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: l10n.remove,
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniMethodChip(
                    label: l10n.cash,
                    icon: Icons.payments,
                    selected: e.method == PaymentMethod.cash,
                    onTap: () {
                      setState(() => e.method = PaymentMethod.cash);
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniMethodChip(
                    label: l10n.card,
                    icon: Icons.credit_card,
                    selected: e.method == PaymentMethod.card,
                    onTap: () {
                      setState(() => e.method = PaymentMethod.card);
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniMethodChip(
                    label: l10n.transfer,
                    icon: Icons.phone_android,
                    selected: e.method == PaymentMethod.transfer,
                    onTap: () {
                      setState(() => e.method = PaymentMethod.transfer);
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (e.method == PaymentMethod.card) ...[
              const SizedBox(height: 10),
              SegmentedButton<CardType>(
                segments: [
                  ButtonSegment(
                    value: CardType.debit,
                    label: Text(l10n.debit, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: CardType.credit,
                    label: Text(l10n.credit, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ],
                selected: {e.cardType},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  setState(() => e.cardType = s.first);
                  widget.onChanged();
                },
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.amount,
                      prefixText: r'$ ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _syncAmount(),
                  ),
                ),
                if (widget.onFillRemaining != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onFillRemaining,
                    child: Text(
                      isEn ? 'Rest' : 'Resto',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            if (e.method == PaymentMethod.cash) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _tenderedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.amountReceived,
                  prefixText: r'$ ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _syncTendered(),
              ),
              if (e.amountTendered > 0 && e.amount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${l10n.change}: \$${(e.amountTendered - e.amount).clamp(0, double.infinity).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMethodChip extends StatelessWidget {
  const _MiniMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
