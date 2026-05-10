#!/usr/bin/env bash
set -euo pipefail
echo "==> Apply migrations to ephemeral Postgres..."
# Postgres service container provides $PGHOST, $PGPORT, $PGUSER, $PGPASSWORD.
if [ -d migrations ]; then
  for f in migrations/*.sql; do
    psql -f "$f"
  done
fi
echo "==> drizzle-kit check (if configured)..."
if [ -f drizzle.config.ts ] || [ -f drizzle.config.js ]; then
  npx drizzle-kit check || true # advisory in v1
fi
echo "==> Run pg-tap tests..."
if find . -name "*.test.sql" | grep -q .; then
  pg_prove --recurse --pset tuples_only=1 --schema test \
    $(find . -name "*.test.sql")
fi
