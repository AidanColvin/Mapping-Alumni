"""Route-level integration tests using httpx + ASGI transport."""
import pytest
import httpx
from app.main import app


@pytest.mark.anyio
async def test_health():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/api/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.anyio
async def test_stats_returns_dict():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/api/stats")
    assert r.status_code == 200
    data = r.json()
    assert "institutions" in data
    assert "people" in data


@pytest.mark.anyio
async def test_search_missing_university_returns_422_or_404():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/api/search", params={"university": ""})
    assert r.status_code in (422, 404)
