# Design Document — Harbr Flutter App

## Overview

Harbr is a Hybrid Edge-Cloud Smart Parking System composed of three tightly coupled subsystems:

1. **Flutter Mobile App** — the driver-facing interface for slot visibility, reservations, gate control, and booking management.
2. **Firebase Realtime Database** — the shared state layer that decouples the Flutter app from all hardware and backend processes.
3. **Python/OpenCV Edge Backend** — runs on an edge device, performs computer vision (slot occupancy, EV/ICE classification, cable compliance), bridges Firebase commands to the Arduino gate controller via MQTT.

Flutter never communicates with MQTT or hardware directly. All hardware actuation is mediated through Firebase. The Python backend is the sole MQTT client.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│  (Riverpod + GoRouter + Firebase Realtime DB SDK)               │
└────────────────────────┬────────────────────────────────────────┘
                         │  Firebase Realtime DB (harbr-3cd5c)
          ┌──────────────┼──────────────┐
          │              │              │
     /slots/        /gate/        /reservations/
     /events/       /violations/
          │              │              │
┌─────────┴──────────────┴──────────────┴──────────┐
│              Python Edge Backend                  │
│  (Firebase Admin SDK + OpenCV + paho-mqtt)        │
│                                                   │
│  ┌─────────────────┐   ┌──────────────────────┐  │
│  │  OpenCV Pipeline│   │  Firebase-MQTT Bridge │  │
│  │  (CV2, YOLO)    │   │  (gate commands)      │  │
│  └─────────────────┘   └──────────┬───────────┘  │
└──────────────────────────────────┬┴──────────────┘
                                   │ HiveMQ Cloud MQTT
                          ┌────────┴────────┐
                          │  Arduino Gate   │
                          │  Controller     │
                          └─────────────────┘
```

---

## Architecture

### Flutter App — Clean Architecture with Riverpod

The app follows a three-layer clean architecture:

- **Presentation layer** — screens, widgets, Riverpod providers (UI state)
- **Domain layer** — pure Dart entities (`ParkingSlot`, `Reservation`, `ParkingEvent`, `UserProfile`)
- **Data layer** — Firebase datasources, Hive cache datasource, InfluxDB datasource

State management uses **Flutter Riverpod** (`StreamProvider`, `FutureProvider`, `StateProvider`). Navigation uses **GoRouter** with auth-gated redirects.

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/app_constants.dart      # SlotStatus, ReservationStatus, EventType, etc.
│   ├── router/app_router.dart            # GoRouter + auth redirect
│   ├── services/reservation_integrity_service.dart
│   └── theme/                            # AppTheme, AppColors, AppTextStyles
├── data/
│   └── datasources/
│       ├── firebase_auth_datasource.dart
│       ├── firebase_slot_datasource.dart
│       ├── firebase_reservation_datasource.dart
│       ├── firebase_event_datasource.dart
│       ├── firebase_gate_datasource.dart  # NEW — /gate/ path listener + writer
│       ├── hive_cache_datasource.dart
│       └── influxdb_datasource.dart
├── domain/
│   └── entities/
│       ├── parking_slot.dart
│       ├── reservation.dart
│       ├── parking_event.dart
│       ├── user_profile.dart
│       └── gate_event.dart               # NEW — gate log entry
└── presentation/
    ├── providers/
    │   ├── app_providers.dart
    │   ├── gate_providers.dart            # NEW — gate status, entry_detected streams
    │   └── reservation_flow_provider.dart
    ├── screens/
    │   ├── onboarding_screen.dart
    │   ├── auth/sign_in_screen.dart
    │   ├── auth/sign_up_screen.dart
    │   ├── home/home_screen.dart          # Slot list + "Find me a slot"
    │   ├── map/slot_map_screen.dart       # NEW — ParkSense Live grid
    │   ├── slot/slot_detail_screen.dart   # NEW — slot detail + reserve
    │   ├── gate/gate_control_screen.dart  # NEW — gate status + event log
    │   ├── bookings/my_bookings_screen.dart
    │   ├── updates/live_updates_screen.dart
    │   └── profile/profile_screen.dart
    └── widgets/
        ├── shell_scaffold.dart
        ├── slot_tile.dart
        ├── slot_map_cell.dart             # NEW — color-coded grid cell
        ├── booking_card.dart              # NEW — active booking with countdown
        ├── gate_log_entry.dart            # NEW — terminal-style log row
        ├── violation_banner.dart          # NEW — in-app violation notification
        └── error_banner.dart
```

### Python Edge Backend

The Python backend is a single long-running process with two concurrent responsibilities:

1. **OpenCV Pipeline** — reads camera frames, detects slot occupancy, classifies vehicles, checks cable compliance, writes results to Firebase and InfluxDB.
2. **Firebase-MQTT Bridge** — listens to Firebase `/gate/open_command`, publishes to HiveMQ; subscribes to Arduino MQTT topics, writes state back to Firebase.

```
hardware/
├── smart_parking_middleware.py     # existing MQTT→Firebase bridge (to be extended)
├── smart_parking_arduino.ino       # Arduino gate controller
├── hardware_only_code.ino
└── cv_pipeline/                    # NEW
    ├── main.py                     # entry point — starts both threads
    ├── slot_detector.py            # background subtraction / YOLO occupancy
    ├── vehicle_classifier.py       # HSV masking for EV/ICE classification
    ├── cable_detector.py           # contour/edge detection for cable compliance
    ├── compliance_timer.py         # per-slot 5-minute EV compliance timer
    ├── firebase_bridge.py          # Firebase Admin SDK read/write helpers
    ├── gate_bridge.py              # Firebase /gate/ listener → MQTT publisher
    └── influx_logger.py            # InfluxDB Cloud event logger
```

---

## Components and Interfaces

### Flutter Components

#### `FirebaseGateDataSource` (new)
Manages all reads and writes to the `/gate/` Firebase path.

```dart
class FirebaseGateDataSource {
  Stream<String> watchGateStatus();           // /gate/status
  Stream<bool> watchEntryDetected();          // /gate/entry_detected
  Future<void> writeOpenCommand(bool value);  // /gate/open_command
  Stream<List<GateEvent>> watchGateEvents();  // /gate/events/
}
```

#### `GateProviders` (new)
Riverpod providers wrapping `FirebaseGateDataSource`.

```dart
final gateStatusProvider = StreamProvider<String>(...);
final entryDetectedProvider = StreamProvider<bool>(...);
```

#### `SlotMapScreen` (new)
Renders a `GridView` of `SlotMapCell` widgets grouped by zone. Consumes `slotsStreamProvider`. Tapping a cell navigates to `SlotDetailScreen` via GoRouter with `slotId` query param.

#### `SlotDetailScreen` (new)
Displays full slot metadata. Shows "Reserve Slot" button when `slot.isAvailable`. On tap, calls `FirebaseReservationDataSource.createReservation()` and writes to `/gate/reservation`.

#### `GateControlScreen` (new)
Displays gate status badge and a `ListView` of `GateLogEntry` widgets. Shows "Confirm Entry & Open Gate" button when `entryDetectedProvider` emits `true`. On tap, calls `FirebaseGateDataSource.writeOpenCommand(true)`.

#### `BookingCard` (new)
Displays active reservation with a `CountdownTimer` widget computing `reservation.endTime - DateTime.now()`. Shows "Open Gate" button that calls `FirebaseGateDataSource.writeOpenCommand(true)`.

### Python Components

#### `SlotDetector`
```python
class SlotDetector:
    def __init__(self, slot_rois: dict[str, tuple], method: str = "background_subtraction"):
        ...
    def process_frame(self, frame: np.ndarray) -> dict[str, str]:
        """Returns {slot_id: status} for all slots."""
```

#### `VehicleClassifier`
```python
class VehicleClassifier:
    def __init__(self, hsv_lower: np.ndarray, hsv_upper: np.ndarray):
        ...
    def classify(self, roof_roi: np.ndarray) -> str:
        """Returns 'ev' or 'ice' based on HSV sticker detection."""
```

#### `CableDetector`
```python
class CableDetector:
    def detect(self, rear_roi: np.ndarray) -> bool:
        """Returns True if charging cable contour detected."""
```

#### `ComplianceTimer`
```python
class ComplianceTimer:
    def start(self, slot_id: str, timeout_seconds: int = 300): ...
    def cancel(self, slot_id: str): ...
    def is_expired(self, slot_id: str) -> bool: ...
```

#### `GateBridge`
```python
class GateBridge:
    def start(self):
        """Attaches Firebase listener on /gate/open_command and MQTT subscriber."""
    def _on_open_command(self, event):
        """Firebase callback → publish to HiveMQ."""
    def _on_mqtt_message(self, client, userdata, msg):
        """MQTT callback → write to Firebase /gate/status or /gate/entry_detected."""
```

---

## Data Models

### Firebase Realtime Database Schema

```
harbr-3cd5c (root)
├── slots/
│   └── {slotId}/                    # e.g. "A1", "A2", "A3"
│       ├── status: "available" | "occupied" | "reserved"
│       ├── reservedBy: string | null   # userId
│       ├── until: number | null        # Unix ms expiry
│       ├── vehicleType: "ev" | "ice" | null
│       ├── lastSensorReading: number   # Unix ms
│       ├── syncStatus: "synced" | "stale"
│       └── violation/
│           ├── type: "ice_in_ev_slot" | "ev_no_cable"
│           ├── timestamp: number       # Unix ms
│           └── slotId: string
│
├── gate/
│   ├── status: "ready" | "open" | "closed"
│   ├── open_command: boolean           # Flutter writes true; Python clears
│   ├── entry_detected: boolean         # Python writes true; Flutter clears
│   ├── reservation/
│   │   ├── slotId: string
│   │   ├── userId: string
│   │   └── timestamp: number           # Unix ms
│   └── events/
│       └── {eventId}/
│           ├── type: string
│           ├── message: string
│           └── timestamp: number       # Unix ms
│
├── reservations/
│   └── {reservationId}/
│       ├── userId: string
│       ├── slotId: string
│       ├── arrivalTime: number         # Unix ms
│       ├── durationHours: number
│       ├── status: "active" | "cancelled" | "completed" | "no_show"
│       └── createdAt: number           # Unix ms
│
└── events/
    └── {eventId}/
        ├── type: "violation" | "no_show" | "reservation" | "sensor" | "auth"
        ├── slotId: string
        ├── message: string
        ├── timestamp: number           # Unix ms
        └── severity: "critical" | "warning" | "info"
```

### Dart Domain Entities

#### `ParkingSlot`
```dart
class ParkingSlot extends Equatable {
  final String id;
  final String status;          // SlotStatus constant
  final String? reservedBy;
  final int? until;             // Unix ms
  final String? vehicleType;    // 'ev' | 'ice' | null
  final int? lastSensorReading; // Unix ms
  final String? syncStatus;     // 'synced' | 'stale'
}
```

#### `Reservation`
```dart
class Reservation extends Equatable {
  final String id;
  final String userId;
  final String slotId;
  final int arrivalTime;        // Unix ms
  final int durationHours;
  final String status;          // ReservationStatus constant
  final int createdAt;          // Unix ms
  // Derived: endTime, isActive, isPast, totalCost
}
```

#### `GateEvent` (new)
```dart
class GateEvent extends Equatable {
  final String id;
  final String type;
  final String message;
  final int timestamp;          // Unix ms
}
```

#### `Violation` (embedded in ParkingSlot, also written to /events/)
```dart
class Violation extends Equatable {
  final String type;            // 'ice_in_ev_slot' | 'ev_no_cable'
  final int timestamp;          // Unix ms
  final String slotId;
}
```

### Python Data Structures

```python
@dataclass
class SlotState:
    slot_id: str
    status: str          # 'available' | 'occupied' | 'reserved'
    vehicle_type: str | None   # 'ev' | 'ice' | None
    last_updated: float  # Unix timestamp

@dataclass
class ViolationEvent:
    slot_id: str
    violation_type: str  # 'ice_in_ev_slot' | 'ev_no_cable'
    timestamp: float
    vehicle_type: str
```

---

## Key Component Interactions and Data Flow

### Flow 1: Slot Occupancy Update

```
Camera Frame
    │
    ▼
SlotDetector.process_frame()
    │  {slot_id: status}
    ▼
firebase_bridge.write_slot_status()
    │  /slots/{id}/status
    ▼
Firebase Realtime DB
    │  onValue stream
    ▼
FirebaseSlotDataSource.watchSlots()
    │  List<ParkingSlot>
    ▼
slotsStreamProvider (Riverpod)
    │
    ▼
HomeScreen / SlotMapScreen rebuild
```

### Flow 2: Gate Open Command

```
Driver taps "Confirm Entry" or "Open Gate"
    │
    ▼
FirebaseGateDataSource.writeOpenCommand(true)
    │  /gate/open_command = true
    ▼
Firebase Realtime DB
    │  onValue callback
    ▼
GateBridge._on_open_command()
    │  mqtt.publish("parking/gate/open")
    ▼
HiveMQ Cloud MQTT
    │
    ▼
Arduino → servo opens gate
    │  mqtt.publish("parking/gate/status", "open")
    ▼
GateBridge._on_mqtt_message()
    │  /gate/status = "open"
    ▼
Firebase Realtime DB
    │  onValue stream
    ▼
gateStatusProvider → GateControlScreen rebuilds
```

### Flow 3: EV Compliance Check

```
SlotDetector detects vehicle in EV slot
    │
    ▼
VehicleClassifier.classify(roof_roi)
    │  "ev" or "ice"
    ▼
[if "ice"] → write Violation to /slots/{id}/violation + InfluxDB
[if "ev"]  → ComplianceTimer.start(slot_id, 300)
                │
                │ (5 minutes pass)
                ▼
            CableDetector.detect(rear_roi)
                │  True / False
                ▼
            [cable found]  → ComplianceTimer.cancel() → mark compliant
            [no cable]     → write Violation to /slots/{id}/violation + InfluxDB
                                │
                                ▼
                            Firebase /slots/{id}/violation
                                │  onValue stream
                                ▼
                            Flutter ViolationBanner notification
```

### Flow 4: Reservation

```
Driver taps "Reserve Slot" on SlotDetailScreen
    │
    ▼
FirebaseReservationDataSource.createReservation()
    │  /reservations/{id} = { userId, slotId, arrivalTime, ... }
    │
    ▼
FirebaseSlotDataSource.updateSlot(status: 'reserved', reservedBy: userId)
    │  /slots/{id}/status = "reserved"
    │
    ▼
Firebase Realtime DB
    │  propagates to all listeners
    ▼
SlotMapScreen + HomeScreen rebuild (slot now shows as Reserved)
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Slot count display correctness

*For any* list of `ParkingSlot` objects with arbitrary statuses, the count formatter SHALL produce a string in the format `"{free}/{total}"` where `free` equals the number of slots with `status == 'available'` and `total` equals the list length.

**Validates: Requirements 1.1**

---

### Property 2: Auto-assign returns nearest free slot

*For any* non-empty list of `ParkingSlot` objects, the auto-assign function SHALL return the slot with the minimum distance value among all slots with `status == 'available'`, or `null` if no free slot exists.

**Validates: Requirements 1.5, 1.6**

---

### Property 3: Slot grid grouping by zone

*For any* list of `ParkingSlot` objects, the zone-grouping function SHALL produce a map where every slot appears in exactly one zone bucket and no slot appears in a zone bucket that does not match its zone prefix.

**Validates: Requirements 2.1**

---

### Property 4: Slot status color mapping is total and correct

*For any* `ParkingSlot`, the color/style mapping function SHALL return a non-null value, and the returned value SHALL match the expected color for the slot's status (white for available, black for occupied, hatched pattern for reserved).

**Validates: Requirements 2.2**

---

### Property 5: Reserve button visibility matches slot status

*For any* `ParkingSlot`, the "Reserve Slot" button SHALL be visible and enabled if and only if `slot.status == 'available'`. For any slot with `status != 'available'`, the button SHALL be absent or disabled.

**Validates: Requirements 3.3, 3.6**

---

### Property 6: Active booking card contains required fields

*For any* active `Reservation`, the booking card widget SHALL render the slot ID, zone, and a countdown value derived from `reservation.endTime - now` that is non-negative.

**Validates: Requirements 5.1**

---

### Property 7: Past bookings are sorted chronologically

*For any* list of past `Reservation` objects, the bookings list SHALL display them sorted by `createdAt` in ascending order (oldest first).

**Validates: Requirements 5.4**

---

### Property 8: OpenCV pipeline output is always a valid status

*For any* camera frame processed by `SlotDetector.process_frame()`, every value in the returned status map SHALL be one of `{'available', 'occupied', 'reserved'}`.

**Validates: Requirements 7.1**

---

### Property 9: Camera error preserves last known slot state

*For any* slot with a known last state, when `SlotDetector.process_frame()` receives a `None` or corrupt frame, the slot state in Firebase SHALL remain unchanged from its last known value.

**Validates: Requirements 7.4**

---

### Property 10: HSV classification is correct and exhaustive

*For any* roof ROI image, `VehicleClassifier.classify()` SHALL return `'ev'` if and only if the image contains pixels within the configured HSV range, and SHALL return `'ice'` otherwise. The result is never `None`.

**Validates: Requirements 8.1, 8.2, 8.3**

---

### Property 11: ICE in EV slot always produces a violation

*For any* slot designated as an EV slot, when `VehicleClassifier.classify()` returns `'ice'`, a `ViolationEvent` with `type == 'ice_in_ev_slot'` SHALL be written to both Firebase `/slots/{id}/violation` and InfluxDB Cloud.

**Validates: Requirements 8.4, 9.5**

---

### Property 12: EV cable compliance — timer cancellation prevents violation

*For any* EV vehicle detected in an EV slot, if `CableDetector.detect()` returns `True` before the 5-minute compliance timer expires, no violation SHALL be written to Firebase for that slot during that parking session.

**Validates: Requirements 9.4**

---

### Property 13: EV cable compliance — expired timer without cable produces violation

*For any* EV vehicle detected in an EV slot, if the compliance timer expires and `CableDetector.detect()` returns `False`, a `ViolationEvent` with `type == 'ev_no_cable'` SHALL be written to both Firebase `/slots/{id}/violation` and InfluxDB Cloud.

**Validates: Requirements 9.2, 9.5**

---

## Error Handling

### Flutter App

| Scenario | Handling |
|---|---|
| Firebase stream error | `AsyncValue.error` state → `ErrorBanner` widget shown |
| Network connectivity lost | `Connectivity` package detects loss → persistent warning banner; Firebase SDK auto-reconnects on restore |
| Slot no longer available on reserve | `FirebaseReservationDataSource.createReservation()` checks current status before write; returns error → `SnackBar` shown |
| Auth state lost | GoRouter redirect sends user to `/onboarding` |
| Hive cache read failure | Falls back to empty state; non-fatal |

### Python Backend

| Scenario | Handling |
|---|---|
| Camera frame is `None` or corrupt | Log error, skip frame, retain last known Firebase state |
| Firebase write failure | Retry with exponential backoff (max 3 attempts), log to stderr |
| MQTT connection lost | `paho-mqtt` auto-reconnect with `reconnect_delay_set()`; re-subscribe on reconnect |
| InfluxDB write failure | Log warning, continue — InfluxDB is non-critical path |
| OpenCV processing exception | Catch, log, skip frame — do not crash the pipeline loop |
| Compliance timer slot eviction | If vehicle leaves before timer fires, cancel timer and clear violation state |

---

## Testing Strategy

### Flutter App

**Unit / Widget Tests** (using `flutter_test`, `mocktail`):
- `SlotTile` and `SlotMapCell` render correct content for each status
- `BookingCard` countdown timer displays correct remaining time
- `GateControlScreen` log appends new events correctly
- `ReservationScreen` disables button for non-available slots
- `FirebaseSlotDataSource.watchSlots()` maps Firebase snapshot to `List<ParkingSlot>` correctly
- `FirebaseReservationDataSource` sorts reservations by `createdAt` descending

**Property-Based Tests** (using `dart_test` with `fast_check` or `glados`):

Each property test runs a minimum of 100 iterations.

- **Property 1** — Slot count formatter: generate random `List<ParkingSlot>` with arbitrary statuses, verify `"{free}/{total}"` output.
  *Tag: Feature: harbr-flutter-app, Property 1: slot count display correctness*

- **Property 2** — Auto-assign nearest free slot: generate random slot lists with varying distances and statuses, verify result is always the minimum-distance available slot or null.
  *Tag: Feature: harbr-flutter-app, Property 2: auto-assign returns nearest free slot*

- **Property 3** — Zone grouping: generate random slot lists, verify grouping function produces correct zone buckets with no slot in wrong bucket.
  *Tag: Feature: harbr-flutter-app, Property 3: slot grid grouping by zone*

- **Property 4** — Color mapping: generate random `ParkingSlot` instances, verify color mapping is non-null and matches expected value for each status.
  *Tag: Feature: harbr-flutter-app, Property 4: slot status color mapping is total and correct*

- **Property 5** — Reserve button visibility: generate random slots, verify button visibility matches `slot.isAvailable`.
  *Tag: Feature: harbr-flutter-app, Property 5: reserve button visibility matches slot status*

- **Property 6** — Booking card fields: generate random active `Reservation` objects, verify card renders slot ID, zone, and non-negative countdown.
  *Tag: Feature: harbr-flutter-app, Property 6: active booking card contains required fields*

- **Property 7** — Past bookings sort: generate random lists of past reservations, verify sorted order.
  *Tag: Feature: harbr-flutter-app, Property 7: past bookings are sorted chronologically*

**Integration Tests** (using `integration_test` package):
- Firebase stream subscription attaches to correct paths on screen load
- Gate open command write propagates to mock Firebase correctly
- Connectivity loss shows warning banner; restore resumes sync
- Violation notification appears when `/slots/{id}/violation` is written

### Python Backend

**Unit Tests** (using `pytest`):
- `VehicleClassifier.classify()` returns `'ev'` for images with sticker pixels in HSV range
- `VehicleClassifier.classify()` returns `'ice'` for images without sticker pixels
- `CableDetector.detect()` returns `True`/`False` for synthetic rear ROI images
- `ComplianceTimer` starts, cancels, and expires correctly
- `SlotDetector` maps background subtraction output to correct status strings

**Property-Based Tests** (using `hypothesis`):

Each property test runs a minimum of 100 iterations.

- **Property 8** — Pipeline output validity: generate synthetic frames, verify all status values in `{available, occupied, reserved}`.
  *Tag: Feature: harbr-flutter-app, Property 8: OpenCV pipeline output is always a valid status*

- **Property 9** — Camera error state preservation: inject `None` frames, verify Firebase mock not called with new state.
  *Tag: Feature: harbr-flutter-app, Property 9: camera error preserves last known slot state*

- **Property 10** — HSV classification exhaustiveness: generate random HSV pixel arrays in/out of range, verify classification correctness and non-null output.
  *Tag: Feature: harbr-flutter-app, Property 10: HSV classification is correct and exhaustive*

- **Property 11** — ICE in EV slot violation: generate ICE vehicle + EV slot combinations, verify both Firebase and InfluxDB mock writes called.
  *Tag: Feature: harbr-flutter-app, Property 11: ICE in EV slot always produces a violation*

- **Property 12** — Cable detected before timeout: simulate EV detection + cable detection before 300s, verify no violation written.
  *Tag: Feature: harbr-flutter-app, Property 12: EV cable compliance — timer cancellation prevents violation*

- **Property 13** — Expired timer without cable: simulate EV detection + timer expiry + no cable, verify violation written to both Firebase and InfluxDB.
  *Tag: Feature: harbr-flutter-app, Property 13: EV cable compliance — expired timer without cable produces violation*

**Integration Tests**:
- `GateBridge` publishes to MQTT mock when Firebase `/gate/open_command` is set to `true`
- `GateBridge` writes to Firebase `/gate/status` when MQTT gate status message received
- `GateBridge` writes to Firebase `/gate/entry_detected` when MQTT vehicle detection message received
- Full pipeline smoke test: camera frame → Firebase write → Flutter stream update (end-to-end with mocked camera)
