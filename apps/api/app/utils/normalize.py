"""Text normalization helpers."""
import re


def normalize(text: str) -> str:
    """Lowercase, strip, collapse whitespace."""
    return re.sub(r"\s+", " ", text).strip().lower()


def name_key(full_name: str) -> str:
    """Stable key for matching the same person across sources."""
    return normalize(re.sub(r"[^\w\s]", "", full_name))
