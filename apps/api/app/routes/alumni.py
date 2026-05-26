"""Individual alumni detail route."""
import httpx
from fastapi import APIRouter, HTTPException

from app.utils.logger import get_logger

router = APIRouter()
log = get_logger(__name__)

_WIKIDATA_SITELINKS = "https://www.wikidata.org/w/api.php"
_WP_SUMMARY = "https://en.wikipedia.org/api/rest_v1/page/summary/{title}"
_HEADERS = {"User-Agent": "AlumniMap/1.0 (alumnimap@example.org)"}


def _get_wikipedia_title(qid: str) -> str | None:
    """Resolve a Wikidata QID to an English Wikipedia page title."""
    params = {
        "action": "wbgetentities",
        "ids": qid,
        "props": "sitelinks",
        "sitefilter": "enwiki",
        "format": "json",
    }
    try:
        r = httpx.get(_WIKIDATA_SITELINKS, params=params, headers=_HEADERS, timeout=10)
        r.raise_for_status()
        data = r.json()
        sitelinks = data.get("entities", {}).get(qid, {}).get("sitelinks", {})
        return sitelinks.get("enwiki", {}).get("title")
    except Exception as exc:
        log.warning("Sitelink lookup failed for %s: %s", qid, exc)
        return None


@router.get("/alumni/{wikidata_qid}")
async def get_alumnus(wikidata_qid: str) -> dict:
    wp_title = _get_wikipedia_title(wikidata_qid)
    if not wp_title:
        raise HTTPException(status_code=404, detail=f"No Wikipedia page for {wikidata_qid}")

    try:
        r = httpx.get(
            _WP_SUMMARY.format(title=wp_title),
            headers=_HEADERS,
            timeout=10,
        )
        if r.status_code == 404:
            raise HTTPException(status_code=404, detail=f"Wikipedia page not found: {wp_title}")
        r.raise_for_status()
        data = r.json()
    except HTTPException:
        raise
    except Exception as exc:
        log.warning("Wikipedia summary fetch failed: %s", exc)
        raise HTTPException(status_code=502, detail="Wikipedia lookup failed") from exc

    return {
        "wikidata_id": wikidata_qid,
        "name": data.get("title"),
        "summary": data.get("extract"),
        "thumbnail": data.get("thumbnail", {}).get("source"),
        "wikipedia_url": data.get("content_urls", {}).get("desktop", {}).get("page"),
        "wikidata_url": f"https://www.wikidata.org/wiki/{wikidata_qid}",
    }
