.PHONY: install up down migrate seed test lint clean

install:
	pip install -e '.[dev]'

up:
	docker compose up -d
	@echo "postgres: 5432 (dev) / 5433 (test)"

down:
	docker compose down -v

migrate:
	alembic upgrade head

seed:
	python -m nutrikids.db.seed

test:
	TEST_DATABASE_URL=postgresql+psycopg2://nutrikids:nutrikids@localhost:5433/nutrikids_test pytest -v -m security

lint:
	ruff check src tests

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
