"""File cache service for cross-device transfers."""

import json
import hashlib
import time
import uuid
from pathlib import Path
from typing import Dict, Optional
from werkzeug.utils import secure_filename

from config import BASE_DIR


class FileCacheService:
    """Manages temporary file storage with 30-day retention."""

    def __init__(self):
        self.base_dir = BASE_DIR / "files_cache"
        self.index_path = self.base_dir / "index.json"
        self.base_dir.mkdir(parents=True, exist_ok=True)
        if not self.index_path.exists():
            self._write_index({})

    def _read_index(self) -> Dict[str, dict]:
        try:
            with self.index_path.open('r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {}

    def _write_index(self, data: Dict[str, dict]) -> None:
        with self.index_path.open('w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)

    def cleanup_expired(self) -> int:
        index = self._read_index()
        now = int(time.time())
        removed = 0
        for file_id in list(index.keys()):
            meta = index[file_id]
            if meta.get('expires_at', 0) <= now:
                self._delete_entry(file_id, meta)
                removed += 1
                del index[file_id]
        if removed:
            self._write_index(index)
        return removed

    def save_upload(self, file_storage, original_name: str, source_mac: str, target_mac: str, action: str, checksum: Optional[str]) -> dict:
        file_id = uuid.uuid4().hex
        safe_name = secure_filename(original_name) or f"file_{file_id}"
        file_dir = self.base_dir / file_id
        file_dir.mkdir(parents=True, exist_ok=True)
        file_path = file_dir / safe_name

        hasher = hashlib.sha256()
        total_bytes = 0

        with file_path.open('wb') as f:
            for chunk in iter(lambda: file_storage.stream.read(1024 * 64), b''):
                if not chunk:
                    break
                f.write(chunk)
                total_bytes += len(chunk)
                hasher.update(chunk)

        computed_checksum = hasher.hexdigest()
        now = int(time.time())
        expires_at = now + 30 * 24 * 60 * 60

        metadata = {
            'file_id': file_id,
            'file_name': safe_name,
            'original_name': original_name,
            'size': total_bytes,
            'checksum': computed_checksum,
            'source_mac': source_mac,
            'target_mac': target_mac,
            'action': action,
            'created_at': now,
            'expires_at': expires_at,
            'client_checksum': checksum
        }

        index = self._read_index()
        index[file_id] = metadata
        self._write_index(index)

        return metadata

    def get_metadata(self, file_id: str) -> Optional[dict]:
        index = self._read_index()
        return index.get(file_id)

    def get_file_path(self, file_id: str) -> Optional[Path]:
        meta = self.get_metadata(file_id)
        if not meta:
            return None
        path = self.base_dir / file_id / meta.get('file_name', '')
        return path if path.exists() else None

    def _delete_entry(self, file_id: str, meta: dict) -> None:
        try:
            file_path = self.base_dir / file_id / meta.get('file_name', '')
            if file_path.exists():
                file_path.unlink()
            dir_path = self.base_dir / file_id
            if dir_path.exists():
                for child in dir_path.iterdir():
                    child.unlink(missing_ok=True)
                dir_path.rmdir()
        except Exception:
            pass
