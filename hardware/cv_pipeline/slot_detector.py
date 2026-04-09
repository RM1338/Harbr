"""
slot_detector.py — Parking slot occupancy detection via background subtraction.
"""

import logging
import cv2
import numpy as np

logger = logging.getLogger(__name__)

VALID_STATUSES = {"available", "occupied", "reserved"}


class SlotDetector:
    """
    Detects parking slot occupancy using OpenCV background subtraction.

    Args:
        slot_rois: Mapping of slot_id → (x, y, w, h) ROI tuple.
        method:    Detection method; currently supports "background_subtraction".
    """

    def __init__(
        self,
        slot_rois: dict[str, tuple],
        method: str = "background_subtraction",
    ):
        self.slot_rois = slot_rois
        self.method = method

        # One background subtractor per slot for independent learning
        self._subtractors: dict[str, cv2.BackgroundSubtractorMOG2] = {
            slot_id: cv2.createBackgroundSubtractorMOG2(
                history=200, varThreshold=80, detectShadows=False
            )
            for slot_id in slot_rois
        }

        # Last known state — returned on corrupt/None frames
        self._last_state: dict[str, str] = {
            slot_id: "available" for slot_id in slot_rois
        }

        # Minimum foreground pixel ratio to consider a slot occupied
        # Higher = less sensitive (fewer false positives)
        self._occupancy_threshold = 0.25

        # Warm-up: feed empty frames so MOG2 learns the background before
        # reporting any slot as occupied
        self._warmup_frames = 60   # ~2 seconds at 30fps
        self._frame_count = 0

    def process_frame(self, frame: np.ndarray) -> dict[str, str]:
        """
        Process a camera frame and return occupancy status for all slots.

        Args:
            frame: BGR image as a numpy array, or None if the camera failed.

        Returns:
            Dict mapping slot_id → status ('available' | 'occupied' | 'reserved').
            On None/corrupt frame, returns the last known state unchanged.
        """
        if frame is None:
            logger.warning("Received None frame — returning last known state.")
            return dict(self._last_state)

        if not isinstance(frame, np.ndarray) or frame.size == 0:
            logger.warning("Received corrupt frame — returning last known state.")
            return dict(self._last_state)

        result: dict[str, str] = {}
        self._frame_count += 1
        in_warmup = self._frame_count <= self._warmup_frames

        for slot_id, (x, y, w, h) in self.slot_rois.items():
            try:
                roi = frame[y : y + h, x : x + w]
                if roi.size == 0:
                    result[slot_id] = self._last_state[slot_id]
                    continue

                fg_mask = self._subtractors[slot_id].apply(roi)
                fg_ratio = np.count_nonzero(fg_mask) / fg_mask.size

                # During warm-up always report available so MOG2 can learn
                if in_warmup:
                    result[slot_id] = "available"
                    self._last_state[slot_id] = "available"
                    continue

                status = "occupied" if fg_ratio >= self._occupancy_threshold else "available"
                result[slot_id] = status
                self._last_state[slot_id] = status

            except Exception as exc:  # noqa: BLE001
                logger.error("Error processing slot %s: %s", slot_id, exc)
                result[slot_id] = self._last_state.get(slot_id, "available")

        return result
