import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/parking_event.dart';
import '../../core/constants/app_constants.dart';

class FirebaseEventDataSource {
  final FirebaseDatabase _db;
  final _uuid = const Uuid();

  FirebaseEventDataSource({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  /// Streams all events ordered by timestamp descending
  Stream<List<ParkingEvent>> watchEvents() {
    return _db
        .ref('events')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return const <ParkingEvent>[];

      final map = Map<String, dynamic>.from(data as Map);
      final events = map.entries.map((entry) {
        final evData = Map<String, dynamic>.from(entry.value as Map);
        return ParkingEvent(
          id: entry.key,
          type: evData['type'] as String? ?? EventType.sensor,
          slotId: evData['slotId'] as String? ?? '',
          message: evData['message'] as String? ?? '',
          timestamp: evData['timestamp'] as int,
          severity: evData['severity'] as String? ?? EventSeverity.info,
        );
      }).toList();

      // Sort descending by timestamp
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events;
    });
  }

  /// Writes a new event to Firebase
  Future<void> writeEvent({
    required String type,
    required String slotId,
    required String message,
    required String severity,
  }) async {
    final id = 'evt_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.ref('events/$id').set({
      'type': type,
      'slotId': slotId,
      'message': message,
      'timestamp': now,
      'severity': severity,
    });
  }
}
