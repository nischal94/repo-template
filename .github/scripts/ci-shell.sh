#!/usr/bin/env bash
set -euo pipefail
echo "==> shellcheck..."
find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" \
  -exec shellcheck {} +
echo "==> shfmt --diff..."
find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" \
  -exec shfmt --diff {} +
