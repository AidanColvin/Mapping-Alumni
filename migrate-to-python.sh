#!/bin/bash
set -e

echo "🐍 Migrating AlumniMap backend to Python + FastAPI..."
echo ""

# ── 1. Remove TypeScript backend ──────────────────────────────────────────────
if [ -d "apps/api" ]; then
  echo "Removing old TypeScript backend..."
  rm -rf apps/api
fi

# ── 2. Python backend scaffold ────────────────────────────────────────────────
mkdir -p apps/api/app/{routes,services,adapters,models,validators,utils,sources}
mkdir -p apps/api/tests
mkdir -p apps/api/data/{cache,sqlite}
mkdir -p apps/api/migrations

# ── pyproject + requirements ──────────────────────────────────────────────────
cat > apps/api/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn[standard]==0.32.0
pydantic==2.9.2
pydantic-settings==2.5.2
httpx==0.27.2
beautifulsoup4==4.12.3
lxml==5.3.0
SPARQLWrapper==2.0.0
python-dotenv==1.0.1
pytest==8.3.3
pytest-asyncio==0.24.0
EOF

cat > apps/api/pyproject.toml << 'EOF'
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "alumnimap-api"
version = "0.1.0"
requires-python = ">=3.10"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
EOF

cat > apps/api/.env.example << 'EOF'
DATABASE_URL=sqlite:///./data/sqlite/alumnimap.db
CACHE_DIR=./data/cache
USER_AGENT=AlumniMap/0.1 (https://github.com/AidanColvin/AlumniMap; alumnimap@example.org)
RATE_LIMIT_PER_MIN=30
CACHE_TTL_HOURS=24
CORS_ORIGINS=http://localhost:3000
EOF

# ── app/__init__.py and main.py ───────────────────────────────────────────────
cat > apps/api/app/__init__.py << 'EOF'
EOF

cat > apps/api/app/main.py << 'EOF'
"""FastAPI entrypoint. Wires routes and middleware."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import init_db
from app.routes import health, search, universities, alumni, companies, sources, stats

app = FastAPI(title="AlumniMap API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(search.router)
app.include_router(universities.router)
app.include_router(alumni.router)
app.include_router(companies.router)
app.include_router(sources.router)
app.include_router(stats.router)


@app.on_event("startup")
def on_startup() -> None:
    init_db()
EOF

# ── config & db ───────────────────────────────────────────────────────────────
cat > apps/api/app/config.py << 'EOF'
"""Application configuration loaded from environment."""
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./data/sqlite/alumnimap.db"
    cache_dir: str = "./data/cache"
    user_agent: str = "AlumniMap/0.1"
    rate_limit_per_min: int = 30
    cache_ttl_hours: int = 24
    cors_origins: str = "http://localhost:3000"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def cache_path(self) -> Path:
        p = Path(self.cache_dir)
        p.mkdir(parents=True, exist_ok=True)
        return p


settings = Settings()
EOF

cat > apps/api/app/db.py << 'EOF'
"""SQLite connection + schema initialization."""
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from app.config import settings

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"


def _db_file() -> Path:
    url = settings.database_url
    assert url.startswith("sqlite:///"), "Only SQLite supported in MVP."
    path = Path(url.replace("sqlite:///", ""))
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


@contextmanager
def get_conn() -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(_db_file())
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    """Apply all .sql migrations in order. Idempotent."""
    with get_conn() as conn:
        for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
            conn.executescript(sql_file.read_text())
EOF

# ── models ────────────────────────────────────────────────────────────────────
cat > apps/api/app/models/__init__.py << 'EOF'
EOF

cat > apps/api/app/models/domain.py << 'EOF'
"""Core domain types. Pydantic models for safe IO."""
from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field

TitleLevel = Literal["c_suite", "founder", "vp", "director", "manager", "individual", "unknown"]
SourceType = Literal["wikidata", "wikipedia", "company_site", "sec_filing", "university_page"]


class Institution(BaseModel):
    id: str
    name: str
    slug: str
    aliases: list[str] = Field(default_factory=list)
    country: Optional[str] = None
    wikidata_id: Optional[str] = None


class Company(BaseModel):
    id: str
    name: str
    slug: str
    sector: Optional[str] = None
    domain: Optional[str] = None


class Employment(BaseModel):
    company: Optional[Company] = None
    title: str = ""
    title_level: TitleLevel = "unknown"
    sector: str = "other"
    is_current: bool = False


class Person(BaseModel):
    id: str
    full_name: str
    source_url: str
    source_type: SourceType
    retrieved_at: datetime
    confidence: float = 0.5
    verified_fields: list[str] = Field(default_factory=list)


class SearchResult(BaseModel):
    person: Person
    employment: list[Employment] = Field(default_factory=list)
    institution: Optional[Institution] = None
EOF

cat > apps/api/app/models/api.py << 'EOF'
"""API request/response shapes."""
from typing import Optional

from pydantic import BaseModel

from app.models.domain import Institution, SearchResult, TitleLevel


class SearchResponse(BaseModel):
    results: list[SearchResult]
    total: int
    page: int
    limit: int
    institution: Optional[Institution] = None


class UniversityResponse(BaseModel):
    institution: Institution
    alumni_count: int
    top_employers: list[dict]


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"


class StatsResponse(BaseModel):
    institutions: int
    people: int
    cached_pages: int


class SourcesResponse(BaseModel):
    allowed_domains: list[str]


class ErrorResponse(BaseModel):
    error: str
    details: Optional[dict] = None
EOF

# ── validators ────────────────────────────────────────────────────────────────
cat > apps/api/app/validators/__init__.py << 'EOF'
EOF

cat > apps/api/app/validators/search_input.py << 'EOF'
"""Input validation schemas."""
from typing import Optional

from pydantic import BaseModel, Field

from app.models.domain import TitleLevel


class SearchInput(BaseModel):
    university: str = Field(..., min_length=2, max_length=120)
    sector: Optional[str] = None
    title_level: Optional[TitleLevel] = None
    company_type: Optional[str] = None
    region: Optional[str] = None
    keyword: Optional[str] = None
    page: int = Field(default=1, ge=1)
    limit: int = Field(default=20, ge=1, le=50)
EOF

# ── utils ─────────────────────────────────────────────────────────────────────
cat > apps/api/app/utils/__init__.py << 'EOF'
EOF

cat > apps/api/app/utils/normalize.py << 'EOF'
"""Text normalization helpers."""
import re


def normalize(text: str) -> str:
    """Lowercase, strip, collapse whitespace."""
    return re.sub(r"\s+", " ", text).strip().lower()


def name_key(full_name: str) -> str:
    """Stable key for matching the same person across sources."""
    return normalize(re.sub(r"[^\w\s]", "", full_name))
EOF

cat > apps/api/app/utils/slugify.py << 'EOF'
"""URL-safe slug generation."""
import re


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"[^a-z0-9-]", "", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")
EOF

cat > apps/api/app/utils/logger.py << 'EOF'
"""Structured JSON logging."""
import json
import sys
from datetime import datetime, timezone


def log(level: str, message: str, **meta) -> None:
    entry = {
        "level": level,
        "message": message,
        "ts": datetime.now(timezone.utc).isoformat(),
        **meta,
    }
    stream = sys.stderr if level == "error" else sys.stdout
    print(json.dumps(entry), file=stream, flush=True)
EOF

cat > apps/api/app/utils/rate_limit.py << 'EOF'
"""Naive in-process rate limiter, per-key sliding window."""
import time
from collections import defaultdict, deque

from app.config import settings

_windows: dict[str, deque[float]] = defaultdict(deque)


def allow(key: str) -> bool:
    """Return True if the key is within the per-minute limit."""
    now = time.time()
    window = _windows[key]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= settings.rate_limit_per_min:
        return False
    window.append(now)
    return True
EOF

cat > apps/api/app/utils/cache.py << 'EOF'
"""File-based cache. Hash URL to filename. Honor TTL."""
import hashlib
import json
import time
from pathlib import Path
from typing import Optional

from app.config import settings


def _key_path(key: str) -> Path:
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return settings.cache_path / f"{digest}.json"


def get(key: str) -> Optional[dict]:
    path = _key_path(key)
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    if time.time() - data["ts"] > settings.cache_ttl_hours * 3600:
        return None
    return data["value"]


def put(key: str, value: dict) -> None:
    path = _key_path(key)
    path.write_text(json.dumps({"ts": time.time(), "value": value}))
EOF

cat > apps/api/app/utils/robots.py << 'EOF'
"""robots.txt-aware fetch guard."""
import urllib.robotparser as rp
from functools import lru_cache
from urllib.parse import urlparse

from app.config import settings


@lru_cache(maxsize=256)
def _parser_for(host: str) -> rp.RobotFileParser:
    parser = rp.RobotFileParser()
    parser.set_url(f"https://{host}/robots.txt")
    try:
        parser.read()
    except Exception:
        pass
    return parser


def is_allowed(url: str) -> bool:
    """Check robots.txt before fetching. Default to True if unreadable."""
    parsed = urlparse(url)
    if not parsed.netloc:
        return False
    parser = _parser_for(parsed.netloc)
    try:
        return parser.can_fetch(settings.user_agent, url)
    except Exception:
        return True
EOF

# ── sources registry ──────────────────────────────────────────────────────────
cat > apps/api/app/sources/__init__.py << 'EOF'
EOF

cat > apps/api/app/sources/registry.py << 'EOF'
"""Allowed source domains. Add new sources here, not in code."""

ALLOWED_DOMAINS: list[str] = [
    "wikidata.org",
    "query.wikidata.org",
    "en.wikipedia.org",
    "www.sec.gov",
    "www.unc.edu",
    "unc.edu",
]


def is_allowed_domain(domain: str) -> bool:
    return any(domain.endswith(d) for d in ALLOWED_DOMAINS)
EOF

# ── adapters ──────────────────────────────────────────────────────────────────
cat > apps/api/app/adapters/__init__.py << 'EOF'
EOF

cat > apps/api/app/adapters/public_web.py << 'EOF'
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

    if not is_allowed(url):
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
EOF

cat > apps/api/app/adapters/wikidata.py << 'EOF'
"""Wikidata SPARQL adapter. Free, no API key required."""
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

import httpx

from app.config import settings
from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.utils import cache
from app.utils.logger import log
from app.utils.slugify import slugify

SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"


def _q_resolve_institution(name: str) -> str:
    return f"""
    SELECT ?university ?universityLabel ?countryLabel WHERE {{
      ?university wdt:P31/wdt:P279* wd:Q38723.
      ?university rdfs:label ?label.
      FILTER(CONTAINS(LCASE(?label), LCASE("{name}"))).
      FILTER(LANG(?label) = "en").
      OPTIONAL {{ ?university wdt:P17 ?country. }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    LIMIT 5
    """


def _q_alumni_for(wikidata_qid: str) -> str:
    return f"""
    SELECT DISTINCT ?person ?personLabel ?employerLabel ?positionLabel WHERE {{
      ?person wdt:P69 wd:{wikidata_qid}.
      OPTIONAL {{ ?person wdt:P108 ?employer. }}
      OPTIONAL {{ ?person wdt:P39 ?position. }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    LIMIT 200
    """


async def _run_sparql(query: str) -> list[dict[str, Any]]:
    cached = cache.get("sparql:" + query)
    if cached:
        return cached.get("bindings", [])

    try:
        async with httpx.AsyncClient(
            headers={
                "User-Agent": settings.user_agent,
                "Accept": "application/sparql-results+json",
            },
            timeout=30.0,
        ) as client:
            r = await client.get(SPARQL_ENDPOINT, params={"query": query, "format": "json"})
            if r.status_code != 200:
                log("warn", "sparql_failed", status=r.status_code)
                return []
            bindings = r.json().get("results", {}).get("bindings", [])
            cache.put("sparql:" + query, {"bindings": bindings})
            return bindings
    except Exception as e:
        log("error", "sparql_exception", error=str(e))
        return []


async def resolve_institution(name: str) -> Institution | None:
    """Find the canonical Wikidata institution for a free-text name."""
    bindings = await _run_sparql(_q_resolve_institution(name))
    if not bindings:
        return None
    top = bindings[0]
    qid_url = top.get("university", {}).get("value", "")
    qid = qid_url.rsplit("/", 1)[-1] if qid_url else None
    label = top.get("universityLabel", {}).get("value", name)
    country = top.get("countryLabel", {}).get("value")
    return Institution(
        id=qid or str(uuid4()),
        name=label,
        slug=slugify(label),
        aliases=[],
        country=country,
        wikidata_id=qid,
    )


async def fetch_alumni(institution: Institution) -> list[SearchResult]:
    """Return alumni records for a resolved institution."""
    if not institution.wikidata_id:
        return []
    bindings = await _run_sparql(_q_alumni_for(institution.wikidata_id))
    results: list[SearchResult] = []
    seen: set[str] = set()

    for b in bindings:
        person_url = b.get("person", {}).get("value", "")
        if not person_url or person_url in seen:
            continue
        seen.add(person_url)

        name = b.get("personLabel", {}).get("value", "Unknown")
        if name.startswith("Q") and name[1:].isdigit():
            continue  # label fallback to QID = no English label

        employer = b.get("employerLabel", {}).get("value")
        position = b.get("positionLabel", {}).get("value", "")

        employment: list[Employment] = []
        if employer:
            employment.append(
                Employment(
                    company=Company(id=str(uuid4()), name=employer, slug=slugify(employer)),
                    title=position,
                )
            )

        results.append(
            SearchResult(
                person=Person(
                    id=person_url.rsplit("/", 1)[-1],
                    full_name=name,
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
EOF

cat > apps/api/app/adapters/wikipedia.py << 'EOF'
"""Wikipedia REST API for short bios. Free, no key."""
import httpx

from app.config import settings
from app.utils import cache


async def fetch_summary(title: str) -> dict | None:
    cached = cache.get("wiki:" + title)
    if cached:
        return cached

    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{title}"
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
EOF

cat > apps/api/app/adapters/company_site.py << 'EOF'
"""Parse public company leadership/about pages."""
from bs4 import BeautifulSoup

from app.adapters.public_web import fetch_text


async def parse_leadership(url: str) -> list[dict]:
    """Extract heuristic name+title pairs from a public leadership page."""
    html = await fetch_text(url)
    if not html:
        return []
    soup = BeautifulSoup(html, "lxml")
    people: list[dict] = []
    for h in soup.find_all(["h2", "h3", "h4"]):
        name = h.get_text(strip=True)
        nxt = h.find_next(["p", "span", "div"])
        title = nxt.get_text(strip=True) if nxt else ""
        if name and 2 < len(name) < 80:
            people.append({"name": name, "title": title[:120], "source_url": url})
    return people
EOF

cat > apps/api/app/adapters/sec_filings.py << 'EOF'
"""SEC EDGAR full-text search adapter. Free, public."""
import httpx

from app.config import settings
from app.utils import cache


async def search_executives(name: str) -> list[dict]:
    cached = cache.get("sec:" + name)
    if cached:
        return cached.get("hits", [])

    url = "https://efts.sec.gov/LATEST/search-index"
    params = {"q": f'"{name}"', "forms": "DEF 14A"}
    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": settings.user_agent}, timeout=15.0
        ) as client:
            r = await client.get(url, params=params)
            if r.status_code != 200:
                return []
            hits = r.json().get("hits", {}).get("hits", [])
            cache.put("sec:" + name, {"hits": hits})
            return hits
    except Exception:
        return []
EOF

# ── services ──────────────────────────────────────────────────────────────────
cat > apps/api/app/services/__init__.py << 'EOF'
EOF

cat > apps/api/app/services/university_resolver.py << 'EOF'
"""Resolve a free-text university name to a canonical Institution."""
from app.adapters import wikidata
from app.models.domain import Institution


async def resolve(name: str) -> Institution | None:
    return await wikidata.resolve_institution(name)
EOF

cat > apps/api/app/services/title_classifier.py << 'EOF'
"""Map raw job titles to a TitleLevel enum value."""
import re

from app.models.domain import TitleLevel

PATTERNS: list[tuple[re.Pattern, TitleLevel]] = [
    (re.compile(r"\b(ceo|cto|coo|cfo|cpo|cmo|chief\b)", re.I), "c_suite"),
    (re.compile(r"\b(founder|co-?founder)\b", re.I), "founder"),
    (re.compile(r"\b(president|partner)\b", re.I), "c_suite"),
    (re.compile(r"\b(vp|vice president|svp|evp)\b", re.I), "vp"),
    (re.compile(r"\bdirector\b", re.I), "director"),
    (re.compile(r"\bmanager\b", re.I), "manager"),
]


def classify(title: str) -> TitleLevel:
    if not title:
        return "unknown"
    for pattern, level in PATTERNS:
        if pattern.search(title):
            return level
    return "individual"
EOF

cat > apps/api/app/services/sector_mapper.py << 'EOF'
"""Heuristic company-name to sector mapper."""
SECTOR_KEYWORDS: dict[str, list[str]] = {
    "technology": ["software", "tech", "ai", "data", "cloud", "cyber", "google", "meta", "microsoft", "apple"],
    "finance": ["bank", "capital", "invest", "financial", "fund", "asset", "goldman", "morgan"],
    "healthcare": ["health", "medical", "pharma", "biotech", "hospital", "clinic", "pfizer"],
    "government": ["department", "agency", "ministry", "federal", "state of", "city of"],
    "education": ["university", "college", "school", "institute", "academy"],
    "media": ["media", "news", "publishing", "broadcast", "times", "post"],
    "consulting": ["consulting", "advisory", "mckinsey", "deloitte", "bain", "bcg"],
    "legal": ["law", "legal", "attorney", "counsel"],
    "nonprofit": ["foundation", "nonprofit", "ngo", "charity"],
}


def map_sector(company_name: str) -> str:
    if not company_name:
        return "other"
    lower = company_name.lower()
    for sector, keywords in SECTOR_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            return sector
    return "other"
EOF

cat > apps/api/app/services/confidence_scorer.py << 'EOF'
"""Score the confidence of a SearchResult based on source quality."""
from app.models.domain import SearchResult

WEIGHTS: dict[str, float] = {
    "sec_filing": 0.35,
    "wikidata": 0.25,
    "wikipedia": 0.20,
    "company_site": 0.20,
    "university_page": 0.15,
}


def score(result: SearchResult) -> SearchResult:
    base = 0.4
    base += WEIGHTS.get(result.person.source_type, 0.0)
    if result.employment:
        base += 0.1
    if result.institution:
        base += 0.1
    result.person.confidence = round(min(max(base, 0.0), 1.0), 3)
    return result
EOF

cat > apps/api/app/services/deduper.py << 'EOF'
"""Merge duplicate people by name. Keep the highest-confidence record."""
from app.models.domain import SearchResult
from app.utils.normalize import name_key


def dedupe(results: list[SearchResult]) -> list[SearchResult]:
    best: dict[str, SearchResult] = {}
    for r in results:
        key = name_key(r.person.full_name)
        if key not in best or r.person.confidence > best[key].person.confidence:
            best[key] = r
    return list(best.values())
EOF

cat > apps/api/app/services/source_priority.py << 'EOF'
"""Pick the higher-priority source type when records conflict."""
PRIORITY: dict[str, int] = {
    "sec_filing": 5,
    "wikidata": 4,
    "wikipedia": 3,
    "company_site": 2,
    "university_page": 1,
}


def higher(a: str, b: str) -> str:
    return a if PRIORITY.get(a, 0) >= PRIORITY.get(b, 0) else b
EOF

cat > apps/api/app/services/company_enricher.py << 'EOF'
"""Enrich a company record with sector and slug."""
from app.models.domain import Company
from app.services.sector_mapper import map_sector
from app.utils.slugify import slugify


def enrich(company: Company) -> Company:
    company.sector = company.sector or map_sector(company.name)
    company.slug = company.slug or slugify(company.name)
    return company
EOF

cat > apps/api/app/services/alumni_search.py << 'EOF'
"""End-to-end alumni search pipeline.
Steps: resolve → fetch → classify → enrich → score → dedupe → filter → paginate.
"""
from app.adapters import wikidata
from app.models.domain import SearchResult
from app.services import (
    confidence_scorer,
    company_enricher,
    deduper,
    sector_mapper,
    title_classifier,
    university_resolver,
)
from app.validators.search_input import SearchInput


async def run(query: SearchInput) -> tuple[list[SearchResult], int, dict | None]:
    institution = await university_resolver.resolve(query.university)
    if not institution:
        return [], 0, None

    raw = await wikidata.fetch_alumni(institution)

    enriched: list[SearchResult] = []
    for r in raw:
        for e in r.employment:
            e.title_level = title_classifier.classify(e.title)
            e.sector = sector_mapper.map_sector(e.company.name if e.company else "")
            if e.company:
                e.company = company_enricher.enrich(e.company)
        enriched.append(confidence_scorer.score(r))

    deduped = deduper.dedupe(enriched)
    filtered = _apply_filters(deduped, query)
    filtered.sort(key=lambda r: r.person.confidence, reverse=True)

    total = len(filtered)
    start = (query.page - 1) * query.limit
    paged = filtered[start : start + query.limit]
    return paged, total, institution.model_dump()


def _apply_filters(results: list[SearchResult], q: SearchInput) -> list[SearchResult]:
    out = results
    if q.title_level:
        out = [r for r in out if any(e.title_level == q.title_level for e in r.employment)]
    if q.sector:
        out = [r for r in out if any(e.sector == q.sector for e in r.employment)]
    if q.keyword:
        kw = q.keyword.lower()
        out = [
            r
            for r in out
            if kw in r.person.full_name.lower()
            or any(kw in (e.company.name.lower() if e.company else "") for e in r.employment)
        ]
    return out
EOF

# ── routes ────────────────────────────────────────────────────────────────────
cat > apps/api/app/routes/__init__.py << 'EOF'
EOF

cat > apps/api/app/routes/health.py << 'EOF'
from fastapi import APIRouter

from app.models.api import HealthResponse

router = APIRouter(prefix="/api/health", tags=["health"])


@router.get("", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse()
EOF

cat > apps/api/app/routes/search.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException

from app.models.api import SearchResponse
from app.services.alumni_search import run
from app.validators.search_input import SearchInput

router = APIRouter(prefix="/api/search", tags=["search"])


@router.get("", response_model=SearchResponse)
async def search(query: SearchInput = Depends()) -> SearchResponse:
    results, total, institution = await run(query)
    if not results and not institution:
        raise HTTPException(status_code=404, detail="University not found")
    return SearchResponse(
        results=results,
        total=total,
        page=query.page,
        limit=query.limit,
        institution=institution,
    )
EOF

cat > apps/api/app/routes/universities.py << 'EOF'
from collections import Counter

from fastapi import APIRouter, HTTPException

from app.adapters import wikidata
from app.models.api import UniversityResponse
from app.services import university_resolver

router = APIRouter(prefix="/api/universities", tags=["universities"])


@router.get("/{slug}", response_model=UniversityResponse)
async def get_university(slug: str) -> UniversityResponse:
    institution = await university_resolver.resolve(slug.replace("-", " "))
    if not institution:
        raise HTTPException(status_code=404, detail="University not found")

    alumni = await wikidata.fetch_alumni(institution)
    employers = Counter()
    for r in alumni:
        for e in r.employment:
            if e.company:
                employers[e.company.name] += 1

    return UniversityResponse(
        institution=institution,
        alumni_count=len(alumni),
        top_employers=[{"company": n, "count": c} for n, c in employers.most_common(10)],
    )
EOF

cat > apps/api/app/routes/alumni.py << 'EOF'
from fastapi import APIRouter, HTTPException

from app.adapters import wikipedia

router = APIRouter(prefix="/api/alumni", tags=["alumni"])


@router.get("/{wikidata_qid}")
async def get_alumnus(wikidata_qid: str):
    """Return a brief bio for a person by their Wikidata QID."""
    summary = await wikipedia.fetch_summary(wikidata_qid)
    if not summary:
        raise HTTPException(status_code=404, detail="Not found")
    return summary
EOF

cat > apps/api/app/routes/companies.py << 'EOF'
from fastapi import APIRouter, Query

from app.services.sector_mapper import SECTOR_KEYWORDS

router = APIRouter(prefix="/api/companies", tags=["companies"])


@router.get("/sectors")
def list_sectors(q: str | None = Query(default=None)) -> dict:
    """Return available sectors and example keywords."""
    if q:
        return {q: SECTOR_KEYWORDS.get(q, [])}
    return {k: v[:5] for k, v in SECTOR_KEYWORDS.items()}
EOF

cat > apps/api/app/routes/sources.py << 'EOF'
from fastapi import APIRouter

from app.models.api import SourcesResponse
from app.sources.registry import ALLOWED_DOMAINS

router = APIRouter(prefix="/api/sources", tags=["sources"])


@router.get("", response_model=SourcesResponse)
def list_sources() -> SourcesResponse:
    return SourcesResponse(allowed_domains=ALLOWED_DOMAINS)
EOF

cat > apps/api/app/routes/stats.py << 'EOF'
from pathlib import Path

from fastapi import APIRouter

from app.config import settings
from app.db import get_conn
from app.models.api import StatsResponse

router = APIRouter(prefix="/api/stats", tags=["stats"])


@router.get("", response_model=StatsResponse)
def stats() -> StatsResponse:
    with get_conn() as conn:
        i = conn.execute("SELECT COUNT(*) FROM institutions").fetchone()[0]
        p = conn.execute("SELECT COUNT(*) FROM people").fetchone()[0]
    cached = len(list(Path(settings.cache_dir).glob("*.json")))
    return StatsResponse(institutions=i, people=p, cached_pages=cached)
EOF

# ── migrations ────────────────────────────────────────────────────────────────
cat > apps/api/migrations/001_init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS institutions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  country TEXT,
  wikidata_id TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT,
  sector TEXT,
  domain TEXT
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  source_url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TEXT NOT NULL,
  confidence REAL DEFAULT 0.5
);

CREATE TABLE IF NOT EXISTS employment_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id TEXT REFERENCES people(id),
  company_id TEXT REFERENCES companies(id),
  title TEXT,
  title_level TEXT,
  sector TEXT,
  is_current INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS education_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id TEXT REFERENCES people(id),
  institution_id TEXT REFERENCES institutions(id),
  start_year INTEGER,
  end_year INTEGER
);

CREATE TABLE IF NOT EXISTS source_documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TEXT NOT NULL,
  person_id TEXT REFERENCES people(id)
);

CREATE INDEX IF NOT EXISTS idx_inst_slug ON institutions(slug);
CREATE INDEX IF NOT EXISTS idx_people_name ON people(full_name);
EOF

# ── tests ─────────────────────────────────────────────────────────────────────
cat > apps/api/tests/__init__.py << 'EOF'
EOF

cat > apps/api/tests/conftest.py << 'EOF'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
EOF

cat > apps/api/tests/test_title_classifier.py << 'EOF'
from app.services.title_classifier import classify


def test_ceo_is_c_suite():
    assert classify("CEO") == "c_suite"
    assert classify("Chief Technology Officer") == "c_suite"


def test_founder():
    assert classify("Co-Founder") == "founder"


def test_vp():
    assert classify("VP of Engineering") == "vp"
    assert classify("Senior Vice President") == "vp"


def test_director():
    assert classify("Director of Sales") == "director"


def test_unknown_falls_through():
    assert classify("Analyst") == "individual"
    assert classify("") == "unknown"
EOF

cat > apps/api/tests/test_sector_mapper.py << 'EOF'
from app.services.sector_mapper import map_sector


def test_tech_company():
    assert map_sector("Google LLC") == "technology"


def test_bank():
    assert map_sector("Goldman Sachs") == "finance"


def test_hospital():
    assert map_sector("Mayo Clinic") == "healthcare"


def test_unknown():
    assert map_sector("Random Co") == "other"


def test_empty():
    assert map_sector("") == "other"
EOF

cat > apps/api/tests/test_deduper.py << 'EOF'
from datetime import datetime, timezone

from app.models.domain import Person, SearchResult
from app.services.deduper import dedupe


def _make(name: str, conf: float) -> SearchResult:
    return SearchResult(
        person=Person(
            id=name,
            full_name=name,
            source_url="https://example.org",
            source_type="wikidata",
            retrieved_at=datetime.now(timezone.utc),
            confidence=conf,
        )
    )


def test_keeps_highest_confidence():
    out = dedupe([_make("Jane Smith", 0.3), _make("Jane Smith", 0.8)])
    assert len(out) == 1
    assert out[0].person.confidence == 0.8


def test_keeps_distinct():
    out = dedupe([_make("Jane Smith", 0.5), _make("John Doe", 0.5)])
    assert len(out) == 2
EOF

cat > apps/api/tests/test_confidence_scorer.py << 'EOF'
from datetime import datetime, timezone

from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.services.confidence_scorer import score


def _make(source_type: str, with_employment: bool, with_institution: bool) -> SearchResult:
    return SearchResult(
        person=Person(
            id="1",
            full_name="X",
            source_url="https://x",
            source_type=source_type,
            retrieved_at=datetime.now(timezone.utc),
            confidence=0.0,
        ),
        employment=(
            [Employment(company=Company(id="c", name="C", slug="c"))] if with_employment else []
        ),
        institution=Institution(id="u", name="U", slug="u") if with_institution else None,
    )


def test_sec_filing_scores_highest():
    sec = score(_make("sec_filing", True, True))
    wiki = score(_make("wikidata", True, True))
    assert sec.person.confidence > wiki.person.confidence


def test_clamps_to_one():
    r = score(_make("sec_filing", True, True))
    assert r.person.confidence <= 1.0
EOF

cat > apps/api/tests/test_slugify.py << 'EOF'
from app.utils.slugify import slugify


def test_basic():
    assert slugify("University of North Carolina") == "university-of-north-carolina"


def test_strips_punctuation():
    assert slugify("Harvard University!!") == "harvard-university"


def test_handles_unicode_fallback():
    assert slugify("École Normale") == "cole-normale"
EOF

cat > apps/api/tests/test_normalize.py << 'EOF'
from app.utils.normalize import name_key, normalize


def test_normalize_collapses_whitespace():
    assert normalize("  Hello   World  ") == "hello world"


def test_name_key_strips_punctuation():
    assert name_key("Jane A. Smith Jr.") == name_key("jane a smith jr")
EOF

# ── apps/api README ───────────────────────────────────────────────────────────
cat > apps/api/README.md << 'EOF'
# AlumniMap API

FastAPI backend. Python 3.10+. Free to run locally — uses SQLite and Wikidata.

## Setup

```bash
cd apps/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

API is then at http://localhost:8000 and docs at http://localhost:8000/docs.

## Tests

```bash
pytest
```

## Endpoints

- `GET /api/health`
- `GET /api/search?university=...&sector=...&title_level=...`
- `GET /api/universities/{slug}`
- `GET /api/alumni/{wikidata_qid}`
- `GET /api/companies/sectors`
- `GET /api/sources`
- `GET /api/stats`
EOF

# ── 3. Point frontend at FastAPI ──────────────────────────────────────────────
if [ -f "apps/web/.env.local" ]; then
  rm apps/web/.env.local
fi

cat > apps/web/.env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

# ── 4. Root-level convenience ─────────────────────────────────────────────────
cat > Makefile << 'EOF'
.PHONY: install dev-api dev-web test

install:
	cd apps/api && python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
	cd apps/web && npm install

dev-api:
	cd apps/api && . .venv/bin/activate && uvicorn app.main:app --reload --port 8000

dev-web:
	cd apps/web && npm run dev

test:
	cd apps/api && . .venv/bin/activate && pytest
EOF

# Update root README
cat > README.md << 'EOF'
# AlumniMap

Free, open-source alumni intelligence platform. Enter a university, see where alumni work and lead — sourced entirely from public data (Wikidata, Wikipedia, SEC EDGAR, public company pages).

## Stack
- **Frontend**: Next.js 14 + Tailwind CSS
- **Backend**: Python 3.10 + FastAPI + Pydantic
- **Database**: SQLite (local) — Postgres-compatible for deployment
- **Data**: Wikidata SPARQL, Wikipedia REST, public web (robots-aware)
- **No paid APIs. No login-gated scraping.**

## Quick start

```bash
# 1. Install everything
make install

# 2. In one terminal — start the API
make dev-api          # http://localhost:8000  (docs at /docs)

# 3. In another terminal — start the frontend
make dev-web          # http://localhost:3000

# 4. Run tests
make test
```

Try it: open http://localhost:3000 and search "University of North Carolina".

## Compliance — what AlumniMap will never do
1. Scrape LinkedIn, X, or any login-gated platform.
2. Bypass paywalls or robots.txt disallow rules.
3. Use paid APIs as a required dependency.
4. Show unsourced facts. Every record carries its `source_url`.
5. Store private or non-public personal data.

## Project layout
```
apps/
  web/          # Next.js frontend
  api/          # Python FastAPI backend
    app/
      routes/      # Thin HTTP handlers
      services/    # Pipeline logic (resolve, score, dedupe, classify)
      adapters/    # Source-specific clients (wikidata, sec, etc)
      models/      # Pydantic types
      utils/       # cache, robots, rate limit, logger
      sources/     # Allowed-domain registry
    tests/      # pytest
    migrations/ # SQL schema
packages/
  shared/       # Legacy TS types (frontend only)
```

## Deployment (free tier)
- **Frontend**: Vercel Hobby — `vercel --prod` in `apps/web`
- **Backend**: Fly.io free tier, Railway, or Render (all support FastAPI + SQLite)
- **No database server required** for MVP; SQLite ships with the app.
EOF

echo ""
echo "✅ Migration complete."
echo ""
echo "Next steps:"
echo "  1. make install         # installs Python venv + npm deps"
echo "  2. make dev-api         # starts FastAPI at localhost:8000"
echo "  3. make dev-web         # in another terminal, starts Next.js at localhost:3000"
echo "  4. make test            # runs pytest"
echo ""
echo "Open http://localhost:8000/docs to explore the API."