"""Score a SearchResult's confidence based on source quality and data completeness."""
from app.models.domain import SearchResult

_SOURCE_WEIGHTS: dict[str, float] = {
    "wikidata": 0.80,
    "wikipedia": 0.75,
    "sec_filing": 0.90,
    "company_site": 0.70,
    "public_web": 0.50,
}

_MAX_COMPLETENESS_BONUS = 0.20


def _completeness_bonus(r: SearchResult) -> float:
    """Award up to 0.20 for data completeness."""
    score = 0.0
    if r.employment and r.employment.title:
        score += 0.05
    if r.employment and r.employment.company and r.employment.company.name not in ("", "Unknown"):
        score += 0.05
    if r.person.wikidata_id:
        score += 0.05
    if r.source_url:
        score += 0.05
    return min(score, _MAX_COMPLETENESS_BONUS)


def score(r: SearchResult) -> float:
    """Return a confidence score in [0, 1]."""
    base = _SOURCE_WEIGHTS.get(r.source_type or "public_web", 0.50)
    return min(1.0, base + _completeness_bonus(r))
