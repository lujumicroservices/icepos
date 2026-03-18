import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashController = TextEditingController();
  final _debitController = TextEditingController();
  final _creditController = TextEditingController();
  final _notesController = TextEditingController();

  Shift? _shift;
  ShiftTotalsForClosure? _totals;
  /// true = resumen final (con detalle y discrepancias). Desde ahí puede Volver o Cerrar corte.
  bool _showSummary = false;
  double _declaredCash = 0;
  double _declaredDebit = 0;
  double _declaredCredit = 0;
  /// Non-null solo después de haber cerrado el corte (pantalla muestra "Listo").
  ShiftClosureResult? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentShift();
  }

  Future<void> _loadCurrentShift() async {
    var shift = await ref.read(posRepositoryProvider).getCurrentShift();
    if (shift == null && mounted) {
      shift = await ref.read(posRepositoryProvider).startShift(0);
    }
    if (!mounted) return;
    if (shift != null && CloudSyncService.isEnabled) {
      final db = ref.read(appDatabaseProvider);
      await CloudSyncService.pullMovementsForShift(db, shift.id);
    }
    if (!mounted) return;
    ShiftTotalsForClosure? totals;
    if (shift != null) {
      totals = await ref.read(posRepositoryProvider).getShiftTotalsForClosure(shift.id);
    }
    setState(() {
      _shift = shift;
      _totals = totals;
      _error = null;
      // Débito y crédito se dejan vacíos: el usuario debe ingresar el valor que reporta la terminal.
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitToSummary() async {
    final l10n = ref.read(appLocalizationsProvider);
    final cash = parseDecimal(_cashController.text);
    if (cash == null || cash < 0) {
      setState(() => _error = l10n.validAmount);
      return;
    }
    final debit = parseDecimal(_debitController.text);
    final credit = parseDecimal(_creditController.text);
    if (debit == null || credit == null || debit < 0 || credit < 0) {
      setState(() => _error = l10n.cardDeclaredRequired);
      return;
    }
    setState(() {
      _error = null;
      _declaredCash = cash;
      _declaredDebit = debit;
      _declaredCredit = credit;
      _showSummary = true;
    });
  }

  void _goBackToForm() {
    setState(() => _showSummary = false);
  }

  Future<void> _showAdjustStartingFundDialog(AppLocalizations l10n) async {
    if (_shift == null) return;
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajustar fondo inicial'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Efectivo que había en caja al iniciar este turno (o el monto actual si no hubo ventas).',
                style: GoogleFonts.inter(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Fondo inicial (\$)',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final v = parseDecimal(controller.text);
                if (v != null && v >= 0) Navigator.pop(ctx, v);
              },
              child: Text(l10n.apply),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted) return;
    if (result != null && _shift != null) {
      await ref.read(posRepositoryProvider).updateShiftStartingFund(_shift!.id, result);
      await _loadCurrentShift();
    }
  }

  Future<void> _confirmCloseCut() async {
    if (_shift == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(posRepositoryProvider).performCloseShift(
            shiftId: _shift!.id,
            declaredCash: _declaredCash,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (mounted) {
        // El siguiente turno inicia con el efectivo que quedó en caja en el corte anterior.
        await ref.read(posRepositoryProvider).startShift(_declaredCash);
      }
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _shift = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.closeShift,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _showSummary
          ? _buildSummary(l10n)
          : _buildForm(l10n),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    final t = _totals;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: Colors.red.shade800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_shift == null || t == null)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else ...[
            if (t.expectedCashInDrawer == 0) ...[
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '¿Reinstalaste la app?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Si no hay ventas en este turno pero sí efectivo en caja, ajusta el fondo inicial para poder hacer el corte correctamente.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAdjustStartingFundDialog(l10n),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Ajustar fondo inicial'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.expectedCashInDrawer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${t.expectedCashInDrawer.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Fondo inicial + ventas efectivo + entradas - salidas',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.enterCountedAmounts,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              decoration: InputDecoration(
                labelText: l10n.totalCashInDrawer,
                hintText: l10n.totalCashInDrawerHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _debitController,
              decoration: InputDecoration(
                labelText: l10n.salesDebit,
                hintText: l10n.cardTerminalHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _creditController,
              decoration: InputDecoration(
                labelText: l10n.salesCredit,
                hintText: l10n.cardTerminalHint,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.salesTransfer,
                border: const OutlineInputBorder(),
                prefixText: r'$ ',
                filled: true,
              ),
              child: Text(
                t.transferSales.toStringAsFixed(2),
                style: GoogleFonts.inter(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitToSummary,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.next,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Resumen final: mismo detalle y discrepancias. Si aún no se cerró, muestra Volver + Cerrar corte; si ya se cerró, Imprimir + Listo.
  Widget _buildSummary(AppLocalizations l10n) {
    final closed = _result != null;
    final t = _totals;
    final r = _result;

    double cashSales;
    double cardSales;
    double transferSales;
    double totalSales;
    double startingFund;
    double movementsCajaNet;
    double expectedCash;
    double declaredCash;
    double difference;

    if (r != null) {
      cashSales = r.cashSales;
      cardSales = r.cardSales;
      transferSales = r.transferSales;
      totalSales = r.totalSales;
      startingFund = r.startingFund;
      movementsCajaNet = r.movementsCajaNet;
      expectedCash = r.closure.systemExpectedCash;
      declaredCash = r.closure.declaredCash;
      difference = r.closure.difference;
    } else if (t != null) {
      cashSales = t.cashSales;
      cardSales = t.cardSales;
      transferSales = t.transferSales;
      totalSales = t.totalSales;
      startingFund = t.startingFund;
      movementsCajaNet = t.movementsCajaNet;
      expectedCash = t.expectedCashInDrawer;
      declaredCash = _declaredCash;
      difference = _declaredCash - t.expectedCashInDrawer;
    } else {
      return const Center(child: CircularProgressIndicator());
    }

    final cashBalanced = difference.abs() < 0.01;
    final cardMismatch = !closed && t != null &&
        (_declaredDebit + _declaredCredit - (t.debitSales + t.creditSales)).abs() >= 0.01;
    final isBalanced = cashBalanced && !cardMismatch;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.closureSummary,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ventas por forma de pago',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: l10n.cash, value: '\$${cashSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.card, value: '\$${cardSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.transfer, value: '\$${transferSales.toStringAsFixed(2)}'),
          _SummaryRow(label: l10n.total, value: '\$${totalSales.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          Text(
            'Caja',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Fondo inicial', value: '\$${startingFund.toStringAsFixed(2)}'),
          _SummaryRow(
            label: l10n.movementsCajaNetLabel,
            value: movementsCajaNet >= 0
                ? '+\$${movementsCajaNet.toStringAsFixed(2)}'
                : '-\$${movementsCajaNet.abs().toStringAsFixed(2)}',
          ),
          const Divider(height: 32),
          if (!closed && t != null) ...[
            Text(
              'Cantidades declaradas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _SummaryRow(label: l10n.totalCashInDrawer, value: '\$${_declaredCash.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesDebit, value: '\$${_declaredDebit.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesCredit, value: '\$${_declaredCredit.toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.salesTransfer, value: '\$${t.transferSales.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _SummaryRow(label: l10n.cardSalesSystem, value: '\$${(t.debitSales + t.creditSales).toStringAsFixed(2)}'),
            _SummaryRow(label: l10n.cardDeclared, value: '\$${(_declaredDebit + _declaredCredit).toStringAsFixed(2)}'),
            if ((_declaredDebit + _declaredCredit - (t.debitSales + t.creditSales)).abs() >= 0.01) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cardMismatchTitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.cardMismatchMessage,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          _SummaryRow(label: 'Esperado en caja', value: '\$${expectedCash.toStringAsFixed(2)}'),
          _SummaryRow(label: 'Declarado (efectivo)', value: '\$${declaredCash.toStringAsFixed(2)}'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanced ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Center(
              child: Text(
                isBalanced
                    ? l10n.closureCorrect
                    : cardMismatch && cashBalanced
                        ? l10n.closureIncorrectCardOnly
                        : cardMismatch && !cashBalanced
                            ? l10n.closureIncorrectCashAndCard.replaceAll(
                                '{amount}',
                                '\$${difference.abs().toStringAsFixed(2)}',
                              )
                            : l10n.differenceInCash.replaceAll(
                                '{amount}',
                                '\$${difference.abs().toStringAsFixed(2)}',
                              ),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!closed) ...[
            const SizedBox(height: 24),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.red.shade800, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _goBackToForm,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.goBack),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _confirmCloseCut,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(l10n.closeCut),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Imprimir corte'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.done),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
