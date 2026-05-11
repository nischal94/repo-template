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
node) npm init -y >/dev/null ;;
python)
  # if-then form so set -e aborts loudly on venv/pip/uv failures.
  # `test -f X || { A && B && C; }` parses correctly but POSIX disables
  # set -e for the entire || RHS, so a mid-chain failure passes silently.
  #
  # `python -m venv .venv` does NOT alter $PATH — plain `pip install` would
  # still resolve to the system pip and install uv globally (or fail on
  # locked-down systems). Address the venv's interpreter directly so uv
  # lands inside .venv and `uv init` runs against it.
  if [ ! -f pyproject.toml ]; then
    python -m venv .venv
    .venv/bin/python -m pip install uv
    .venv/bin/uv init .
  fi
  ;;
go) test -f go.mod || go mod init "github.com/nischal94/$PROJECT_NAME" ;;
shell) echo "Shell project; no toolchain init." ;;
*) echo "Unknown lang; skipping toolchain init." ;;
esac

# Remove unused profile workflows for a cleaner Actions tab.
KEEP="$LANG"
shopt -s nullglob
for w in .github/workflows/ci-*.yml; do
  base=$(basename "$w" .yml)
  stack=${base#ci-}
  case "$stack" in
  "$KEEP" | docker | sql | e2e | docs | shell) : ;; # keep cross-cutting + chosen
  *) rm -f "$w" ;;
  esac
done
shopt -u nullglob

# Wire Makefile to language-specific commands.
# Targets map to standard tooling per language; customize after bootstrap.
cat >Makefile <<'EOF'
.PHONY: install lint test build ci

EOF

case "$LANG" in
node)
  cat >>Makefile <<'EOF'
install:
	npm install

lint:
	npm run lint

test:
	npm test

build:
	npm run build

ci: install lint test build
EOF
  ;;
python)
  cat >>Makefile <<'EOF'
install:
	pip install -e .[dev,test]

lint:
	ruff check .

test:
	pytest

build:
	python -m build

ci: install lint test build
EOF
  ;;
go)
  cat >>Makefile <<'EOF'
install:
	go mod download

lint:
	go vet ./...

test:
	go test ./...

build:
	go build ./...

ci: install lint test build
EOF
  ;;
*)
  cat >>Makefile <<'EOF'
install:
	@echo 'No install command configured.'

lint:
	@echo 'No lint command configured.'

test:
	@echo 'No test command configured.'

build:
	@echo 'No build command configured.'

ci: install lint test build
EOF
  ;;
esac

echo "==> Bootstrap complete. Initial commit:"
git add .
git commit -m "chore: initial bootstrap from nischal94/repo-template"
