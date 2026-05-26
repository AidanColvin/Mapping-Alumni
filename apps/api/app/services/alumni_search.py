"""End-to-end alumni search pipeline.
Steps: resolve → fetch → classify → enrich → score → dedupe → filter → paginate → persist.
"""
from app.adapters import wikidata
from app.db import get_conn, upsert_company, upsert_employment, upsert_institution, upsert_person
from app.models.domain import Institution, SearchResult
from app.services import (
    confidence_scorer,
    company_enricher,
    deduper,
    sector_mapper,
    title_classifier,
    university_resolver,
)
from app.utils.logger import log
from app.validators.search_input import SearchInput


async def run(query: SearchInput) -> tuple[list[SearchResult], int, dict | None]:
    institution = await university_resolver.resolve(query.university)
    if not institution:
        return [], 0, None

    raw = await wikidata.fetch_alumni(institution)

    enriched: list[SearchResult] = []
    for r in raw:
        for e in r.employment:
            e.title_level = title_classifier.classify(e.title)
            e.sector = sector_mapper.map_sector(e.company.name if e.company else "")
            if e.company:
                e.company = company_enricher.enrich(e.company)
        enriched.append(confidence_scorer.score(r))

    deduped = deduper.dedupe(enriched)
    filtered = _apply_filters(deduped, query)
    filtered.sort(key=lambda r: r.person.confidence, reverse=True)

    _persist(institution, filtered)

    total = len(filtered)
    start = (query.page - 1) * query.limit
    paged = filtered[start : start + query.limit]
    return paged, total, institution.model_dump()


def _apply_filters(results: list[SearchResult], q: SearchInput) -> list[SearchResult]:
    out = results
    if q.title_level:
        out = [r for r in out if any(e.title_level == q.title_level for e in r.employment)]
    if q.sector:
        out = [r for r in out if any(e.sector == q.sector for e in r.employment)]
    if q.company_type:
        ct = q.company_type.lower()
        out = [
            r for r in out
            if any(ct in (e.sector or "").lower() or ct in (e.company.name.lower() if e.company else "") for e in r.employment)
        ]
    if q.region:
        region = q.region.lower()
        out = [
            r for r in out
            if (r.institution and region in (r.institution.country or "").lower())
            or any(region in (e.company.name.lower() if e.company else "") for e in r.employment)
        ]
    if q.keyword:
        kw = q.keyword.lower()
        out = [
            r for r in out
            if kw in r.person.full_name.lower()
            or any(kw in (e.company.name.lower() if e.company else "") for e in r.employment)
            or any(kw in e.title.lower() for e in r.employment)
        ]
    return out


def _persist(institution: Institution, results: list[SearchResult]) -> None:
    """Upsert search results into the local database."""
    try:
        with get_conn() as conn:
            upsert_institution(conn, institution)
            for r in results:
                upsert_person(conn, r.person, r.person.confidence)
                for e in r.employment:
                    if e.company:
                        upsert_company(conn, e.company)
                    upsert_employment(conn, r.person.id, e)
    except Exception as exc:
        log("warn", "persist_failed", error=str(exc))
