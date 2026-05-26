"""Structured JSON logging."""
import json
import sys
from datetime import datetime, timezone


def log(level: str, message: str, **meta) -> None:
    entry = {
        "level": level,
        "message": message,
        "ts": datetime.now(timezone.utc).isoformat(),
        **meta,
    }
    stream = sys.stderr if level == "error" else sys.stdout
    print(json.dumps(entry), file=stream, flush=True)
