"""Merge duplicate people by name+institution. Keep the highest-confidence record."""
from app.models.domain import SearchResult
from app.utils.normalize import name_key


def _dedup_key(r: SearchResult) -> str:
    name = name_key(r.person.full_name)
    inst_id = r.institution.wikidata_id if r.institution else ""
    return f"{name}|{inst_id}"


def dedupe(results: list[SearchResult]) -> list[SearchResult]:
    best: dict[str, SearchResult] = {}
    for r in results:
        key = _dedup_key(r)
        if key not in best or r.person.confidence > best[key].person.confidence:
            best[key] = r
    return list(best.values())
