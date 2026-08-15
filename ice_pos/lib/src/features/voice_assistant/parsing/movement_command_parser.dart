import 'package:ice_pos/src/features/voice_assistant/domain/create_movement_payload.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/voice_command_result.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/voice_intent.dart';
import 'package:ice_pos/src/features/voice_assistant/parsing/spanish_amount_parser.dart';

/// Rule-based parser for cash/bank movement voice commands (Spanish).
class MovementCommandParser {
  const MovementCommandParser();

  VoiceCommandResult parse(String rawTranscript) {
    final transcript = rawTranscript.trim();
    if (transcript.isEmpty) {
      return VoiceCommandResult(
        intent: VoiceIntent.unknown,
        transcript: transcript,
        confidence: 0,
        message: 'empty',
      );
    }

    final lower = transcript.toLowerCase();
    final looksLikeMovement = RegExp(
      r'\b(movimiento|entrada|salida|ingreso|egreso|retiro|deposito|depósito)\b',
    ).hasMatch(lower);

    if (!looksLikeMovement) {
      return VoiceCommandResult(
        intent: VoiceIntent.unknown,
        transcript: transcript,
        confidence: 0.1,
      );
    }

    final type = _parseType(lower);
    final account = _parseAccount(lower);
    final amount = SpanishAmountParser.parse(lower);
    final reason = _parseReason(transcript, lower);

    final missing = <String>[];
    if (type == null) missing.add('type');
    if (amount == null) missing.add('amount');
    if (reason == null || reason.isEmpty) missing.add('reason');

    var confidence = 0.55;
    if (type != null) confidence += 0.15;
    if (amount != null) confidence += 0.15;
    if (reason != null && reason.isNotEmpty) confidence += 0.15;

    if (missing.isNotEmpty) {
      return VoiceCommandResult(
        intent: VoiceIntent.createMovement,
        transcript: transcript,
        confidence: confidence.clamp(0, 1),
        movement: type != null && amount != null
            ? CreateMovementPayload(
                type: type,
                amount: amount,
                reason: reason ?? '',
                account: account,
              )
            : null,
        missingFields: missing,
      );
    }

    return VoiceCommandResult(
      intent: VoiceIntent.createMovement,
      transcript: transcript,
      confidence: confidence.clamp(0, 1),
      movement: CreateMovementPayload(
        type: type!,
        amount: amount!,
        reason: reason!,
        account: account,
      ),
    );
  }

  static String? _parseType(String lower) {
    if (RegExp(r'\b(salida|egreso|retiro|gasto|pago)\b').hasMatch(lower)) {
      return 'SALIDA';
    }
    if (RegExp(r'\b(entrada|ingreso|deposito|depósito|abono)\b').hasMatch(lower)) {
      return 'ENTRADA';
    }
    return null;
  }

  static String _parseAccount(String lower) {
    if (RegExp(r'\b(banco|cuenta bancaria|transferencia bancaria)\b').hasMatch(lower)) {
      return 'BANCO';
    }
    return 'CAJA';
  }

  static String? _parseReason(String original, String lower) {
    final patterns = [
      RegExp(
        r'(?:por\s+concepto\s+de|concepto\s+de|por\s+concepto|concepto|por|motivo|de)\s+(.+)$',
        caseSensitive: false,
      ),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(original.trim());
      if (m != null) {
        var reason = m.group(1)!.trim();
        reason = reason
            .replaceAll(RegExp(r'\b(en caja|en banco|caja|banco|pesos?)\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (reason.isNotEmpty) return _titleCase(reason);
      }
    }

    // Fallback: strip known tokens and use remainder.
    var stripped = lower
        .replaceAll(RegExp(r'\b(movimiento|agrega|agregar|registra|registrar|nuevo|una|un)\b'), '')
        .replaceAll(RegExp(r'\b(entrada|salida|ingreso|egreso|retiro)\b'), '')
        .replaceAll(RegExp(r'\b(en caja|en banco|caja|banco|pesos?)\b'), '')
        .replaceAll(RegExp(r'[\d.,]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length >= 3) return _titleCase(stripped);
    return null;
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
