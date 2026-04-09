import 'dart:async';
import '../../data/datasources/firebase_slot_datasource.dart';
import '../../data/datasources/firebase_reservation_datasource.dart';
import '../../data/datasources/firebase_event_datasource.dart';
import '../constants/app_constants.dart';

/// Schedules a local check 15 minutes after the reservation's arrival time.
/// If the slot is not "occupied" at that point, auto-cancels the reservation
/// and writes a "no_show" event to Firebase.
class ReservationIntegrityService {
  static final Map<String, Timer> _timers = {};

  static void scheduleNoShowCheck({
    required String resId,
    required String slotId,
    required DateTime arrivalTime,
    required String userId,
  }) {
    // Cancel any existing timer for this reservation
    _timers[resId]?.cancel();

    final checkTime = arrivalTime.add(const Duration(minutes: 15));
    final now = DateTime.now();
    final delay = checkTime.isAfter(now)
        ? checkTime.difference(now)
        : Duration.zero;

    _timers[resId] = Timer(delay, () async {
      await _runNoShowCheck(resId: resId, slotId: slotId, userId: userId);
      _timers.remove(resId);
    });
  }

  static Future<void> _runNoShowCheck({
    required String resId,
    required String slotId,
    required String userId,
  }) async {
    try {
      final slotDS = FirebaseSlotDataSource();
      final resDS = FirebaseReservationDataSource();
      final eventDS = FirebaseEventDataSource();

      // Check current slot status
      final status = await slotDS.getSlotStatus(slotId);

      if (status != SlotStatus.occupied) {
        // User didn't show up — auto cancel
        await resDS.updateReservationStatus(resId, ReservationStatus.noShow);

        // Free the slot
        await slotDS.updateSlot(
          slotId: slotId,
          status: SlotStatus.available,
          reservedBy: null,
          until: null,
        );

        // Write no_show event
        await eventDS.writeEvent(
          type: EventType.noShow,
          slotId: slotId,
          message: 'No-show detected at slot $slotId. Reservation auto-cancelled.',
          severity: EventSeverity.warning,
        );
      }
    } catch (e) {
      // Silently fail — don't crash app for background check
    }
  }

  /// Cancel a scheduled check (e.g. if user manually cancels before time)
  static void cancelCheck(String resId) {
    _timers[resId]?.cancel();
    _timers.remove(resId);
  }

  static void disposeAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
