from datetime import datetime, timezone

from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.services.confidence_scorer import score


def _make(source_type: str, with_employment: bool, with_institution: bool) -> SearchResult:
    return SearchResult(
        person=Person(
            id="1",
            full_name="X",
            source_url="https://x",
            source_type=source_type,
            retrieved_at=datetime.now(timezone.utc),
            confidence=0.0,
        ),
        employment=(
            [Employment(company=Company(id="c", name="C", slug="c"))] if with_employment else []
        ),
        institution=Institution(id="u", name="U", slug="u") if with_institution else None,
    )


def test_sec_filing_scores_highest():
    sec = score(_make("sec_filing", True, True))
    wiki = score(_make("wikidata", True, True))
    assert sec.person.confidence > wiki.person.confidence


def test_clamps_to_one():
    r = score(_make("sec_filing", True, True))
    assert r.person.confidence <= 1.0
