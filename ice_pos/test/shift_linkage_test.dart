import 'package:flutter_test/flutter_test.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/shift/shift_linkage.dart';

Shift _shift({
  required int id,
  int? cloudShiftId,
  required DateTime start,
  DateTime? end,
}) =>
    Shift(
      id: id,
      cloudShiftId: cloudShiftId,
      cloudRegisterId: null,
      startTime: start,
      endTime: end,
      startingFund: 0,
    );

Movement _movement({
  required int id,
  required int shiftId,
  required DateTime date,
  String type = 'SALIDA',
  double amount = 100,
}) =>
    Movement(
      id: id,
      date: date,
      type: type,
      account: 'CAJA',
      amount: amount,
      reason: 'test',
      shiftId: shiftId,
      needsCloudSync: false,
      cancelledAt: null,
    );

void main() {
  group('buildStrictCloudToLocalShiftMap', () {
    test('maps only explicit cloud_shift_id', () {
      final map = buildStrictCloudToLocalShiftMap([
        _shift(id: 74, cloudShiftId: 177, start: DateTime(2026, 6, 18)),
        _shift(id: 10, cloudShiftId: 74, start: DateTime(2026, 4, 25), end: DateTime(2026, 4, 27)),
      ]);
      expect(map[177], 74);
      expect(map[74], 10);
      expect(map.containsKey(74), isTrue);
    });

    test('ignores shifts without cloud_shift_id', () {
      final map = buildStrictCloudToLocalShiftMap([
        _shift(id: 5, cloudShiftId: null, start: DateTime(2026, 1, 1)),
      ]);
      expect(map, isEmpty);
    });
  });

  group('findOpenLocalShiftByCloudId', () {
    test('matches cloud_shift_id not local id', () {
      final open = _shift(id: 74, cloudShiftId: 177, start: DateTime(2026, 6, 18));
      final closed = _shift(
        id: 10,
        cloudShiftId: 74,
        start: DateTime(2026, 4, 25),
        end: DateTime(2026, 4, 27),
      );
      expect(findOpenLocalShiftByCloudId([open, closed], 177)?.id, 74);
      expect(findOpenLocalShiftByCloudId([open, closed], 74), isNull);
    });
  });

  group('isMovementInShiftWindow', () {
    final shift = _shift(id: 1, cloudShiftId: 177, start: DateTime(2026, 6, 18, 15, 0));

    test('accepts movement during open shift', () {
      expect(
        isMovementInShiftWindow(
          movementDate: DateTime(2026, 6, 18, 16, 0),
          shift: shift,
        ),
        isTrue,
      );
    });

    test('rejects movement before shift start (April on June shift)', () {
      expect(
        isMovementInShiftWindow(
          movementDate: DateTime(2026, 4, 25, 21, 0),
          shift: shift,
        ),
        isFalse,
      );
    });
  });

  group('isMovementRelevantToShift', () {
    final shift = _shift(id: 74, cloudShiftId: 177, start: DateTime(2026, 6, 18, 15, 0));

    test('stale movement same shift_id wrong date is excluded', () {
      final stale = _movement(
        id: 57,
        shiftId: 74,
        date: DateTime(2026, 4, 25, 21, 0),
      );
      final current = _movement(
        id: 203,
        shiftId: 74,
        date: DateTime(2026, 6, 18, 16, 0),
      );
      expect(isMovementRelevantToShift(stale, shift), isFalse);
      expect(isMovementRelevantToShift(current, shift), isTrue);
    });
  });

  group('netCajaFromMovements', () {
    test('computes entrada minus salida', () {
      final net = netCajaFromMovements([
        _movement(id: 1, shiftId: 1, date: DateTime(2026, 1, 1), type: 'ENTRADA', amount: 50),
        _movement(id: 2, shiftId: 1, date: DateTime(2026, 1, 1), type: 'SALIDA', amount: 1000),
      ]);
      expect(net, -950);
    });
  });
}
