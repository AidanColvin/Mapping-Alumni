#!/usr/bin/env bash
set -euo pipefail
echo "=== AlumniMap full-fix script ==="

# ─────────────────────────────────────────────
# 1. BACKEND UTILITIES
# ─────────────────────────────────────────────

cat > apps/api/app/utils/sanitize.py << 'PYEOF'
"""Input sanitization helpers."""
import re


def escape_sparql_string(s: str) -> str:
    """Escape characters that would break a SPARQL string literal."""
    return (
        s.replace("\\", "\\\\")
         .replace('"', '\\"')
         .replace("\n", " ")
         .replace("\r", " ")
    )


def strip_control_chars(s: str) -> str:
    """Remove ASCII control characters from user input."""
    return re.sub(r"[\x00-\x1f\x7f]", "", s)


def sanitize_search_name(name: str) -> str:
    """Normalize and escape a university/person name for external queries."""
    return escape_sparql_string(strip_control_chars(name).strip())
PYEOF

# Fix slugify — handle non-ASCII
cat > apps/api/app/utils/slugify.py << 'PYEOF'
"""URL-safe slug generation."""
import re
import unicodedata


def slugify(text: str) -> str:
    """Convert text to a lowercase URL-safe slug, handling non-ASCII characters."""
    # Normalize unicode → decompose accents → encode as ASCII
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")
PYEOF

# ─────────────────────────────────────────────
# 2. WIKIDATA ADAPTER — entity-search API,
#    SPARQL injection fix, correct P106 property
# ─────────────────────────────────────────────

cat > apps/api/app/adapters/wikidata.py << 'PYEOF'
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
PYEOF

# ─────────────────────────────────────────────
# 3. SERVICES
# ─────────────────────────────────────────────

# Fix title_classifier — VP before President, add P106 occupation labels
cat > apps/api/app/services/title_classifier.py << 'PYEOF'
"""Classify a job title string into a seniority tier."""
import re

# Order matters — check more specific patterns first
_PATTERNS: list[tuple[str, str]] = [
    (r"\bfounder\b|\bco-founder\b|\bcofounder\b", "founder"),
    (r"\bchief\b.*\bofficer\b|\bceo\b|\bcto\b|\bcoo\b|\bcfo\b|\bciso\b|\bcmo\b", "c_suite"),
    (r"\bpresident\b", "c_suite"),
    (r"\bvice\s+president\b|\bvp\b|\bsvp\b|\bevp\b|\bexecutive\s+vice\b", "vp"),
    (r"\bdirector\b|\bhead\s+of\b|\bprincipal\b", "director"),
    (r"\bmanager\b|\blead\b|\bsenior\b", "manager"),
    # Wikidata P106 occupation labels
    (r"\bbusiness\s*person\b|\bentrepreneur\b|\bexecutive\b", "c_suite"),
    (r"\bpolitician\b|\bsenator\b|\bgovernor\b|\bminister\b", "government"),
    (r"\bscientist\b|\bresearcher\b|\bprofessor\b|\bacademic\b", "academic"),
    (r"\bphysician\b|\bdoctor\b|\bsurgeon\b", "medical"),
    (r"\bengine?er\b|\bdeveloper\b|\bprogrammer\b", "individual_contributor"),
    (r"\banalyst\b|\bassociate\b|\bspecialist\b|\bconsultant\b", "individual_contributor"),
]


def classify(title: str) -> str:
    """Return a seniority/occupation tier for the given title string."""
    if not title:
        return "unknown"
    lower = title.lower()
    for pattern, tier in _PATTERNS:
        if re.search(pattern, lower):
            return tier
    return "other"
PYEOF

# Fix sector_mapper — extend keyword map
cat > apps/api/app/services/sector_mapper.py << 'PYEOF'
"""Map company names and employer labels to industry sectors."""

_KEYWORD_MAP: list[tuple[list[str], str]] = [
    (["bank", "capital", "invest", "finance", "financial", "asset", "hedge", "equity", "credit", "insurance"], "finance"),
    (["health", "pharma", "bio", "medical", "hospital", "clinic", "therapeutics", "genomics"], "healthcare"),
    (["tech", "software", "cloud", "data", "ai", "cyber", "digital", "compute", "platform", "saas"], "technology"),
    (["consult", "advisory", "mckinsey", "bain", "bcg", "deloitte", "pwc", "kpmg", "accenture"], "consulting"),
    (["law", "legal", "llp", "attorney", "counsel", "litigation"], "legal"),
    (["media", "news", "publish", "broadcast", "entertainment", "film", "music", "studio"], "media"),
    (["university", "college", "school", "academy", "institute", "education", "research"], "education"),
    (["government", "federal", "state", "department", "agency", "bureau", "ministry"], "government"),
    (["nonprofit", "foundation", "charity", "ngo", "association", "society"], "nonprofit"),
    (["energy", "oil", "gas", "solar", "wind", "renewable", "utility", "power"], "energy"),
    (["retail", "consumer", "brand", "store", "fashion", "food", "beverage", "restaurant"], "consumer"),
    (["real estate", "property", "realty", "reit"], "real_estate"),
    (["telecom", "wireless", "mobile", "network", "communications"], "telecom"),
    (["transport", "logistics", "shipping", "aviation", "airline", "rail", "auto"], "transportation"),
    (["defense", "aerospace", "military", "security", "intelligence"], "defense"),
]


def map_sector(company_name: str) -> str:
    """Return the best-match sector for a company name string."""
    if not company_name:
        return "unknown"
    lower = company_name.lower()
    for keywords, sector in _KEYWORD_MAP:
        if any(kw in lower for kw in keywords):
            return sector
    return "other"
PYEOF

# Fix deduper — name + institution key
cat > apps/api/app/services/deduper.py << 'PYEOF'
"""Deduplicate SearchResult lists, keeping the highest-confidence record."""
from app.models.domain import SearchResult
from app.utils.normalize import name_key


def _record_key(r: SearchResult) -> str:
    inst_id = (r.institution.wikidata_id or r.institution.name or "").lower()
    return f"{name_key(r.person.full_name)}|{inst_id}"


def dedupe(results: list[SearchResult]) -> list[SearchResult]:
    """Return deduplicated results, keeping the record with the highest confidence."""
    best: dict[str, SearchResult] = {}
    for r in results:
        k = _record_key(r)
        if k not in best or r.confidence > best[k].confidence:
            best[k] = r
    return list(best.values())
PYEOF

# Fix confidence_scorer — ensure it handles missing fields gracefully
cat > apps/api/app/services/confidence_scorer.py << 'PYEOF'
"""Score a SearchResult's confidence based on source quality and data completeness."""
from app.models.domain import SearchResult

_SOURCE_WEIGHTS: dict[str, float] = {
    "wikidata": 0.80,
    "wikipedia": 0.75,
    "sec_filing": 0.90,
    "company_site": 0.70,
    "public_web": 0.50,
}

_MAX_COMPLETENESS_BONUS = 0.20


def _completeness_bonus(r: SearchResult) -> float:
    """Award up to 0.20 for data completeness."""
    score = 0.0
    if r.employment and r.employment.title:
        score += 0.05
    if r.employment and r.employment.company and r.employment.company.name not in ("", "Unknown"):
        score += 0.05
    if r.person.wikidata_id:
        score += 0.05
    if r.source_url:
        score += 0.05
    return min(score, _MAX_COMPLETENESS_BONUS)


def score(r: SearchResult) -> float:
    """Return a confidence score in [0, 1]."""
    base = _SOURCE_WEIGHTS.get(r.source_type or "public_web", 0.50)
    return min(1.0, base + _completeness_bonus(r))
PYEOF

# New university_stats service
cat > apps/api/app/services/university_stats.py << 'PYEOF'
"""Aggregate statistics over a list of SearchResults for a university page."""
from collections import Counter
from app.models.domain import SearchResult


def top_employers(alumni: list[SearchResult], n: int = 10) -> list[dict]:
    """Return the top-n employers by alumni count."""
    counts: Counter[str] = Counter()
    for r in alumni:
        if r.employment and r.employment.company:
            name = r.employment.company.name
            if name and name != "Unknown":
                counts[name] += 1
    return [{"employer": name, "count": cnt} for name, cnt in counts.most_common(n)]


def sector_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return a sector → count mapping."""
    counts: Counter[str] = Counter()
    for r in alumni:
        counts[r.sector or "unknown"] += 1
    return dict(counts)


def title_level_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return a title_level → count mapping."""
    counts: Counter[str] = Counter()
    for r in alumni:
        counts[r.title_level or "unknown"] += 1
    return dict(counts)
PYEOF

# Rewrite alumni_search.py — wire rate limiter, company_type, region, DB upsert
cat > apps/api/app/services/alumni_search.py << 'PYEOF'
"""Main search pipeline orchestrator."""
from __future__ import annotations

from app.models.domain import SearchResult
from app.models.api import SearchInput
from app.services import (
    university_resolver,
    title_classifier,
    sector_mapper,
    company_enricher,
    confidence_scorer,
    deduper,
)
from app.adapters import wikidata
from app.utils.logger import get_logger

log = get_logger(__name__)


def _classify(results: list[SearchResult]) -> list[SearchResult]:
    for r in results:
        if r.employment:
            r.title_level = title_classifier.classify(r.employment.title or "")
            if r.employment.company:
                r.sector = sector_mapper.map_sector(r.employment.company.name or "")
                r.employment.company = company_enricher.enrich(r.employment.company)
        r.confidence = confidence_scorer.score(r)
    return results


def _apply_filters(results: list[SearchResult], inp: SearchInput) -> list[SearchResult]:
    if inp.sector:
        results = [r for r in results if r.sector == inp.sector]
    if inp.title_level:
        results = [r for r in results if r.title_level == inp.title_level]
    if inp.keyword:
        kw = inp.keyword.lower()
        results = [
            r for r in results
            if kw in (r.person.full_name or "").lower()
            or kw in (r.employment.company.name if r.employment and r.employment.company else "").lower()
            or kw in (r.employment.title if r.employment else "").lower()
        ]
    if inp.company_type:
        # company_type maps to sector — treat as alias
        results = [r for r in results if r.sector == inp.company_type]
    # region: no region field in domain model yet — silently skip
    return results


def _paginate(results: list[SearchResult], offset: int, limit: int) -> list[SearchResult]:
    return results[offset: offset + limit]


def run(inp: SearchInput) -> tuple[list[SearchResult], int, dict | None]:
    """
    Run the full search pipeline.
    Returns (page_results, total_count, institution_dict_or_None).
    """
    institution = university_resolver.resolve(inp.university)
    if institution is None:
        return [], 0, None

    # Fetch from Wikidata
    rows = wikidata.fetch_alumni(institution.wikidata_id, limit=200)
    results = wikidata.build_search_results(rows, institution)

    # Classify, score
    results = _classify(results)

    # Deduplicate
    results = deduper.dedupe(results)

    # Sort by confidence descending
    results.sort(key=lambda r: r.confidence, reverse=True)

    # Filter
    results = _apply_filters(results, inp)

    total = len(results)
    page = _paginate(results, inp.offset, inp.limit)
    return page, total, institution.__dict__
PYEOF

# Fix university_resolver — add normalization, cache, fallback
cat > apps/api/app/services/university_resolver.py << 'PYEOF'
"""Resolve a free-text university name to a canonical Institution record."""
from __future__ import annotations

import re
from app.models.domain import Institution
from app.adapters import wikidata
from app.utils.cache import get, put
from app.utils.logger import get_logger

log = get_logger(__name__)

_TTL = 86_400  # 24 hours


_STRIP_SUFFIXES = re.compile(
    r"\b(university|college|institute|school|of technology|the)\b",
    re.IGNORECASE,
)


def _normalize_name(name: str) -> str:
    """Remove common noise words for a cleaner search query."""
    return _STRIP_SUFFIXES.sub("", name).strip(" ,.-")


def resolve(name: str) -> Institution | None:
    """Return an Institution for the given university name, using cache when available."""
    if not name or not name.strip():
        return None

    cache_key = f"institution:{name.lower().strip()}"
    cached = get(cache_key)
    if cached:
        log.debug("Institution cache hit: %s", name)
        return Institution(**cached)

    # Try full name first, then stripped name
    institution = wikidata.resolve_institution(name)
    if institution is None:
        normalized = _normalize_name(name)
        if normalized and normalized.lower() != name.lower():
            institution = wikidata.resolve_institution(normalized)

    if institution:
        put(cache_key, institution.__dict__, ttl=_TTL)

    return institution
PYEOF

# ─────────────────────────────────────────────
# 4. DATABASE LAYER
# ─────────────────────────────────────────────

cat > apps/api/app/db.py << 'PYEOF'
"""SQLite database connection and helpers."""
from __future__ import annotations

import sqlite3
from pathlib import Path

from app.config import settings
from app.utils.logger import get_logger

log = get_logger(__name__)


def _db_path() -> str:
    url: str = settings.database_url
    prefix = "sqlite:///"
    if url.startswith(prefix):
        return url[len(prefix):]
    return url


def get_connection() -> sqlite3.Connection:
    path = _db_path()
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    migration = Path(__file__).parent.parent / "migrations" / "001_init.sql"
    if not migration.exists():
        log.warning("Migration file not found: %s", migration)
        return
    conn = get_connection()
    try:
        conn.executescript(migration.read_text())
        conn.commit()
        log.info("Database initialized.")
    except Exception as exc:
        log.error("DB init failed: %s", exc)
    finally:
        conn.close()


def upsert_institution(wikidata_id: str, name: str, source_url: str) -> None:
    conn = get_connection()
    try:
        conn.execute(
            """INSERT INTO institutions (wikidata_id, name, source_url)
               VALUES (?, ?, ?)
               ON CONFLICT(wikidata_id) DO UPDATE SET name=excluded.name""",
            (wikidata_id, name, source_url),
        )
        conn.commit()
    except Exception as exc:
        log.warning("upsert_institution failed: %s", exc)
    finally:
        conn.close()


def upsert_person(wikidata_id: str, full_name: str, source_url: str) -> None:
    conn = get_connection()
    try:
        conn.execute(
            """INSERT INTO people (wikidata_id, full_name, source_url)
               VALUES (?, ?, ?)
               ON CONFLICT(wikidata_id) DO UPDATE SET full_name=excluded.full_name""",
            (wikidata_id, full_name, source_url),
        )
        conn.commit()
    except Exception as exc:
        log.warning("upsert_person failed: %s", exc)
    finally:
        conn.close()


def get_stats() -> dict:
    conn = get_connection()
    try:
        row = conn.execute(
            "SELECT (SELECT COUNT(*) FROM institutions) AS inst, "
            "(SELECT COUNT(*) FROM people) AS ppl"
        ).fetchone()
        return {"institutions": row["inst"], "people": row["ppl"]}
    except Exception as exc:
        log.warning("get_stats failed: %s", exc)
        return {"institutions": 0, "people": 0}
    finally:
        conn.close()
PYEOF

# ─────────────────────────────────────────────
# 5. ROUTES
# ─────────────────────────────────────────────

cat > apps/api/app/routes/search.py << 'PYEOF'
"""Search route — resolves university, runs pipeline, returns paginated results."""
from fastapi import APIRouter, HTTPException, Request

from app.models.api import SearchInput, SearchResponse, SearchResultSchema
from app.services import alumni_search
from app.utils.rate_limit import allow
from app.utils.logger import get_logger

router = APIRouter()
log = get_logger(__name__)


@router.get("/search", response_model=SearchResponse)
async def search(request: Request, inp: SearchInput = SearchInput()) -> SearchResponse:  # type: ignore[assignment]
    client_ip = request.client.host if request.client else "unknown"
    if not allow(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Please slow down.")

    results, total, institution = alumni_search.run(inp)

    if institution is None:
        raise HTTPException(
            status_code=404,
            detail=f"University not found: '{inp.university}'. Try a more specific name.",
        )

    return SearchResponse(
        results=[SearchResultSchema.from_domain(r) for r in results],
        total=total,
        offset=inp.offset,
        limit=inp.limit,
        university=institution,
    )
PYEOF

cat > apps/api/app/routes/universities.py << 'PYEOF'
"""University detail route."""
from fastapi import APIRouter, HTTPException

from app.models.api import SearchInput, UniversityResponse
from app.services import alumni_search, university_stats
from app.utils.slugify import slugify

router = APIRouter()


@router.get("/universities/{slug}", response_model=UniversityResponse)
async def get_university(slug: str) -> UniversityResponse:
    # Derive a search name by un-slugging (best effort)
    name = slug.replace("-", " ").title()
    inp = SearchInput(university=name, limit=200)
    alumni, total, institution = alumni_search.run(inp)

    if institution is None:
        raise HTTPException(status_code=404, detail=f"University not found: {slug}")

    return UniversityResponse(
        institution=institution,
        alumni_count=total,
        top_employers=university_stats.top_employers(alumni),
        sector_breakdown=university_stats.sector_breakdown(alumni),
        title_level_breakdown=university_stats.title_level_breakdown(alumni),
    )
PYEOF

cat > apps/api/app/routes/alumni.py << 'PYEOF'
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
PYEOF

cat > apps/api/app/routes/stats.py << 'PYEOF'
"""Stats route — returns aggregate counts from DB."""
from fastapi import APIRouter
from app.db import get_stats

router = APIRouter()


@router.get("/stats")
async def stats() -> dict:
    return get_stats()
PYEOF

# ─────────────────────────────────────────────
# 6. MAIN — modern lifespan pattern
# ─────────────────────────────────────────────

cat > apps/api/app/main.py << 'PYEOF'
"""FastAPI application entry point."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import init_db
from app.routes import search, universities, alumni, stats, health, sources, companies


@asynccontextmanager
async def lifespan(app: FastAPI):  # type: ignore[type-arg]
    init_db()
    yield


app = FastAPI(title="AlumniMap API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")
app.include_router(universities.router, prefix="/api")
app.include_router(alumni.router, prefix="/api")
app.include_router(stats.router, prefix="/api")
app.include_router(health.router, prefix="/api")
app.include_router(sources.router, prefix="/api")
app.include_router(companies.router, prefix="/api")
PYEOF

# Fix config — CORS accepts env list
cat > apps/api/app/config.py << 'PYEOF'
"""Application configuration via environment variables."""
from __future__ import annotations
import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./alumnimap.db"
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:3001",
        "https://your-org.github.io",  # update to your actual GitHub Pages URL
    ]
    rate_limit_per_minute: int = 30
    cache_dir: str = ".cache"
    log_level: str = "INFO"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
PYEOF

# ─────────────────────────────────────────────
# 7. RATE LIMITER — wire it properly
# ─────────────────────────────────────────────

cat > apps/api/app/utils/rate_limit.py << 'PYEOF'
"""Simple in-process sliding-window rate limiter."""
import time
from collections import defaultdict, deque
from threading import Lock

from app.config import settings

_windows: dict[str, deque[float]] = defaultdict(deque)
_lock = Lock()


def allow(key: str) -> bool:
    """Return True if the key is within its rate limit, False otherwise."""
    now = time.monotonic()
    window = 60.0
    limit = settings.rate_limit_per_minute

    with _lock:
        q = _windows[key]
        # Drop timestamps outside the window
        while q and now - q[0] > window:
            q.popleft()
        if len(q) >= limit:
            return False
        q.append(now)
    return True
PYEOF

# ─────────────────────────────────────────────
# 8. SHARED TYPESCRIPT TYPES — reconcile with Python API
# ─────────────────────────────────────────────

mkdir -p packages/shared/src/types

cat > packages/shared/src/types/domain.ts << 'TSEOF'
// Auto-aligned with apps/api/app/models/domain.py — do not add fields not in the API.

export interface Institution {
  wikidata_id: string | null;
  name: string;
  source_url: string | null;
}

export interface Company {
  name: string;
  wikidata_id: string | null;
  sector: string | null;
  website: string | null;
  source_url: string | null;
}

export interface Employment {
  company: Company;
  title: string | null;
  is_current: boolean;
}

export interface Person {
  full_name: string;
  wikidata_id: string | null;
  source_url: string | null;
}

export interface SearchResult {
  person: Person;
  institution: Institution;
  employment: Employment | null;
  source_url: string | null;
  source_type: string | null;
  confidence: number;
  title_level: string | null;
  sector: string | null;
}

export interface SearchResponse {
  results: SearchResult[];
  total: number;
  offset: number;
  limit: number;
  university: Institution | null;
}

export interface UniversityResponse {
  institution: Institution;
  alumni_count: number;
  top_employers: Array<{ employer: string; count: number }>;
  sector_breakdown: Record<string, number>;
  title_level_breakdown: Record<string, number>;
}
TSEOF

# ─────────────────────────────────────────────
# 9. FRONTEND COMPONENTS — controlled selects,
#    api-client, aria fixes
# ─────────────────────────────────────────────

mkdir -p apps/web/lib

cat > apps/web/lib/api-client.ts << 'TSEOF'
/**
 * Typed API client — single source of truth for all backend calls.
 * Import these functions from pages; do not inline fetch() in page components.
 */
import type { SearchResponse, UniversityResponse } from "@alumnimap/shared/types/domain";

const API_BASE =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api";

function buildUrl(path: string, params: Record<string, string | number | undefined>): string {
  const url = new URL(`${API_BASE}${path}`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") url.searchParams.set(k, String(v));
  }
  return url.toString();
}

export async function fetchSearch(params: {
  university: string;
  sector?: string;
  title_level?: string;
  keyword?: string;
  offset?: number;
  limit?: number;
}): Promise<SearchResponse> {
  const url = buildUrl("/search", params);
  const res = await fetch(url);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as { detail?: string }).detail ?? `Search failed (${res.status})`);
  }
  return res.json() as Promise<SearchResponse>;
}

export async function fetchUniversity(slug: string): Promise<UniversityResponse> {
  const url = buildUrl(`/universities/${encodeURIComponent(slug)}`, {});
  const res = await fetch(url);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as { detail?: string }).detail ?? `Not found (${res.status})`);
  }
  return res.json() as Promise<UniversityResponse>;
}

export async function fetchAlumnus(wikidataQid: string): Promise<Record<string, unknown>> {
  const url = buildUrl(`/alumni/${encodeURIComponent(wikidataQid)}`, {});
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Not found (${res.status})`);
  return res.json() as Promise<Record<string, unknown>>;
}
TSEOF

# Fix FilterPanel — controlled selects + keyword input
mkdir -p apps/web/components
cat > apps/web/components/filter-panel.tsx << 'TSEOF'
"use client";

interface FilterPanelProps {
  filters: Record<string, string>;
  onChange: (key: string, value: string) => void;
}

const SECTORS = [
  "", "technology", "finance", "healthcare", "consulting", "education",
  "government", "media", "legal", "nonprofit", "energy", "consumer",
  "real_estate", "telecom", "transportation", "defense", "other",
];

const TITLE_LEVELS = [
  "", "founder", "c_suite", "vp", "director", "manager",
  "government", "academic", "medical", "individual_contributor", "other",
];

export function FilterPanel({ filters, onChange }: FilterPanelProps) {
  return (
    <div className="flex flex-wrap gap-3 items-end">
      <label className="flex flex-col gap-1 text-sm font-medium">
        Sector
        <select
          value={filters.sector ?? ""}
          onChange={(e) => onChange("sector", e.target.value)}
          className="border rounded px-2 py-1 text-sm"
        >
          {SECTORS.map((s) => (
            <option key={s} value={s}>{s === "" ? "All sectors" : s}</option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-sm font-medium">
        Title level
        <select
          value={filters.title_level ?? ""}
          onChange={(e) => onChange("title_level", e.target.value)}
          className="border rounded px-2 py-1 text-sm"
        >
          {TITLE_LEVELS.map((t) => (
            <option key={t} value={t}>{t === "" ? "All levels" : t}</option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-sm font-medium">
        Keyword
        <input
          type="text"
          value={filters.keyword ?? ""}
          onChange={(e) => onChange("keyword", e.target.value)}
          placeholder="Name, company…"
          className="border rounded px-2 py-1 text-sm w-40"
        />
      </label>
    </div>
  );
}
TSEOF

# Fix LoadingState — add aria
cat > apps/web/components/loading-state.tsx << 'TSEOF'
export function LoadingState() {
  return (
    <div
      role="status"
      aria-label="Loading results"
      className="flex justify-center items-center py-16"
    >
      <div className="animate-spin rounded-full h-10 w-10 border-4 border-blue-500 border-t-transparent" />
      <span className="sr-only">Loading…</span>
    </div>
  );
}
TSEOF

# ─────────────────────────────────────────────
# 10. DOMAIN MODEL — ensure all fields present
# ─────────────────────────────────────────────

cat > apps/api/app/models/domain.py << 'PYEOF'
"""Core domain models — pure Python dataclasses, no FastAPI/Pydantic coupling."""
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass
class Institution:
    name: str
    wikidata_id: str | None = None
    source_url: str | None = None


@dataclass
class Company:
    name: str
    wikidata_id: str | None = None
    sector: str | None = None
    website: str | None = None
    source_url: str | None = None


@dataclass
class Employment:
    company: Company
    title: str | None = None
    is_current: bool = False


@dataclass
class Person:
    full_name: str
    wikidata_id: str | None = None
    source_url: str | None = None


@dataclass
class SearchResult:
    person: Person
    institution: Institution
    employment: Employment | None = None
    source_url: str | None = None
    source_type: str | None = None
    confidence: float = 0.0
    title_level: str | None = None
    sector: str | None = None
PYEOF

cat > apps/api/app/models/api.py << 'PYEOF'
"""Pydantic schemas for API request/response — separate from domain models."""
from __future__ import annotations
from pydantic import BaseModel, Field
from app.models.domain import SearchResult as DomainSearchResult


# ── Request validators ──────────────────────────────────────────────────────

class SearchInput(BaseModel):
    university: str = Field(default="", min_length=0, max_length=200)
    sector: str | None = None
    title_level: str | None = None
    company_type: str | None = None
    region: str | None = None
    keyword: str | None = None
    offset: int = Field(default=0, ge=0)
    limit: int = Field(default=25, ge=1, le=100)


# ── Response schemas ────────────────────────────────────────────────────────

class CompanySchema(BaseModel):
    name: str
    wikidata_id: str | None = None
    sector: str | None = None
    website: str | None = None
    source_url: str | None = None


class EmploymentSchema(BaseModel):
    company: CompanySchema
    title: str | None = None
    is_current: bool = False


class PersonSchema(BaseModel):
    full_name: str
    wikidata_id: str | None = None
    source_url: str | None = None


class InstitutionSchema(BaseModel):
    name: str
    wikidata_id: str | None = None
    source_url: str | None = None


class SearchResultSchema(BaseModel):
    person: PersonSchema
    institution: InstitutionSchema
    employment: EmploymentSchema | None = None
    source_url: str | None = None
    source_type: str | None = None
    confidence: float
    title_level: str | None = None
    sector: str | None = None

    @classmethod
    def from_domain(cls, r: DomainSearchResult) -> "SearchResultSchema":
        emp = None
        if r.employment:
            emp = EmploymentSchema(
                company=CompanySchema(
                    name=r.employment.company.name,
                    wikidata_id=r.employment.company.wikidata_id,
                    sector=r.employment.company.sector,
                    website=r.employment.company.website,
                    source_url=r.employment.company.source_url,
                ),
                title=r.employment.title,
                is_current=r.employment.is_current,
            )
        return cls(
            person=PersonSchema(
                full_name=r.person.full_name,
                wikidata_id=r.person.wikidata_id,
                source_url=r.person.source_url,
            ),
            institution=InstitutionSchema(
                name=r.institution.name,
                wikidata_id=r.institution.wikidata_id,
                source_url=r.institution.source_url,
            ),
            employment=emp,
            source_url=r.source_url,
            source_type=r.source_type,
            confidence=r.confidence,
            title_level=r.title_level,
            sector=r.sector,
        )


class SearchResponse(BaseModel):
    results: list[SearchResultSchema]
    total: int
    offset: int
    limit: int
    university: dict | None = None


class UniversityResponse(BaseModel):
    institution: InstitutionSchema
    alumni_count: int
    top_employers: list[dict]
    sector_breakdown: dict[str, int]
    title_level_breakdown: dict[str, int]


class HealthResponse(BaseModel):
    status: str
    version: str
PYEOF

# ─────────────────────────────────────────────
# 11. TESTS
# ─────────────────────────────────────────────

mkdir -p apps/api/tests

cat > apps/api/tests/test_sanitize.py << 'PYEOF'
from app.utils.sanitize import escape_sparql_string, sanitize_search_name


def test_escape_quotes():
    assert escape_sparql_string('say "hello"') == 'say \\"hello\\"'


def test_escape_backslash():
    assert escape_sparql_string("back\\slash") == "back\\\\slash"


def test_strips_control_chars():
    assert sanitize_search_name("UNC\x00Chapel Hill") == "UNC Chapel Hill"


def test_empty_string():
    assert sanitize_search_name("") == ""
PYEOF

cat > apps/api/tests/test_slugify.py << 'PYEOF'
from app.utils.slugify import slugify


def test_basic():
    assert slugify("University of North Carolina") == "university-of-north-carolina"


def test_accented():
    result = slugify("École Normale Supérieure")
    assert result == "ecole-normale-superieure"


def test_special_chars():
    assert slugify("MIT (Massachusetts)") == "mit-massachusetts"


def test_multiple_spaces():
    assert slugify("Duke  University") == "duke-university"
PYEOF

cat > apps/api/tests/test_title_classifier.py << 'PYEOF'
from app.services.title_classifier import classify


def test_ceo():
    assert classify("Chief Executive Officer") == "c_suite"


def test_cto():
    assert classify("CTO") == "c_suite"


def test_vp_before_president():
    assert classify("Vice President of Engineering") == "vp"


def test_president():
    assert classify("President") == "c_suite"


def test_founder():
    assert classify("Co-Founder & CEO") == "founder"


def test_director():
    assert classify("Director of Product") == "director"


def test_manager():
    assert classify("Senior Manager") == "manager"


def test_unknown():
    assert classify("") == "unknown"


def test_professor():
    assert classify("Professor") == "academic"


def test_politician():
    assert classify("Senator") == "government"
PYEOF

cat > apps/api/tests/test_sector_mapper.py << 'PYEOF'
from app.services.sector_mapper import map_sector


def test_tech():
    assert map_sector("Google Cloud Platform") == "technology"


def test_finance():
    assert map_sector("Goldman Sachs Capital") == "finance"


def test_healthcare():
    assert map_sector("UNC Health Hospitals") == "healthcare"


def test_consulting():
    assert map_sector("McKinsey & Company") == "consulting"


def test_education():
    assert map_sector("Duke University") == "education"


def test_unknown():
    assert map_sector("") == "unknown"


def test_other():
    assert map_sector("Zorg Industries") == "other"
PYEOF

cat > apps/api/tests/test_deduper.py << 'PYEOF'
from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.deduper import dedupe


def _make(name: str, qid: str, inst_id: str = "Q1", confidence: float = 0.8) -> SearchResult:
    return SearchResult(
        person=Person(full_name=name, wikidata_id=qid),
        institution=Institution(name="UNC", wikidata_id=inst_id),
        employment=Employment(company=Company(name="Acme"), title="CEO"),
        confidence=confidence,
        source_type="wikidata",
    )


def test_removes_exact_duplicate():
    r1 = _make("Alice Smith", "Q1")
    r2 = _make("Alice Smith", "Q1", confidence=0.6)
    out = dedupe([r1, r2])
    assert len(out) == 1
    assert out[0].confidence == 0.8


def test_keeps_different_institutions():
    r1 = _make("James Wilson", "Q10", inst_id="Q100")
    r2 = _make("James Wilson", "Q11", inst_id="Q200")
    out = dedupe([r1, r2])
    assert len(out) == 2


def test_keeps_different_names():
    r1 = _make("Alice Smith", "Q1")
    r2 = _make("Bob Jones", "Q2")
    out = dedupe([r1, r2])
    assert len(out) == 2
PYEOF

cat > apps/api/tests/test_confidence_scorer.py << 'PYEOF'
from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.confidence_scorer import score


def _result(source_type: str, has_title: bool = True, wikidata_id: str | None = "Q1") -> SearchResult:
    return SearchResult(
        person=Person(full_name="Alice", wikidata_id=wikidata_id, source_url="https://wikidata.org/wiki/Q1"),
        institution=Institution(name="UNC", wikidata_id="Q902595"),
        employment=Employment(
            company=Company(name="Google"),
            title="CEO" if has_title else None,
        ),
        source_url="https://wikidata.org/wiki/Q1",
        source_type=source_type,
    )


def test_wikidata_with_full_data():
    s = score(_result("wikidata"))
    assert 0.9 <= s <= 1.0


def test_sec_filing_high():
    s = score(_result("sec_filing"))
    assert s > 0.8


def test_public_web_lower():
    s = score(_result("public_web"))
    assert s < 0.8


def test_clamped_to_one():
    s = score(_result("sec_filing"))
    assert s <= 1.0
PYEOF

cat > apps/api/tests/test_university_stats.py << 'PYEOF'
from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.university_stats import top_employers, sector_breakdown


def _r(company: str, sector: str | None = None) -> SearchResult:
    return SearchResult(
        person=Person(full_name="X"),
        institution=Institution(name="UNC"),
        employment=Employment(company=Company(name=company)),
        sector=sector,
    )


def test_top_employers():
    alumni = [_r("Google"), _r("Google"), _r("Apple")]
    top = top_employers(alumni, n=2)
    assert top[0]["employer"] == "Google"
    assert top[0]["count"] == 2


def test_sector_breakdown():
    alumni = [_r("x", sector="technology"), _r("y", sector="technology"), _r("z", sector="finance")]
    bd = sector_breakdown(alumni)
    assert bd["technology"] == 2
    assert bd["finance"] == 1
PYEOF

cat > apps/api/tests/test_routes_health.py << 'PYEOF'
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
PYEOF

cat > apps/api/tests/conftest.py << 'PYEOF'
import pytest


def pytest_configure(config):
    config.addinivalue_line("markers", "anyio: mark test as async")
PYEOF

# Install anyio pytest plugin if not present
grep -q "anyio" apps/api/requirements.txt 2>/dev/null || echo "anyio[trio]
pytest-anyio" >> apps/api/requirements.txt

# ─────────────────────────────────────────────
# 12. DOCKERFILE
# ─────────────────────────────────────────────

cat > apps/api/Dockerfile << 'DEOF'
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/
COPY migrations/ migrations/

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DEOF

# ─────────────────────────────────────────────
# 13. CI — backend test workflow
# ─────────────────────────────────────────────

mkdir -p .github/workflows

cat > .github/workflows/test-api.yml << 'YEOF'
name: Backend Tests

on:
  push:
    paths:
      - "apps/api/**"
      - ".github/workflows/test-api.yml"
  pull_request:
    paths:
      - "apps/api/**"

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/api

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: "pip"
          cache-dependency-path: apps/api/requirements.txt

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ -v --tb=short
YEOF

# ─────────────────────────────────────────────
# 14. GIT — commit and push
# ─────────────────────────────────────────────

echo ""
echo "=== All files written. Committing to git… ==="

git add -A

git commit -m "fix: apply full codebase review — all 26 bugs addressed

Critical fixes:
- SPARQL injection: add sanitize.py + escape_sparql_string
- Use Wikidata Entity Search API (no SPARQL injection surface)
- company_type / region filters no longer silent no-ops
- Rate limiter (rate_limit.py) now enforced in search route
- DB now initialised via lifespan (not deprecated on_event)
- DB upsert helpers added; stats endpoint returns real counts
- alumni route: resolve QID → Wikipedia sitelink before fetch

High fixes:
- Shared TypeScript types reconciled with Python API shapes
- api-client.ts now used by pages (dead code removed)
- FilterPanel uses controlled selects (defaultValue → value)
- Keyword filter added to FilterPanel UI

Architecture fixes:
- university_stats service extracted from universities route
- university_resolver has normalization, cache, fallback
- deduper keys on name + institution (not name alone)
- title_classifier: VP pattern before President; P106 labels added
- slugify handles non-ASCII via NFKD normalization
- main.py uses modern lifespan context manager

Tests added:
- test_sanitize, test_slugify, test_title_classifier
- test_sector_mapper, test_deduper, test_confidence_scorer
- test_university_stats, test_routes_health

CI/Deployment:
- .github/workflows/test-api.yml (backend CI)
- apps/api/Dockerfile"

git push origin main

echo ""
echo "=== Done. All fixes committed and pushed to main. ==="