# Harbr — Smart Parking for the Future

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
[![OpenCV](https://img.shields.io/badge/opencv-%23white.svg?style=for-the-badge&logo=opencv&logoColor=white)](https://opencv.org/)

**Harbr** is an advanced, vision-powered smart parking ecosystem designed to eliminate friction for drivers and lot operators. Built with a modular, microservice-inspired architecture, it combines real-time computer vision, cloud analytics, and a premium mobile experience.

---

## 🎨 The Kinetic Blueprint
The Harbr interface follows the **Kinetic Blueprint** design philosophy—a high-contrast, engineering-focused aesthetic that feels production-grade and "alive."
*   **The Void:** Deep charcoal backgrounds for maximum focus.
*   **The Signal:** Electric blue accents for interactive elements.
*   **Active Monitoring:** Real-time slot status transitions (Available, Occupied, Reserved).

---

## 🚀 Key Features

### 1. Frictionless Entry (ALPR)
Say goodbye to kiosks and QR codes. Harbr uses **Automatic License Plate Recognition (ALPR)** at the entry gate.
*   The system identifies your plate as you approach.
*   Instantly verifies your active reservation in Firebase.
*   Automatically triggers the gate to open—no windows rolled down.

### 2. Vision-Based Slot Monitoring
Instead of expensive per-slot hardware sensors, Harbr leverages wide-angle cameras and **OpenCV** to monitor multiple slots simultaneously.
*   **AI Classification:** Detects vehicle presence, color, and type.
*   **Visual Verification:** Provides real-time occupied vs. vacant status directly to the mobile app.

### 3. Comprehensive Analytics (InfluxDB)
Lot operators gain a bird's-eye view of their facility via **InfluxDB Cloud**.
*   Track peak occupancy hours.
*   Analyze user behavior patterns.
*   Real-time telemetry for entries, exits, and revenue.

### 4. Vehicle Anomaly Logging
A built-in safety net for drivers and operators. Harbr captures high-definition snapshots of vehicles upon entry, providing a timestamped record of the vehicle's condition for liability protection.

---

## 🏗 Modular Architecture
Harbr is split into four independent, decoupled modules to ensure scalability and ease of maintenance:

1.  **Vision Edge Node (Python + OpenCV):** Process camera feeds locally (Webcams/Mobile IP Cams) and transmit lightweight telemetry.
2.  **Core Backend (Firebase + Cloud Functions):** The central brain managing reservations, authentication, and orchestration.
3.  **Mobile App (Flutter):** The premium user interface for booking, navigation, and real-time monitoring.
4.  **Hardware Actuators (ESP32/Arduino):** Physical controllers for gate servos and lighting (optional modular expansion).

---

## 🛠 Tech Stack
- **Frontend:** Flutter (State management: Riverpod)
- **Backend:** Firebase (Firestore, Realtime DB, Auth)
- **Analytics:** InfluxDB Cloud 
- **Vision:** OpenCV, Python (YOLO/ALPR logic)
- **Protocols:** MQTT, REST, WebSockets

---

## 🏁 Getting Started

### Vision Node Setup
```bash
cd hardware
pip install paho-mqtt firebase-admin influxdb-client opencv-python
python smart_parking_middleware.py
```

### Flutter App Setup
1. Ensure Flutter is installed.
2. Add your `google-services.json` / `GoogleService-Info.plist` for Firebase.
3. Run `flutter pub get`.
4. Run `flutter run`.

---

## 🌟 The Harbr Vision
Harbr isn't just an app; it's a statement on how urban infrastructure should work. By replacing hardware complexity with vision-based intelligence, we create a system that is cheaper to deploy, easier to maintain, and magical to use.
