import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/gate_event.dart';

class FirebaseGateDataSource {
  final FirebaseDatabase _db;

  FirebaseGateDataSource({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  /// Streams the gate status from /gate/status
  /// Values: "ready" | "open" | "closed"
  Stream<String> watchGateStatus() {
    return _db.ref('gate/status').onValue.map((event) {
      return event.snapshot.value as String? ?? 'ready';
    });
  }

  /// Streams the entry_detected flag from /gate/entry_detected
  Stream<bool> watchEntryDetected() {
    return _db.ref('gate/entry_detected').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Writes a boolean value to /gate/open_command
  Future<void> writeOpenCommand(bool value) async {
    await _db.ref('gate/open_command').set(value);
  }

  /// Writes reservation metadata to /gate/reservation
  Future<void> writeGateReservation({
    required String slotId,
    required String userId,
    required int timestamp,
  }) async {
    await _db.ref('gate/reservation').set({
      'slotId': slotId,
      'userId': userId,
      'timestamp': timestamp,
    });
  }

  /// Streams the list of gate events from /gate/events/
  Stream<List<GateEvent>> watchGateEvents() {
    return _db
        .ref('gate/events')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return const <GateEvent>[];

      final map = Map<String, dynamic>.from(data as Map);
      final events = map.entries.map((entry) {
        final evData = Map<String, dynamic>.from(entry.value as Map);
        return GateEvent(
          id: entry.key,
          type: evData['type'] as String? ?? '',
          message: evData['message'] as String? ?? '',
          timestamp: evData['timestamp'] as int? ?? 0,
        );
      }).toList();

      // Sort descending by timestamp (newest first)
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events;
    });
  }
}
