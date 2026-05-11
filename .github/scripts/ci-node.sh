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
# If the project defines its own typecheck script, honor it strictly
# (don't fall back to a generic tsc invocation that could mask stricter
# flags). If not defined, fall back to `npx tsc --noEmit` ONLY when a
# tsconfig.json exists.
if npm run | grep -qE "^  typecheck$"; then
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
