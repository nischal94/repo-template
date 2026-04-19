# repo-template

Personal template for new repositories. Click **Use this template** → **Create a new repository** to start a project with these defaults baked in.

For the master operational reference (post-creation checklist, promotion paths, runbooks, conditional Tier 5 items), see **[`docs/SECURITY-OPERATIONS.md`](docs/SECURITY-OPERATIONS.md)**.

---

## What's included

### Workflows (`.github/workflows/`)

| Workflow | Trigger | Purpose | Mode |
|---|---|---|---|
| `gitleaks.yml` | every PR + push to main | PR-time secret scan; catches custom patterns GitHub-native scanning misses | blocking |
| `pr-title.yml` | every PR | Enforces Conventional Commits; prerequisite for clean changelogs / release-please | blocking |
| `actionlint.yml` | when `.github/workflows/` changes | Workflow YAML correctness — typos, bad expressions, shell-injection patterns | advisory on first run, promote to blocking after baseline cleanup |
| `dependency-review.yml` | when manifests change | Pre-merge gate on vulnerable / restrictive-license deps | blocking on `high` severity |
| `osv-scanner.yml` | when manifests change + weekly | Cross-ecosystem vuln scan against OSV database; complements Dependabot | blocking |
| `scorecard.yml` | weekly + push to main | OpenSSF Scorecard supply-chain audit (18+ checks); SARIF + public badge | informational |
| `claude.yml` | `@claude` mention in PRs/issues | AI code review on demand; requires `ANTHROPIC_API_KEY` secret | on-demand |

All workflows ship with **`step-security/harden-runner`** in audit mode for egress logging.

### Community files

- `SECURITY.md` — vulnerability disclosure policy (points to GitHub Private Vulnerability Reporting).
- `CONTRIBUTING.md` — branch naming, PR expectations, security-reporting pointer.
- `.github/CODEOWNERS` — auto-routes review requests.
- `.github/PULL_REQUEST_TEMPLATE.md` — keeps PR descriptions consistent.
- `.github/ISSUE_TEMPLATE/` — bug + feature templates.
- `.github/dependabot.yml` — `github-actions` ecosystem enabled with grouping; pip/npm/docker blocks pre-configured (commented) with grouping built in.
- `.editorconfig` — cross-editor indentation/EOL consistency.
- `LICENSE` — MIT.

---

## Post-creation checklist (TL;DR)

The full version with rationale lives in [`docs/SECURITY-OPERATIONS.md §2`](docs/SECURITY-OPERATIONS.md#2-post-creation-checklist-per-repo). The condensed version:

1. **Settings → Code security**: enable private vulnerability reporting, Dependabot alerts + security updates, secret scanning, push protection, CodeQL default setup.
2. **Settings → Branches**: add protection on `main` requiring `gitleaks` + `Validate PR title` + project CI checks, 1 approval, conversation resolution, no force-push.
3. **Settings → Tags**: add rule for pattern `v*` (prevents release-tag tampering).
4. **Settings → Actions**: require approval for first-time contributors.
5. Edit `.github/dependabot.yml` to uncomment the `pip` / `npm` / `docker` ecosystem block matching your stack (grouping is pre-configured).
6. (If using Claude review) `gh secret set ANTHROPIC_API_KEY -R <owner>/<repo>`.
7. (Optional) Add Scorecard badge to README after first weekly run completes.

---

## Tiered hardening additions

| Tier | Items | When to add |
|---|---|---|
| **Tier A** (this template) | gitleaks, pr-title, actionlint, dep-review, OSV-Scanner, Scorecard, harden-runner audit, Dependabot grouping | Default for every new repo |
| **Tier B** | bandit (Python SAST), pip-audit, trivy (image+fs), eslint-plugin-security, npm audit, Codecov, image-CVE Trivy | Repos with real users or shipped artifacts |
| **Tier C** | cosign signing, SBOM, SLSA provenance, release-please | Repos publishing consumed artifacts (npm/pypi/docker hub/etc) |
| **Tier D — Hardening polish** | SHA-pin via pinact, harden-runner block-mode allow-list, required signed commits, zizmor one-time audit | Add as the repo matures or after a security incident |

Full descriptions and configuration examples in [`docs/SECURITY-OPERATIONS.md §7-§8`](docs/SECURITY-OPERATIONS.md#7-tier-4-hardening-additions).

---

## AI code review

Two complementary options:

- **`claude.yml`** (in this template) — Claude Code Action, triggered by `@claude` mentions. Per-repo workflow, needs `ANTHROPIC_API_KEY`.
- **CodeRabbit / Greptile** (GitHub Apps, install once at account level) — auto-comments on every PR, no per-repo config. Install via:
  - `https://github.com/apps/coderabbitai`
  - `https://github.com/apps/greptileai`

The two layers are complementary: Claude responds to specific asks; CodeRabbit/Greptile provide passive review on every PR.

---

## Notes

- Third-party actions are pinned to **major version tags** (`@v6`) for readability. Dependabot keeps tags current. For SHA-pinning, see Tier D in `docs/SECURITY-OPERATIONS.md`.
- The Dependabot config uses **grouping** (`groups:`) to collapse update bursts — instead of N separate weekly PRs, you get 1-3 grouped weekly PRs per ecosystem.
