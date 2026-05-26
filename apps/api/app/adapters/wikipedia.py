"""Wikipedia REST API for short bios. Free, no key."""
import httpx

from app.config import settings
from app.utils import cache
from app.utils.robots import is_allowed

WIKIPEDIA_API = "https://en.wikipedia.org/api/rest_v1/page/summary"


async def fetch_summary(title: str) -> dict | None:
    """Fetch a Wikipedia article summary by article title (not Wikidata QID)."""
    cached = cache.get("wiki:" + title)
    if cached:
        return cached

    url = f"{WIKIPEDIA_API}/{title}"
    if not await is_allowed(url):
        return None

    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent}, timeout=10.0
        ) as client:
            r = await client.get(url)
            if r.status_code != 200:
                return None
            data = r.json()
            cache.put("wiki:" + title, data)
            return data
    except Exception:
        return None


async def resolve_title_from_qid(qid: str) -> str | None:
    """Given a Wikidata QID, return the corresponding English Wikipedia article title."""
    url = f"https://www.wikidata.org/wiki/Special:EntityData/{qid}.json"
    cached = cache.get("qid_title:" + qid)
    if cached:
        return cached.get("title")

    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent}, timeout=10.0
        ) as client:
            r = await client.get(url)
            if r.status_code != 200:
                return None
            data = r.json()
            entities = data.get("entities", {})
            entity = entities.get(qid, {})
            sitelinks = entity.get("sitelinks", {})
            enwiki = sitelinks.get("enwiki", {})
            title = enwiki.get("title")
            if title:
                cache.put("qid_title:" + qid, {"title": title})
            return title
    except Exception:
        return None
