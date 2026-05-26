"""Naive in-process rate limiter, per-key sliding window."""
import time
from collections import defaultdict, deque

from app.config import settings

_windows: dict[str, deque[float]] = defaultdict(deque)


def allow(key: str) -> bool:
    """Return True if the key is within the per-minute limit."""
    now = time.time()
    window = _windows[key]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= settings.rate_limit_per_min:
        return False
    window.append(now)
    return True


def remaining(key: str) -> int:
    """Return how many requests remain in the current window."""
    now = time.time()
    window = _windows[key]
    active = sum(1 for ts in window if now - ts <= 60)
    return max(0, settings.rate_limit_per_min - active)
