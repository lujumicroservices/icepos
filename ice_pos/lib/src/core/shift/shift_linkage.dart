import 'package:ice_pos/src/core/database/app_database.dart';

/// Active interval for a shift: [startTime] through [endTime] or [now] if still open.
class ShiftActiveRange {
  const ShiftActiveRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

ShiftActiveRange shiftActiveRange(Shift shift, {DateTime? now}) {
  final end = shift.endTime ?? now ?? DateTime.now();
  return ShiftActiveRange(start: shift.startTime, end: end);
}

/// Whether [movementDate] falls inside the shift's operating window (inclusive).
bool isMovementInShiftWindow({
  required DateTime movementDate,
  required Shift shift,
  DateTime? now,
}) {
  final range = shiftActiveRange(shift, now: now);
  final local = movementDate.toLocal();
  final start = range.start.toLocal();
  final end = range.end.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}

/// Maps Supabase `shifts.id` → local [Shifts.id] using **only** [Shift.cloudShiftId].
///
/// Never maps by local autoincrement id (that caused collisions when local id 74 reused
/// while cloud still had a different closed shift 74).
Map<int, int> buildStrictCloudToLocalShiftMap(Iterable<Shift> shifts) {
  final map = <int, int>{};
  for (final s in shifts) {
    final cloud = s.cloudShiftId;
    if (cloud != null) {
      map[cloud] = s.id;
    }
  }
  return map;
}

/// Open local shift whose [Shift.cloudShiftId] equals [cloudShiftId].
Shift? findOpenLocalShiftByCloudId(Iterable<Shift> shifts, int cloudShiftId) {
  for (final s in shifts) {
    if (s.endTime != null) continue;
    if (s.cloudShiftId == cloudShiftId) return s;
  }
  return null;
}

bool isMovementRelevantToShift(Movement movement, Shift shift, {DateTime? now}) {
  if (movement.shiftId != shift.id) return false;
  if (movement.cancelledAt != null) return false;
  return isMovementInShiftWindow(
    movementDate: movement.date,
    shift: shift,
    now: now,
  );
}

/// Net CAJA: sum(ENTRADA) − sum(SALIDA). Caller should pre-filter by shift/window.
double netCajaFromMovements(Iterable<Movement> movements) {
  var net = 0.0;
  for (final r in movements) {
    if (r.account != 'CAJA') continue;
    if (r.cancelledAt != null) continue;
    if (r.type == 'ENTRADA') {
      net += r.amount;
    } else if (r.type == 'SALIDA') {
      net -= r.amount;
    }
  }
  return net;
}
