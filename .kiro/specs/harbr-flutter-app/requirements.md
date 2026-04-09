# Requirements Document

## Introduction

Harbr is a Hybrid Edge-Cloud Smart Parking System. This document covers the Flutter mobile application, Firebase Realtime Database integration, and OpenCV-based computer vision pipeline that together form the user-facing and edge-processing components of the system.

The Flutter app provides drivers with real-time slot visibility, slot reservation, gate control, and booking management. Firebase Realtime Database acts as the shared state layer between the Flutter app and the Python/OpenCV backend. The OpenCV pipeline runs on an edge device (managed by the user), performing vehicle classification, EV cable compliance detection, and slot occupancy analysis, writing results back to Firebase.

Flutter never communicates with MQTT directly. Python is the sole MQTT client and bridges Firebase commands to the Arduino gate controller.

---

## Glossary

- **App**: The Harbr Flutter mobile application.
- **Driver**: The end user operating the App.
- **Slot**: A single physical parking space identified by a unique ID, zone (A, B, or C), row, and distance from the entrance.
- **Zone**: A logical grouping of Slots — Zone A, Zone B, or Zone C.
- **Firebase**: Firebase Realtime Database instance (`harbr-3cd5c`) used as the shared state layer.
- **Python_Backend**: The Python process running on the edge device that owns MQTT communication, runs the OpenCV pipeline, and writes results to Firebase.
- **OpenCV_Pipeline**: The Python/OpenCV computer vision pipeline that performs slot occupancy detection and EV compliance checks.
- **Gate**: The physical entry gate controlled by the Arduino via MQTT, with state reflected in Firebase.
- **Booking**: A reservation made by a Driver for a specific Slot, stored in Firebase under `/gate/reservation`.
- **EV**: Electric Vehicle — identified by a colored roof sticker detected by the OpenCV_Pipeline.
- **ICE**: Internal Combustion Engine vehicle.
- **Violation**: A compliance breach — either an EV in an EV slot without a charging cable after 5 minutes, or an ICE vehicle in an EV-designated slot.
- **HSV_Masking**: Hue-Saturation-Value color space masking used to detect colored roof stickers.
- **Background_Subtraction**: An OpenCV technique used to detect foreground objects (vehicles) against a static background.

---

## Requirements

### Requirement 1: Home / Slot Status Screen

**User Story:** As a Driver, I want to see the total number of available slots and a list of all slots with their current status, so that I can quickly assess parking availability.

#### Acceptance Criteria

1. THE App SHALL display the total count of free slots and total slot count in the format `{free}/{total}` on the Home screen.
2. WHEN the App loads the Home screen, THE App SHALL subscribe to the Firebase `/slots/` path and reflect live updates within 2 seconds of a change being written to Firebase.
3. THE App SHALL display each Slot in a list showing slot ID, zone, and status (Free, Occupied, or Reserved).
4. WHEN a Slot status changes in Firebase, THE App SHALL update the corresponding list item without requiring a full screen reload.
5. THE App SHALL provide a "Find me a slot" button that auto-assigns the Driver to the nearest free Slot.
6. WHEN the Driver taps "Find me a slot" and no free Slot exists, THE App SHALL display a message indicating no slots are currently available.

---

### Requirement 2: Slot Map Screen (ParkSense Live)

**User Story:** As a Driver, I want to view a visual grid of all parking slots grouped by zone, so that I can spatially understand availability and choose a slot.

#### Acceptance Criteria

1. THE App SHALL render a grid layout of all Slots grouped by Zone (A, B, C) on the Slot Map screen.
2. THE App SHALL color-code each Slot cell: white for Free, black for Occupied, and a hatched pattern for Reserved.
3. WHEN the Driver taps a Slot cell, THE App SHALL navigate to the Slot Detail screen for that Slot.
4. WHEN slot data changes in Firebase `/slots/`, THE App SHALL update the grid in real time without requiring navigation away from the screen.

---

### Requirement 3: Slot Detail Screen

**User Story:** As a Driver, I want to view detailed information about a specific slot and reserve it, so that I can secure a parking space before arriving.

#### Acceptance Criteria

1. THE App SHALL display the slot ID, zone, row, and distance from the entrance on the Slot Detail screen.
2. THE App SHALL display the last sensor reading and sync status for the selected Slot.
3. WHEN the selected Slot status is Free, THE App SHALL display a "Reserve Slot" button.
4. WHEN the Driver taps "Reserve Slot", THE App SHALL write a Booking entry to Firebase `/gate/reservation` containing the slot ID, Driver identifier, and reservation timestamp.
5. WHEN the Driver taps "Reserve Slot" and the Slot status is no longer Free at the time of writing, THE App SHALL display an error message indicating the slot is no longer available.
6. WHEN the selected Slot status is Occupied or Reserved by another Driver, THE App SHALL disable the "Reserve Slot" button.

---

### Requirement 4: Gate Control Screen

**User Story:** As a Driver, I want to view the gate status and confirm my entry to open the gate, so that I can enter the parking facility without manual intervention.

#### Acceptance Criteria

1. THE App SHALL display the current gate status (Ready, Open, or Closed) by reading Firebase `/gate/status`.
2. WHEN the Python_Backend writes `true` to Firebase `/gate/entry_detected`, THE App SHALL display an in-app notification prompting the Driver to confirm entry.
3. WHEN the Driver taps "Confirm Entry & Open Gate", THE App SHALL write `true` to Firebase `/gate/open_command`.
4. THE App SHALL display a terminal-style log of timestamped gate events on the Gate Control screen.
5. WHEN a new gate event is written to Firebase `/gate/`, THE App SHALL append the event to the gate event log within 2 seconds.
6. THE App SHALL NOT write to any MQTT topic directly; all gate actuation SHALL be mediated through Firebase.

---

### Requirement 5: Bookings Screen

**User Story:** As a Driver, I want to view my active booking with a countdown timer and my booking history, so that I can manage my reservations and enter the facility on time.

#### Acceptance Criteria

1. THE App SHALL display the Driver's active Booking as a card showing slot ID, zone, and a countdown timer to booking expiry.
2. WHEN the Driver has an active Booking, THE App SHALL display an "Open Gate" button on the Bookings screen.
3. WHEN the Driver taps "Open Gate" on the Bookings screen, THE App SHALL write `true` to Firebase `/gate/open_command`.
4. THE App SHALL display a chronological list of past Bookings for the Driver.
5. WHEN the Driver has no active Booking, THE App SHALL display a message indicating no active booking exists.

---

### Requirement 6: Firebase Realtime Database Integration

**User Story:** As a Driver, I want the app to stay in sync with the physical parking system in real time, so that the slot and gate information I see is always accurate.

#### Acceptance Criteria

1. THE App SHALL use the Firebase Realtime Database SDK to subscribe to `/slots/` for live slot occupancy data.
2. THE App SHALL use the Firebase Realtime Database SDK to subscribe to `/gate/status` and `/gate/entry_detected` for live gate state.
3. WHEN the App loses network connectivity, THE App SHALL display a connectivity warning and resume live sync automatically when connectivity is restored.
4. THE App SHALL read slot occupancy data exclusively from Firebase `/slots/`; THE App SHALL NOT poll any hardware device or MQTT broker directly.
5. WHEN a Violation is written to Firebase `/slots/{id}/violation` by the Python_Backend, THE App SHALL display an in-app notification identifying the affected Slot.

---

### Requirement 7: Slot Occupancy Detection (OpenCV Pipeline)

**User Story:** As a system operator, I want the OpenCV pipeline to detect whether each parking slot is free, occupied, or reserved, so that Firebase always reflects accurate real-time occupancy.

#### Acceptance Criteria

1. THE OpenCV_Pipeline SHALL process camera frames and classify each Slot as Free, Occupied, or Reserved.
2. WHEN a Slot occupancy state changes, THE OpenCV_Pipeline SHALL write the updated status to Firebase `/slots/{id}` within 3 seconds of the change occurring in the camera frame.
3. THE OpenCV_Pipeline SHALL use Background_Subtraction or a YOLO object detector to determine per-slot vehicle presence.
4. WHEN the OpenCV_Pipeline cannot process a frame due to a camera error, THE OpenCV_Pipeline SHALL log the error and retain the last known slot state in Firebase.

---

### Requirement 8: Vehicle Classification (OpenCV Pipeline)

**User Story:** As a system operator, I want the OpenCV pipeline to classify each entering vehicle as EV or ICE using roof sticker color, so that compliance checks can be applied correctly.

#### Acceptance Criteria

1. WHEN a vehicle enters a Slot, THE OpenCV_Pipeline SHALL apply HSV_Masking to the vehicle's roof region to detect the presence of a colored sticker.
2. WHEN a colored sticker is detected within the defined HSV range, THE OpenCV_Pipeline SHALL classify the vehicle as EV.
3. WHEN no colored sticker is detected, THE OpenCV_Pipeline SHALL classify the vehicle as ICE.
4. WHEN an ICE vehicle is detected in an EV-designated Slot, THE OpenCV_Pipeline SHALL immediately write a Violation to Firebase `/slots/{id}/violation` and log the event to InfluxDB Cloud.

---

### Requirement 9: EV Cable Compliance Detection (OpenCV Pipeline)

**User Story:** As a system operator, I want the OpenCV pipeline to verify that an EV vehicle has connected a charging cable within 5 minutes of parking, so that EV slots are used correctly.

#### Acceptance Criteria

1. WHEN an EV vehicle is detected in an EV-designated Slot, THE OpenCV_Pipeline SHALL start a 5-minute compliance timer for that Slot.
2. WHEN the compliance timer expires and no charging cable is detected at the rear bounding box of the vehicle, THE OpenCV_Pipeline SHALL write a Violation to Firebase `/slots/{id}/violation`.
3. THE OpenCV_Pipeline SHALL use contour and edge detection on the rear bounding box region of the vehicle to determine cable presence.
4. WHEN a charging cable is detected before the compliance timer expires, THE OpenCV_Pipeline SHALL cancel the timer and record the Slot as compliant.
5. WHEN a Violation is written to Firebase `/slots/{id}/violation`, THE OpenCV_Pipeline SHALL also log the event to InfluxDB Cloud with the slot ID, vehicle classification, and timestamp.

---

### Requirement 10: Python–Firebase–Gate Bridge

**User Story:** As a system operator, I want the Python backend to bridge Firebase gate commands to the Arduino via MQTT, so that the Flutter app can control the gate without direct hardware access.

#### Acceptance Criteria

1. WHEN Flutter writes `true` to Firebase `/gate/open_command`, THE Python_Backend SHALL detect the change and publish the open command to the HiveMQ Cloud MQTT broker.
2. WHEN the Arduino gate controller reports a state change via MQTT, THE Python_Backend SHALL write the updated state to Firebase `/gate/status`.
3. WHEN the Arduino detects a vehicle at the gate, THE Python_Backend SHALL write `true` to Firebase `/gate/entry_detected`.
4. THE Python_Backend SHALL be the sole process writing to the HiveMQ Cloud MQTT broker; THE App SHALL NOT connect to MQTT directly.
