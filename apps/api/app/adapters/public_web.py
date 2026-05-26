"""Robots-aware public web fetcher with file caching."""
import httpx

from app.config import settings
from app.utils import cache
from app.utils.logger import log
from app.utils.robots import is_allowed


async def fetch_text(url: str, timeout: float = 10.0) -> str | None:
    """Fetch a URL and return the body text, or None on failure."""
    cached = cache.get(url)
    if cached:
        return cached.get("body")

    if not await is_allowed(url):
        log("warn", "robots_blocked", url=url)
        return None

    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent},
            timeout=timeout,
            follow_redirects=True,
        ) as client:
            r = await client.get(url)
            if r.status_code != 200:
                return None
            cache.put(url, {"body": r.text, "status": r.status_code})
            return r.text
    except Exception as e:
        log("warn", "fetch_failed", url=url, error=str(e))
        return None
