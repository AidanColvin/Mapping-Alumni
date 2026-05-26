"""Resolve a free-text university name to a canonical Institution record."""
from __future__ import annotations

import re
from app.models.domain import Institution
from app.adapters import wikidata
from app.utils.cache import get, put
from app.utils.logger import get_logger

log = get_logger(__name__)

_TTL = 86_400  # 24 hours


_STRIP_SUFFIXES = re.compile(
    r"\b(university|college|institute|school|of technology|the)\b",
    re.IGNORECASE,
)


def _normalize_name(name: str) -> str:
    """Remove common noise words for a cleaner search query."""
    return _STRIP_SUFFIXES.sub("", name).strip(" ,.-")


def resolve(name: str) -> Institution | None:
    """Return an Institution for the given university name, using cache when available."""
    if not name or not name.strip():
        return None

    cache_key = f"institution:{name.lower().strip()}"
    cached = get(cache_key)
    if cached:
        log.debug("Institution cache hit: %s", name)
        return Institution(**cached)

    # Try full name first, then stripped name
    institution = wikidata.resolve_institution(name)
    if institution is None:
        normalized = _normalize_name(name)
        if normalized and normalized.lower() != name.lower():
            institution = wikidata.resolve_institution(normalized)

    if institution:
        put(cache_key, institution.__dict__, ttl=_TTL)

    return institution
