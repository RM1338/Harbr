"""
cable_detector.py — Charging cable detection via Canny edges and contour analysis.
"""

import logging
import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Contours smaller than this area (in pixels) are ignored as noise
_DEFAULT_MIN_CONTOUR_AREA = 500


class CableDetector:
    """
    Detects the presence of a charging cable in a rear-bumper ROI image
    using Canny edge detection and contour analysis.

    Args:
        canny_threshold1: Lower hysteresis threshold for Canny. Default 50.
        canny_threshold2: Upper hysteresis threshold for Canny. Default 150.
        min_contour_area: Minimum contour area to count as a cable. Default 500.
    """

    def __init__(
        self,
        canny_threshold1: int = 50,
        canny_threshold2: int = 150,
        min_contour_area: int = _DEFAULT_MIN_CONTOUR_AREA,
    ):
        self.canny_threshold1 = canny_threshold1
        self.canny_threshold2 = canny_threshold2
        self.min_contour_area = min_contour_area

    def detect(self, rear_roi: np.ndarray) -> bool:
        """
        Detect whether a charging cable is present in the rear ROI.

        Args:
            rear_roi: BGR image crop of the vehicle's rear bumper area.

        Returns:
            True if at least one contour exceeding the minimum area is found,
            False otherwise (including on invalid input).
        """
        if rear_roi is None or not isinstance(rear_roi, np.ndarray) or rear_roi.size == 0:
            logger.warning("Invalid rear_roi — returning False.")
            return False

        try:
            gray = cv2.cvtColor(rear_roi, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, self.canny_threshold1, self.canny_threshold2)

            contours, _ = cv2.findContours(
                edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
            )

            return any(
                cv2.contourArea(c) >= self.min_contour_area for c in contours
            )

        except Exception as exc:  # noqa: BLE001
            logger.error("CableDetector error: %s", exc)
            return False
