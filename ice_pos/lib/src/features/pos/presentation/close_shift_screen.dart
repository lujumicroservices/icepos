import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  ShiftClosureResult? _result;
  Shift? _shift;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentShift();
  }

  Future<void> _showStartShiftDialog(BuildContext context) async {
    final controller = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Shift'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Starting Fund (cash in drawer)',
            hintText: 'e.g. 500',
            border: OutlineInputBorder(),
            prefixText: '\$ ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, true);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final fund = double.tryParse(controller.text.trim()) ?? 0;
      await ref.read(posRepositoryProvider).startShift(fund);
      _loadCurrentShift();
    }
  }

  Future<void> _loadCurrentShift() async {
    final shift =
        await ref.read(posRepositoryProvider).getCurrentShift();
    if (mounted) {
      setState(() {
        _shift = shift;
        _error = shift == null ? 'No active shift. Start a shift first.' : null;
      });
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitBlindCount() async {
    if (_shift == null) return;
    final declared = double.tryParse(_cashController.text.trim());
    if (declared == null || declared < 0) {
      setState(() => _error = 'Enter a valid cash amount');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(posRepositoryProvider).performCloseShift(
            shiftId: _shift!.id,
            declaredCash: declared,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Close Shift',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _result != null ? _buildSummary() : _buildBlindCountForm(),
    );
  }

  Widget _buildBlindCountForm() {
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
          if (_shift == null && _error == null)
            const Center(child: CircularProgressIndicator())
          else if (_shift == null && _error != null) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showStartShiftDialog(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Shift'),
                  ),
                ],
              ),
            ),
          ]
          else if (_shift != null) ...[
            Text(
              'Step 1: Enter Total Cash in Drawer',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Count the physical cash in the drawer. Do NOT look at the expected amount.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _cashController,
              decoration: const InputDecoration(
                labelText: 'Enter Total Cash in Drawer',
                hintText: 'e.g. 580.50',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Petty cash withdrawal',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _submitBlindCount,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Submit',
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

  Widget _buildSummary() {
    final r = _result!;
    final c = r.closure;
    final isBalanced = c.difference.abs() < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shift Summary (Z-Report)',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryRow(
            label: 'Starting Fund',
            value: '\$${r.startingFund.toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Cash Sales',
            value: '\$${r.cashSales.toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Expenses',
            value: '-\$${r.expenses.toStringAsFixed(2)}',
          ),
          const Divider(height: 32),
          _SummaryRow(
            label: 'Expected',
            value: '\$${c.systemExpectedCash.toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Declared',
            value: '\$${c.declaredCash.toStringAsFixed(2)}',
          ),
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
                    ? 'Balanced'
                    : 'Discrepancy: \$${c.difference.abs().toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // Placeholder for print
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Z-Report'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
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
