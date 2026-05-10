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
npm run typecheck --if-present || npx tsc --noEmit
echo "==> Test..."
npm test --if-present
echo "==> Coverage..."
npm run test:coverage --if-present
echo "==> Build..."
npm run build --if-present
