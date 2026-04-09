import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/parking_slot.dart';
import '../../domain/entities/reservation.dart';

/// Returns a formatted string "{free}/{total}" for a list of [ParkingSlot].
///
/// [free] = count of slots with status == SlotStatus.available
/// [total] = list length
String formatSlotCount(List<ParkingSlot> slots) {
  final free = slots.where((s) => s.isAvailable).length;
  final total = slots.length;
  return '$free/$total';
}

/// Represents a parking slot with an associated distance value for
/// auto-assign purposes.
class SlotWithDistance {
  final ParkingSlot slot;
  final double distance;

  const SlotWithDistance({required this.slot, required this.distance});
}

/// Returns the [SlotWithDistance] with the minimum distance among all entries
/// where [slot.isAvailable] is true, or null if no available slot exists.
SlotWithDistance? autoAssignNearest(List<SlotWithDistance> slotsWithDistances) {
  final available = slotsWithDistances.where((s) => s.slot.isAvailable).toList();
  if (available.isEmpty) return null;
  return available.reduce((a, b) => a.distance <= b.distance ? a : b);
}

/// Returns the background [Color] for a slot cell based on its status.
///
/// - available → Colors.white
/// - occupied  → Colors.black
/// - reserved  → Colors.grey.shade200
Color slotStatusColor(ParkingSlot slot) {
  switch (slot.status) {
    case SlotStatus.available:
      return Colors.white;
    case SlotStatus.occupied:
      return Colors.black;
    case SlotStatus.reserved:
      return Colors.grey.shade200;
    default:
      return Colors.white;
  }
}

/// Returns whether the "Reserve Slot" button should be visible for [slot].
bool isReserveButtonVisible(ParkingSlot slot) => slot.isAvailable;

/// Computes the countdown [Duration] for an active [Reservation].
///
/// Returns [Duration.zero] if the reservation has already expired.
Duration computeCountdown(Reservation reservation, DateTime now) {
  final end = DateTime.fromMillisecondsSinceEpoch(reservation.endTime);
  final diff = end.difference(now);
  return diff.isNegative ? Duration.zero : diff;
}

/// Sorts a list of [Reservation] objects by [createdAt] ascending (oldest first).
List<Reservation> sortReservationsByCreatedAt(List<Reservation> reservations) {
  final sorted = List<Reservation>.from(reservations);
  sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted;
}
