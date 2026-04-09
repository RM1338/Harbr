import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/firebase_gate_datasource.dart';
import '../../domain/entities/gate_event.dart';

// ── Data Source ───────────────────────────────────────────────────────────────

final firebaseGateDataSourceProvider = Provider<FirebaseGateDataSource>(
  (ref) => FirebaseGateDataSource(),
);

// ── Gate Streams ──────────────────────────────────────────────────────────────

final gateStatusProvider = StreamProvider<String>((ref) {
  final ds = ref.watch(firebaseGateDataSourceProvider);
  return ds.watchGateStatus();
});

final entryDetectedProvider = StreamProvider<bool>((ref) {
  final ds = ref.watch(firebaseGateDataSourceProvider);
  return ds.watchEntryDetected();
});

final gateEventsProvider = StreamProvider<List<GateEvent>>((ref) {
  final ds = ref.watch(firebaseGateDataSourceProvider);
  return ds.watchGateEvents();
});
