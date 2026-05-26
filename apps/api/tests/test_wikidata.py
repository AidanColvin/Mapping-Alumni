"""Tests for the Wikidata adapter with mocked HTTP."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.adapters.wikidata import _q_alumni_for, _q_resolve_institution, fetch_alumni, resolve_institution
from app.models.domain import Institution

_MOCK_INSTITUTION_BINDINGS = [
    {
        "university": {"value": "https://www.wikidata.org/entity/Q192760"},
        "universityLabel": {"value": "University of North Carolina at Chapel Hill"},
        "countryLabel": {"value": "United States of America"},
    }
]

_MOCK_ALUMNI_BINDINGS = [
    {
        "person": {"value": "https://www.wikidata.org/entity/Q76"},
        "personLabel": {"value": "Barack Obama"},
        "employerLabel": {"value": "United States federal government"},
        "occupationLabel": {"value": "politician"},
    },
    {
        "person": {"value": "https://www.wikidata.org/entity/Q77"},
        "personLabel": {"value": "Q77"},  # no label — should be skipped
    },
]


def test_q_resolve_institution_escapes_quotes():
    q = _q_resolve_institution('Test "University"')
    assert '\\"University\\"' in q


def test_q_alumni_for_contains_qid():
    q = _q_alumni_for("Q192760")
    assert "Q192760" in q


@pytest.mark.asyncio
async def test_resolve_institution_returns_institution():
    with patch("app.adapters.wikidata._run_sparql", new=AsyncMock(return_value=_MOCK_INSTITUTION_BINDINGS)):
        result = await resolve_institution("University of North Carolina")
    assert result is not None
    assert result.wikidata_id == "Q192760"
    assert "north carolina" in result.name.lower()


@pytest.mark.asyncio
async def test_resolve_institution_returns_none_when_empty():
    with patch("app.adapters.wikidata._run_sparql", new=AsyncMock(return_value=[])):
        result = await resolve_institution("NotAUniversity XYZ")
    assert result is None


@pytest.mark.asyncio
async def test_fetch_alumni_skips_qid_labels():
    inst = Institution(id="Q192760", name="UNC", slug="unc", wikidata_id="Q192760")
    with patch("app.adapters.wikidata._run_sparql", new=AsyncMock(return_value=_MOCK_ALUMNI_BINDINGS)):
        results = await fetch_alumni(inst)
    names = [r.person.full_name for r in results]
    assert "Barack Obama" in names
    assert "Q77" not in names  # QID label should be skipped


@pytest.mark.asyncio
async def test_fetch_alumni_returns_empty_without_qid():
    inst = Institution(id="x", name="No QID U", slug="no-qid-u", wikidata_id=None)
    results = await fetch_alumni(inst)
    assert results == []
