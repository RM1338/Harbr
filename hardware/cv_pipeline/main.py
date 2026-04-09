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

# Slot ROIs: slot_id → (x, y, w, h) — defined using setup_rois.py
SLOT_ROIS: dict[str, tuple] = {
    "A1": (517, 183, 114, 231),
    "A2": (365, 191, 106, 231),
    "A3": (213, 200, 111, 229),
    "A4": (30,  192, 130, 229),
}

# EV-designated slots — ICE vehicles here trigger a violation
EV_SLOTS: set[str] = {"A1", "A2", "A3", "A4"}
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


# Status colours for the preview window (BGR)
_COLOUR_AVAILABLE = (0, 220, 80)
_COLOUR_OCCUPIED  = (0, 60, 220)
_COLOUR_RESERVED  = (0, 180, 255)
_COLOUR_TEXT      = (255, 255, 255)
_COLOURS_CYCLE    = [
    (0, 220, 80),
    (255, 120, 0),
    (0, 200, 255),
    (220, 0, 255),
]


def _draw_preview(frame: np.ndarray, slot_statuses: dict[str, str]) -> np.ndarray:
    """Draw ROI boxes and status labels on a copy of the frame."""
    display = frame.copy()

    for i, (slot_id, (x, y, w, h)) in enumerate(SLOT_ROIS.items()):
        status = slot_statuses.get(slot_id, "available")

        if status == "occupied":
            box_colour = _COLOUR_OCCUPIED
        elif status == "reserved":
            box_colour = _COLOUR_RESERVED
        else:
            # Use a unique colour per slot when available so they're easy to tell apart
            box_colour = _COLOURS_CYCLE[i % len(_COLOURS_CYCLE)]

        thickness = 3 if status == "occupied" else 2
        cv2.rectangle(display, (x, y), (x + w, y + h), box_colour, thickness)

        # Filled label background so text is readable even without fonts
        label = f"{slot_id}: {status.upper()}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(display, (x, y), (x + tw + 10, y + th + 10), box_colour, -1)
        cv2.putText(display, label, (x + 5, y + th + 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

    # Bottom status bar
    bar_y = display.shape[0] - 30
    cv2.rectangle(display, (0, bar_y), (display.shape[1], display.shape[0]),
                  (30, 30, 30), -1)
    summary = "  |  ".join(
        f"{sid}: {'OCC' if st == 'occupied' else 'FREE'}"
        for sid, st in slot_statuses.items()
    )
    cv2.putText(display, summary + "   Q=quit",
                (8, display.shape[0] - 10),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 200), 1)
    return display


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
    logger.info("Preview window open — press Q to quit.")

    slot_statuses: dict[str, str] = {sid: "available" for sid in SLOT_ROIS}

    # Create and initialise the window before the loop so Qt has time to render
    cv2.namedWindow("Harbr — Parking CV Pipeline", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("Harbr — Parking CV Pipeline", 800, 500)

    # Prime the window with a black frame so it appears immediately
    ret, first_frame = cap.read()
    if ret and first_frame is not None:
        cv2.imshow("Harbr — Parking CV Pipeline", first_frame)
        cv2.waitKey(1)

    # Only run detection + Firebase writes every N frames to avoid lag.
    # Display updates every frame so the preview stays smooth.
    DETECT_EVERY_N_FRAMES = 10
    frame_count = 0

    # Firebase writes run in a daemon thread so they never block the display loop
    _write_executor = threading.Thread(target=lambda: None, daemon=True)

    def _async_write(fn, *args, **kwargs):
        t = threading.Thread(target=fn, args=args, kwargs=kwargs, daemon=True)
        t.start()

    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                logger.warning("Camera read failed — skipping frame.")
                time.sleep(0.05)
                continue

            frame_count += 1

            # Run detection only every N frames
            if frame_count % DETECT_EVERY_N_FRAMES == 0:
                try:
                    slot_statuses = slot_detector.process_frame(frame)
                except Exception as exc:  # noqa: BLE001
                    logger.error("SlotDetector error: %s", exc)

                for slot_id, status in slot_statuses.items():
                    try:
                        if status == "occupied":
                            _async_write(
                                _process_occupied_slot,
                                slot_id=slot_id,
                                frame=frame.copy(),
                                vehicle_classifier=vehicle_classifier,
                                cable_detector=cable_detector,
                                compliance_timer=compliance_timer,
                                firebase_bridge=firebase_bridge,
                                influx_logger=influx_logger,
                                slot_rois=SLOT_ROIS,
                            )
                        else:
                            compliance_timer.cancel(slot_id)
                            _async_write(firebase_bridge.write_slot_status, slot_id, status)
                            _async_write(influx_logger.log_slot_status, slot_id, status)
                    except Exception as exc:  # noqa: BLE001
                        logger.error("Error processing slot %s: %s", slot_id, exc)

            # Always update the preview — smooth display regardless of detection rate
            preview = _draw_preview(frame, slot_statuses)
            cv2.imshow("Harbr — Parking CV Pipeline", preview)

            # Q to quit
            if cv2.waitKey(1) & 0xFF == ord('q'):
                logger.info("Quit key pressed.")
                break

    except KeyboardInterrupt:
        logger.info("Pipeline loop stopped by user.")
    finally:
        cap.release()
        cv2.destroyAllWindows()
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
