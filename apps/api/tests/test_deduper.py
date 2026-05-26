from datetime import datetime, timezone

from app.models.domain import Person, SearchResult
from app.services.deduper import dedupe


def _make(name: str, conf: float) -> SearchResult:
    return SearchResult(
        person=Person(
            id=name,
            full_name=name,
            source_url="https://example.org",
            source_type="wikidata",
            retrieved_at=datetime.now(timezone.utc),
            confidence=conf,
        )
    )


def test_keeps_highest_confidence():
    out = dedupe([_make("Jane Smith", 0.3), _make("Jane Smith", 0.8)])
    assert len(out) == 1
    assert out[0].person.confidence == 0.8


def test_keeps_distinct():
    out = dedupe([_make("Jane Smith", 0.5), _make("John Doe", 0.5)])
    assert len(out) == 2
