"""HTTP-level route tests via ASGI test client."""
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models.domain import Company, Employment, Institution, Person, SearchResult

_INST = Institution(id="Q1", name="Test U", slug="test-u", wikidata_id="Q1")
_PERSON = Person(
    id="P1",
    full_name="Jane Doe",
    source_url="https://www.wikidata.org/wiki/Q1",
    source_type="wikidata",
    retrieved_at=datetime.now(timezone.utc),
    confidence=0.75,
)
_RESULT = SearchResult(
    person=_PERSON,
    employment=[
        Employment(
            company=Company(id="c1", name="Google", slug="google", sector="technology"),
            title="engineer",
            title_level="individual",
            sector="technology",
            is_current=True,
        )
    ],
    institution=_INST,
)


@pytest.fixture
def client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


@pytest.mark.asyncio
async def test_health(client):
    r = await client.get("/api/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_search_returns_404_when_not_found(client):
    with patch(
        "app.routes.search.run",
        new=AsyncMock(return_value=([], 0, None)),
    ):
        r = await client.get("/api/search?university=nonexistent_university_xyz")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_search_returns_results(client):
    with patch(
        "app.routes.search.run",
        new=AsyncMock(return_value=([_RESULT], 1, _INST.model_dump())),
    ):
        r = await client.get("/api/search?university=Test+U")
    assert r.status_code == 200
    data = r.json()
    assert data["total"] == 1
    assert data["results"][0]["person"]["full_name"] == "Jane Doe"


@pytest.mark.asyncio
async def test_search_validates_short_query(client):
    r = await client.get("/api/search?university=X")
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_sources_endpoint(client):
    r = await client.get("/api/sources")
    assert r.status_code == 200
    assert "allowed_domains" in r.json()


@pytest.mark.asyncio
async def test_stats_endpoint(client):
    r = await client.get("/api/stats")
    assert r.status_code == 200
    body = r.json()
    assert "institutions" in body
    assert "people" in body
    assert "cached_pages" in body


@pytest.mark.asyncio
async def test_sectors_endpoint(client):
    r = await client.get("/api/companies/sectors")
    assert r.status_code == 200
    assert "technology" in r.json()
