import 'package:flutter_test/flutter_test.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/voice_intent.dart';
import 'package:ice_pos/src/features/voice_assistant/parsing/movement_command_parser.dart';
import 'package:ice_pos/src/features/voice_assistant/parsing/spanish_amount_parser.dart';

void main() {
  const parser = MovementCommandParser();

  group('SpanishAmountParser', () {
    test('parses digits', () {
      expect(SpanishAmountParser.parse('200 pesos'), 200);
      expect(SpanishAmountParser.parse('1,500.50'), 1500.50);
    });

    test('parses word amounts', () {
      expect(SpanishAmountParser.parse('dos mil pesos'), 2000);
      expect(SpanishAmountParser.parse('quinientos pesos'), 500);
      expect(SpanishAmountParser.parse('doscientos pesos'), 200);
    });
  });

  group('MovementCommandParser', () {
    test('entrada with amount and reason', () {
      final r = parser.parse('entrada 200 pesos por sueldo');
      expect(r.intent, VoiceIntent.createMovement);
      expect(r.isActionable, isTrue);
      expect(r.movement!.type, 'ENTRADA');
      expect(r.movement!.amount, 200);
      expect(r.movement!.reason.toLowerCase(), contains('sueldo'));
      expect(r.movement!.account, 'CAJA');
    });

    test('salida en banco', () {
      final r = parser.parse('salida 500 en banco por renta');
      expect(r.movement!.type, 'SALIDA');
      expect(r.movement!.account, 'BANCO');
      expect(r.movement!.amount, 500);
    });

    test('unknown without movement keywords', () {
      final r = parser.parse('hola mundo');
      expect(r.intent, VoiceIntent.unknown);
    });

    test('missing amount asks clarification', () {
      final r = parser.parse('entrada por sueldo');
      expect(r.intent, VoiceIntent.createMovement);
      expect(r.needsClarification, isTrue);
      expect(r.missingFields, contains('amount'));
    });
  });
}
