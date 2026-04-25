#!/usr/bin/env python3
"""Headless wrapper around the working test_yolo tracker logic."""

from __future__ import annotations

import argparse
import glob
import json
import os
import platform
import threading
import time

import cv2
import serial
import serial.tools.list_ports
import torch
from ultralytics import YOLO


MODEL_PATH = "best_03_14.pt"
TARGET_CLASS = "blue_cube"
BAUD = 115200

CAMERA_INDEX = 0
CAMERA_WIDTH, CAMERA_HEIGHT = 640, 480
INFER_IMGSZ = 512
CONF_THRESH = 0.45

BASE_MIN, BASE_MAX, BASE_HOME = 0, 90, 45
CAM_MIN, CAM_MAX, CAM_HOME = 35, 120, 40

KP = 0.004
DEADZONE_PX = 35
MAX_STEP_DEG = 2
EMA_ALPHA = 0.35
CMD_GAP_SEC = 0.10
BASE_CMD_GAP_SEC = CMD_GAP_SEC / 1.3
ALIGN_HOLD_SEC = 0.55

PREPICK_TIMEOUT_SEC = 8.0
GRAB_TIMEOUT_SEC = 12.0


def emit_status(status: str, **fields):
    payload = {"status": status, **fields}
    print("TRACK_STATUS:" + json.dumps(payload, ensure_ascii=True), flush=True)


class CameraThread(threading.Thread):
    def __init__(self, cap):
        super().__init__(daemon=True)
        self.cap = cap
        self._latest = None
        self._lock = threading.Lock()
        self._stop = threading.Event()

    def run(self):
        while not self._stop.is_set():
            ok, frame = self.cap.read()
            if ok:
                with self._lock:
                    self._latest = frame
            else:
                time.sleep(0.002)

    def read_latest(self):
        with self._lock:
            return None if self._latest is None else self._latest.copy()

    def stop(self):
        self._stop.set()


def normalize_label(value: str) -> str:
    return value.strip().lower().replace("_", " ")


def find_arduino_port():
    for port in serial.tools.list_ports.comports():
        description = (port.description or "").lower()
        device = (port.device or "").lower()
        if any(keyword in description for keyword in ("arduino", "ch340", "ch341", "wchusbserial", "usb-serial", "usb serial")) or any(
            keyword in device for keyword in ("ttyacm", "ttyusb", "ttych341")
        ):
            return port.device
    for pattern in ("/dev/ttyCH341USB*", "/dev/ttyCH341*"):
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[0]
    return None


def connect_arduino(port: str | None, baud_rate: int):
    if port:
        try:
            return serial.Serial(port, baud_rate, timeout=0.05)
        except Exception as exc:
            raise RuntimeError(f"Failed to open serial port {port}: {exc}") from exc

    auto_port = find_arduino_port()
    if auto_port is None:
        raise RuntimeError("No Arduino")
    return serial.Serial(auto_port, baud_rate, timeout=0.05)


def open_camera(camera_index: int):
    backend = cv2.CAP_V4L2 if platform.system() == "Linux" else cv2.CAP_DSHOW if platform.system() == "Windows" else 0
    cap = cv2.VideoCapture(camera_index, backend)
    if not cap.isOpened():
        cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        return None
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    return cap


def clamp(value, low, high):
    return low if value < low else high if value > high else value


def send_and_wait(ser, cmd: str, timeout_sec: float):
    ser.reset_input_buffer()
    ser.write((cmd + "\n").encode())
    start = time.time()
    while (time.time() - start) < timeout_sec:
        line = ser.readline().decode(errors="ignore").strip()
        if line == "OK":
            return True
        if line == "ERR":
            return False
    return False


def resolve_target_class(model, target_label: str):
    desired = normalize_label(target_label)
    for class_id, name in model.names.items():
        if normalize_label(str(name)) == desired:
            return class_id, str(name)
    available = [str(name) for _, name in model.names.items()]
    raise RuntimeError(f"Target class '{target_label}' not found in model labels: {available}")


def run_tracking_pick(target_label: str, model_path: str, serial_port: str | None, baud_rate: int, camera_index: int, headless: bool, max_run_sec: float):
    if not os.path.exists(model_path):
        raise RuntimeError(f"Model not found: {model_path}")

    model = YOLO(model_path)
    use_cuda = torch.cuda.is_available()
    target_id, resolved_label = resolve_target_class(model, target_label)

    cap = open_camera(camera_index)
    if cap is None:
        raise RuntimeError("Camera failed")
    cam = CameraThread(cap)
    cam.start()

    ser = connect_arduino(serial_port, baud_rate)
    time.sleep(2.0)
    ser.reset_input_buffer()

    base = BASE_HOME
    theta = CAM_HOME
    # For app-driven headless flow, plan step s1 already homes and s2 opens gripper.
    # Avoid issuing another home here because firmware home can close gripper (GRIP_HOME).
    if not headless:
        ser.write(b"home\n")

    emit_status("tracking_started", target_label=target_label)
    emit_status("tracker_ready", target_label=resolved_label, model_path=model_path)

    sm_x = None
    sm_y = None
    centered_since = None
    last_base_cmd_t = 0.0
    last_cam_cmd_t = 0.0
    pick_armed = headless
    waiting_for_grab_align = False
    last_emit_t = 0.0
    start_time = time.time()

    try:
        while True:
            if time.time() - start_time > max_run_sec:
                raise RuntimeError("Tracking timed out")

            frame = cam.read_latest()
            if frame is None:
                time.sleep(0.005)
                continue

            now = time.time()
            height, width = frame.shape[:2]
            cx0, cy0 = width // 2, height // 2

            results = model.predict(
                frame,
                imgsz=INFER_IMGSZ,
                conf=CONF_THRESH,
                classes=[target_id],
                device=0 if use_cuda else "cpu",
                half=use_cuda,
                verbose=False,
            )[0]

            best = None
            for box in results.boxes:
                if int(box.cls[0]) != target_id:
                    continue
                conf = float(box.conf[0])
                if best is None or conf > best["conf"]:
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    best = {
                        "conf": conf,
                        "x1": x1,
                        "y1": y1,
                        "x2": x2,
                        "y2": y2,
                        "cx": (x1 + x2) // 2,
                        "cy": (y1 + y2) // 2,
                    }

            cv2.line(frame, (cx0, 0), (cx0, height), (255, 0, 0), 1)
            cv2.line(frame, (0, cy0), (width, cy0), (255, 0, 0), 1)

            centered = False
            if best is not None:
                if sm_x is None:
                    sm_x, sm_y = float(best["cx"]), float(best["cy"])
                else:
                    sm_x = (1 - EMA_ALPHA) * sm_x + EMA_ALPHA * best["cx"]
                    sm_y = (1 - EMA_ALPHA) * sm_y + EMA_ALPHA * best["cy"]

                cv2.rectangle(frame, (best["x1"], best["y1"]), (best["x2"], best["y2"]), (0, 255, 0), 2)
                cv2.circle(frame, (best["cx"], best["cy"]), 5, (0, 255, 255), -1)
                cv2.putText(
                    frame,
                    f"obj:({best['cx']},{best['cy']})",
                    (best["cx"] + 8, best["cy"] - 8),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.45,
                    (0, 255, 255),
                    1,
                )
                cv2.circle(frame, (int(sm_x), int(sm_y)), 4, (255, 255, 0), -1)

                err_b = int(sm_x) - cx0
                err_c = cy0 - int(sm_y)
                centered = abs(err_b) <= DEADZONE_PX and abs(err_c) <= DEADZONE_PX

                if now - last_emit_t >= 0.4:
                    emit_status("object_detected", target_label=resolved_label, confidence=best["conf"], error_px=err_b)
                    last_emit_t = now

                if (now - last_base_cmd_t) >= BASE_CMD_GAP_SEC:
                    if abs(err_b) > DEADZONE_PX:
                        step_b = clamp(-err_b * KP, -MAX_STEP_DEG, MAX_STEP_DEG)
                        if 0.0 < abs(step_b) < 1.0:
                            step_b = -1.0 if step_b < 0 else 1.0
                        next_base = clamp(base + int(step_b), BASE_MIN, BASE_MAX)
                        if next_base != base:
                            base = next_base
                            ser.write(f"b {base}\n".encode())
                            emit_status("tracking_update", base_angle=base, error_px=err_b)
                    last_base_cmd_t = now

                if (now - last_cam_cmd_t) >= CMD_GAP_SEC:
                    if abs(err_c) > DEADZONE_PX:
                        step_c = clamp(err_c * KP, -MAX_STEP_DEG, MAX_STEP_DEG)
                        if 0.0 < abs(step_c) < 1.0:
                            step_c = -1.0 if step_c < 0 else 1.0
                        next_theta = clamp(theta + int(step_c), CAM_MIN, CAM_MAX)
                        if next_theta != theta:
                            theta = next_theta
                            ser.write(f"c {theta}\n".encode())
                    last_cam_cmd_t = now
            else:
                sm_x = None
                sm_y = None

            centered_since = (centered_since or now) if centered else None
            aligned = bool(centered and centered_since and (now - centered_since) >= ALIGN_HOLD_SEC)

            if waiting_for_grab_align:
                status = "PREPICK_ALIGN" if not aligned else "PREPICK_ALIGNED"
            elif pick_armed:
                status = "PICK_ARMED"
            elif aligned:
                status = "ALIGNED"
            else:
                status = "TRACK"

            cv2.putText(
                frame,
                status,
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (0, 255, 0) if aligned else (0, 200, 200),
                2,
            )
            if not headless:
                cv2.putText(frame, "p: pick  q: quit", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (220, 220, 220), 2)
                cv2.imshow("Auto Pick", frame)

            if waiting_for_grab_align and aligned:
                emit_status("prepick_locked", target_label=resolved_label)
                if send_and_wait(ser, "grab", GRAB_TIMEOUT_SEC):
                    emit_status("grabbing", target_label=resolved_label)
                    emit_status("picked", target_label=resolved_label)
                waiting_for_grab_align = False
                pick_armed = False
                centered_since = None
                t_now = time.time()
                last_base_cmd_t = t_now
                last_cam_cmd_t = t_now
                if headless:
                    return 0

            if pick_armed and aligned:
                if send_and_wait(ser, "prepick", PREPICK_TIMEOUT_SEC):
                    waiting_for_grab_align = True
                else:
                    pick_armed = False
                    waiting_for_grab_align = False
                centered_since = None
                t_now = time.time()
                last_base_cmd_t = t_now
                last_cam_cmd_t = t_now

            if not headless:
                key = cv2.waitKey(1) & 0xFF
                if key == ord("p"):
                    pick_armed = True
                if key == ord("q"):
                    break

    finally:
        cam.stop()
        cap.release()
        if not headless:
            cv2.destroyAllWindows()
        try:
            if not headless:
                ser.write(b"home\n")
                time.sleep(0.5)
            ser.close()
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-class", default=TARGET_CLASS)
    parser.add_argument("--model-path", default=MODEL_PATH)
    parser.add_argument("--serial-port", default="")
    parser.add_argument("--baud-rate", type=int, default=BAUD)
    parser.add_argument("--camera-index", type=int, default=CAMERA_INDEX)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--max-run-sec", type=float, default=30.0)
    args = parser.parse_args()

    try:
        return run_tracking_pick(
            target_label=args.target_class,
            model_path=args.model_path,
            serial_port=args.serial_port or None,
            baud_rate=args.baud_rate,
            camera_index=args.camera_index,
            headless=args.headless,
            max_run_sec=args.max_run_sec,
        )
    except Exception as exc:
        emit_status("tracking_failed", error=str(exc))
        print(f"TRACK_ERROR:{exc}", flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())