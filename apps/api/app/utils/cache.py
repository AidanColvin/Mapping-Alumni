"""File-based cache. Hash URL to filename. Honor TTL."""
import hashlib
import json
import time
from pathlib import Path
from typing import Optional

from app.config import settings


def _key_path(key: str) -> Path:
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return settings.cache_path / f"{digest}.json"


def get(key: str) -> Optional[dict]:
    path = _key_path(key)
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    if time.time() - data["ts"] > settings.cache_ttl_hours * 3600:
        return None
    return data["value"]


def put(key: str, value: dict) -> None:
    path = _key_path(key)
    path.write_text(json.dumps({"ts": time.time(), "value": value}))
