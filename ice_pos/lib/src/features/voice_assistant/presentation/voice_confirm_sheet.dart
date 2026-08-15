import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/create_movement_payload.dart';

/// Confirmation / edit sheet before registering a voice movement.
Future<CreateMovementPayload?> showVoiceConfirmSheet(
  BuildContext context,
  WidgetRef ref, {
  required CreateMovementPayload initial,
  required String transcript,
  List<String> missingFields = const [],
}) {
  final l10n = ref.read(appLocalizationsProvider);
  return showModalBottomSheet<CreateMovementPayload>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _VoiceConfirmSheet(
      l10n: l10n,
      initial: initial,
      transcript: transcript,
      missingFields: missingFields,
    ),
  );
}

class _VoiceConfirmSheet extends StatefulWidget {
  const _VoiceConfirmSheet({
    required this.l10n,
    required this.initial,
    required this.transcript,
    required this.missingFields,
  });

  final AppLocalizations l10n;
  final CreateMovementPayload initial;
  final String transcript;
  final List<String> missingFields;

  @override
  State<_VoiceConfirmSheet> createState() => _VoiceConfirmSheetState();
}

class _VoiceConfirmSheetState extends State<_VoiceConfirmSheet> {
  late String _type;
  late String _account;
  late TextEditingController _amountCtrl;
  late TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _account = widget.initial.account;
    _amountCtrl = TextEditingController(
      text: widget.initial.amount > 0 ? widget.initial.amount.toStringAsFixed(0) : '',
    );
    _reasonCtrl = TextEditingController(text: widget.initial.reason);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.voiceConfirmTitle,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '"${widget.transcript}"',
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (widget.missingFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.voiceConfirmIncomplete,
                style: GoogleFonts.inter(fontSize: 13, color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ENTRADA', label: Text(l10n.entry)),
                ButtonSegment(value: 'SALIDA', label: Text(l10n.exit)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: l10n.voiceAmountLabel,
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: InputDecoration(
                labelText: l10n.concept,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'CAJA', label: Text(l10n.accountCash)),
                ButtonSegment(value: 'BANCO', label: Text(l10n.accountBank)),
              ],
              selected: {_account},
              onSelectionChanged: (s) => setState(() => _account = s.first),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.voiceRegister),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final l10n = widget.l10n;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final reason = _reasonCtrl.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceInvalidAmount)),
      );
      return;
    }
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceMissingReason)),
      );
      return;
    }
    Navigator.pop(
      context,
      CreateMovementPayload(
        type: _type,
        amount: amount,
        reason: reason,
        account: _account,
      ),
    );
  }
}
