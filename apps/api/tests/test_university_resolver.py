"""Tests for the university resolver service."""
from unittest.mock import AsyncMock, patch

import pytest

from app.models.domain import Institution
from app.services.university_resolver import _expand_abbreviations, _normalize_name, resolve

_INST = Institution(id="Q1", name="University of North Carolina at Chapel Hill", slug="unc", wikidata_id="Q192760")


def test_expand_unc_abbreviation():
    assert "university of north carolina" in _expand_abbreviations("unc").lower()


def test_expand_mit_abbreviation():
    assert "massachusetts institute of technology" in _expand_abbreviations("MIT").lower()


def test_normalize_strips_punctuation():
    result = _normalize_name("UNC!!!")
    assert "!" not in result


def test_normalize_collapses_whitespace():
    result = _normalize_name("  University  of   NC  ")
    assert "  " not in result


@pytest.mark.asyncio
async def test_resolve_returns_institution():
    with patch("app.services.university_resolver.wikidata.resolve_institution", new=AsyncMock(return_value=_INST)):
        result = await resolve("UNC")
    assert result is not None
    assert result.wikidata_id == "Q192760"


@pytest.mark.asyncio
async def test_resolve_falls_back_to_original_name():
    async def mock_resolve(name):
        if "university of north carolina" in name.lower():
            return None  # expanded name fails
        return _INST  # original name succeeds

    with patch("app.services.university_resolver.wikidata.resolve_institution", side_effect=mock_resolve):
        result = await resolve("UNC")
    # Should try fallback and succeed
    assert result is not None


@pytest.mark.asyncio
async def test_resolve_returns_none_when_both_fail():
    with patch("app.services.university_resolver.wikidata.resolve_institution", new=AsyncMock(return_value=None)):
        result = await resolve("NotARealUniversityXyz999")
    assert result is None
