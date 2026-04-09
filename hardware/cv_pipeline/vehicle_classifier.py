"""
vehicle_classifier.py — EV/ICE classification via HSV colour masking.
"""

import logging
import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Minimum fraction of ROI pixels that must match the HSV range to classify as EV
_DEFAULT_EV_PIXEL_THRESHOLD = 0.05


class VehicleClassifier:
    """
    Classifies a vehicle as EV or ICE by detecting a coloured roof sticker
    using HSV masking.

    Args:
        hsv_lower: Lower bound of the target HSV colour range (shape (3,)).
        hsv_upper: Upper bound of the target HSV colour range (shape (3,)).
        ev_pixel_threshold: Fraction of ROI pixels that must be within the
                            HSV range to return 'ev'. Defaults to 0.05.
    """

    def __init__(
        self,
        hsv_lower: np.ndarray,
        hsv_upper: np.ndarray,
        ev_pixel_threshold: float = _DEFAULT_EV_PIXEL_THRESHOLD,
    ):
        self.hsv_lower = np.asarray(hsv_lower, dtype=np.uint8)
        self.hsv_upper = np.asarray(hsv_upper, dtype=np.uint8)
        self.ev_pixel_threshold = ev_pixel_threshold

    def classify(self, roof_roi: np.ndarray) -> str:
        """
        Classify a vehicle based on its roof ROI image.

        Args:
            roof_roi: BGR image crop of the vehicle roof area.

        Returns:
            'ev' if the sticker colour is detected, 'ice' otherwise.
            Never returns None.
        """
        if roof_roi is None or not isinstance(roof_roi, np.ndarray) or roof_roi.size == 0:
            logger.warning("Invalid roof_roi — defaulting to 'ice'.")
            return "ice"

        try:
            hsv = cv2.cvtColor(roof_roi, cv2.COLOR_BGR2HSV)
            mask = cv2.inRange(hsv, self.hsv_lower, self.hsv_upper)

            match_ratio = np.count_nonzero(mask) / mask.size
            return "ev" if match_ratio >= self.ev_pixel_threshold else "ice"

        except Exception as exc:  # noqa: BLE001
            logger.error("VehicleClassifier error: %s", exc)
            return "ice"
