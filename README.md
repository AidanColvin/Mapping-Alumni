# AlumniMap

**Free, open-source alumni intelligence.** Enter a university name, see where its alumni work and lead — sourced entirely from public data.

> 🎓 **Live demo:** [aidancolvin.github.io/Mapping-Alumni](https://aidancolvin.github.io/Mapping-Alumni/)
> The demo shows verified Fortune 500 C-Suite alumni from UNC Chapel Hill.

---

## What it does

AlumniMap lets anyone answer the question: *"Who from [University] has risen to a C-Suite or senior leadership role?"*

You type a university name. The platform:
1. Resolves the institution to a canonical Wikidata entity
2. Queries multiple public data sources for people who list that institution in their education history
3. Scores, deduplicates, and classifies each result
4. Returns a ranked list of alumni with their current employer, title, sector, and source links

Every record carries a `source_url` so claims can be independently verified. Nothing is invented — if it can't be sourced, it isn't shown.

---

## Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 14 + Tailwind CSS |
| Backend | Python 3.10+ · FastAPI · Pydantic v2 |
| Database | SQLite (local dev) — Postgres-compatible schema for production |
| Data sources | Wikidata SPARQL · Wikipedia REST · SEC EDGAR · Public company pages |
| Tests | pytest (backend) |
| Deployment | GitHub Pages (frontend demo) · Fly.io / Railway / Render (API) |

No paid APIs. No login-gated scraping. No vendor lock-in.

---

## Data pipeline

```
User query: "UNC Chapel Hill"
        │
        ▼
┌─────────────────────┐
│  UniversityResolver  │  Wikidata entity search → canonical institution ID + slug
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Source Adapters     │  Run in parallel against each allowed source:
│                     │    • wikidata.py   — SPARQL: educated-at + employer queries
│                     │    • wikipedia.py  — REST API: notable alumni sections
│                     │    • sec_filings.py — EDGAR: executive bios in proxy filings
│                     │    • company_site.py — Public leadership pages
│                     │    • public_web.py   — robots-aware open web fallback
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Deduper             │  Merge records for the same person across sources
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  TitleClassifier     │  Map raw title strings → seniority tiers
│                     │    c_suite · vp · director · manager · founder · …
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  SectorMapper        │  Normalize employer sector into standard buckets
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  ConfidenceScorer    │  Score each record 0–1 based on source quality
│                     │  + data completeness bonus (title, company, Wikidata ID)
└────────┬────────────┘
         │
         ▼
    SearchResponse (JSON)
```

### Confidence scoring

Each result is scored on a scale of 0–1:

| Source | Base score |
|---|---|
| SEC EDGAR filing | 0.90 |
| Wikidata | 0.80 |
| Wikipedia | 0.75 |
| Company site | 0.70 |
| Public web | 0.50 |

Up to +0.20 completeness bonus for: confirmed job title, confirmed employer, Wikidata entity ID, and a verifiable source URL.

### Title classification

Raw title strings are regex-matched into tiers:

`c_suite` → `vp` → `director` → `manager` → `founder` → `individual_contributor` → `government` → `academic` → `other`

---

## Project layout

```
.
├── apps/
│   ├── api/                    Python FastAPI backend
│   │   ├── app/
│   │   │   ├── adapters/       Source-specific data clients
│   │   │   │   ├── wikidata.py         Wikidata SPARQL + entity search
│   │   │   │   ├── wikipedia.py        Wikipedia REST API
│   │   │   │   ├── sec_filings.py      SEC EDGAR proxy filings
│   │   │   │   ├── company_site.py     Public company leadership pages
│   │   │   │   └── public_web.py       Open-web robots-aware fallback
│   │   │   ├── services/       Business logic
│   │   │   │   ├── alumni_search.py        Main search pipeline orchestrator
│   │   │   │   ├── university_resolver.py  Canonical institution lookup
│   │   │   │   ├── confidence_scorer.py    0–1 trust scoring
│   │   │   │   ├── title_classifier.py     Seniority tier regex mapping
│   │   │   │   ├── sector_mapper.py        Industry sector normalization
│   │   │   │   ├── deduper.py              Cross-source record merging
│   │   │   │   ├── company_enricher.py     Employer metadata enrichment
│   │   │   │   ├── source_priority.py      Source ranking logic
│   │   │   │   └── university_stats.py     Aggregate stat generation
│   │   │   ├── routes/         HTTP route handlers (thin — no business logic)
│   │   │   │   ├── search.py           GET /api/search
│   │   │   │   ├── universities.py     GET /api/universities
│   │   │   │   ├── alumni.py           GET /api/alumni
│   │   │   │   ├── companies.py        GET /api/companies
│   │   │   │   ├── stats.py            GET /api/stats
│   │   │   │   ├── sources.py          GET /api/sources
│   │   │   │   └── health.py           GET /api/health
│   │   │   ├── models/
│   │   │   │   ├── domain.py           Internal domain types (Person, Employment, …)
│   │   │   │   └── api.py              Request/response Pydantic schemas
│   │   │   ├── utils/
│   │   │   │   ├── cache.py            Simple file-based response cache
│   │   │   │   ├── rate_limit.py       Per-source rate limiter
│   │   │   │   ├── robots.py           robots.txt compliance checker
│   │   │   │   ├── normalize.py        Text normalization helpers
│   │   │   │   ├── sanitize.py         Input sanitization
│   │   │   │   ├── slugify.py          URL slug generation
│   │   │   │   └── logger.py           Structured logging setup
│   │   │   ├── validators/
│   │   │   │   └── search_input.py     Query parameter validation
│   │   │   ├── sources/
│   │   │   │   └── registry.py         Allowed-domain registry
│   │   │   ├── db.py                   Database init + connection
│   │   │   ├── config.py               Environment-based settings (pydantic-settings)
│   │   │   └── main.py                 FastAPI app factory + CORS middleware
│   │   ├── migrations/
│   │   │   └── 001_initial.sql         Database schema
│   │   ├── tests/                      pytest test suite
│   │   ├── pyproject.toml
│   │   └── Dockerfile
│   │
│   └── web/                    Next.js 14 frontend
│       ├── app/
│       │   ├── page.tsx                Home / search landing
│       │   ├── search/page.tsx         Search results page
│       │   └── university/page.tsx     University detail page
│       ├── components/
│       │   ├── search-bar.tsx          Search input + routing
│       │   ├── alumni-card.tsx         Individual result card
│       │   ├── results-grid.tsx        Card grid layout
│       │   ├── filter-panel.tsx        Sector / level filters
│       │   ├── stats-chip.tsx          Tag / badge component
│       │   ├── source-link.tsx         Verified source link
│       │   ├── loading-state.tsx       Loading skeleton
│       │   └── empty-state.tsx         Zero-results state
│       ├── lib/
│       │   ├── api-client.ts           Backend API wrapper
│       │   ├── formatters.ts           Display formatting helpers
│       │   └── query-state.ts          URL ↔ filter state sync
│       └── next.config.js              Static export config (basePath for GitHub Pages)
│
├── packages/
│   └── shared/                 Shared TypeScript types (frontend only)
│
├── docs/                       GitHub Pages demo (static HTML, no build required)
│   └── index.html              Self-contained interactive demo
│
├── Makefile                    Developer task runner
└── supabase/                   (Optional) Supabase schema for cloud deployment
```

---

## Database schema

```sql
institutions        id, name, slug, country, wikidata_id
people              id, full_name, source_url, source_type, confidence
employment_history  person_id → company_id, title, title_level, sector, is_current
education_history   person_id → institution_id, start_year, end_year
companies           id, name, slug, sector, domain
source_documents    url, source_type, retrieved_at, person_id
```

SQLite for local development. The schema is intentionally Postgres-compatible — swap the `database_url` env var to migrate.

---

## API endpoints

All routes are read-only (`GET`). Interactive docs auto-generated at `http://localhost:8000/docs`.

| Endpoint | Description |
|---|---|
| `GET /api/search?university=UNC+Chapel+Hill` | Main search — returns ranked alumni list |
| `GET /api/universities?q=north+carolina` | Typeahead / institution lookup |
| `GET /api/universities/{slug}` | Institution detail + aggregate stats |
| `GET /api/alumni/{id}` | Single person record |
| `GET /api/companies` | Company index |
| `GET /api/stats` | Global platform stats |
| `GET /api/sources` | List of active data sources |
| `GET /api/health` | Liveness check |

**Example response** (`/api/search?university=UNC Chapel Hill&title_level=c_suite`):

```json
{
  "results": [
    {
      "person": {
        "full_name": "Chuck Robbins",
        "source_type": "wikidata",
        "source_url": "https://www.wikidata.org/wiki/Q...",
        "confidence": 0.99
      },
      "employment": {
        "title": "Chairman & CEO",
        "company": { "name": "Cisco Systems", "sector": "Technology" },
        "is_current": true,
        "title_level": "c_suite"
      }
    }
  ],
  "total": 47,
  "institution": {
    "name": "University of North Carolina at Chapel Hill",
    "slug": "unc-chapel-hill",
    "wikidata_id": "Q192882"
  }
}
```

---

## Quick start

**Requirements:** Python 3.10+, Node.js 18+, `make`

```bash
# Clone
git clone https://github.com/AidanColvin/Mapping-Alumni.git
cd Mapping-Alumni

# Install everything (backend venv + frontend node_modules)
make install

# Terminal 1 — API server
make dev-api          # → http://localhost:8000  (Swagger UI at /docs)

# Terminal 2 — Frontend
make dev-web          # → http://localhost:3000

# Run tests
make test

# Clean up
make clean
```

### Environment variables

Copy `.env.example` to `.env` and edit as needed (or export directly):

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./alumnimap.db` | SQLite path or Postgres URL |
| `CORS_ORIGINS` | `["http://localhost:3000"]` | Allowed frontend origins |
| `RATE_LIMIT_PER_MINUTE` | `30` | Max requests/min per source |
| `CACHE_DIR` | `.cache` | File-based response cache directory |
| `LOG_LEVEL` | `INFO` | `DEBUG` / `INFO` / `WARNING` / `ERROR` |

---

## Deployment

### Frontend (GitHub Pages — already live)

The `docs/index.html` demo deploys automatically on every push to `main` via GitHub's legacy branch deployment from `/docs`. No build step required.

### Frontend (full Next.js app)

```bash
cd apps/web
npx vercel --prod          # Vercel Hobby (free)
# or: npm run build && serve out/
```

The Next.js config in `apps/web/next.config.js` sets `output: 'export'` and applies a `basePath` for GitHub Pages when `NODE_ENV=production`.

### Backend API

The API is a standard ASGI app. Any platform that runs Python works:

```bash
# Fly.io (free tier)
fly launch --dockerfile apps/api/Dockerfile
fly deploy

# Railway / Render
# Point to apps/api/Dockerfile and set environment variables in the dashboard

# Local production preview
docker build -t alumnimap-api apps/api/
docker run -p 8000:8000 alumnimap-api
```

For production, set `DATABASE_URL` to a Postgres connection string and run the migration:

```bash
psql $DATABASE_URL < apps/api/migrations/001_initial.sql
```

---

## Compliance

AlumniMap is built on a strict public-data-only principle:

1. **No LinkedIn scraping.** We never touch LinkedIn, X/Twitter, or any login-gated platform.
2. **robots.txt respected.** The `robots.py` utility checks `Disallow` rules before every fetch.
3. **Rate limiting enforced.** Per-source throttling prevents hammering any single domain.
4. **No paid API dependency.** Every data source must be freely accessible to contribute data.
5. **No private data.** Only facts already published in public sources (Wikipedia, Wikidata, SEC filings, public company pages) are stored.
6. **Every fact is sourced.** Every record carries a `source_url`. Nothing is synthesized or inferred without attribution.

---

## Contributing

1. Fork the repo and create a branch: `git checkout -b feat/your-feature`
2. Make changes — backend in `apps/api/`, frontend in `apps/web/`
3. Run `make test` to confirm tests pass
4. Open a pull request with a description of what the change does and why

Adding a new data source means implementing the adapter interface in `apps/api/app/adapters/` and registering the domain in `apps/api/app/sources/registry.py`.

---

## License

[Apache 2.0](LICENSE) — free to use, modify, and deploy. Attribution appreciated.
