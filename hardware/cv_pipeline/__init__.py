"""
hardware/cv_pipeline — OpenCV-based parking slot analysis pipeline.

Modules:
    slot_detector      — Background subtraction occupancy detection
    vehicle_classifier — HSV masking EV/ICE classification
    cable_detector     — Canny edge + contour cable detection
    compliance_timer   — Per-slot 5-minute threading timers
    firebase_bridge    — Firebase Admin SDK write helpers with retry
    influx_logger      — InfluxDB Cloud event logger (non-critical)
    gate_bridge        — Firebase /gate/ ↔ HiveMQ MQTT bridge
"""

from .slot_detector import SlotDetector
from .vehicle_classifier import VehicleClassifier
from .cable_detector import CableDetector
from .compliance_timer import ComplianceTimer
from .firebase_bridge import FirebaseBridge
from .influx_logger import InfluxLogger
from .gate_bridge import GateBridge

__all__ = [
    "SlotDetector",
    "VehicleClassifier",
    "CableDetector",
    "ComplianceTimer",
    "FirebaseBridge",
    "InfluxLogger",
    "GateBridge",
]
