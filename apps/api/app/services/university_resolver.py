"""Resolve a free-text university name to a canonical Institution.

Applies normalization before querying so that "unc chapel hill",
"UNC", "University of North Carolina" all resolve correctly.
"""
import re

from app.adapters import wikidata
from app.models.domain import Institution
from app.utils import cache
from app.utils.logger import log

# Common abbreviations expanded before lookup
_ABBREVIATIONS: dict[str, str] = {
    r"\bunc\b": "university of north carolina",
    r"\bmit\b": "massachusetts institute of technology",
    r"\bucla\b": "university of california los angeles",
    r"\busc\b": "university of southern california",
    r"\bnyc\b": "new york",
    r"\bcu\b": "columbia university",
    r"\bgu\b": "georgetown university",
}


def _expand_abbreviations(name: str) -> str:
    result = name.lower().strip()
    for pattern, expansion in _ABBREVIATIONS.items():
        result = re.sub(pattern, expansion, result, flags=re.I)
    return result.strip()


def _normalize_name(name: str) -> str:
    """Strip extra punctuation and collapse whitespace."""
    name = re.sub(r"[^\w\s-]", " ", name)
    name = re.sub(r"\s+", " ", name).strip()
    return _expand_abbreviations(name)


async def resolve(name: str) -> Institution | None:
    """Resolve a free-text university name to a canonical Institution."""
    normalized = _normalize_name(name)
    cache_key = "resolver:" + normalized
    cached = cache.get(cache_key)
    if cached:
        from app.utils.slugify import slugify
        return Institution(**cached)

    institution = await wikidata.resolve_institution(normalized)
    if not institution:
        # Fallback: try the original name without abbreviation expansion
        institution = await wikidata.resolve_institution(name.strip())

    if institution:
        cache.put(cache_key, institution.model_dump())
        log("info", "resolved_institution", name=name, resolved=institution.name, qid=institution.wikidata_id)
    else:
        log("warn", "institution_not_found", name=name)

    return institution
