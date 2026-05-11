# Changelog

All notable changes to this template are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

When you create a repo from this template, **note the date** below — it tells you which workflow set + docs you started from. Use [`docs/UPGRADING.md`](docs/UPGRADING.md) to pull in later improvements.

## [Unreleased]

### Security

- **Workflow hardening sweep** — every `actions/checkout` call in every workflow now sets `persist-credentials: false` (29/29 checkouts on `repo-template`, 11/11 on `nischal94/.github`). Removes the `GITHUB_TOKEN` from `.git/config` after checkout so compromised downstream steps can't read it. Codified as one of four canonical workflow hardening defaults in [`nischal94/.github`'s POLICIES.md → Workflow hardening defaults](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md#workflow-hardening-defaults).
- **Egress allowlist gaps closed** — `ci-shell` (`proxy.golang.org`, `sum.golang.org`, `storage.googleapis.com`), `ci-sql` (Ubuntu archive mirrors), `ci-go` (`vuln.go.dev` for `govulncheck`), `ci-docker` (`mirror.gcr.io`, `pkg-containers.githubusercontent.com` for Trivy DB blobs), and `ci-e2e` (Ubuntu archives for Playwright `--with-deps` + `cdn.playwright.dev`) all had `egress-policy: block` with allowlists that didn't cover endpoints the underlying scripts actually contact. Fixed before any derived repo could become the canary.
- **`force-sync.yml` script-injection fix** (on `nischal94/.github`) — workflow_dispatch `inputs.target` is now passed via `env:` and referenced as `$TARGET` in shell, never interpolated directly into `run:` blocks.

### Changed

- **Node 24 readiness** — every pinned third-party action bumped to its Node-24-ready SHA ahead of the June 2 2026 GitHub deprecation (`actions/checkout` → v5.0.0, `step-security/harden-runner` → v2.13.1, `setup-node` → v4.4.0, `setup-python` → v5.6.0, `setup-go` → v5.5.0, `dependency-review-action` → v4.7.3, `upload/download-artifact` → v4.6.2/v4.3.0, `scorecard-action` → v2.4.3, `sbom-action` → v0.20.5, `setup-ruby` → v1.265.0, `softprops/action-gh-release` → v2.4.0, `codeql/upload-sarif` → `codeql-bundle-v2.23.2`).
- **Canonical ruleset relaxed for solo-account use** — `required_approving_review_count: 0` and `require_code_owner_review: false`. CODEOWNERS files blanked to comment-only placeholders. Restores normal `gh pr merge` flow on a single-identity account where the self-review trap previously blocked every merge. Documented in [POLICIES.md → Pull request rules](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md#pull-request-rules).
- **Standard merge flow documented** — `gh pr create --fill && gh pr merge --auto --squash --delete-branch` is the everyday workflow; `gh-merge` shell function for immediate-merge after CI is green. See [POLICIES.md → Merging PRs](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md#merging-prs--use-gh-merge-not-gh-pr-merge).
- **Scorecard `publish_results: false`** — the action was failing on every push trying to publish to `api.scorecard.dev`. Findings still surface in the GitHub Security tab via SARIF upload.

### Fixed

- **`scripts/bootstrap.sh` python init** — four bugs in the one-liner that initialized Python projects:
  - shfmt format drift (case-branch labels used tabs in a 2-space-indent file)
  - Bash operator-precedence bug (`test || A && B && C` parsed as `(test || A) && B && C`, so `B && C` ran even when `test` succeeded)
  - `set -e` was silently disabled inside `|| { ... }`, masking pip/uv install failures
  - `python -m venv .venv` followed by plain `pip install` resolved to the system pip, not the venv's pip; uv was being installed globally and `.venv` sat empty
  - All four addressed; the python branch now uses an explicit `if [ ! -f pyproject.toml ]; then ... fi` block with `.venv/bin/python -m pip install` and `.venv/bin/uv init`.
- **Bootstrap workflow-cleanup glob** — added `shopt -s nullglob` so the cleanup loop doesn't iterate once with a literal `ci-*.yml` string when the directory is empty.

## [2026-04-19] — Initial baseline

### Added
- **Workflows** (`.github/workflows/`):
  - `gitleaks.yml` — diff-time secret scan
  - `pr-title.yml` — Conventional Commits enforcement
  - `actionlint.yml` — workflow YAML correctness
  - `dependency-review.yml` — pre-merge vuln/license gate on dep PRs
  - `osv-scanner.yml` — cross-ecosystem vuln scan against Google's OSV DB
  - `scorecard.yml` — OpenSSF Scorecard weekly audit + public badge
  - `claude.yml` — AI code review via @claude mentions
  - `dependabot-automerge.yml` — auto-merge for safe-by-semver Dependabot PRs
- **Community files**: `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, PR template (10-section comprehensive), bug + feature issue templates
- **Config**: `dependabot.yml` (3-group pattern + grouping for github-actions, opt-in for pip/npm/docker), `.editorconfig`, `.gitignore`, MIT `LICENSE`
- **Docs**:
  - `docs/SECURITY-OPERATIONS.md` — master operational reference (10 sections, runbooks, tier guide)
  - `docs/GETTING-STARTED.md` — orientation for new users
  - `docs/UPGRADING.md` — how derived repos pull in template improvements
- **Repo settings**: secret scanning + push protection, Dependabot security updates, allow_auto_merge, delete_branch_on_merge, branch protection on `main` (gitleaks + Validate PR title required), tag protection ruleset (`v*` pattern), CodeQL default setup, private vulnerability reporting

### Hardening defaults
- All workflows include `step-security/harden-runner@v2` in audit mode (egress logging)
- All workflow `permissions:` blocks use minimum required scopes
- Dependabot `open-pull-requests-limit: 2` (hard cap on burst)

### Notes
- Third-party actions are pinned to **major version tags** (`@v6`) for readability. Dependabot keeps tags current. For SHA-pinning, see [`docs/SECURITY-OPERATIONS.md §7.2`](docs/SECURITY-OPERATIONS.md#72-sha-pin-third-party-actions).
- This is the **3-group default**: security + minor-patch grouped, majors stay individual. Switch to FULL grouping for dormant repos per [`docs/SECURITY-OPERATIONS.md §5.2`](docs/SECURITY-OPERATIONS.md#52-alternative-full-grouping-pattern-for-dormant-repos).

[Unreleased]: https://github.com/nischal94/repo-template/compare/2026-04-19...HEAD
