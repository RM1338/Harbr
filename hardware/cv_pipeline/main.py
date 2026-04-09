"""
main.py — Entry point for the Harbr OpenCV CV pipeline.

Starts two concurrent activities:
  1. GateBridge (daemon thread) — Firebase /gate/open_command ↔ HiveMQ MQTT
  2. OpenCV pipeline loop (main thread) — camera → slot detection → Firebase + InfluxDB

Configuration is read from environment variables (see CONFIG section below).
"""

import logging
import os
import threading
import time

import cv2
import numpy as np

from .cable_detector import CableDetector
from .compliance_timer import ComplianceTimer
from .firebase_bridge import FirebaseBridge
from .gate_bridge import GateBridge
from .influx_logger import InfluxLogger
from .slot_detector import SlotDetector
from .vehicle_classifier import VehicleClassifier

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

# ── CONFIG — override via environment variables ───────────────────────────────
FIREBASE_CRED   = os.getenv("FIREBASE_CRED",   "serviceAccountKey.json")
FIREBASE_DB_URL = os.getenv("FIREBASE_DB_URL", "https://YOUR-PROJECT.firebaseio.com")

INFLUX_URL      = os.getenv("INFLUX_URL",    "https://us-east-1-1.aws.cloud2.influxdata.com")
INFLUX_TOKEN    = os.getenv("INFLUX_TOKEN",  "YOUR_INFLUX_TOKEN")
INFLUX_ORG      = os.getenv("INFLUX_ORG",   "YOUR_ORG")
INFLUX_BUCKET   = os.getenv("INFLUX_BUCKET", "parking")

HIVEMQ_HOST     = os.getenv("HIVEMQ_HOST",     "YOUR-CLUSTER.hivemq.cloud")
HIVEMQ_PORT     = int(os.getenv("HIVEMQ_PORT", "8883"))
HIVEMQ_USER     = os.getenv("HIVEMQ_USER",     "")
HIVEMQ_PASSWORD = os.getenv("HIVEMQ_PASSWORD", "")

CAMERA_INDEX    = int(os.getenv("CAMERA_INDEX", "0"))

# EV sticker HSV range (green sticker default)
HSV_LOWER = np.array([35, 100, 100], dtype=np.uint8)
HSV_UPPER = np.array([85, 255, 255], dtype=np.uint8)

# Slot ROIs: slot_id → (x, y, w, h) — adjust to match camera mount
SLOT_ROIS: dict[str, tuple] = {
    "A1": (0,   0,   200, 150),
    "A2": (200, 0,   200, 150),
    "A3": (400, 0,   200, 150),
}

# EV-designated slots — ICE vehicles here trigger a violation
EV_SLOTS: set[str] = {"A1", "A2"}
# ─────────────────────────────────────────────────────────────────────────────


def _build_components() -> tuple[
    SlotDetector,
    VehicleClassifier,
    CableDetector,
    ComplianceTimer,
    FirebaseBridge,
    InfluxLogger,
    GateBridge,
]:
    """Initialise and return all pipeline components."""
    firebase_bridge = FirebaseBridge(cred_path=FIREBASE_CRED, db_url=FIREBASE_DB_URL)
    influx_logger = InfluxLogger(
        url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG, bucket=INFLUX_BUCKET
    )

    def _on_timer_expire(slot_id: str) -> None:
        """Called when a compliance timer fires — check cable, write violation if absent."""
        logger.warning("Compliance timer expired for slot %s — cable check required.", slot_id)
        # Violation is written by the pipeline loop on the next frame that
        # detects the slot still occupied without a cable.  The timer expiry
        # flag is checked there via compliance_timer.is_expired().

    compliance_timer = ComplianceTimer(on_expire=_on_timer_expire)

    slot_detector = SlotDetector(slot_rois=SLOT_ROIS)
    vehicle_classifier = VehicleClassifier(hsv_lower=HSV_LOWER, hsv_upper=HSV_UPPER)
    cable_detector = CableDetector()

    gate_bridge = GateBridge(
        firebase_bridge=firebase_bridge,
        mqtt_host=HIVEMQ_HOST,
        mqtt_port=HIVEMQ_PORT,
        mqtt_username=HIVEMQ_USER,
        mqtt_password=HIVEMQ_PASSWORD,
    )

    return (
        slot_detector,
        vehicle_classifier,
        cable_detector,
        compliance_timer,
        firebase_bridge,
        influx_logger,
        gate_bridge,
    )


def _run_gate_bridge(gate_bridge: GateBridge) -> None:
    """Target function for the GateBridge daemon thread."""
    try:
        gate_bridge.start()
    except Exception as exc:  # noqa: BLE001
        logger.error("GateBridge thread crashed: %s", exc)


def _process_occupied_slot(
    slot_id: str,
    frame: np.ndarray,
    vehicle_classifier: VehicleClassifier,
    cable_detector: CableDetector,
    compliance_timer: ComplianceTimer,
    firebase_bridge: FirebaseBridge,
    influx_logger: InfluxLogger,
    slot_rois: dict[str, tuple],
) -> str | None:
    """
    Classify vehicle and check cable compliance for an occupied slot.

    Returns the detected vehicle_type ('ev' or 'ice'), or None on error.
    """
    roi_coords = slot_rois.get(slot_id)
    if roi_coords is None:
        return None

    x, y, w, h = roi_coords
    slot_roi = frame[y: y + h, x: x + w]

    vehicle_type = vehicle_classifier.classify(slot_roi)
    firebase_bridge.write_slot_status(slot_id, "occupied", vehicle_type)
    influx_logger.log_slot_status(slot_id, "occupied")

    if slot_id in EV_SLOTS:
        if vehicle_type == "ice":
            # ICE in EV slot — immediate violation
            ts = time.time()
            logger.warning("Violation: ICE in EV slot %s", slot_id)
            firebase_bridge.write_violation(slot_id, "ice_in_ev_slot", ts)
            influx_logger.log_violation(slot_id, "ice_in_ev_slot", vehicle_type, ts)
            compliance_timer.cancel(slot_id)

        elif vehicle_type == "ev":
            if compliance_timer.is_expired(slot_id):
                # Timer expired — check cable
                cable_present = cable_detector.detect(slot_roi)
                if not cable_present:
                    ts = time.time()
                    logger.warning("Violation: EV no cable in slot %s", slot_id)
                    firebase_bridge.write_violation(slot_id, "ev_no_cable", ts)
                    influx_logger.log_violation(slot_id, "ev_no_cable", vehicle_type, ts)
                else:
                    compliance_timer.cancel(slot_id)
            else:
                # Start timer if not already running
                compliance_timer.start(slot_id)

    return vehicle_type


def _pipeline_loop(
    slot_detector: SlotDetector,
    vehicle_classifier: VehicleClassifier,
    cable_detector: CableDetector,
    compliance_timer: ComplianceTimer,
    firebase_bridge: FirebaseBridge,
    influx_logger: InfluxLogger,
) -> None:
    """Main OpenCV pipeline loop — runs in the main thread."""
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        logger.error("Cannot open camera index %d.", CAMERA_INDEX)
        return

    logger.info("Camera opened (index=%d). Starting pipeline loop.", CAMERA_INDEX)

    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                logger.warning("Camera read failed — skipping frame.")
                time.sleep(0.1)
                continue

            try:
                slot_statuses = slot_detector.process_frame(frame)
            except Exception as exc:  # noqa: BLE001
                logger.error("SlotDetector error: %s — skipping frame.", exc)
                time.sleep(0.1)
                continue

            for slot_id, status in slot_statuses.items():
                try:
                    if status == "occupied":
                        _process_occupied_slot(
                            slot_id=slot_id,
                            frame=frame,
                            vehicle_classifier=vehicle_classifier,
                            cable_detector=cable_detector,
                            compliance_timer=compliance_timer,
                            firebase_bridge=firebase_bridge,
                            influx_logger=influx_logger,
                            slot_rois=SLOT_ROIS,
                        )
                    else:
                        # Slot is free or reserved — cancel any running timer
                        compliance_timer.cancel(slot_id)
                        firebase_bridge.write_slot_status(slot_id, status)
                        influx_logger.log_slot_status(slot_id, status)

                except Exception as exc:  # noqa: BLE001
                    logger.error("Error processing slot %s: %s", slot_id, exc)

    except KeyboardInterrupt:
        logger.info("Pipeline loop stopped by user.")
    finally:
        cap.release()
        logger.info("Camera released.")


def main() -> None:
    """
    Entry point — initialises all components, starts GateBridge in a daemon
    thread, then runs the OpenCV pipeline loop in the main thread.
    """
    logger.info("Starting Harbr CV pipeline…")

    (
        slot_detector,
        vehicle_classifier,
        cable_detector,
        compliance_timer,
        firebase_bridge,
        influx_logger,
        gate_bridge,
    ) = _build_components()

    # GateBridge runs in a daemon thread so it exits when the main thread exits
    gate_thread = threading.Thread(
        target=_run_gate_bridge,
        args=(gate_bridge,),
        name="GateBridgeThread",
        daemon=True,
    )
    gate_thread.start()
    logger.info("GateBridge thread started.")

    # OpenCV pipeline runs in the main thread
    _pipeline_loop(
        slot_detector=slot_detector,
        vehicle_classifier=vehicle_classifier,
        cable_detector=cable_detector,
        compliance_timer=compliance_timer,
        firebase_bridge=firebase_bridge,
        influx_logger=influx_logger,
    )


if __name__ == "__main__":
    main()
