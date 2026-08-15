import 'package:ice_pos/src/features/voice_assistant/domain/create_movement_payload.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/voice_intent.dart';

/// Output of the voice command router / parsers.
class VoiceCommandResult {
  const VoiceCommandResult({
    required this.intent,
    required this.transcript,
    required this.confidence,
    this.movement,
    this.missingFields = const [],
    this.message,
  });

  final VoiceIntent intent;
  final String transcript;
  /// 0..1 — local rule parser confidence.
  final double confidence;
  final CreateMovementPayload? movement;
  final List<String> missingFields;
  final String? message;

  bool get isActionable =>
      intent == VoiceIntent.createMovement &&
      movement != null &&
      missingFields.isEmpty;

  bool get needsClarification =>
      intent == VoiceIntent.createMovement && missingFields.isNotEmpty;
}
