"""Wikidata adapter. Uses Entity Search API for lookup, SPARQL for alumni.

Both endpoints are free and designed for programmatic use.
We send a descriptive User-Agent per Wikimedia guidelines.
"""
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

import httpx

from app.config import settings
from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.utils import cache
from app.utils.logger import log
from app.utils.sanitize import sanitize_search_name
from app.utils.slugify import slugify

SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"
ENTITY_SEARCH_API = "https://www.wikidata.org/w/api.php"

# Wikidata types that represent educational institutions
_INSTITUTION_TYPES = {"Q38723", "Q3918", "Q875538", "Q1371037", "Q23002054"}


def _q_alumni_for(wikidata_qid: str) -> str:
    # P69 = educated at, P108 = employer, P106 = occupation
    return f"""
    SELECT DISTINCT ?person ?personLabel ?employer ?employerLabel ?occupation ?occupationLabel WHERE {{
      ?person wdt:P69 wd:{wikidata_qid}.
      OPTIONAL {{ ?person wdt:P108 ?employer. }}
      OPTIONAL {{ ?person wdt:P106 ?occupation. }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    LIMIT 500
    """


async def _entity_search(name: str) -> Institution | None:
    """Use the Wikidata wbsearchentities API to find an institution by name."""
    safe_name = sanitize_search_name(name)
    cache_key = f"entity_search:{safe_name}"
    cached = cache.get(cache_key)
    if cached and cached.get("hit"):
        return Institution(**cached["institution"])

    params = {
        "action": "wbsearchentities",
        "search": safe_name,
        "language": "en",
        "type": "item",
        "limit": 10,
        "format": "json",
    }
    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent}, timeout=15.0
        ) as client:
            r = await client.get(ENTITY_SEARCH_API, params=params)
            if r.status_code != 200:
                log("warn", "entity_search_failed", status=r.status_code)
                return None
            results = r.json().get("search", [])
    except Exception as e:
        log("error", "entity_search_exception", error=str(e))
        return None

    # Find the first result that is an instance of a known institution type
    for item in results:
        qid = item.get("id", "")
        label = item.get("label", "")
        desc = item.get("description", "").lower()
        # Accept if description mentions university/college/institution
        if any(kw in desc for kw in ("university", "college", "institute", "school", "académie", "académique")):
            institution = Institution(
                id=qid,
                name=label,
                slug=slugify(label),
                aliases=[a.get("value", "") for a in item.get("aliases", {}).get("en", [])],
                country=None,
                wikidata_id=qid,
            )
            cache.put(cache_key, {"hit": True, "institution": institution.model_dump()})
            return institution

    # Fallback: accept the first result if description contains education keywords
    for item in results:
        qid = item.get("id", "")
        label = item.get("label", "")
        desc = item.get("description", "").lower()
        if any(kw in desc for kw in ("public", "private", "research", "liberal arts", "engineering")):
            institution = Institution(
                id=qid,
                name=label,
                slug=slugify(label),
                aliases=[],
                country=None,
                wikidata_id=qid,
            )
            cache.put(cache_key, {"hit": True, "institution": institution.model_dump()})
            return institution

    cache.put(cache_key, {"hit": False})
    return None


async def _run_sparql(query: str) -> list[dict[str, Any]]:
    cache_key = "sparql:" + query
    cached = cache.get(cache_key)
    if cached:
        return cached.get("bindings", [])

    try:
        async with httpx.AsyncClient(
            headers={
                "User-Agent": settings.user_agent,
                "Accept": "application/sparql-results+json",
            },
            timeout=45.0,
        ) as client:
            r = await client.get(SPARQL_ENDPOINT, params={"query": query, "format": "json"})
            if r.status_code == 429:
                log("warn", "sparql_rate_limited")
                return []
            if r.status_code != 200:
                log("warn", "sparql_failed", status=r.status_code)
                return []
            bindings = r.json().get("results", {}).get("bindings", [])
            cache.put(cache_key, {"bindings": bindings})
            return bindings
    except Exception as e:
        log("error", "sparql_exception", error=str(e))
        return []


async def resolve_institution(name: str) -> Institution | None:
    """Find the canonical Wikidata institution for a free-text name.
    Uses entity search API (faster, separate rate limit from SPARQL).
    """
    return await _entity_search(name)


async def fetch_alumni(institution: Institution) -> list[SearchResult]:
    """Return alumni records for a resolved institution via SPARQL."""
    if not institution.wikidata_id:
        return []
    bindings = await _run_sparql(_q_alumni_for(institution.wikidata_id))

    # Group by person URL: each person gets one record with first employer + occupation
    person_map: dict[str, dict] = {}
    for b in bindings:
        person_url = b.get("person", {}).get("value", "")
        if not person_url:
            continue
        name = b.get("personLabel", {}).get("value", "Unknown")
        if name.startswith("Q") and name[1:].isdigit():
            continue  # label fallback to QID = no English label

        if person_url not in person_map:
            person_map[person_url] = {"name": name, "employer": None, "occupation": None}

        if not person_map[person_url]["employer"]:
            employer = b.get("employerLabel", {}).get("value")
            if employer:
                person_map[person_url]["employer"] = employer

        if not person_map[person_url]["occupation"]:
            occupation = b.get("occupationLabel", {}).get("value")
            if occupation:
                person_map[person_url]["occupation"] = occupation

    results: list[SearchResult] = []
    for person_url, data in person_map.items():
        employment: list[Employment] = []
        if data["employer"]:
            employment.append(
                Employment(
                    company=Company(
                        id=str(uuid4()),
                        name=data["employer"],
                        slug=slugify(data["employer"]),
                    ),
                    title=data["occupation"] or "",
                    is_current=True,
                )
            )

        results.append(
            SearchResult(
                person=Person(
                    id=person_url.rsplit("/", 1)[-1],
                    full_name=data["name"],
                    source_url=person_url,
                    source_type="wikidata",
                    retrieved_at=datetime.now(timezone.utc),
                    confidence=0.6,
                    verified_fields=["full_name", "education"],
                ),
                employment=employment,
                institution=institution,
            )
        )

    return results
