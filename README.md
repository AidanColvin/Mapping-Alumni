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
