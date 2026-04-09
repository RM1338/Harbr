# Tasks

## Task List

- [x] 1. Flutter Data Layer — Gate Datasource & Domain Entity
  - [x] 1.1 Create `GateEvent` domain entity in `lib/domain/entities/gate_event.dart`
  - [x] 1.2 Create `FirebaseGateDataSource` in `lib/data/datasources/firebase_gate_datasource.dart` with `watchGateStatus()`, `watchEntryDetected()`, `writeOpenCommand()`, and `watchGateEvents()` methods
  - [x] 1.3 Extend `ParkingSlot` entity with `vehicleType`, `lastSensorReading`, and `syncStatus` fields
  - [x] 1.4 Add gate providers (`gateStatusProvider`, `entryDetectedProvider`, `gateEventsProvider`) to `lib/presentation/providers/gate_providers.dart`

- [x] 2. Flutter Presentation — Slot Map Screen (ParkSense Live)
  - [x] 2.1 Create `SlotMapCell` widget in `lib/presentation/widgets/slot_map_cell.dart` with color-coding (white=free, black=occupied, hatched=reserved)
  - [x] 2.2 Create `SlotMapScreen` in `lib/presentation/screens/map/slot_map_screen.dart` rendering a `GridView` grouped by zone, consuming `slotsStreamProvider`
  - [x] 2.3 Wire tap navigation from `SlotMapCell` to `SlotDetailScreen` via GoRouter with `slotId` query param
  - [x] 2.4 Add `/map` route to `app_router.dart` and bottom nav item to `ShellScaffold`

- [x] 3. Flutter Presentation — Slot Detail Screen
  - [x] 3.1 Create `SlotDetailScreen` in `lib/presentation/screens/slot/slot_detail_screen.dart` displaying slot ID, zone, row, distance, last sensor reading, and sync status
  - [x] 3.2 Implement conditional "Reserve Slot" button — visible and enabled only when `slot.isAvailable`
  - [x] 3.3 Implement reservation write: call `FirebaseReservationDataSource.createReservation()` and write to `/gate/reservation` on button tap
  - [x] 3.4 Handle race condition: check slot status at write time and show error `SnackBar` if slot is no longer available
  - [x] 3.5 Add `/slot` route to `app_router.dart`

- [x] 4. Flutter Presentation — Gate Control Screen
  - [x] 4.1 Create `GateLogEntry` widget in `lib/presentation/widgets/gate_log_entry.dart` for terminal-style timestamped log rows
  - [x] 4.2 Create `GateControlScreen` in `lib/presentation/screens/gate/gate_control_screen.dart` displaying gate status badge and scrollable event log
  - [x] 4.3 Implement entry detection notification: show confirmation dialog when `entryDetectedProvider` emits `true`
  - [x] 4.4 Implement "Confirm Entry & Open Gate" button writing `true` to `/gate/open_command` via `FirebaseGateDataSource`
  - [x] 4.5 Add `/gate` route to `app_router.dart` and bottom nav item to `ShellScaffold`

- [x] 5. Flutter Presentation — Bookings Screen Enhancements
  - [x] 5.1 Create `BookingCard` widget in `lib/presentation/widgets/booking_card.dart` with slot ID, zone, and live countdown timer to `reservation.endTime`
  - [x] 5.2 Add "Open Gate" button to `BookingCard` that writes `true` to `/gate/open_command`
  - [x] 5.3 Update `MyBookingsScreen` to show active booking card at top and past bookings list sorted by `createdAt` ascending
  - [x] 5.4 Show "No active booking" empty state when no active reservation exists

- [x] 6. Flutter — Violation Notification & Connectivity
  - [x] 6.1 Create `ViolationBanner` widget in `lib/presentation/widgets/violation_banner.dart` for in-app violation notifications
  - [x] 6.2 Add Firebase listener on `/slots/{id}/violation` in `FirebaseSlotDataSource` and surface violation events via a `violationStreamProvider`
  - [x] 6.3 Implement connectivity monitoring using the `connectivity_plus` package; show persistent warning banner on loss and auto-dismiss on restore

- [x] 7. Flutter — Property-Based Tests (Dart)
  - [x] 7.1 Write property test for slot count formatter — Property 1: for any `List<ParkingSlot>`, verify `"{free}/{total}"` output correctness (min 100 iterations)
  - [x] 7.2 Write property test for auto-assign nearest free slot — Property 2: for any slot list, verify result is minimum-distance available slot or null (min 100 iterations)
  - [x] 7.3 Write property test for zone grouping — Property 3: for any slot list, verify every slot appears in exactly one correct zone bucket (min 100 iterations)
  - [x] 7.4 Write property test for color mapping — Property 4: for any `ParkingSlot`, verify color mapping is non-null and matches expected status color (min 100 iterations)
  - [x] 7.5 Write property test for reserve button visibility — Property 5: for any slot, verify button visible iff `slot.isAvailable` (min 100 iterations)
  - [x] 7.6 Write property test for booking card fields — Property 6: for any active `Reservation`, verify card renders slot ID, zone, and non-negative countdown (min 100 iterations)
  - [x] 7.7 Write property test for past bookings sort — Property 7: for any list of past reservations, verify sorted by `createdAt` ascending (min 100 iterations)

- [x] 8. Python — OpenCV Pipeline Setup
  - [x] 8.1 Create `hardware/cv_pipeline/` directory with `__init__.py` and `main.py` entry point
  - [x] 8.2 Implement `SlotDetector` in `slot_detector.py` using OpenCV background subtraction (`cv2.createBackgroundSubtractorMOG2`) with configurable slot ROIs
  - [x] 8.3 Implement `VehicleClassifier` in `vehicle_classifier.py` using HSV masking (`cv2.inRange`) on the roof ROI to classify EV vs ICE
  - [x] 8.4 Implement `CableDetector` in `cable_detector.py` using Canny edge detection and contour analysis on the rear bounding box ROI
  - [x] 8.5 Implement `ComplianceTimer` in `compliance_timer.py` with per-slot 5-minute timers using `threading.Timer`

- [x] 9. Python — Firebase Bridge & InfluxDB Logger
  - [x] 9.1 Implement `FirebaseBridge` in `firebase_bridge.py` with `write_slot_status()`, `write_violation()`, `write_gate_status()`, and `write_entry_detected()` methods using Firebase Admin SDK
  - [x] 9.2 Implement `InfluxLogger` in `influx_logger.py` with `log_violation()` and `log_slot_status()` methods writing to InfluxDB Cloud
  - [x] 9.3 Implement `GateBridge` in `gate_bridge.py` with Firebase `/gate/open_command` listener → HiveMQ MQTT publish, and MQTT subscriber → Firebase `/gate/status` and `/gate/entry_detected` writes
  - [x] 9.4 Wire all components together in `main.py` running the OpenCV pipeline loop and `GateBridge` in separate threads

- [x] 10. Python — Property-Based Tests (Hypothesis)
  - [x] 10.1 Write property test for pipeline output validity — Property 8: for any synthetic frame, verify all status values in `{available, occupied, reserved}` (min 100 iterations)
  - [x] 10.2 Write property test for camera error state preservation — Property 9: inject `None` frames, verify Firebase mock not called with new state (min 100 iterations)
  - [x] 10.3 Write property test for HSV classification exhaustiveness — Property 10: generate random HSV pixel arrays in/out of range, verify correct and non-null classification (min 100 iterations)
  - [x] 10.4 Write property test for ICE in EV slot violation — Property 11: generate ICE + EV slot combinations, verify both Firebase and InfluxDB writes called (min 100 iterations)
  - [x] 10.5 Write property test for cable detected before timeout — Property 12: simulate EV + cable detection before 300s, verify no violation written (min 100 iterations)
  - [x] 10.6 Write property test for expired timer without cable — Property 13: simulate EV + timer expiry + no cable, verify violation written to both Firebase and InfluxDB (min 100 iterations)

- [x] 11. Integration & Smoke Tests
  - [x] 11.1 Flutter integration test: verify `FirebaseSlotDataSource.watchSlots()` attaches listener to `/slots/` path
  - [x] 11.2 Flutter integration test: verify gate open command write propagates correctly through mock Firebase
  - [x] 11.3 Flutter integration test: verify violation notification appears when `/slots/{id}/violation` is written to mock Firebase
  - [x] 11.4 Python integration test: verify `GateBridge` publishes to MQTT mock when Firebase `/gate/open_command` is set to `true`
  - [x] 11.5 Python integration test: verify `GateBridge` writes to Firebase `/gate/status` when MQTT gate status message received
  - [x] 11.6 Python smoke test: verify no MQTT client import or instantiation exists in any Flutter/Dart source file
