import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/features/pos/presentation/split_payment_editor.dart';

/// Payment method for checkout.
enum PaymentMethod {
  cash,
  card,
  transfer,
}

/// Card type when payment method is CARD.
enum CardType {
  debit,
  credit,
}

/// Result returned when the user confirms the sale.
class CheckoutResult {
  const CheckoutResult({
    required this.method,
    this.cardType,
    required this.amountReceived,
  });

  final PaymentMethod method;
  final CardType? cardType;
  final double amountReceived;

  Map<String, dynamic> toMap() => {
        'method': method.name.toUpperCase(),
        'cardType': cardType?.name.toUpperCase(),
        'amountReceived': amountReceived,
      };

  /// Payment method string for DB: CASH, CARD_DEBIT, CARD_CREDIT, TRANSFER.
  String get paymentMethodDb {
    switch (method) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.card:
        return cardType == CardType.credit ? 'CARD_CREDIT' : 'CARD_DEBIT';
      case PaymentMethod.transfer:
        return 'TRANSFER';
    }
  }
}

/// Dynamic checkout dialog: payment method, amount received (cash), card type, and confirm/cancel.
class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.cartTotal,
    this.l10n,
  });

  final double cartTotal;
  final AppLocalizations? l10n;

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  CardType _cardType = CardType.debit;
  bool _splitMode = false;
  final GlobalKey<SplitPaymentEditorState> _splitEditorKey = GlobalKey();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  static const _billDenominations = [500.0, 200.0, 100.0, 50.0, 20.0];
  static const _coinDenominations = [20.0, 10.0, 5.0, 2.0, 1.0];

  /// Cuántas veces se tocó cada denominación (permite sumar varios billetes).
  final Map<double, int> _denominationCounts = {};

  @override
  void initState() {
    super.initState();
    _amountController.text = '0.00';
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final fromText = parseDecimal(_amountController.text) ?? 0.0;
    final fromDenoms = _totalFromDenominations();
    if ((fromText - fromDenoms).abs() > 0.009) {
      _denominationCounts.clear();
    }
    setState(() {});
  }

  double _totalFromDenominations() {
    var total = 0.0;
    for (final e in _denominationCounts.entries) {
      total += e.key * e.value;
    }
    return total;
  }

  void _syncAmountField(double total) {
    _amountController.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double get _amountReceived {
    return parseDecimal(_amountController.text) ?? 0.0;
  }

  bool get _canConfirm {
    if (widget.cartTotal <= 0) return false;
    if (_splitMode) {
      final editor = _splitEditorKey.currentState;
      if (editor == null) return false;
      return editor.isComplete && editor.cashTenderedValid && editor.toPaymentMaps().isNotEmpty;
    }
    if (_selectedMethod == PaymentMethod.cash) {
      return _amountReceived >= widget.cartTotal;
    }
    return true;
  }

  void _setAmount(double value) {
    setState(() {
      _denominationCounts.clear();
      _amountController.text = value.toStringAsFixed(2);
    });
  }

  void _addDenomination(double value) {
    setState(() {
      _denominationCounts[value] = (_denominationCounts[value] ?? 0) + 1;
      _syncAmountField(_totalFromDenominations());
    });
  }

  void _removeOneDenomination(double value) {
    final count = _denominationCounts[value] ?? 0;
    if (count <= 0) return;
    setState(() {
      if (count == 1) {
        _denominationCounts.remove(value);
      } else {
        _denominationCounts[value] = count - 1;
      }
      _syncAmountField(_totalFromDenominations());
    });
  }

  void _clearTendered() => _setAmount(0);

  AppLocalizations get _l10n =>
      widget.l10n ?? AppLocalizations(const Locale('es'));

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(
        l10n.checkout,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.total}: \$${widget.cartTotal.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.singlePayment, style: GoogleFonts.inter(fontSize: 12)),
                  icon: const Icon(Icons.looks_one_outlined, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.splitPayment, style: GoogleFonts.inter(fontSize: 12)),
                  icon: const Icon(Icons.call_split, size: 18),
                ),
              ],
              selected: {_splitMode},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _splitMode = s.first);
              },
            ),
            const SizedBox(height: 16),
            if (!_splitMode) ...[
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    label: l10n.cash,
                    icon: Icons.payments,
                    selected: _selectedMethod == PaymentMethod.cash,
                    onTap: () => setState(() => _selectedMethod = PaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MethodChip(
                    label: l10n.card,
                    icon: Icons.credit_card,
                    selected: _selectedMethod == PaymentMethod.card,
                    onTap: () => setState(() => _selectedMethod = PaymentMethod.card),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MethodChip(
                    label: l10n.transfer,
                    icon: Icons.phone_android,
                    selected: _selectedMethod == PaymentMethod.transfer,
                    onTap: () => setState(() => _selectedMethod = PaymentMethod.transfer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedMethod == PaymentMethod.cash) _buildCashSection(),
            if (_selectedMethod == PaymentMethod.card) _buildCardSection(),
            if (_selectedMethod == PaymentMethod.transfer) _buildTransferSection(),
            ] else
              SplitPaymentEditor(
                key: _splitEditorKey,
                cartTotal: widget.cartTotal,
                l10n: l10n,
                onChanged: () => setState(() {}),
              ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_l10n.cancel, style: GoogleFonts.inter()),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () {
                  if (_splitMode) {
                    final editor = _splitEditorKey.currentState!;
                    Navigator.of(context).pop(<String, dynamic>{
                      'split': true,
                      'payments': editor.toPaymentMaps(),
                    });
                    return;
                  }
                  final amountTendered = _selectedMethod == PaymentMethod.cash
                      ? _amountReceived
                      : widget.cartTotal;
                  Navigator.of(context).pop(<String, dynamic>{
                    'method': _selectedMethod.name,
                    'amountTendered': amountTendered,
                    'cardType': _selectedMethod == PaymentMethod.card
                        ? _cardType.name
                        : null,
                  });
                }
              : null,
          child: Text(_l10n.confirmSale, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildCashSection() {
    final l10n = _l10n;
    final change = _amountReceived - widget.cartTotal;
    final isEn = l10n.locale.languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.amountReceived,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          focusNode: _amountFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixText: r'$ ',
            suffixIcon: _amountReceived > 0
                ? IconButton(
                    icon: const Icon(Icons.backspace_outlined),
                    tooltip: isEn ? 'Clear' : 'Borrar',
                    onPressed: _clearTendered,
                  )
                : null,
          ),
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        if (_denominationCounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in (_denominationCounts.entries.toList()
                ..sort((a, b) => b.key.compareTo(a.key))))
                InputChip(
                  label: Text(
                    '\$${entry.key.toStringAsFixed(entry.key == entry.key.roundToDouble() ? 0 : 2)}'
                    '${entry.value > 1 ? ' ×${entry.value}' : ''}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onDeleted: () {
                    setState(() {
                      _denominationCounts.remove(entry.key);
                      _syncAmountField(_totalFromDenominations());
                    });
                  },
                  deleteIcon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () => _setAmount(widget.cartTotal),
              child: Text(l10n.exactAmount),
            ),
            OutlinedButton(
              onPressed: _amountReceived > 0 ? _clearTendered : null,
              child: Text(isEn ? 'Clear' : 'Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isEn ? 'Bills' : 'Billetes',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _DenominationGrid(
          values: _billDenominations,
          counts: _denominationCounts,
          isCoin: false,
          onTap: _addDenomination,
          onLongPress: _removeOneDenomination,
        ),
        const SizedBox(height: 14),
        Text(
          isEn ? 'Coins' : 'Monedas',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        _DenominationGrid(
          values: _coinDenominations,
          counts: _denominationCounts,
          isCoin: true,
          onTap: _addDenomination,
          onLongPress: _removeOneDenomination,
        ),
        if (_amountReceived > 0) ...[
          const SizedBox(height: 20),
          _ChangeDisplay(
            change: change,
            label: l10n.change,
            exactLabel: l10n.exactAmount,
            locale: l10n.locale,
          ),
        ],
      ],
    );
  }

  Widget _buildCardSection() {
    final l10n = _l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l10n.card} (${l10n.debit}/${l10n.credit})',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<CardType>(
                segments: [
                  ButtonSegment<CardType>(
                    value: CardType.debit,
                    label: Text(l10n.debit),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  ButtonSegment<CardType>(
                    value: CardType.credit,
                    label: Text(l10n.credit),
                    icon: const Icon(Icons.credit_card_outlined),
                  ),
                ],
                selected: {_cardType},
                onSelectionChanged: (Set<CardType> s) {
                  if (s.isNotEmpty) setState(() => _cardType = s.first);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransferSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _l10n.verifyTransfer,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Grid of bill/coin tap targets; tap adds, long-press removes one.
class _DenominationGrid extends StatelessWidget {
  const _DenominationGrid({
    required this.values,
    required this.counts,
    required this.isCoin,
    required this.onTap,
    required this.onLongPress,
  });

  final List<double> values;
  final Map<double, int> counts;
  final bool isCoin;
  final void Function(double value) onTap;
  final void Function(double value) onLongPress;

  static String _label(double v) {
    final whole = v == v.roundToDouble();
    return whole ? '\$${v.toInt()}' : '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTile = 72.0;
        final cols = (constraints.maxWidth / minTile).floor().clamp(3, 5);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: isCoin ? 1.35 : 1.55,
          children: [
            for (final value in values)
              _DenominationTile(
                label: _label(value),
                count: counts[value] ?? 0,
                isCoin: isCoin,
                baseColor: isCoin ? scheme.secondaryContainer : scheme.primaryContainer,
                onColor: isCoin ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
                onTap: () => onTap(value),
                onLongPress: () => onLongPress(value),
              ),
          ],
        );
      },
    );
  }
}

class _DenominationTile extends StatelessWidget {
  const _DenominationTile({
    required this.label,
    required this.count,
    required this.isCoin,
    required this.baseColor,
    required this.onColor,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final int count;
  final bool isCoin;
  final Color baseColor;
  final Color onColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? baseColor : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCoin ? Icons.monetization_on_outlined : Icons.payments_outlined,
                    size: isCoin ? 20 : 22,
                    color: active
                        ? onColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: isCoin ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? onColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: onColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: baseColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cambio a entregar — grande y visible para el vendedor.
class _ChangeDisplay extends StatelessWidget {
  const _ChangeDisplay({
    required this.change,
    required this.label,
    required this.exactLabel,
    required this.locale,
  });

  final double change;
  final String label;
  final String exactLabel;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInsufficient = change < 0;
    final isExact = !isInsufficient && change < 0.005;
    final bg = isInsufficient
        ? scheme.errorContainer
        : isExact
            ? scheme.primaryContainer
            : scheme.tertiaryContainer;
    final fg = isInsufficient
        ? scheme.onErrorContainer
        : isExact
            ? scheme.onPrimaryContainer
            : scheme.onTertiaryContainer;
    final amount = isInsufficient ? change.abs() : change;
    final title = isInsufficient
        ? (locale.languageCode == 'en' ? 'SHORT' : 'FALTA')
        : isExact
            ? exactLabel.toUpperCase()
            : label.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 2.5),
        boxShadow: isInsufficient || isExact
            ? null
            : [
                BoxShadow(
                  color: fg.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: fg.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: isExact ? 36 : 48,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
