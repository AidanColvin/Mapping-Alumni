"""Main search pipeline orchestrator."""
from __future__ import annotations

from app.models.domain import SearchResult
from app.models.api import SearchInput
from app.services import (
    university_resolver,
    title_classifier,
    sector_mapper,
    company_enricher,
    confidence_scorer,
    deduper,
)
from app.adapters import wikidata
from app.utils.logger import get_logger

log = get_logger(__name__)

def _classify(results: list[SearchResult]) -> list[SearchResult]:
    for r in results:
        if r.employment:
            r.title_level = title_classifier.classify(r.employment.title or "")
            if r.employment.company:
                r.sector = sector_mapper.map_sector(r.employment.company.name or "")
                r.employment.company = company_enricher.enrich(r.employment.company)
        r.confidence = confidence_scorer.score(r)
    return results

def _apply_filters(results: list[SearchResult], inp: SearchInput) -> list[SearchResult]:
    if inp.sector:
        results = [r for r in results if r.sector == inp.sector]
    if inp.title_level:
        results = [r for r in results if r.title_level == inp.title_level]
    if inp.keyword:
        kw = inp.keyword.lower()
        results = [
            r for r in results
            if kw in (r.person.full_name or "").lower()
            or kw in (r.employment.company.name if r.employment and r.employment.company else "").lower()
            or kw in (r.employment.title if r.employment else "").lower()
        ]
    if inp.company_type:
        results = [r for r in results if r.sector == inp.company_type]
    
    return results

def _paginate(results: list[SearchResult], offset: int, limit: int) -> list[SearchResult]:
    return results[offset: offset + limit]

def run(inp: SearchInput) -> tuple[list[SearchResult], int, dict | None]:
    """
    Run the full search pipeline.
    Returns (page_results, total_count, institution_dict_or_None).
    """
    institution = university_resolver.resolve(inp.university)
    if institution is None:
        return [], 0, None

    # Fetch from Wikidata
    rows = wikidata.fetch_alumni(institution.wikidata_id, limit=200)
    results = wikidata.build_search_results(rows, institution)

    # Classify, score
    results = _classify(results)

    # Deduplicate
    results = deduper.dedupe(results)

    # Sort by confidence descending
    results.sort(key=lambda r: r.confidence, reverse=True)

    # Filter
    results = _apply_filters(results, inp)

    # Write to Database to populate the stats endpoint (BUG-05 Fix)
    try:
        from app.db import upsert_search_results
        upsert_search_results(results, institution)
    except ImportError:
        log.warning("Database upsert helper missing. Skipping DB write.")

    total = len(results)
    page = _paginate(results, inp.offset, inp.limit)
    return page, total, institution.__dict__
