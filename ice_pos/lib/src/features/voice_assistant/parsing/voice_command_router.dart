import 'package:ice_pos/src/features/voice_assistant/domain/voice_command_result.dart';
import 'package:ice_pos/src/features/voice_assistant/parsing/movement_command_parser.dart';

/// Routes transcript to intent-specific parsers (extend with more parsers later).
class VoiceCommandRouter {
  VoiceCommandRouter({MovementCommandParser? movementParser})
      : _movementParser = movementParser ?? const MovementCommandParser();

  final MovementCommandParser _movementParser;

  VoiceCommandResult route(String transcript) {
    return _movementParser.parse(transcript);
  }
}
