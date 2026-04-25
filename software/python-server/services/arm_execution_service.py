"""Arm execution coordination service.

Tracks arm command status updates (received/executing/done/error) keyed by command_id
and provides blocking waits for terminal states for step-by-step plan execution.
"""

from __future__ import annotations

import threading
import time
from typing import Any, Dict

try:
    # Eventlet sleep yields execution so Socket.IO handlers can run while we wait.
    from eventlet import sleep as _cooperative_sleep
except Exception:  # pragma: no cover
    from time import sleep as _cooperative_sleep


class ArmExecutionService:
    """In-memory coordinator for command status updates."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._lock = threading.Lock()
        self._command_updates: Dict[str, Dict[str, Any]] = {}
        self._step_updates: Dict[str, Dict[str, Any]] = {}
        self._initialized = True

    def _append_update(self, store: Dict[str, Dict[str, Any]], key: str, payload: Dict[str, Any], status: str) -> None:
        record = store.setdefault(
            key,
            {
                "history": [],
                "terminal": "",
                "updated_at": 0.0,
            },
        )
        record["history"].append(payload)
        record["updated_at"] = time.time()
        if status in ("done", "error"):
            record["terminal"] = status

    def update_status(self, payload: Dict[str, Any]) -> None:
        """Record status update for a command."""
        command_id = (payload.get("command_id") or "").strip()
        plan_id = (payload.get("plan_id") or "").strip()
        step_id = (payload.get("step_id") or "").strip()

        status = (payload.get("status") or "").strip().lower()

        with self._lock:
            if command_id:
                self._append_update(self._command_updates, command_id, payload, status)

            if plan_id and step_id:
                step_key = f"{plan_id}:{step_id}"
                self._append_update(self._step_updates, step_key, payload, status)

    def reset_tracking(self, command_id: str = "", plan_id: str = "", step_id: str = "") -> None:
        """Clear prior history for a command/step before a new dispatch attempt."""
        step_key = f"{plan_id}:{step_id}" if plan_id and step_id else ""
        with self._lock:
            if command_id and command_id in self._command_updates:
                del self._command_updates[command_id]
            if step_key and step_key in self._step_updates:
                del self._step_updates[step_key]

    def wait_for_terminal(
        self,
        command_id: str,
        timeout_sec: float,
        plan_id: str = "",
        step_id: str = "",
    ) -> Dict[str, Any]:
        """Wait until command reaches done/error or timeout.

        Returns a dictionary with keys:
        - status: done|error|timeout
        - history: list of observed updates
        - last: last observed payload (if any)
        """
        deadline = time.time() + max(0.0, timeout_sec)
        step_key = f"{plan_id}:{step_id}" if plan_id and step_id else ""

        while True:
            with self._lock:
                record = self._command_updates.get(command_id)
                if record and record.get("terminal"):
                    history = list(record.get("history", []))
                    return {
                        "status": record["terminal"],
                        "history": history,
                        "last": history[-1] if history else None,
                    }

                if step_key:
                    step_record = self._step_updates.get(step_key)
                    if step_record and step_record.get("terminal"):
                        history = list(step_record.get("history", []))
                        return {
                            "status": step_record["terminal"],
                            "history": history,
                            "last": history[-1] if history else None,
                        }

                remaining = deadline - time.time()
                if remaining <= 0:
                    history = []
                    if record:
                        history = list(record.get("history", []))
                    elif step_key and self._step_updates.get(step_key):
                        history = list(self._step_updates[step_key].get("history", []))
                    return {
                        "status": "timeout",
                        "history": history,
                        "last": history[-1] if history else None,
                    }

            # Yield to event loop so websocket arm_status updates can be processed.
            _cooperative_sleep(min(0.05, remaining))


arm_execution_service = ArmExecutionService()
