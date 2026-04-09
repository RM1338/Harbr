import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/parking_slot.dart';
import '../../core/constants/app_constants.dart';

class FirebaseSlotDataSource {
  final FirebaseDatabase _db;

  FirebaseSlotDataSource({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  /// Streams all parking slots from Firebase as a list
  Stream<List<ParkingSlot>> watchSlots() {
    return _db.ref('slots').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return _emptySlots();

      final map = Map<String, dynamic>.from(data as Map);
      final slots = <ParkingSlot>[];

      for (final id in kAllSlotIds) {
        if (map.containsKey(id)) {
          final slotData = Map<String, dynamic>.from(map[id] as Map);
          slots.add(ParkingSlot(
            id: id,
            status: slotData['status'] as String? ?? SlotStatus.available,
            reservedBy: slotData['reservedBy'] as String?,
            until: slotData['until'] as int?,
          ));
        } else {
          // Slot not yet in DB — treat as available
          slots.add(ParkingSlot(id: id, status: SlotStatus.available));
        }
      }

      return slots;
    });
  }

  /// Reads current status of a single slot (one-time)
  Future<String> getSlotStatus(String slotId) async {
    final snapshot = await _db.ref('slots/$slotId/status').get();
    return snapshot.value as String? ?? SlotStatus.available;
  }

  /// Updates a slot's status and reservedBy/until fields
  Future<void> updateSlot({
    required String slotId,
    required String status,
    String? reservedBy,
    int? until,
  }) async {
    await _db.ref('slots/$slotId').update({
      'status': status,
      'reservedBy': reservedBy,
      'until': until,
    });
  }

  /// Returns a list of all 12 slots as "available" (offline fallback)
  List<ParkingSlot> _emptySlots() =>
      kAllSlotIds.map((id) => ParkingSlot(id: id, status: SlotStatus.available)).toList();
}
