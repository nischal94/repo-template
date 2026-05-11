#!/usr/bin/env bash
# Shell CI: shellcheck + shfmt formatter enforcement.
#
# Two scoping modes:
#
#   1. Diff-scoped (PR context): when CHANGED_SHELL_FILES is set and non-empty,
#      only those files are checked. This is what should fire on PRs so a
#      docs-only PR is never failed by pre-existing drift in an unrelated .sh.
#
#   2. Full-tree (push / no PR base): when CHANGED_SHELL_FILES is unset or
#      empty, every .sh in the current directory is checked. This is the
#      baseline enforcement on push-to-main and the safe default for any
#      other caller.
#
# The workflow (.github/workflows/ci-shell.yml) is responsible for computing
# CHANGED_SHELL_FILES from the PR diff and exporting it before invoking this
# script.

set -euo pipefail

# Common exclusions (vendored / VCS dirs that should never be touched).
EXCLUDE_PATHS=(-not -path "./node_modules/*" -not -path "./.git/*")

if [ -n "${CHANGED_SHELL_FILES:-}" ]; then
  # Diff-scoped: filter the caller-supplied list down to files that still
  # exist and live under this stack path. Caller passes newline-separated
  # paths relative to repo root; ci-shell.yml's per-path loop has already
  # `cd`'d into the stack path, so we re-filter here for safety.
  mapfile -t FILES < <(
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      case "$f" in
      node_modules/* | .git/*) continue ;;
      esac
      printf '%s\n' "$f"
    done <<<"$CHANGED_SHELL_FILES"
  )

  if [ "${#FILES[@]}" -eq 0 ]; then
    echo "==> No .sh files changed under this stack path; skipping shellcheck/shfmt."
    exit 0
  fi

  echo "==> shellcheck (${#FILES[@]} changed file(s))..."
  shellcheck "${FILES[@]}"
  echo "==> shfmt --diff (${#FILES[@]} changed file(s))..."
  shfmt --diff "${FILES[@]}"
else
  echo "==> shellcheck (full tree)..."
  find . -name "*.sh" "${EXCLUDE_PATHS[@]}" \
    -exec shellcheck {} +
  echo "==> shfmt --diff (full tree)..."
  find . -name "*.sh" "${EXCLUDE_PATHS[@]}" \
    -exec shfmt --diff {} +
fi
