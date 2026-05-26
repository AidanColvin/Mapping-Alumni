"""Integration tests for the alumni search pipeline (mocked adapters)."""
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest

from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.services.alumni_search import _apply_filters, run
from app.validators.search_input import SearchInput

_INST = Institution(id="Q1", name="Test U", slug="test-u", wikidata_id="Q1")


def _make(name: str, employer: str | None = None, sector: str = "other", level: str = "individual") -> SearchResult:
    emp = []
    if employer:
        emp.append(
            Employment(
                company=Company(id="c1", name=employer, slug="e"),
                title="analyst",
                title_level=level,
                sector=sector,
                is_current=True,
            )
        )
    return SearchResult(
        person=Person(
            id=name,
            full_name=name,
            source_url="https://x",
            source_type="wikidata",
            retrieved_at=datetime.now(timezone.utc),
            confidence=0.6,
        ),
        employment=emp,
        institution=_INST,
    )


class FakeInput(SearchInput):
    model_config = {"arbitrary_types_allowed": True}


def _q(**kwargs) -> SearchInput:
    return SearchInput(university="Test U", **kwargs)


def test_apply_filters_sector():
    results = [
        _make("A", "Google", sector="technology"),
        _make("B", "Bank", sector="finance"),
    ]
    out = _apply_filters(results, _q(sector="technology"))
    assert len(out) == 1
    assert out[0].person.full_name == "A"


def test_apply_filters_title_level():
    results = [
        _make("CEO Person", "Acme", level="c_suite"),
        _make("Analyst", "Acme", level="individual"),
    ]
    out = _apply_filters(results, _q(title_level="c_suite"))
    assert len(out) == 1


def test_apply_filters_keyword_name():
    results = [_make("Alice Smith", "Corp"), _make("Bob Jones", "Corp")]
    out = _apply_filters(results, _q(keyword="alice"))
    assert len(out) == 1


def test_apply_filters_keyword_employer():
    results = [_make("Alice", "Google"), _make("Bob", "Microsoft")]
    out = _apply_filters(results, _q(keyword="google"))
    assert len(out) == 1


def test_apply_filters_no_filters():
    results = [_make("A"), _make("B")]
    out = _apply_filters(results, _q())
    assert len(out) == 2


@pytest.mark.asyncio
async def test_run_returns_empty_when_institution_not_found():
    with patch("app.services.alumni_search.university_resolver.resolve", new=AsyncMock(return_value=None)):
        results, total, inst = await run(_q())
    assert results == []
    assert total == 0
    assert inst is None


@pytest.mark.asyncio
async def test_run_full_pipeline_mocked():
    raw = [_make("Jane Doe", "Apple"), _make("Jane Doe", "Apple")]  # duplicate
    with (
        patch("app.services.alumni_search.university_resolver.resolve", new=AsyncMock(return_value=_INST)),
        patch("app.services.alumni_search.wikidata.fetch_alumni", new=AsyncMock(return_value=raw)),
        patch("app.services.alumni_search._persist"),
    ):
        results, total, inst = await run(_q())
    # Deduplication should reduce to 1
    assert total == 1
    assert inst is not None
