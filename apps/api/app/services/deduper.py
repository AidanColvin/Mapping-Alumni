"""Deduplicate SearchResult lists, keeping the highest-confidence record."""
from app.models.domain import SearchResult
from app.utils.normalize import name_key


def _record_key(r: SearchResult) -> str:
    inst_id = (r.institution.wikidata_id or r.institution.name or "").lower()
    return f"{name_key(r.person.full_name)}|{inst_id}"


def dedupe(results: list[SearchResult]) -> list[SearchResult]:
    """Return deduplicated results, keeping the record with the highest confidence."""
    best: dict[str, SearchResult] = {}
    for r in results:
        k = _record_key(r)
        if k not in best or r.confidence > best[k].confidence:
            best[k] = r
    return list(best.values())
