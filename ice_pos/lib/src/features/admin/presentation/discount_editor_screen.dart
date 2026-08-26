import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/discount_type.dart';

class DiscountEditorScreen extends ConsumerStatefulWidget {
  const DiscountEditorScreen({
    super.key,
    this.discountId,
    this.initialCode,
    this.initialType,
    this.initialPercentage,
    this.initialDescription,
    this.initialIsActive = true,
  });

  final int? discountId;
  final String? initialCode;
  final String? initialType;
  final double? initialPercentage;
  final String? initialDescription;
  final bool initialIsActive;

  @override
  ConsumerState<DiscountEditorScreen> createState() =>
      _DiscountEditorScreenState();
}

class _DiscountEditorScreenState extends ConsumerState<DiscountEditorScreen> {
  final _codeController = TextEditingController();
  final _percentageController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = DiscountType.percentage;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.initialCode ?? '';
    _type = DiscountType.isValid(widget.initialType ?? '')
        ? widget.initialType!
        : DiscountType.percentage;
    final pct = widget.initialPercentage ?? 0.1;
    _percentageController.text =
        (pct * 100).toStringAsFixed(pct * 100 % 1 == 0 ? 0 : 1);
    _descriptionController.text = widget.initialDescription ?? '';
    _isActive = widget.initialIsActive;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.discountCodeRequired)),
      );
      return;
    }

    var percentage = 0.0;
    if (_type == DiscountType.percentage) {
      final pct = double.tryParse(_percentageController.text.trim());
      if (pct == null || pct <= 0 || pct > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidPercentage)),
        );
        return;
      }
      percentage = pct / 100;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(posRepositoryProvider).saveDiscount(
            id: widget.discountId,
            code: code,
            type: _type,
            percentage: percentage,
            description: _descriptionController.text.trim(),
            isActive: _isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.discountSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final isEdit = widget.discountId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.editDiscount : l10n.newDiscount,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: l10n.discountCode,
              hintText: 'EMPLEADO2026',
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.discountType,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: DiscountType.employee,
                label: Text(l10n.discountTypeEmployee),
                icon: const Icon(Icons.badge_outlined),
              ),
              ButtonSegment(
                value: DiscountType.percentage,
                label: Text(l10n.discountTypePercentage),
                icon: const Icon(Icons.percent),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() => _type = s.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _type == DiscountType.employee
                ? l10n.discountTypeEmployeeHint
                : l10n.discountTypePercentageHint,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_type == DiscountType.percentage) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _percentageController,
              decoration: InputDecoration(
                labelText: l10n.percentageHint,
                border: const OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.descriptionOptional,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.active),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isSaving ? null : () => _save(l10n),
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
