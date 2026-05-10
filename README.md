# repo-template

Template repository for new projects on `github.com/nischal94`. Click **Use this template** → **Create a new repository** to start with the full Layer 1 + Layer 2 baseline pre-installed.

## What you get on day zero

Two layers of CI, both delivered automatically:

- **Layer 1 — universal security baseline.** Auto-scaffolded into every enrolled repo by the [`nischal94-policy` GitHub App](https://github.com/settings/apps/nischal94-policy) (see [`nischal94/.github`](https://github.com/nischal94/.github)). Includes secret scanning, dependency review, vulnerability scanning, action pinning, license check, PR-title enforcement.
- **Layer 2 — stack-specific CI/CD.** Comes from this template. Detects your project's primary language and runs the right workflows: lint, type-check, test, build, optional CD + release pipeline + SBOM.

Plus the canonical branch ruleset (signed commits, PR review, no force-push, required-status-checks) is auto-applied by the App after the scaffold PR merges. **No manual branch protection setup required.**

## Quick start

```bash
gh repo create nischal94/<your-project> --template nischal94/repo-template --public
gh repo clone nischal94/<your-project> && cd <your-project>
bash scripts/bootstrap.sh
git push origin main
```

`bootstrap.sh` asks for project name, primary language (`node|python|go|shell|other`), and license. It then:
- Initializes the toolchain for your language (`npm init`, `python -m venv`, `go mod init`, etc.)
- Removes language-profile workflows for languages you're not using
- Generates a `Makefile` wired to your stack's commands

After your first push: add the new repo to `nischal94/.github`'s `SCAFFOLD_ALLOWLIST` (see `.github/workflows/scaffold-on-poll.yml`). Within ~5 minutes the App opens a scaffold PR; merge it, and the canonical ruleset auto-applies on the next cron tick.

## What's included in this template

### Layer 2 stack-specific workflows (`.github/workflows/`)

| Workflow | Triggers when | Calls |
|---|---|---|
| `ci-node.yml` | `package.json` present (or `stacks.yml: kind: node`) | `bash .github/scripts/ci-node.sh` |
| `ci-python.yml` | `pyproject.toml` or `requirements*.txt` present | `bash .github/scripts/ci-python.sh` |
| `ci-go.yml` | `go.mod` present | `bash .github/scripts/ci-go.sh` |
| `ci-shell.yml` | shell is the primary language (no other lang detected) | `bash .github/scripts/ci-shell.sh` |
| `ci-docker.yml` | `Dockerfile` or `compose.yml` present | `bash .github/scripts/ci-docker.sh` |
| `ci-sql.yml` | `migrations/` dir or `*.sql` files present | `bash .github/scripts/ci-sql.sh` (Postgres 16 service container) |
| `ci-e2e.yml` | `playwright.config.*` or `cypress.config.*` present | `bash .github/scripts/ci-e2e.sh` |
| `ci-docs.yml` | `mkdocs.yml`, `docusaurus.config.*`, or `docs/` dir present | `bash .github/scripts/ci-docs.sh` |

Each workflow has a `detect` job that returns clean if its language doesn't apply — no spurious failures on mismatched repos. For monorepos, `.github/stacks.yml` overrides auto-detection.

### CD + release pipeline

| Workflow | Triggers when | Notes |
|---|---|---|
| `cd-deploy.yml` | push to `main` (or manual dispatch) | Detects target via `vercel.json`, `fly.toml`, or `railway.toml`. Smoke-test job inline (post-deploy) per spec §10.6. |
| `release.yml` | push of `v*` tag | Builds release artifact, generates SLSA provenance via [`slsa-framework/slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator) (tag-pinned per spec §4.6 exception), publishes GitHub Release. |
| `sbom-on-release.yml` | release published | Generates CycloneDX SBOM via [`anchore/sbom-action`](https://github.com/anchore/sbom-action). |

### Layer 1 universal workflows (auto-scaffolded by the App)

These don't ship in the template — they get added by the scaffold PR after enrollment:

| Workflow | Purpose |
|---|---|
| `gitleaks.yml` | PR-time secret scan |
| `dependency-review.yml` | Pre-merge gate on vulnerable / unallowed-license deps |
| `osv-scanner.yml` | Cross-ecosystem vuln scan (OSV database) |
| `actionlint.yml` | Workflow YAML correctness |
| `pin-actions.yml` | Verifies all actions are SHA-pinned |
| `pr-title.yml` | Enforces Conventional Commits PR titles |
| `license-check.yml` | License allowlist enforcement |

See [`nischal94/.github/docs/POLICIES.md`](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md) for what each enforces.

### Skeleton config files

Pre-configured for the common stacks:

- `.editorconfig`, `.gitattributes` — cross-editor consistency
- `.nvmrc`, `.python-version`, `.go-version`, `.tool-versions` — toolchain version pins (used by `actions/setup-node`, `setup-python`, `setup-go`, asdf, mise)
- `lefthook.yml` — pre-commit / pre-push git hooks (lint, typecheck, test)
- `commitlint.config.js` — enforces Conventional Commits locally before push
- `release-please-config.json`, `release-please-manifest.json` — automated semver + CHANGELOG via [release-please](https://github.com/googleapis/release-please)
- `Makefile` — generated by `bootstrap.sh` to match your chosen language
- `.github/stacks.yml.example`, `.github/smoke.yml.example` — copy + rename to activate

### Doc stubs (`docs/`)

- `ARCHITECTURE.md`, `RUNBOOK.md`, `THREAT_MODEL.md` — empty templates with section headers; fill in per project

### Other

- `LICENSE-OVERRIDE.md` — for cases where `license-check.yml` flags an unfamiliar license that's actually fine
- `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, `dependabot.yml`, issue/PR templates — community files (auto-supplied by GitHub via `.github` magic-name where applicable)

## Branch protection & merge flow

The canonical ruleset (auto-applied by the App after scaffold PR merge) requires:

- 1 approving review (solo accounts: use `gh pr merge --admin` for unblocking; see [`nischal94/.github`#21](https://github.com/nischal94/.github/issues/21))
- Signed commits
- All 7 Layer 1 status checks passing (`gitleaks`, `dependency-review`, `osv-scanner`, `actionlint`, `pin-actions`, `validate-pr-title`, `license-check`)
- No force-push, no deletion, no `pull_request_target` workflows

Layer 2 status checks (`ci-*` per language) are **not** in the required list — they're advisory at the canonical level. Add them to per-repo branch protection if you want them blocking.

## Cross-references

- **Operational reference**: [`docs/SECURITY-OPERATIONS.md`](docs/SECURITY-OPERATIONS.md) — runbooks, promotion paths, conditional Tier 5 items
- **Design rationale**: [`docs/specs/2026-05-09-enterprise-ci-template-design.md`](docs/specs/2026-05-09-enterprise-ci-template-design.md) (currently v0.6)
- **Implementation plan**: [`docs/specs/2026-05-09-enterprise-ci-template-plan.md`](docs/specs/2026-05-09-enterprise-ci-template-plan.md) — the task-by-task plan that built this template
- **Policy enforcement**: [`nischal94/.github`](https://github.com/nischal94/.github) — Layer 1 source + App config + `policies/canonical-ruleset.json`

## AI code review

Two complementary options:

- **`claude.yml`** workflow (auto-scaffolded with Layer 1) — triggered by `@claude` mentions in PRs/issues. Needs `ANTHROPIC_API_KEY` repo secret.
- **CodeRabbit / Greptile** (GitHub Apps, install once at account level) — passive review on every PR, no per-repo config:
  - https://github.com/apps/coderabbitai
  - https://github.com/apps/greptileai

The two layers are complementary: Claude responds to specific asks; CodeRabbit/Greptile provide passive review on every PR.
