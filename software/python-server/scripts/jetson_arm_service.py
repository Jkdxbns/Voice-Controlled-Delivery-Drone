#!/usr/bin/env python3
"""Jetson Arm Bridge Service.

Purpose:
- Connect to FlaskServer_v12 over Socket.IO
- Register as a WebSocket client device
- Advertise one arm device over bt_update mapping
- Receive routed bt-control tasks
- Execute command locally (serial passthrough)
- Emit status strings back to server via arm_status
"""

import os
import json
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
import glob

try:
    import socketio
    if not hasattr(socketio, "Client"):
        mod_file = getattr(socketio, "__file__", "<unknown>")
        raise ImportError(
            "Loaded an incompatible 'socketio' module "
            f"from {mod_file}. Expected 'python-socketio'."
        )
except Exception as exc:  # pragma: no cover
    print("[ARM_SERVICE] Missing or incompatible dependency: python-socketio")
    print(f"[ARM_SERVICE] Import error: {exc}")
    print(f"[ARM_SERVICE] Loaded module path: {getattr(locals().get('socketio', None), '__file__', '<not loaded>')}")
    print(f"[ARM_SERVICE] Fix with:")
    print(f"[ARM_SERVICE]   {sys.executable} -m pip uninstall -y socketio python-socketio")
    print(f"[ARM_SERVICE]   {sys.executable} -m pip install --no-cache-dir 'python-socketio[client]'")
    raise

try:
    import serial  # pyserial
    import serial.tools.list_ports
except Exception:  # pragma: no cover
    serial = None


# Known Arduino/compatible USB vendor IDs
_ARDUINO_VIDS = {
    0x2341,  # Arduino LLC
    0x1A86,  # CH340 (common Uno/Nano clone)
    0x0403,  # FTDI
    0x10C4,  # CP210x (Silicon Labs)
    0x067B,  # PL2303
}


class AuditLogger:
    def __init__(self):
        self._lock = threading.Lock()
        self._dir = Path(__file__).resolve().parent / "logs"
        self._dir.mkdir(parents=True, exist_ok=True)
        self._path = self._dir / "arm_bridge_audit.jsonl"

    def log(self, event: str, **fields):
        payload = {
            "event": event,
            "ts": time.time(),
            "iso_time": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime()),
            **fields,
        }
        line = json.dumps(payload, ensure_ascii=True)
        with self._lock:
            with self._path.open("a", encoding="utf-8") as handle:
                handle.write(line + "\n")


audit_logger = AuditLogger()


def _env_first(*names: str) -> str:
    for name in names:
        value = os.getenv(name, "").strip()
        if value:
            return value
    return ""


def _default_tracker_model_path() -> str:
    configured = _env_first("ARM_TRACKER_MODEL_PATH", "ARM_MODEL_PATH")
    if configured:
        return configured

    local_model = Path(__file__).resolve().parent / "best_03_14.pt"
    if local_model.exists():
        return str(local_model)

    return ""


def _detect_serial_port() -> str | None:
    """Return the first likely Arduino serial port, or None if not found."""
    if serial is None:
        return None
    candidates = list(serial.tools.list_ports.comports())
    # Prefer ports whose VID matches a known Arduino chip
    for p in candidates:
        if p.vid in _ARDUINO_VIDS:
            print(f"[ARM_SERVICE] Auto-detected Arduino port: {p.device} ({p.description})")
            return p.device
    # Fallback: common Linux USB serial device names.
    for p in candidates:
        if (
            p.device.startswith("/dev/ttyUSB")
            or p.device.startswith("/dev/ttyACM")
            or p.device.startswith("/dev/ttyCH341USB")
        ):
            print(f"[ARM_SERVICE] Auto-detected fallback port: {p.device} ({p.description})")
            return p.device

    # Last resort: direct filesystem probe for CH341 / USB serial device names.
    for pattern in ("/dev/ttyCH341USB*", "/dev/ttyCH341*", "/dev/ttyUSB*", "/dev/ttyACM*"):
        hits = sorted(glob.glob(pattern))
        if hits:
            print(f"[ARM_SERVICE] Auto-detected glob fallback port: {hits[0]}")
            return hits[0]

    return None


def _resolve_serial_port(configured_port: str) -> str | None:
    """Pick a usable serial port.

    Order:
    1) Configured ARM_SERIAL_PORT if it currently exists.
    2) Auto-detected Arduino-compatible port.
    """
    candidate = (configured_port or "").strip()
    if candidate:
        if os.path.exists(candidate):
            return candidate
        print(f"[ARM_SERVICE] Configured serial port not present: {candidate}; falling back to auto-detect")

    return _detect_serial_port()


@dataclass
class Config:
    server_url: str = os.getenv("ARM_SERVER_URL", "http://127.0.0.1:5000")
    jetson_mac: str = os.getenv("ARM_JETSON_MAC", "02:00:00:00:00:99")
    jetson_device_id: str = os.getenv("ARM_DEVICE_ID", "jetson-arm-01")
    jetson_name: str = os.getenv("ARM_DEVICE_NAME", "Jetson Arm Controller")
    jetson_model: str = os.getenv("ARM_MODEL_NAME", "NVIDIA Jetson")
    arm_target_mac: str = os.getenv("ARM_TARGET_MAC", "AA:BB:CC:DD:EE:01")
    arm_target_name: str = os.getenv("ARM_TARGET_NAME", "robotic-arm")
    arm_target_type: str = os.getenv("ARM_TARGET_TYPE", "classic")
    serial_port: str = os.getenv("ARM_SERIAL_PORT", "")  # empty = auto-detect
    serial_baud: int = int(os.getenv("ARM_SERIAL_BAUD", "115200"))
    serial_timeout_sec: float = float(os.getenv("ARM_SERIAL_TIMEOUT", "2.0"))
    serial_long_timeout_sec: float = float(os.getenv("ARM_SERIAL_LONG_TIMEOUT", "8.0"))
    tracker_script_path: str = os.getenv("ARM_TRACKER_SCRIPT", str(Path(__file__).resolve().parent / "tracker_pick_controller.py"))
    tracker_model_path: str = _default_tracker_model_path()
    tracker_camera_index: int = int(os.getenv("ARM_TRACKER_CAMERA_INDEX", "0"))
    tracker_max_run_sec: float = float(os.getenv("ARM_TRACKER_MAX_RUN_SEC", "30.0"))
    serial_enabled: bool = os.getenv("ARM_SERIAL_ENABLED", "1") == "1"
    ping_interval_sec: float = float(os.getenv("ARM_PING_INTERVAL", "15"))


class ArmExecutor:
    """Simple arm command executor with optional serial passthrough."""

    def __init__(self, cfg: Config):
        self.cfg = cfg
        self._ser = None
        if cfg.serial_enabled and serial is not None:
            self._open_serial()

    def _open_serial(self):
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None

        port = _resolve_serial_port(self.cfg.serial_port)
        if not port:
            print("[ARM_SERVICE] No serial port found — running in dry-run mode")
            return
        try:
            self._ser = serial.Serial(
                port=port,
                baudrate=self.cfg.serial_baud,
                timeout=self.cfg.serial_timeout_sec,
            )
            time.sleep(1.0)
            print(f"[ARM_SERVICE] Serial connected: {port} @ {self.cfg.serial_baud}")
        except Exception as exc:
            self._ser = None
            print(f"[ARM_SERVICE] Serial open failed on {port}: {exc}")

    @staticmethod
    def _is_retriable_serial_error(exc: Exception) -> bool:
        text = str(exc).lower()
        return (
            "input/output error" in text
            or "errno 5" in text
            or "i/o error" in text
            or "write failed" in text
            or "device disconnected" in text
        )

    def close(self):
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None

    def _execute_track_pick(self, command: str, progress_callback=None) -> tuple[bool, str]:
        parts = command.strip().split(maxsplit=1)
        if len(parts) != 2 or not parts[1].strip():
            return False, "missing target label"

        target_label = parts[1].strip()
        tracker_script = Path(self.cfg.tracker_script_path)
        if not tracker_script.exists():
            return False, f"tracker script not found: {tracker_script}"
        if not self.cfg.tracker_model_path:
            return False, "ARM_TRACKER_MODEL_PATH is not configured and no local best_03_14.pt was found"
        if not Path(self.cfg.tracker_model_path).exists():
            return False, f"tracker model not found: {self.cfg.tracker_model_path}"

        serial_port = _resolve_serial_port(self.cfg.serial_port)
        if not serial_port:
            return False, "no serial port available for tracker"

        # Release the shared serial handle while the tracker subprocess owns the port.
        self.close()

        process = subprocess.Popen(
            [
                sys.executable,
                str(tracker_script),
                "--target-class",
                target_label,
                "--model-path",
                self.cfg.tracker_model_path,
                "--serial-port",
                serial_port,
                "--baud-rate",
                str(self.cfg.serial_baud),
                "--camera-index",
                str(self.cfg.tracker_camera_index),
                "--headless",
                "--max-run-sec",
                str(self.cfg.tracker_max_run_sec),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        last_status = "tracker_finished"
        try:
            assert process.stdout is not None
            for raw_line in process.stdout:
                line = raw_line.strip()
                if not line:
                    continue
                audit_logger.log("tracker_stdout", command=command, line=line)
                if line.startswith("TRACK_STATUS:"):
                    try:
                        payload = json.loads(line.split(":", 1)[1])
                        status_name = payload.get("status", "tracking_update")
                        last_status = status_name
                        if progress_callback:
                            progress_callback(status_name, payload)
                    except Exception as exc:
                        audit_logger.log("tracker_parse_error", command=command, error=str(exc), line=line)
                else:
                    if progress_callback:
                        progress_callback("tracking_log", {"line": line})

            exit_code = process.wait(timeout=self.cfg.tracker_max_run_sec + 5.0)
            if exit_code == 0:
                return True, last_status
            return False, last_status
        finally:
            self._open_serial()

    def execute(self, command: str, progress_callback=None) -> tuple[bool, str]:
        if not command:
            return False, "empty command"

        if command.strip().lower().startswith("track_pick "):
            return self._execute_track_pick(command, progress_callback=progress_callback)

        if self._ser is None:
            if self.cfg.serial_enabled and serial is not None:
                self._open_serial()
            if self._ser is None:
                # Dry-run mode if serial is disabled or unavailable.
                print(f"[ARM_SERVICE] DRY-RUN command: {command}")
                return True, "dry-run"

        try:
            line = (command.strip() + "\n").encode("utf-8")
            self._ser.write(line)
            self._ser.flush()

            command_key = command.strip().split()[0].lower()
            requires_explicit_result = command_key in {"prepick", "grab", "pick", "pp"}
            wait_window_sec = self.cfg.serial_long_timeout_sec if requires_explicit_result else self.cfg.serial_timeout_sec
            deadline = time.time() + max(0.1, wait_window_sec)
            last_resp = ""

            while time.time() < deadline:
                resp = self._ser.readline().decode("utf-8", errors="ignore").strip()
                if not resp:
                    continue

                last_resp = resp
                normalized = resp.strip().lower()

                if normalized in {"err", "error", "failed", "fail"}:
                    audit_logger.log("serial_execute", command=command, ok=False, response=resp)
                    return False, resp

                if normalized in {"ok", "done"}:
                    audit_logger.log("serial_execute", command=command, ok=True, response=resp)
                    return True, resp

                # For short/non-blocking commands, any non-error line is fine.
                if not requires_explicit_result:
                    audit_logger.log("serial_execute", command=command, ok=True, response=resp)
                    return True, resp

            if requires_explicit_result:
                timeout_msg = "TIMEOUT_WAITING_RESULT"
                if last_resp:
                    timeout_msg = f"{timeout_msg}:{last_resp}"
                audit_logger.log("serial_execute", command=command, ok=False, response=timeout_msg)
                return False, timeout_msg

            audit_logger.log("serial_execute", command=command, ok=True, response=(last_resp or "sent"))
            return True, (last_resp or "sent")
        except Exception as exc:
            if self._is_retriable_serial_error(exc):
                audit_logger.log("serial_execute_retry", command=command, reason=str(exc))
                self._open_serial()
                if self._ser is not None:
                    try:
                        line = (command.strip() + "\n").encode("utf-8")
                        self._ser.write(line)
                        self._ser.flush()
                        audit_logger.log("serial_execute", command=command, ok=True, response="retried_sent")
                        return True, "retried_sent"
                    except Exception as retry_exc:
                        audit_logger.log("serial_execute", command=command, ok=False, response=f"retry_failed: {retry_exc}")
                        return False, f"write failed after reconnect: {retry_exc}"

            audit_logger.log("serial_execute", command=command, ok=False, response=str(exc))
            return False, str(exc)


class JetsonArmBridge:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.sio = socketio.Client(reconnection=True, logger=False, engineio_logger=False)
        self.executor = ArmExecutor(cfg)
        self.stop_event = threading.Event()
        self._register_handlers()

    def _status(self, status: str, message: str, command: str = "", task: dict | None = None):
        routed_from = None
        plan_id = ""
        step_id = ""
        command_id = ""
        if task:
            routed_from = task.get("_routed_from") or task.get("routed_from")
            plan_id = task.get("plan_id") or ""
            step_id = task.get("step_id") or ""
            command_id = task.get("command_id") or ""

        payload = {
            "status": status,
            "message": message,
            "command": command,
            "plan_id": plan_id,
            "step_id": step_id,
            "command_id": command_id,
        }
        if routed_from:
            payload["_routed_from"] = routed_from

        print(
            f"[ARM_SERVICE] {status} | command='{command}' "
            f"| plan_id={plan_id or '-'} step_id={step_id or '-'} command_id={command_id or '-'} "
            f"| {message}"
        )
        audit_logger.log("arm_status_emit", payload=payload, routed_from=routed_from)

        try:
            self.sio.emit("arm_status", payload)
        except Exception as exc:
            print(f"[ARM_SERVICE] Failed to emit arm_status: {exc}")

    def _extract_command(self, task: dict) -> str:
        output = task.get("output") or {}
        cmd = output.get("generated_output")
        if isinstance(cmd, str) and cmd.strip():
            return cmd.strip()
        cmd2 = task.get("command")
        if isinstance(cmd2, str):
            return cmd2.strip()
        return ""

    def _emit_bt_update(self):
        if not self.sio.connected:
            return
        payload = {
            "connected_devices": [
                {
                    "mac": self.cfg.arm_target_mac,
                    "name": self.cfg.arm_target_name,
                    "type": self.cfg.arm_target_type,
                }
            ]
        }
        self.sio.emit("bt_update", payload)
        audit_logger.log("bt_update_emit", payload=payload)

    def _register_handlers(self):
        @self.sio.event
        def connect():
            print("[ARM_SERVICE] Connected to server")
            audit_logger.log("socket_connected", server_url=self.cfg.server_url)
            self.sio.emit(
                "register",
                {
                    "mac_address": self.cfg.jetson_mac,
                    "device_id": self.cfg.jetson_device_id,
                    "device_name": self.cfg.jetson_name,
                    "model_name": self.cfg.jetson_model,
                },
            )

        @self.sio.event
        def disconnect():
            print("[ARM_SERVICE] Disconnected from server")
            audit_logger.log("socket_disconnected")

        @self.sio.on("registered")
        def on_registered(data):
            print(f"[ARM_SERVICE] Registered: {data}")
            audit_logger.log("registered", payload=data)
            self._emit_bt_update()

        @self.sio.on("task")
        def on_task(data):
            if not isinstance(data, dict):
                return

            task_type = data.get("task", "")
            if task_type != "bt-control":
                return

            audit_logger.log("task_received", payload=data)

            command = self._extract_command(data)
            if not command:
                self._status("error", "No command in task payload", task=data)
                return

            self._status("received", "Command received", command=command, task=data)
            self._status("executing", "Executing command", command=command, task=data)

            ok, details = self.executor.execute(
                command,
                progress_callback=lambda status_name, payload: self._status(
                    "executing",
                    status_name,
                    command=command,
                    task=data,
                ),
            )
            if ok:
                self._status("done", details, command=command, task=data)
            else:
                self._status("error", details, command=command, task=data)

        @self.sio.on("error")
        def on_error(data):
            print(f"[ARM_SERVICE] Server error: {data}")
            audit_logger.log("server_error", payload=data)

        @self.sio.on("arm_status_ack")
        def on_ack(data):
            print(f"[ARM_SERVICE] arm_status ack: {data}")
            audit_logger.log("arm_status_ack", payload=data)

    def _ping_loop(self):
        while not self.stop_event.is_set():
            try:
                if self.sio.connected:
                    self.sio.emit("ping_server", {})
                    # Periodic BT re-advertisement heals transient routing state loss.
                    self._emit_bt_update()
            except Exception as exc:
                print(f"[ARM_SERVICE] ping failed: {exc}")
            self.stop_event.wait(self.cfg.ping_interval_sec)

    def run(self):
        ping_thread = threading.Thread(target=self._ping_loop, daemon=True)
        ping_thread.start()

        while not self.stop_event.is_set():
            try:
                if not self.sio.connected:
                    self.sio.connect(self.cfg.server_url, transports=["websocket"])
                self.stop_event.wait(1.0)
            except Exception as exc:
                print(f"[ARM_SERVICE] connect/reconnect error: {exc}")
                audit_logger.log("socket_connect_error", error=str(exc))
                self.stop_event.wait(3.0)

    def shutdown(self):
        self.stop_event.set()
        try:
            if self.sio.connected:
                self.sio.disconnect()
        except Exception:
            pass
        self.executor.close()


def main():
    cfg = Config()
    print(f"[ARM_SERVICE] Python executable: {sys.executable}")
    print(f"[ARM_SERVICE] Python version: {sys.version.split()[0]}")
    print(f"[ARM_SERVICE] Server URL: {cfg.server_url}")
    audit_logger.log("process_started", python=sys.executable, python_version=sys.version.split()[0], server_url=cfg.server_url)
    bridge = JetsonArmBridge(cfg)

    def _handle_signal(_sig, _frame):
        print("[ARM_SERVICE] Shutdown signal received")
        audit_logger.log("shutdown_signal")
        bridge.shutdown()

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    try:
        bridge.run()
    finally:
        bridge.shutdown()


if __name__ == "__main__":
    main()
