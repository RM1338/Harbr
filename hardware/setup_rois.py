"""
setup_rois.py — Interactive tool to define parking slot ROIs using your webcam.

Run this ONCE before starting the main pipeline to figure out where to draw
the slot boxes. It will print the SLOT_ROIS dict you need to paste into main.py.

Usage:
    cd hardware
    python setup_rois.py

Controls:
    - Click and drag to draw a slot ROI box
    - After drawing, type the slot name (e.g. A1) in the terminal and press Enter
    - Press D to delete the last drawn box
    - Press S to save and print the final SLOT_ROIS dict
    - Press Q to quit without saving
    - Press R to reset all boxes
    - Press SPACE to capture a clean background frame (do this with NO cars)
"""

import sys
import os
import cv2
import numpy as np

CAMERA_INDEX = int(os.getenv("CAMERA_INDEX", "0"))

# State
rois: dict[str, tuple] = {}       # slot_id → (x, y, w, h)
drawing = False
start_x, start_y = 0, 0
current_rect = None
frame_display = None

COLOURS = [
    (0, 220, 80),
    (0, 120, 255),
    (255, 180, 0),
    (180, 0, 255),
    (0, 220, 220),
]


def get_colour(i):
    return COLOURS[i % len(COLOURS)]


def draw_all(frame):
    out = frame.copy()
    for i, (slot_id, (x, y, w, h)) in enumerate(rois.items()):
        c = get_colour(i)
        cv2.rectangle(out, (x, y), (x + w, y + h), c, 2)
        cv2.putText(out, slot_id, (x + 6, y + 22),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, c, 2)
    if current_rect:
        x1, y1, x2, y2 = current_rect
        cv2.rectangle(out, (x1, y1), (x2, y2), (255, 255, 255), 1)
    cv2.putText(out,
                "Drag=draw box  S=save  D=delete last  R=reset  Q=quit",
                (8, out.shape[0] - 10),
                cv2.FONT_HERSHEY_SIMPLEX, 0.42, (180, 180, 180), 1)
    return out


def mouse_cb(event, x, y, flags, param):
    global drawing, start_x, start_y, current_rect, frame_display

    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
        start_x, start_y = x, y
        current_rect = None

    elif event == cv2.EVENT_MOUSEMOVE and drawing:
        current_rect = (min(start_x, x), min(start_y, y),
                        max(start_x, x), max(start_y, y))
        if frame_display is not None:
            cv2.imshow("ROI Setup", draw_all(frame_display))

    elif event == cv2.EVENT_LBUTTONUP:
        drawing = False
        if abs(x - start_x) > 10 and abs(y - start_y) > 10:
            rx = min(start_x, x)
            ry = min(start_y, y)
            rw = abs(x - start_x)
            rh = abs(y - start_y)
            current_rect = None

            slot_id = input(f"  → Name this slot (e.g. A1, A2): ").strip()
            if slot_id:
                rois[slot_id] = (rx, ry, rw, rh)
                print(f"  ✓ Saved {slot_id}: x={rx}, y={ry}, w={rw}, h={rh}")
        else:
            current_rect = None


def main():
    global frame_display

    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        # Try index 1 and 2 as fallback
        for idx in [1, 2]:
            cap = cv2.VideoCapture(idx)
            if cap.isOpened():
                print(f"[INFO] Camera opened on index {idx}")
                break
        else:
            print("[ERROR] Cannot open any camera. Check your webcam connection.")
            sys.exit(1)

    cv2.namedWindow("ROI Setup")
    cv2.setMouseCallback("ROI Setup", mouse_cb)

    print("\n=== Harbr ROI Setup ===")
    print("1. Point your webcam at the parking area")
    print("2. Drag boxes over each parking slot")
    print("3. Type the slot name (A1, A2, A3) when prompted")
    print("4. Press S when done to get the config to paste into main.py\n")

    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print("[WARN] Camera read failed")
            continue

        frame_display = frame
        cv2.imshow("ROI Setup", draw_all(frame))

        key = cv2.waitKey(1) & 0xFF

        if key == ord('q'):
            break

        elif key == ord('r'):
            rois.clear()
            print("[RESET] All ROIs cleared.")

        elif key == ord('d'):
            if rois:
                removed = list(rois.keys())[-1]
                del rois[removed]
                print(f"[DELETE] Removed {removed}")

        elif key == ord('s'):
            if not rois:
                print("[WARN] No ROIs defined yet.")
                continue

            print("\n" + "="*50)
            print("Paste this into hardware/cv_pipeline/main.py")
            print("replacing the SLOT_ROIS block:\n")
            print("SLOT_ROIS: dict[str, tuple] = {")
            for slot_id, (x, y, w, h) in rois.items():
                print(f'    "{slot_id}": ({x}, {y}, {w}, {h}),')
            print("}")
            print("="*50 + "\n")
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
