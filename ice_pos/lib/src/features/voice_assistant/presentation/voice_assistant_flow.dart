import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/create_movement_payload.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/voice_intent.dart';
import 'package:ice_pos/src/features/voice_assistant/execution/movement_submit.dart';
import 'package:ice_pos/src/features/voice_assistant/parsing/voice_command_router.dart';
import 'package:ice_pos/src/features/voice_assistant/presentation/voice_confirm_sheet.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Starts mic (or text fallback on web) → parse → confirm → submit movement.
Future<void> startVoiceMovementFlow(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onCloudRefresh,
}) async {
  final l10n = ref.read(appLocalizationsProvider);
  final router = VoiceCommandRouter();

  String? transcript;
  if (kIsWeb) {
    transcript = await _promptTextFallback(context, l10n);
  } else {
    transcript = await _listenWithMic(context, l10n);
  }
  if (!context.mounted || transcript == null || transcript.trim().isEmpty) return;

  var result = router.route(transcript);
  if (result.intent == VoiceIntent.unknown) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceCommandNotUnderstood)),
      );
    }
    return;
  }

  CreateMovementPayload? payload = result.movement;
  if (payload == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceCommandNotUnderstood)),
      );
    }
    return;
  }

  if (!context.mounted) return;
  payload = await showVoiceConfirmSheet(
    context,
    ref,
    initial: payload,
    transcript: result.transcript,
    missingFields: result.missingFields,
  );
  if (!context.mounted || payload == null) return;

  final feedback = await submitMovement(
    ref: ref,
    payload: payload,
    onCloudRefresh: onCloudRefresh,
  );
  if (!context.mounted || feedback == null) return;

  final isError = feedback.contains('Error') ||
      feedback.contains('error') ||
      feedback.contains('internet') ||
      feedback.contains('Internet');
  showMovementSubmitFeedback(context, feedback, isError: isError);
}

Future<String?> _listenWithMic(BuildContext context, AppLocalizations l10n) async {
  final mic = await Permission.microphone.request();
  if (!mic.isGranted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceMicPermissionDenied)),
      );
    }
    return null;
  }

  final stt = SpeechToText();
  final available = await stt.initialize(
    onError: (_) {},
    onStatus: (_) {},
  );
  if (!available) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceSttUnavailable)),
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (ctx) => _VoiceListenSheet(stt: stt, l10n: l10n),
  );
}

Future<String?> _promptTextFallback(BuildContext context, AppLocalizations l10n) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.voiceTextFallbackTitle),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: l10n.voiceTextFallbackHint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(l10n.voiceContinue),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

class _VoiceListenSheet extends StatefulWidget {
  const _VoiceListenSheet({required this.stt, required this.l10n});

  final SpeechToText stt;
  final AppLocalizations l10n;

  @override
  State<_VoiceListenSheet> createState() => _VoiceListenSheetState();
}

class _VoiceListenSheetState extends State<_VoiceListenSheet> {
  var _words = '';
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    await widget.stt.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _words = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          unawaited(_finish(r.recognizedWords.trim()));
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'es_MX',
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _finish(String text) async {
    await widget.stt.stop();
    if (mounted) Navigator.pop(context, text);
  }

  Future<void> _cancel() async {
    await widget.stt.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    unawaited(widget.stt.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            widget.l10n.voiceListening,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _words.isEmpty ? widget.l10n.voiceListeningHint : _words,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: Text(widget.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _words.trim().isEmpty ? null : () => _finish(_words.trim()),
                  child: Text(widget.l10n.voiceContinue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
