"""Score the confidence of a SearchResult based on source quality."""
from app.models.domain import SearchResult

WEIGHTS: dict[str, float] = {
    "sec_filing": 0.35,
    "wikidata": 0.25,
    "wikipedia": 0.20,
    "company_site": 0.20,
    "university_page": 0.15,
}


def score(result: SearchResult) -> SearchResult:
    base = 0.4
    base += WEIGHTS.get(result.person.source_type, 0.0)
    if result.employment:
        base += 0.1
    if result.institution:
        base += 0.1
    result.person.confidence = round(min(max(base, 0.0), 1.0), 3)
    return result
