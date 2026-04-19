# Changelog

All notable changes to this template are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

When you create a repo from this template, **note the date** below — it tells you which workflow set + docs you started from. Use [`docs/UPGRADING.md`](docs/UPGRADING.md) to pull in later improvements.

## [Unreleased]

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
