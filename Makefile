.PHONY: install dev-api dev-web test clean

# Install all dependencies for both frontend and backend
install:
	@echo "Installing Backend Dependencies..."
	python3.11 -m venv .venv
	.venv/bin/pip install -r apps/api/requirements.txt
	PYTHONPATH=apps/api .venv/bin/python -c "from app.db import init_db; init_db()"
	@echo "Installing Frontend Dependencies..."
	cd apps/web && npm install

# Run the FastAPI backend locally
dev-api:
	@echo "Starting FastAPI server..."
	.venv/bin/uvicorn app.main:app --app-dir apps/api --reload --port 8000

# Run the Next.js frontend locally
dev-web:
	@echo "Starting Next.js server..."
	cd apps/web && npm run dev

# Run all tests
test:
	@echo "Running Backend Tests..."
	PYTHONPATH=apps/api .venv/bin/pytest apps/api
	@echo "Frontend tests are currently empty."

# Clean up build artifacts and caches
clean:
	rm -rf .venv
	rm -rf apps/web/node_modules
	rm -rf apps/web/.next
	find . -type d -name "__pycache__" -exec rm -r {} +
	@echo "Cleaned environment."
