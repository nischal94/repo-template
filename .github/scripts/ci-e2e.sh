#!/usr/bin/env bash
set -euo pipefail
if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
  echo "==> Install Playwright browsers..."
  npx playwright install --with-deps
  echo "==> Run Playwright..."
  npx playwright test
elif [ -f cypress.config.ts ] || [ -f cypress.config.js ]; then
  echo "==> Run Cypress..."
  npx cypress run
else
  echo "No E2E config detected; skipping."
fi
