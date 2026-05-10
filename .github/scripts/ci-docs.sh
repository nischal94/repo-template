#!/usr/bin/env bash
set -euo pipefail
echo "==> Build docs..."
if [ -f mkdocs.yml ]; then
  pip install mkdocs mkdocs-material
  mkdocs build --strict
elif [ -f docusaurus.config.ts ] || [ -f docusaurus.config.js ]; then
  npm ci
  npm run build
elif [ -d docs ]; then
  echo "Plain docs/ dir, no build step. Running link-check only."
fi
echo "==> Link check..."
npx -y markdown-link-check **/*.md || true # advisory until tuned
