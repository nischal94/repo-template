#!/usr/bin/env bash
# Run once after `gh repo create --template`. Stack scaffolding only;
# branch protection is the App's responsibility per spec §4.7.
set -euo pipefail

echo "==> Project name (default: current dir):"
read -r PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-$(basename "$PWD")}

echo "==> Primary language? [node|python|go|shell|other]:"
read -r LANG

echo "==> License? [MIT|Apache-2.0|BSD-3-Clause]:"
read -r LICENSE
LICENSE=${LICENSE:-MIT}

# Initialize toolchain.
case "$LANG" in
  node)   npm init -y > /dev/null ;;
  python) test -f pyproject.toml || python -m venv .venv && pip install uv && uv init . ;;
  go)     test -f go.mod || go mod init "github.com/nischal94/$PROJECT_NAME" ;;
  shell)  echo "Shell project; no toolchain init." ;;
  *)      echo "Unknown lang; skipping toolchain init." ;;
esac

# Remove unused profile workflows for a cleaner Actions tab.
KEEP="$LANG"
for w in .github/workflows/ci-*.yml; do
  base=$(basename "$w" .yml)
  stack=${base#ci-}
  case "$stack" in
    "$KEEP"|docker|sql|e2e|docs|shell) : ;; # keep cross-cutting + chosen
    *) rm -f "$w" ;;
  esac
done

# Wire Makefile to language-specific commands.
cat > Makefile <<EOF
.PHONY: install lint test build ci

install:
EOF
case "$LANG" in
  node)   echo "	npm install" >> Makefile ;;
  python) echo "	pip install -e .[dev,test]" >> Makefile ;;
  go)     echo "	go mod download" >> Makefile ;;
  *)      echo "	@echo 'No install command configured.'" >> Makefile ;;
esac
# ... (lint, test, build, ci targets follow same pattern)

echo "==> Bootstrap complete. Initial commit:"
git add .
git commit -m "chore: initial bootstrap from nischal94/repo-template"
