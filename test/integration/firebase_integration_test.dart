/// Integration tests for Firebase datasources.
///
/// 11.1 — FirebaseSlotDataSource.watchSlots() attaches listener to /slots/ path
/// 11.2 — Gate open command write propagates correctly through mock Firebase
/// 11.3 — Violation notification appears when /slots/{id}/violation is written
///
/// Uses manual mock objects (no real Firebase connection required).

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbr/data/datasources/firebase_gate_datasource.dart';
import 'package:harbr/data/datasources/firebase_slot_datasource.dart';
import 'package:harbr/domain/entities/violation.dart';

// ── Mock helpers ──────────────────────────────────────────────────────────────

/// Records every [ref(path)] call and the subsequent operation performed.
class _MockFirebaseDatabase extends Fake implements FirebaseDatabase {
  final List<String> refPaths = [];
  final Map<String, _MockDatabaseReference> _refs = {};

  @override
  DatabaseReference ref([String? path]) {
    final p = path ?? '/';
    refPaths.add(p);
    return _refs.putIfAbsent(p, () => _MockDatabaseReference(p));
  }
}

class _MockDatabaseReference extends Fake implements DatabaseReference {
  final String path;
  final List<dynamic> setValues = [];
  final List<Map<String, dynamic>> updateValues = [];

  // onValue stream controller — tests push events here
  final StreamController<DatabaseEvent> _onValueController =
      StreamController<DatabaseEvent>.broadcast();

  _MockDatabaseReference(this.path);

  @override
  Stream<DatabaseEvent> get onValue => _onValueController.stream;

  @override
  Future<void> set(Object? value, {Object? priority}) async {
    setValues.add(value);
  }

  @override
  Future<void> update(Map<Object?, Object?> value) async {
    updateValues.add(Map<String, dynamic>.from(value));
  }

  @override
  DatabaseReference child(String path) {
    // Return a child ref — for simplicity reuse the same mock
    return _MockDatabaseReference('${this.path}/$path');
  }

  @override
  Query orderByChild(String key) => _MockQuery(this);

  /// Push a snapshot event into the onValue stream.
  void pushEvent(Object? data) {
    _onValueController.add(_MockDatabaseEvent(_MockDataSnapshot(data)));
  }

  void dispose() {
    _onValueController.close();
  }
}

class _MockQuery extends Fake implements Query {
  final _MockDatabaseReference _ref;
  _MockQuery(this._ref);

  @override
  Stream<DatabaseEvent> get onValue => _ref.onValue;
}

class _MockDatabaseEvent extends Fake implements DatabaseEvent {
  @override
  final DataSnapshot snapshot;
  _MockDatabaseEvent(this.snapshot);
}

class _MockDataSnapshot extends Fake implements DataSnapshot {
  final Object? _value;
  _MockDataSnapshot(this._value);

  @override
  Object? get value => _value;
}

void main() {
// ── 11.1: watchSlots() attaches listener to /slots/ path ─────────────────────

group('11.1 FirebaseSlotDataSource.watchSlots() — path binding', () {
  test('watchSlots() calls ref("slots") on the database', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    // Subscribe to the stream (this triggers the ref() call)
    final sub = ds.watchSlots().listen((_) {});
    addTearDown(sub.cancel);

    // The datasource must have called ref('slots')
    expect(
      mockDb.refPaths,
      contains('slots'),
      reason: 'watchSlots() must attach a listener to the /slots/ path',
    );
  });

  test('watchSlots() emits a list when the mock pushes a snapshot', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final emitted = <List<dynamic>>[];
    final sub = ds.watchSlots().listen(emitted.add);
    addTearDown(sub.cancel);

    // Push a snapshot with one slot
    final slotsRef = mockDb._refs['slots']!;
    slotsRef.pushEvent({
      'A1': {'status': 'available'},
    });

    // Allow microtasks to propagate
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isNotEmpty,
        reason: 'watchSlots() must emit when Firebase pushes a value');
    expect(emitted.first, isA<List>());
  });

  test('watchSlots() emits fallback slot list when snapshot data is null', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final emitted = <List<dynamic>>[];
    final sub = ds.watchSlots().listen(emitted.add);
    addTearDown(sub.cancel);

    mockDb._refs['slots']!.pushEvent(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isNotEmpty);
    // Datasource returns a fallback list of all slots as 'available' when data is null
    expect(emitted.first, isNotEmpty,
        reason: 'null snapshot must produce a fallback list of available slots');
  });
});

// ── 11.2: writeOpenCommand(true) writes to /gate/open_command ────────────────

group('11.2 FirebaseGateDataSource.writeOpenCommand() — propagation', () {
  test('writeOpenCommand(true) calls set(true) on gate/open_command ref', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseGateDataSource(db: mockDb);

    await ds.writeOpenCommand(true);

    expect(
      mockDb.refPaths,
      contains('gate/open_command'),
      reason: 'writeOpenCommand must target the gate/open_command path',
    );

    final ref = mockDb._refs['gate/open_command']!;
    expect(
      ref.setValues,
      contains(true),
      reason: 'writeOpenCommand(true) must call set(true) on the ref',
    );
  });

  test('writeOpenCommand(false) calls set(false) on gate/open_command ref', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseGateDataSource(db: mockDb);

    await ds.writeOpenCommand(false);

    final ref = mockDb._refs['gate/open_command']!;
    expect(ref.setValues, contains(false));
  });

  test('writeOpenCommand does not write to any other path', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseGateDataSource(db: mockDb);

    await ds.writeOpenCommand(true);

    // Only gate/open_command should have been written
    final writtenPaths = mockDb._refs.entries
        .where((e) => e.value.setValues.isNotEmpty)
        .map((e) => e.key)
        .toList();

    expect(writtenPaths, equals(['gate/open_command']),
        reason: 'writeOpenCommand must only write to gate/open_command');
  });
});

// ── 11.3: violation notification when /slots/{id}/violation is written ────────

group('11.3 FirebaseSlotDataSource.watchViolations() — violation stream', () {
  test('watchViolations() subscribes to /slots/{id}/violation for each slot', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final sub = ds.watchViolations().listen((_) {});
    addTearDown(sub.cancel);

    // Allow subscriptions to be set up
    await Future<void>.delayed(Duration.zero);

    // Each slot ID should have a ref for its violation path
    // kAllSlotIds = ['A1', 'A2', 'A3']
    for (final slotId in ['A1', 'A2', 'A3']) {
      expect(
        mockDb.refPaths,
        contains('slots/$slotId/violation'),
        reason: 'watchViolations() must subscribe to slots/$slotId/violation',
      );
    }
  });

  test('watchViolations() emits Violation when violation data is pushed', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final violations = <Violation>[];
    final sub = ds.watchViolations().listen(violations.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(Duration.zero);

    // Simulate Python backend writing a violation to /slots/A1/violation
    final violationRef = mockDb._refs['slots/A1/violation']!;
    violationRef.pushEvent({
      'type': 'ice_in_ev_slot',
      'timestamp': 1700000000000,
      'slotId': 'A1',
    });

    await Future<void>.delayed(Duration.zero);

    expect(violations, hasLength(1),
        reason: 'watchViolations() must emit when a violation is written');
    expect(violations.first.slotId, equals('A1'));
    expect(violations.first.type, equals('ice_in_ev_slot'));
    expect(violations.first.timestamp, equals(1700000000000));
  });

  test('watchViolations() ignores null violation data', () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final violations = <Violation>[];
    final sub = ds.watchViolations().listen(violations.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(Duration.zero);

    // Push null (cleared violation)
    mockDb._refs['slots/A1/violation']!.pushEvent(null);
    await Future<void>.delayed(Duration.zero);

    expect(violations, isEmpty,
        reason: 'null violation data must not emit a Violation event');
  });

  test('watchViolations() emits violations from multiple slots independently',
      () async {
    final mockDb = _MockFirebaseDatabase();
    final ds = FirebaseSlotDataSource(db: mockDb);

    final violations = <Violation>[];
    final sub = ds.watchViolations().listen(violations.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(Duration.zero);

    // Write violations to two different slots
    mockDb._refs['slots/A1/violation']!.pushEvent({
      'type': 'ice_in_ev_slot',
      'timestamp': 1700000000001,
      'slotId': 'A1',
    });
    mockDb._refs['slots/A2/violation']!.pushEvent({
      'type': 'ev_no_cable',
      'timestamp': 1700000000002,
      'slotId': 'A2',
    });

    await Future<void>.delayed(Duration.zero);

    expect(violations, hasLength(2));
    final slotIds = violations.map((v) => v.slotId).toSet();
    expect(slotIds, containsAll(['A1', 'A2']));
  });
});
} // end main()
