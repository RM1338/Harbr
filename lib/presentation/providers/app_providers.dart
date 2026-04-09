import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../data/datasources/firebase_slot_datasource.dart';
import '../../data/datasources/firebase_reservation_datasource.dart';
import '../../data/datasources/firebase_event_datasource.dart';
import '../../data/datasources/influxdb_datasource.dart';
import '../../data/datasources/hive_cache_datasource.dart';
import '../../domain/entities/parking_slot.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/entities/parking_event.dart';
import '../../domain/entities/violation.dart';

// ── Data Sources ─────────────────────────────────────────────────────────────

final firebaseAuthDSProvider = Provider<FirebaseAuthDataSource>(
  (ref) => FirebaseAuthDataSource(),
);

final firebaseSlotDSProvider = Provider<FirebaseSlotDataSource>(
  (ref) => FirebaseSlotDataSource(),
);

final firebaseReservationDSProvider = Provider<FirebaseReservationDataSource>(
  (ref) => FirebaseReservationDataSource(),
);

final firebaseEventDSProvider = Provider<FirebaseEventDataSource>(
  (ref) => FirebaseEventDataSource(),
);

final hiveCacheProvider = Provider<HiveCacheDataSource>(
  (ref) => HiveCacheDataSource(),
);

final influxDbDSProvider = Provider<InfluxDBDataSource>(
  (ref) {
    final ds = InfluxDBDataSource();
    ref.onDispose(() => ds.close());
    return ds;
  },
);

// ── Auth ─────────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthDSProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// ── Slots ────────────────────────────────────────────────────────────────────

final slotsStreamProvider = StreamProvider<List<ParkingSlot>>((ref) {
  final ds = ref.watch(firebaseSlotDSProvider);
  final influxDs = ref.read(influxDbDSProvider);

  return ds.watchSlots().map((slots) {
    // Every time slots update from Firebase (like an Arduino sensor update),
    // push the state of all slots to InfluxDB for time-series modeling.
    for (final slot in slots) {
      influxDs.writeSlotStatus(slot);
    }
    return slots;
  });
});

// ── Reservations ─────────────────────────────────────────────────────────────

final userReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);

  final ds = ref.watch(firebaseReservationDSProvider);
  return ds.watchUserReservations(user.uid);
});

// ── Events ────────────────────────────────────────────────────────────────────

final eventsStreamProvider = StreamProvider<List<ParkingEvent>>((ref) {
  final ds = ref.watch(firebaseEventDSProvider);
  return ds.watchEvents();
});

// ── Violations ────────────────────────────────────────────────────────────────

final violationStreamProvider = StreamProvider<Violation>((ref) {
  final ds = ref.watch(firebaseSlotDSProvider);
  return ds.watchViolations();
});

// ── Connectivity ──────────────────────────────────────────────────────────────

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// ── Settings (Hive) ──────────────────────────────────────────────────────────

final notificationsEnabledProvider =
    StateProvider<bool>((ref) {
  final cache = ref.watch(hiveCacheProvider);
  return cache.notificationsEnabled;
});

// ── User Profile ──────────────────────────────────────────────────────────────

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final ds = ref.watch(firebaseAuthDSProvider);
  return ds.getUserProfile(user.uid);
});
