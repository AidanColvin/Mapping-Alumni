"""SEC EDGAR full-text search adapter. Free, public.

EDGAR fair-use requires User-Agent in format: "Name email@example.com"
Ref: https://www.sec.gov/os/accessing-edgar-data
"""
import httpx

from app.config import settings
from app.utils import cache

EDGAR_SEARCH = "https://efts.sec.gov/LATEST/search-index"


def _edgar_user_agent() -> str:
    """EDGAR requires 'Company Name admin@company.com' format."""
    ua = settings.user_agent
    # If already formatted correctly, return as-is
    if "@" in ua:
        return ua
    return f"{ua} alumnimap@example.org"


async def search_executives(name: str) -> list[dict]:
    """Search SEC EDGAR for proxy filings mentioning this person's name."""
    cache_key = "sec:" + name
    cached = cache.get(cache_key)
    if cached:
        return cached.get("hits", [])

    params = {"q": f'"{name}"', "forms": "DEF 14A", "dateRange": "custom", "startdt": "2015-01-01"}
    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": _edgar_user_agent()}, timeout=15.0
        ) as client:
            r = await client.get(EDGAR_SEARCH, params=params)
            if r.status_code != 200:
                return []
            hits = r.json().get("hits", {}).get("hits", [])
            cache.put(cache_key, {"hits": hits})
            return hits
    except Exception:
        return []
