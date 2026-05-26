"""Wikidata adapter — uses Entity Search API + SPARQL for alumni."""
from __future__ import annotations

import time
import httpx
from typing import Any

from app.models.domain import Institution, Person, Company, Employment, SearchResult
from app.utils.sanitize import sanitize_search_name
from app.utils.logger import get_logger

log = get_logger(__name__)

ENTITY_SEARCH_URL = "https://www.wikidata.org/w/api.php"
SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"
HEADERS = {
    "User-Agent": "AlumniMap/1.0 (https://github.com/your-org/alumnimap; alumnimap@example.org)",
    "Accept": "application/sparql-results+json",
}
_LAST_SPARQL_CALL: float = 0.0
_SPARQL_MIN_INTERVAL = 1.5  # seconds — Wikidata fair-use


def _throttle() -> None:
    global _LAST_SPARQL_CALL
    elapsed = time.monotonic() - _LAST_SPARQL_CALL
    if elapsed < _SPARQL_MIN_INTERVAL:
        time.sleep(_SPARQL_MIN_INTERVAL - elapsed)
    _LAST_SPARQL_CALL = time.monotonic()


# ── Institution resolution ──────────────────────────────────────────────────

def resolve_institution(name: str) -> Institution | None:
    """Resolve a university name to an Institution using the Wikidata Entity Search API."""
    safe_name = sanitize_search_name(name)
    if not safe_name:
        return None

    params = {
        "action": "wbsearchentities",
        "search": safe_name,
        "language": "en",
        "type": "item",
        "limit": 5,
        "format": "json",
    }
    try:
        r = httpx.get(ENTITY_SEARCH_URL, params=params, headers=HEADERS, timeout=10)
        r.raise_for_status()
        data = r.json()
    except Exception as exc:
        log.warning("Wikidata entity search failed: %s", exc)
        return None

    for item in data.get("search", []):
        desc = item.get("description", "").lower()
        label = item.get("label", "")
        if any(kw in desc for kw in ("university", "college", "institute", "school")):
            return Institution(
                wikidata_id=item["id"],
                name=label,
                source_url=f"https://www.wikidata.org/wiki/{item['id']}",
            )

    # Fallback: accept the first result if the label fuzzy-matches
    for item in data.get("search", []):
        if safe_name.lower() in item.get("label", "").lower():
            return Institution(
                wikidata_id=item["id"],
                name=item["label"],
                source_url=f"https://www.wikidata.org/wiki/{item['id']}",
            )
    return None


# ── Alumni SPARQL query ─────────────────────────────────────────────────────

_ALUMNI_QUERY = """\
SELECT DISTINCT ?person ?personLabel ?employer ?employerLabel ?title ?titleLabel WHERE {{
  ?person wdt:P69 wd:{qid} ;
          wdt:P108 ?employer .
  OPTIONAL {{
    ?person p:P108 ?empStmt .
    ?empStmt ps:P108 ?employer .
    ?empStmt pq:P794 ?title .
  }}
  OPTIONAL {{ ?person wdt:P106 ?title . }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en,*" . }}
}}
LIMIT {limit}
"""


def fetch_alumni(
    institution_qid: str,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Return raw Wikidata rows for alumni of the given institution QID."""
    _throttle()
    query = _ALUMNI_QUERY.format(qid=institution_qid, limit=limit)
    try:
        r = httpx.get(
            SPARQL_ENDPOINT,
            params={"query": query, "format": "json"},
            headers=HEADERS,
            timeout=30,
        )
        r.raise_for_status()
        return r.json().get("results", {}).get("bindings", [])
    except Exception as exc:
        log.warning("Wikidata SPARQL failed for %s: %s", institution_qid, exc)
        return []


# ── Row → domain model ──────────────────────────────────────────────────────

def _row_to_search_result(row: dict[str, Any], institution: Institution) -> SearchResult | None:
    person_uri = row.get("person", {}).get("value", "")
    person_label = row.get("personLabel", {}).get("value", "")
    employer_label = row.get("employerLabel", {}).get("value", "")
    title_label = row.get("titleLabel", {}).get("value", "")

    if not person_label or person_label.startswith("Q"):
        return None

    qid = person_uri.rsplit("/", 1)[-1] if person_uri else ""
    person = Person(
        full_name=person_label,
        wikidata_id=qid,
        source_url=person_uri or f"https://www.wikidata.org/wiki/{qid}",
    )
    employment = Employment(
        company=Company(name=employer_label or "Unknown"),
        title=title_label or "",
        is_current=True,
    )
    return SearchResult(
        person=person,
        institution=institution,
        employment=employment,
        source_url=person_uri,
        source_type="wikidata",
    )


def build_search_results(
    rows: list[dict[str, Any]], institution: Institution
) -> list[SearchResult]:
    """Convert raw SPARQL rows to deduplicated SearchResult objects."""
    seen: set[str] = set()
    results: list[SearchResult] = []
    for row in rows:
        sr = _row_to_search_result(row, institution)
        if sr is None:
            continue
        key = sr.person.wikidata_id or sr.person.full_name
        if key in seen:
            continue
        seen.add(key)
        results.append(sr)
    return results
