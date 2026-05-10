#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing deps..."
if [ -f pyproject.toml ]; then
  pip install -e ".[dev,test]" || pip install -e .
fi
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi
if [ -f requirements-dev.txt ]; then
  pip install -r requirements-dev.txt
fi
echo "==> Lint (ruff)..."
ruff check .
echo "==> Format check (ruff format)..."
ruff format --check .
echo "==> Typecheck (mypy)..."
mypy . || true # mypy as advisory until type-clean
echo "==> Test (pytest)..."
pytest --cov --cov-report=xml --cov-report=term
echo "==> Audit (pip-audit)..."
pip-audit
echo "==> Bandit..."
bandit -r . -ll
