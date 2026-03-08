import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
  });

  final double cartTotal;

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  CardType _cardType = CardType.debit;
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.cartTotal > 0 ? widget.cartTotal.toStringAsFixed(2) : '';
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double get _amountReceived {
    final v = double.tryParse(
      _amountController.text.replaceFirst(',', '.'),
    );
    return v ?? 0.0;
  }

  bool get _canConfirm {
    if (_selectedMethod == PaymentMethod.cash) {
      return _amountReceived >= widget.cartTotal && widget.cartTotal > 0;
    }
    return widget.cartTotal > 0;
  }

  void _setAmount(double value) {
    _amountController.text = value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Checkout',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total: \$${widget.cartTotal.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    label: 'Cash',
                    icon: Icons.payments,
                    selected: _selectedMethod == PaymentMethod.cash,
                    onTap: () => setState(() => _selectedMethod = PaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MethodChip(
                    label: 'Card',
                    icon: Icons.credit_card,
                    selected: _selectedMethod == PaymentMethod.card,
                    onTap: () => setState(() => _selectedMethod = PaymentMethod.card),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MethodChip(
                    label: 'Transfer',
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.inter()),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () {
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
          child: Text('Confirm Sale', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildCashSection() {
    final change = _amountReceived - widget.cartTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cantidad Recibida',
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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixText: r'$ ',
          ),
          style: GoogleFonts.inter(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () => _setAmount(widget.cartTotal),
              child: const Text('Exact Amount'),
            ),
            FilledButton.tonal(
              onPressed: () => _setAmount(100),
              child: const Text('\$100'),
            ),
            FilledButton.tonal(
              onPressed: () => _setAmount(200),
              child: const Text('\$200'),
            ),
            FilledButton.tonal(
              onPressed: () => _setAmount(500),
              child: const Text('\$500'),
            ),
          ],
        ),
        if (_amountReceived > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Change: \$${change >= 0 ? change.toStringAsFixed(2) : '0.00'}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: change >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Card type',
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
                segments: const [
                  ButtonSegment<CardType>(
                    value: CardType.debit,
                    label: Text('Debit'),
                    icon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  ButtonSegment<CardType>(
                    value: CardType.credit,
                    label: Text('Credit'),
                    icon: Icon(Icons.credit_card_outlined),
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
        'Verify transfer in banking app before confirming.',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
