import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/reservation.dart';
import '../../core/constants/app_constants.dart';

class FirebaseReservationDataSource {
  final FirebaseDatabase _db;
  final _uuid = const Uuid();

  FirebaseReservationDataSource({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  /// Streams all reservations for a specific user
  Stream<List<Reservation>> watchUserReservations(String userId) {
    return _db.ref('reservations').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return const <Reservation>[];

      final map = Map<String, dynamic>.from(data as Map);
      final reservations = <Reservation>[];

      map.forEach((key, value) {
        final resData = Map<String, dynamic>.from(value as Map);
        if (resData['userId'] == userId) {
          reservations.add(_fromMap(key, resData));
        }
      });

      // Sort by createdAt descending
      reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reservations;
    });
  }

  /// Creates a new reservation and returns its ID
  Future<String> createReservation({
    required String userId,
    required String slotId,
    required int arrivalTime,
    required int durationHours,
  }) async {
    final id = 'res_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.ref('reservations/$id').set({
      'userId': userId,
      'slotId': slotId,
      'arrivalTime': arrivalTime,
      'durationHours': durationHours,
      'status': ReservationStatus.active,
      'createdAt': now,
    });

    return id;
  }

  /// Updates a reservation's status
  Future<void> updateReservationStatus(String resId, String status) async {
    await _db.ref('reservations/$resId/status').set(status);
  }

  /// Reads a single reservation once
  Future<Reservation?> getReservation(String resId) async {
    final snapshot = await _db.ref('reservations/$resId').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return _fromMap(resId, data);
  }

  Reservation _fromMap(String id, Map<String, dynamic> map) {
    return Reservation(
      id: id,
      userId: map['userId'] as String,
      slotId: map['slotId'] as String,
      arrivalTime: map['arrivalTime'] as int,
      durationHours: map['durationHours'] as int,
      status: map['status'] as String? ?? ReservationStatus.active,
      createdAt: map['createdAt'] as int,
    );
  }
}
