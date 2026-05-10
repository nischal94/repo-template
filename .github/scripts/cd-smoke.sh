#!/usr/bin/env bash
set -euo pipefail
if [ ! -f .github/smoke.yml ]; then
  echo "No .github/smoke.yml; skipping smoke check."
  exit 0
fi
ROUTES=$(yq '.routes[]' .github/smoke.yml)
BASE_URL="${PREVIEW_URL:-}"
if [ -z "$BASE_URL" ]; then
  echo "::error::PREVIEW_URL not set; cannot smoke test."
  exit 1
fi
for ROUTE in $ROUTES; do
  URL="${BASE_URL}${ROUTE}"
  echo "==> GET $URL"
  HTTP=$(curl -sS -o /dev/null -w "%{http_code}" "$URL")
  if [ "$HTTP" -ge 400 ]; then
    echo "::error::$URL returned $HTTP"
    exit 1
  fi
  echo "    OK ($HTTP)"
done
