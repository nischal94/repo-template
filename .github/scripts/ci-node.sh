#!/usr/bin/env bash
# CI entry point for Node projects. Called by .github/workflows/ci-node.yml.
set -euo pipefail
echo "==> Installing deps..."
if [ -f package-lock.json ]; then
  npm ci
elif [ -f pnpm-lock.yaml ]; then
  npx pnpm i --frozen-lockfile
elif [ -f yarn.lock ]; then
  yarn install --frozen-lockfile
else
  npm i
fi
echo "==> Lint..."
npm run lint --if-present
echo "==> Typecheck..."
# Detect typecheck script presence via `npm pkg get`, which is format-stable
# across npm 8-11 and immune to NPM_CONFIG_JSON / color settings (unlike
# parsing `npm run` output). Returns the script string in quotes when
# present, or `{}` when absent.
#
# Three branches:
#   1. Script defined → run it strictly. No fallback that could mask
#      stricter user flags (e.g. `tsc --strict --noEmit`).
#   2. No script + tsconfig.json present → generic `tsc --noEmit` fallback.
#   3. No script + no tsconfig → genuinely no typecheck to run; skip clean.
TYPECHECK_SCRIPT=$(npm pkg get scripts.typecheck 2>/dev/null || echo "{}")
if [ "$TYPECHECK_SCRIPT" != "{}" ]; then
  npm run typecheck
elif [ -f tsconfig.json ]; then
  npx tsc --noEmit
else
  echo "==> No typecheck script and no tsconfig.json; skipping typecheck."
fi
echo "==> Test..."
npm test --if-present
echo "==> Coverage..."
npm run test:coverage --if-present
echo "==> Build..."
npm run build --if-present
