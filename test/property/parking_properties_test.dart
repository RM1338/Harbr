/// Property-Based Tests — Harbr Flutter App
///
/// Implements Properties 1–7 from the design document using manual
/// property testing with dart:math Random (100+ iterations each).
///
/// **Validates: Requirements 1.1, 1.5, 1.6, 2.1, 2.2, 3.3, 3.6, 5.1, 5.4**

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbr/core/constants/app_constants.dart';
import 'package:harbr/core/utils/parking_utils.dart';
import 'package:harbr/domain/entities/parking_slot.dart';
import 'package:harbr/domain/entities/reservation.dart';
import 'package:harbr/presentation/screens/map/slot_map_screen.dart';

// ── Generators ────────────────────────────────────────────────────────────────

const _statuses = [
  SlotStatus.available,
  SlotStatus.occupied,
  SlotStatus.reserved,
];

const _pastStatuses = [
  ReservationStatus.cancelled,
  ReservationStatus.completed,
  ReservationStatus.noShow,
];

/// Generates a random [ParkingSlot] with a given [id] and random status.
ParkingSlot _randomSlot(Random rng, {String? id}) {
  final slotId = id ?? '${String.fromCharCode(65 + rng.nextInt(5))}${rng.nextInt(9) + 1}';
  final status = _statuses[rng.nextInt(_statuses.length)];
  return ParkingSlot(id: slotId, status: status);
}

/// Generates a list of [ParkingSlot] with unique IDs and length in [1..maxLen].
List<ParkingSlot> _randomSlotList(Random rng, {int maxLen = 20}) {
  final len = rng.nextInt(maxLen) + 1;
  final usedIds = <String>{};
  final slots = <ParkingSlot>[];
  var attempts = 0;
  while (slots.length < len && attempts < len * 10) {
    attempts++;
    final id = '${String.fromCharCode(65 + rng.nextInt(5))}${rng.nextInt(9) + 1}';
    if (usedIds.add(id)) {
      final status = _statuses[rng.nextInt(_statuses.length)];
      slots.add(ParkingSlot(id: id, status: status));
    }
  }
  return slots;
}

/// Generates a random [Reservation] with a past status.
Reservation _randomPastReservation(Random rng, {String? id}) {
  final resId = id ?? 'res_${rng.nextInt(100000)}';
  final status = _pastStatuses[rng.nextInt(_pastStatuses.length)];
  final createdAt = rng.nextInt(1000000000) + 1000000000;
  final arrivalTime = createdAt + rng.nextInt(3600000);
  return Reservation(
    id: resId,
    userId: 'user_${rng.nextInt(1000)}',
    slotId: 'A${rng.nextInt(9) + 1}',
    arrivalTime: arrivalTime,
    durationHours: rng.nextInt(5) + 1,
    status: status,
    createdAt: createdAt,
  );
}

// ── Property 1: Slot count formatter ─────────────────────────────────────────

/// **Validates: Requirements 1.1**
///
/// For any List<ParkingSlot>, formatSlotCount() must return "{free}/{total}"
/// where free = count of available slots and total = list length.
void main() {
  group('Property 1: slot count formatter', () {
    test('formatSlotCount returns "{free}/{total}" for any slot list', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final slots = _randomSlotList(rng);
        final result = formatSlotCount(slots);

        final expectedFree = slots.where((s) => s.isAvailable).length;
        final expectedTotal = slots.length;
        final expected = '$expectedFree/$expectedTotal';

        expect(
          result,
          equals(expected),
          reason: 'Iteration $i: slots=$slots, got "$result", expected "$expected"',
        );

        // Structural check: must match "{int}/{int}" pattern
        final parts = result.split('/');
        expect(parts.length, equals(2),
            reason: 'Iteration $i: result "$result" must contain exactly one "/"');
        expect(int.tryParse(parts[0]), isNotNull,
            reason: 'Iteration $i: free count "${parts[0]}" must be an integer');
        expect(int.tryParse(parts[1]), isNotNull,
            reason: 'Iteration $i: total count "${parts[1]}" must be an integer');

        final free = int.parse(parts[0]);
        final total = int.parse(parts[1]);
        expect(free, lessThanOrEqualTo(total),
            reason: 'Iteration $i: free ($free) must be <= total ($total)');
        expect(free, greaterThanOrEqualTo(0),
            reason: 'Iteration $i: free count must be non-negative');
      }
    });

    test('formatSlotCount handles empty list', () {
      expect(formatSlotCount([]), equals('0/0'));
    });

    test('formatSlotCount handles all-available list', () {
      final rng = Random(1);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(20) + 1;
        final slots = List.generate(
          len,
          (j) => ParkingSlot(id: 'A$j', status: SlotStatus.available),
        );
        final result = formatSlotCount(slots);
        expect(result, equals('$len/$len'),
            reason: 'All-available list of $len should be "$len/$len"');
      }
    });

    test('formatSlotCount handles all-occupied list', () {
      final rng = Random(2);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(20) + 1;
        final slots = List.generate(
          len,
          (j) => ParkingSlot(id: 'A$j', status: SlotStatus.occupied),
        );
        final result = formatSlotCount(slots);
        expect(result, equals('0/$len'),
            reason: 'All-occupied list of $len should be "0/$len"');
      }
    });
  });

  // ── Property 2: Auto-assign nearest free slot ───────────────────────────────

  /// **Validates: Requirements 1.5, 1.6**
  ///
  /// For any list of SlotWithDistance, autoAssignNearest() must return the
  /// available slot with the minimum distance, or null if none are available.
  group('Property 2: auto-assign nearest free slot', () {
    test('returns minimum-distance available slot or null', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(15) + 1;
        final slotsWithDist = List.generate(len, (j) {
          final slot = _randomSlot(rng, id: 'A$j');
          final distance = rng.nextDouble() * 500;
          return SlotWithDistance(slot: slot, distance: distance);
        });

        final result = autoAssignNearest(slotsWithDist);
        final availableSlots = slotsWithDist.where((s) => s.slot.isAvailable).toList();

        if (availableSlots.isEmpty) {
          expect(result, isNull,
              reason: 'Iteration $i: no available slots → must return null');
        } else {
          expect(result, isNotNull,
              reason: 'Iteration $i: available slots exist → must not return null');
          expect(result!.slot.isAvailable, isTrue,
              reason: 'Iteration $i: returned slot must be available');

          // Verify it is the minimum distance
          final minDist = availableSlots.map((s) => s.distance).reduce(min);
          expect(result.distance, equals(minDist),
              reason: 'Iteration $i: returned distance ${result.distance} must equal min $minDist');
        }
      }
    });

    test('returns null when all slots are occupied', () {
      final rng = Random(3);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(10) + 1;
        final slotsWithDist = List.generate(len, (j) {
          final slot = ParkingSlot(id: 'A$j', status: SlotStatus.occupied);
          return SlotWithDistance(slot: slot, distance: rng.nextDouble() * 100);
        });
        expect(autoAssignNearest(slotsWithDist), isNull,
            reason: 'Iteration $i: all occupied → null');
      }
    });

    test('returns the single available slot when only one exists', () {
      final rng = Random(4);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(9) + 2; // at least 2 slots
        final availableIdx = rng.nextInt(len);
        final slotsWithDist = List.generate(len, (j) {
          final status = j == availableIdx ? SlotStatus.available : SlotStatus.occupied;
          final slot = ParkingSlot(id: 'A$j', status: status);
          return SlotWithDistance(slot: slot, distance: rng.nextDouble() * 100);
        });
        final result = autoAssignNearest(slotsWithDist);
        expect(result, isNotNull);
        expect(result!.slot.id, equals('A$availableIdx'),
            reason: 'Iteration $i: only available slot is A$availableIdx');
      }
    });
  });

  // ── Property 3: Zone grouping ─────────────────────────────────────────────

  /// **Validates: Requirements 2.1**
  ///
  /// For any List<ParkingSlot>, groupSlotsByZone() must place every slot in
  /// exactly one zone bucket matching its ID prefix. Slots with empty IDs
  /// are excluded.
  group('Property 3: zone grouping', () {
    test('every slot appears in exactly one correct zone bucket', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final slots = _randomSlotList(rng);
        final grouped = groupSlotsByZone(slots);

        // Collect all slots from grouped map
        final allGroupedSlots = grouped.values.expand((list) => list).toList();

        // Filter out slots with empty IDs (they are excluded by groupSlotsByZone)
        final validSlots = slots.where((s) => s.id.isNotEmpty).toList();

        // Every valid slot must appear exactly once
        for (final slot in validSlots) {
          final occurrences = allGroupedSlots.where((s) => s.id == slot.id).length;
          expect(occurrences, equals(1),
              reason: 'Iteration $i: slot ${slot.id} must appear exactly once, found $occurrences');
        }

        // Total count must match
        expect(allGroupedSlots.length, equals(validSlots.length),
            reason: 'Iteration $i: grouped total must equal valid slot count');

        // Each slot must be in the correct zone bucket
        for (final entry in grouped.entries) {
          final zone = entry.key;
          for (final slot in entry.value) {
            expect(slot.id[0].toUpperCase(), equals(zone),
                reason: 'Iteration $i: slot ${slot.id} in zone $zone has wrong prefix');
          }
        }
      }
    });

    test('slots with empty IDs are excluded from grouping', () {
      final slots = [
        const ParkingSlot(id: '', status: SlotStatus.available),
        const ParkingSlot(id: 'A1', status: SlotStatus.available),
        const ParkingSlot(id: 'B2', status: SlotStatus.occupied),
      ];
      final grouped = groupSlotsByZone(slots);
      final allIds = grouped.values.expand((l) => l).map((s) => s.id).toList();
      expect(allIds, containsAll(['A1', 'B2']));
      expect(allIds, isNot(contains('')));
    });

    test('zones are sorted alphabetically', () {
      final rng = Random(5);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final slots = _randomSlotList(rng);
        final grouped = groupSlotsByZone(slots);
        final keys = grouped.keys.toList();
        final sortedKeys = List<String>.from(keys)..sort();
        expect(keys, equals(sortedKeys),
            reason: 'Iteration $i: zone keys must be sorted alphabetically');
      }
    });
  });

  // ── Property 4: Color mapping ─────────────────────────────────────────────

  /// **Validates: Requirements 2.2**
  ///
  /// For any ParkingSlot, slotStatusColor() must return a non-null Color
  /// matching the expected value for each status.
  group('Property 4: color mapping', () {
    test('color mapping is non-null and matches expected status color', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final slot = _randomSlot(rng);
        final color = slotStatusColor(slot);

        // Must be non-null (Dart non-nullable guarantees this, but verify value)
        expect(color, isNotNull,
            reason: 'Iteration $i: color must not be null for slot ${slot.id}');

        // Must match expected color for status
        switch (slot.status) {
          case SlotStatus.available:
            expect(color, equals(Colors.white),
                reason: 'Iteration $i: available slot must map to white');
            break;
          case SlotStatus.occupied:
            expect(color, equals(Colors.black),
                reason: 'Iteration $i: occupied slot must map to black');
            break;
          case SlotStatus.reserved:
            expect(color, equals(Colors.grey.shade200),
                reason: 'Iteration $i: reserved slot must map to grey.shade200');
            break;
        }
      }
    });

    test('all three statuses produce distinct colors', () {
      final available = slotStatusColor(const ParkingSlot(id: 'A1', status: SlotStatus.available));
      final occupied = slotStatusColor(const ParkingSlot(id: 'A1', status: SlotStatus.occupied));
      final reserved = slotStatusColor(const ParkingSlot(id: 'A1', status: SlotStatus.reserved));

      expect(available, isNot(equals(occupied)));
      expect(available, isNot(equals(reserved)));
      expect(occupied, isNot(equals(reserved)));
    });

    test('color mapping covers every possible status without throwing', () {
      for (final status in _statuses) {
        final slot = ParkingSlot(id: 'X1', status: status);
        expect(() => slotStatusColor(slot), returnsNormally,
            reason: 'slotStatusColor must not throw for status "$status"');
      }
    });
  });

  // ── Property 5: Reserve button visibility ────────────────────────────────

  /// **Validates: Requirements 3.3, 3.6**
  ///
  /// isReserveButtonVisible() must return true iff slot.isAvailable.
  group('Property 5: reserve button visibility', () {
    test('button visible iff slot.isAvailable', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final slot = _randomSlot(rng);
        final visible = isReserveButtonVisible(slot);

        expect(visible, equals(slot.isAvailable),
            reason: 'Iteration $i: slot ${slot.id} status=${slot.status}, '
                'visible=$visible but isAvailable=${slot.isAvailable}');
      }
    });

    test('button is visible for available slot', () {
      const slot = ParkingSlot(id: 'A1', status: SlotStatus.available);
      expect(isReserveButtonVisible(slot), isTrue);
    });

    test('button is not visible for occupied slot', () {
      const slot = ParkingSlot(id: 'A1', status: SlotStatus.occupied);
      expect(isReserveButtonVisible(slot), isFalse);
    });

    test('button is not visible for reserved slot', () {
      const slot = ParkingSlot(id: 'A1', status: SlotStatus.reserved);
      expect(isReserveButtonVisible(slot), isFalse);
    });

    test('visibility is consistent with slot.isAvailable across all statuses', () {
      for (final status in _statuses) {
        final slot = ParkingSlot(id: 'X1', status: status);
        expect(isReserveButtonVisible(slot), equals(slot.isAvailable),
            reason: 'Status "$status": visibility must equal isAvailable');
      }
    });
  });

  // ── Property 6: Booking card fields ──────────────────────────────────────

  /// **Validates: Requirements 5.1**
  ///
  /// For any active Reservation, computeCountdown() must return a non-negative
  /// Duration, and the slot ID and zone can be derived correctly.
  group('Property 6: booking card fields', () {
    test('countdown is non-negative for any active reservation', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final now = DateTime.now();
        // Create a reservation that ends in the future (active)
        final durationHours = rng.nextInt(10) + 1;
        final arrivalTime = now.millisecondsSinceEpoch - rng.nextInt(1800000); // up to 30 min ago
        final reservation = Reservation(
          id: 'res_$i',
          userId: 'user_1',
          slotId: '${String.fromCharCode(65 + rng.nextInt(5))}${rng.nextInt(9) + 1}',
          arrivalTime: arrivalTime,
          durationHours: durationHours,
          status: ReservationStatus.active,
          createdAt: arrivalTime - 60000,
        );

        final countdown = computeCountdown(reservation, now);

        expect(countdown.inMilliseconds, greaterThanOrEqualTo(0),
            reason: 'Iteration $i: countdown must be non-negative');
      }
    });

    test('slot ID is non-empty for any reservation', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final now = DateTime.now();
        final slotId = '${String.fromCharCode(65 + rng.nextInt(5))}${rng.nextInt(9) + 1}';
        final reservation = Reservation(
          id: 'res_$i',
          userId: 'user_1',
          slotId: slotId,
          arrivalTime: now.millisecondsSinceEpoch,
          durationHours: rng.nextInt(5) + 1,
          status: ReservationStatus.active,
          createdAt: now.millisecondsSinceEpoch - 60000,
        );

        expect(reservation.slotId, isNotEmpty,
            reason: 'Iteration $i: slotId must be non-empty');

        // Zone is first character of slotId
        final zone = reservation.slotId[0];
        expect(zone, isNotEmpty,
            reason: 'Iteration $i: zone derived from slotId must be non-empty');
      }
    });

    test('countdown is zero when reservation has expired', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final now = DateTime.now();
        // Reservation that ended in the past
        final arrivalTime = now.millisecondsSinceEpoch - 7200000; // 2 hours ago
        final reservation = Reservation(
          id: 'res_$i',
          userId: 'user_1',
          slotId: 'A1',
          arrivalTime: arrivalTime,
          durationHours: 1, // ended 1 hour ago
          status: ReservationStatus.active,
          createdAt: arrivalTime - 60000,
        );

        final countdown = computeCountdown(reservation, now);
        expect(countdown, equals(Duration.zero),
            reason: 'Iteration $i: expired reservation must have zero countdown');
      }
    });

    test('countdown decreases as time advances', () {
      final base = DateTime(2025, 1, 1, 12, 0, 0);
      final reservation = Reservation(
        id: 'res_1',
        userId: 'user_1',
        slotId: 'A1',
        arrivalTime: base.millisecondsSinceEpoch,
        durationHours: 2,
        status: ReservationStatus.active,
        createdAt: base.millisecondsSinceEpoch - 60000,
      );

      final t1 = base.add(const Duration(minutes: 30));
      final t2 = base.add(const Duration(minutes: 60));

      final c1 = computeCountdown(reservation, t1);
      final c2 = computeCountdown(reservation, t2);

      expect(c1.inSeconds, greaterThan(c2.inSeconds),
          reason: 'Countdown at t1 must be greater than at t2 (t2 > t1)');
    });
  });

  // ── Property 7: Past bookings sort ───────────────────────────────────────

  /// **Validates: Requirements 5.4**
  ///
  /// sortReservationsByCreatedAt() must return reservations sorted by
  /// createdAt ascending (oldest first).
  group('Property 7: past bookings sort', () {
    test('sorted by createdAt ascending for any list of past reservations', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(20) + 1;
        final reservations = List.generate(len, (j) => _randomPastReservation(rng, id: 'res_${i}_$j'));
        final sorted = sortReservationsByCreatedAt(reservations);

        expect(sorted.length, equals(reservations.length),
            reason: 'Iteration $i: sorted list must have same length');

        for (var j = 0; j < sorted.length - 1; j++) {
          expect(sorted[j].createdAt, lessThanOrEqualTo(sorted[j + 1].createdAt),
              reason: 'Iteration $i: element $j (${sorted[j].createdAt}) must be '
                  '<= element ${j + 1} (${sorted[j + 1].createdAt})');
        }
      }
    });

    test('sort does not mutate the original list', () {
      final rng = Random(6);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(10) + 2;
        final original = List.generate(len, (j) => _randomPastReservation(rng, id: 'res_$j'));
        final originalOrder = original.map((r) => r.id).toList();

        sortReservationsByCreatedAt(original);

        // Original list must be unchanged
        expect(original.map((r) => r.id).toList(), equals(originalOrder),
            reason: 'Iteration $i: original list must not be mutated');
      }
    });

    test('single-element list is trivially sorted', () {
      final rng = Random(7);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final single = [_randomPastReservation(rng)];
        final sorted = sortReservationsByCreatedAt(single);
        expect(sorted.length, equals(1));
        expect(sorted[0].id, equals(single[0].id));
      }
    });

    test('already-sorted list remains sorted', () {
      final rng = Random(8);
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final len = rng.nextInt(10) + 2;
        // Generate with strictly increasing createdAt
        var t = 1000000000;
        final reservations = List.generate(len, (j) {
          t += rng.nextInt(100000) + 1;
          return Reservation(
            id: 'res_$j',
            userId: 'u',
            slotId: 'A1',
            arrivalTime: t + 1000,
            durationHours: 1,
            status: ReservationStatus.completed,
            createdAt: t,
          );
        });
        final sorted = sortReservationsByCreatedAt(reservations);
        for (var j = 0; j < sorted.length - 1; j++) {
          expect(sorted[j].createdAt, lessThanOrEqualTo(sorted[j + 1].createdAt));
        }
      }
    });

    test('reverse-sorted list becomes correctly sorted', () {
      final reservations = [
        Reservation(id: 'r3', userId: 'u', slotId: 'A1', arrivalTime: 3000, durationHours: 1, status: ReservationStatus.completed, createdAt: 3000),
        Reservation(id: 'r2', userId: 'u', slotId: 'A1', arrivalTime: 2000, durationHours: 1, status: ReservationStatus.completed, createdAt: 2000),
        Reservation(id: 'r1', userId: 'u', slotId: 'A1', arrivalTime: 1000, durationHours: 1, status: ReservationStatus.completed, createdAt: 1000),
      ];
      final sorted = sortReservationsByCreatedAt(reservations);
      expect(sorted.map((r) => r.id).toList(), equals(['r1', 'r2', 'r3']));
    });
  });
}
