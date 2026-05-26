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
