"""
webcam_debug.py — Interactive webcam tester for the Harbr CV pipeline.

Shows 4 windows:
  1. Main — live feed with ROI boxes, slot status labels, and FG ratio bars
  2. FG Mask — raw background subtraction output for each slot
  3. HSV Mask — EV sticker colour mask on the full frame
  4. Edges — Canny edge output (cable detection view)

Controls:
  Q        — quit
  R        — reset background subtractors (re-learn background)
  S        — save current frame as test_frame.jpg
  1/2/3    — toggle ROI drawing for slot A1/A2/A3
  +/-      — raise/lower occupancy threshold by 0.01

Usage:
  cd hardware
  python webcam_debug.py

  # Use a different camera index:
  CAMERA_INDEX=1 python webcam_debug.py
"""

import os
import sys
import time

import cv2
import numpy as np

# Import CV modules directly to avoid triggering firebase_admin / paho imports
# from __init__.py (those are only needed when running the full pipeline).
_cv_dir = os.path.join(os.path.dirname(__file__), "cv_pipeline")
sys.path.insert(0, _cv_dir)

import importlib.util as _ilu

def _load(name, path):
    spec = _ilu.spec_from_file_location(name, path)
    mod = _ilu.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

_sd = _load("slot_detector",      os.path.join(_cv_dir, "slot_detector.py"))
_vc = _load("vehicle_classifier", os.path.join(_cv_dir, "vehicle_classifier.py"))
_cd = _load("cable_detector",     os.path.join(_cv_dir, "cable_detector.py"))

SlotDetector      = _sd.SlotDetector
VehicleClassifier = _vc.VehicleClassifier
CableDetector     = _cd.CableDetector

# ── CONFIG — tweak these to match your webcam view ───────────────────────────

CAMERA_INDEX = int(os.getenv("CAMERA_INDEX", "0"))

# Slot ROIs: (x, y, w, h) — adjust to cover your actual parking spots
# Tip: start with large boxes covering most of the frame, then narrow down
SLOT_ROIS = {
    "A1": (10,  10,  200, 180),
    "A2": (220, 10,  200, 180),
    "A3": (430, 10,  200, 180),
}

# EV sticker HSV range — default is green; change to match your sticker colour
# Use the HSV picker window (press H) to find the right range
HSV_LOWER = np.array([35, 100, 100], dtype=np.uint8)   # green lower
HSV_UPPER = np.array([85, 255, 255], dtype=np.uint8)   # green upper

# ─────────────────────────────────────────────────────────────────────────────

# Status colours (BGR)
COLOUR_AVAILABLE = (0, 220, 80)    # green
COLOUR_OCCUPIED  = (0, 60, 220)    # red
COLOUR_TEXT      = (255, 255, 255) # white
COLOUR_FG_BAR    = (0, 200, 255)   # yellow


def draw_roi(frame, slot_id, x, y, w, h, status, fg_ratio, threshold):
    colour = COLOUR_AVAILABLE if status == "available" else COLOUR_OCCUPIED

    # ROI rectangle
    cv2.rectangle(frame, (x, y), (x + w, y + h), colour, 2)

    # Slot label + status
    label = f"{slot_id}: {status.upper()}"
    cv2.putText(frame, label, (x + 4, y + 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, colour, 2)

    # FG ratio bar (fills from left, threshold line in white)
    bar_x, bar_y = x + 4, y + h - 14
    bar_w = w - 8
    filled = int(bar_w * min(fg_ratio, 1.0))
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_w, bar_y + 10), (50, 50, 50), -1)
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + filled, bar_y + 10), COLOUR_FG_BAR, -1)
    thresh_x = bar_x + int(bar_w * threshold)
    cv2.line(frame, (thresh_x, bar_y - 2), (thresh_x, bar_y + 12), (255, 255, 255), 1)

    # FG ratio text
    cv2.putText(frame, f"{fg_ratio:.2f}", (x + 4, y + h - 18),
                cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLOUR_TEXT, 1)


def build_fg_panel(frame, slot_rois, subtractors):
    """Build a side-by-side panel of foreground masks for all slots."""
    masks = []
    for slot_id, (x, y, w, h) in slot_rois.items():
        roi = frame[y:y + h, x:x + w]
        if roi.size == 0:
            masks.append(np.zeros((h, w), dtype=np.uint8))
            continue
        mask = subtractors[slot_id].apply(roi, learningRate=0)  # read-only apply
        # Convert to BGR for stacking
        mask_bgr = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR)
        cv2.putText(mask_bgr, slot_id, (4, 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        masks.append(mask_bgr)

    if not masks:
        return np.zeros((180, 200, 3), dtype=np.uint8)

    # Resize all to same height before hstack
    target_h = 180
    resized = []
    for m in masks:
        h, w = m.shape[:2]
        scale = target_h / h
        resized.append(cv2.resize(m, (int(w * scale), target_h)))
    return np.hstack(resized)


def main():
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print(f"[ERROR] Cannot open camera index {CAMERA_INDEX}.")
        print("  Try: CAMERA_INDEX=1 python webcam_debug.py")
        sys.exit(1)

    print(f"[OK] Camera {CAMERA_INDEX} opened.")
    print("Controls: Q=quit  R=reset BG  S=save frame  +/-=threshold")

    detector = SlotDetector(slot_rois=SLOT_ROIS)
    classifier = VehicleClassifier(hsv_lower=HSV_LOWER, hsv_upper=HSV_UPPER)
    cable_detector = CableDetector()

    threshold = detector._occupancy_threshold
    fg_ratios = {sid: 0.0 for sid in SLOT_ROIS}
    vehicle_types = {sid: "—" for sid in SLOT_ROIS}
    cable_results = {sid: False for sid in SLOT_ROIS}

    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print("[WARN] Camera read failed — retrying…")
            time.sleep(0.05)
            continue

        frame_count += 1
        display = frame.copy()

        # ── Run pipeline ──────────────────────────────────────────────────────
        statuses = detector.process_frame(frame)

        # Compute per-slot FG ratios for the bar display (read-only pass)
        for slot_id, (x, y, w, h) in SLOT_ROIS.items():
            roi = frame[y:y + h, x:x + w]
            if roi.size > 0:
                mask = detector._subtractors[slot_id].apply(roi, learningRate=0)
                fg_ratios[slot_id] = np.count_nonzero(mask) / mask.size

        # Classify vehicle and check cable every 10 frames (avoid thrashing)
        if frame_count % 10 == 0:
            for slot_id, (x, y, w, h) in SLOT_ROIS.items():
                roi = frame[y:y + h, x:x + w]
                if roi.size > 0:
                    vehicle_types[slot_id] = classifier.classify(roi)
                    cable_results[slot_id] = cable_detector.detect(roi)

        # ── Draw ROIs on main frame ───────────────────────────────────────────
        for slot_id, (x, y, w, h) in SLOT_ROIS.items():
            status = statuses.get(slot_id, "available")
            draw_roi(display, slot_id, x, y, w, h,
                     status, fg_ratios[slot_id], threshold)

            # Vehicle type + cable below the ROI
            vtype = vehicle_types[slot_id]
            cable = "cable✓" if cable_results[slot_id] else "no cable"
            info = f"{vtype} | {cable}"
            cv2.putText(display, info, (x + 4, y + h + 16),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.42, (200, 200, 200), 1)

        # HUD — threshold + frame count
        cv2.putText(display, f"threshold: {threshold:.2f}  frame: {frame_count}",
                    (8, display.shape[0] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (180, 180, 180), 1)

        # ── HSV mask window ───────────────────────────────────────────────────
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        hsv_mask = cv2.inRange(hsv, HSV_LOWER, HSV_UPPER)
        hsv_display = cv2.cvtColor(hsv_mask, cv2.COLOR_GRAY2BGR)
        cv2.putText(hsv_display, "HSV EV mask (green sticker)",
                    (8, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1)

        # ── Canny edges window ────────────────────────────────────────────────
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 50, 150)
        edges_display = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        cv2.putText(edges_display, "Canny edges (cable detection)",
                    (8, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1)

        # ── FG mask panel ─────────────────────────────────────────────────────
        fg_panel = build_fg_panel(frame, SLOT_ROIS, detector._subtractors)

        # ── Show windows ──────────────────────────────────────────────────────
        cv2.imshow("Harbr CV — Main (Q to quit)", display)
        cv2.imshow("FG Masks (background subtraction)", fg_panel)
        cv2.imshow("HSV Mask (EV sticker)", hsv_display)
        cv2.imshow("Canny Edges (cable)", edges_display)

        # ── Keyboard controls ─────────────────────────────────────────────────
        key = cv2.waitKey(1) & 0xFF

        if key == ord('q'):
            break

        elif key == ord('r'):
            # Reset background subtractors — re-learn background
            detector._subtractors = {
                sid: cv2.createBackgroundSubtractorMOG2(
                    history=500, varThreshold=50, detectShadows=False
                )
                for sid in SLOT_ROIS
            }
            detector._last_state = {sid: "available" for sid in SLOT_ROIS}
            print("[RESET] Background subtractors cleared.")

        elif key == ord('s'):
            fname = f"test_frame_{int(time.time())}.jpg"
            cv2.imwrite(fname, frame)
            print(f"[SAVED] {fname}")

        elif key == ord('+') or key == ord('='):
            threshold = min(threshold + 0.01, 1.0)
            detector._occupancy_threshold = threshold
            print(f"[THRESHOLD] {threshold:.2f}")

        elif key == ord('-'):
            threshold = max(threshold - 0.01, 0.01)
            detector._occupancy_threshold = threshold
            print(f"[THRESHOLD] {threshold:.2f}")

    cap.release()
    cv2.destroyAllWindows()
    print("Done.")


if __name__ == "__main__":
    main()
