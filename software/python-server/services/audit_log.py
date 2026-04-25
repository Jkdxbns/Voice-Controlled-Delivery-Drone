"""Lightweight JSONL audit logging for assistant and arm pipeline events."""

from __future__ import annotations

import json
import threading
import time
from pathlib import Path
from typing import Any


_LOCK = threading.Lock()
_BASE_DIR = Path(__file__).resolve().parents[1] / "logs"
_BASE_DIR.mkdir(parents=True, exist_ok=True)


def audit_event(stream: str, event: str, **fields: Any) -> None:
    safe_stream = "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in stream) or "audit"
    file_path = _BASE_DIR / f"{safe_stream}.jsonl"
    payload = {
        "event": event,
        "ts": time.time(),
        "iso_time": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime()),
        **fields,
    }
    line = json.dumps(payload, ensure_ascii=True)
    with _LOCK:
        with file_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")