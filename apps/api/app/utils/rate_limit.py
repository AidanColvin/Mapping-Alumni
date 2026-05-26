"""Simple in-process sliding-window rate limiter."""
import time
from collections import defaultdict, deque
from threading import Lock

from app.config import settings

_windows: dict[str, deque[float]] = defaultdict(deque)
_lock = Lock()


def allow(key: str) -> bool:
    """Return True if the key is within its rate limit, False otherwise."""
    now = time.monotonic()
    window = 60.0
    limit = settings.rate_limit_per_minute

    with _lock:
        q = _windows[key]
        # Drop timestamps outside the window
        while q and now - q[0] > window:
            q.popleft()
        if len(q) >= limit:
            return False
        q.append(now)
    return True
