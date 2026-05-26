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
