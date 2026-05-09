# Enterprise CI Template Design

- **Status:** Draft, pending implementation plan
- **Date:** 2026-05-09
- **Author:** Nischal (`@nischal94`)
- **Scope:** Future repos created on the `nischal94` GitHub account
- **Non-goals:** Retroactive migration of existing repos; multi-org governance; GHEC-specific features

## 1. Problem

There is no consistent, enterprise-grade CI baseline applied to new repos. Each
new project either inherits an outdated copy of `repo-template` or starts from
scratch. The CI checks that exist are not uniformly required by branch
protection, so checks run but do not block merges. There is no mechanism that
keeps repos aligned with policy over time.

The goal is a template system that, on day zero of any new project, produces a
repo that:

- Passes a stated supply-chain bar ([SLSA Level 3](https://slsa.dev/spec/v1.0/levels), [OpenSSF Scorecard](https://scorecard.dev) ≥ 7).
- Auto-detects its stack and runs appropriate CI without per-project wiring.
- Has its branch protection enforced server-side, before any human can push.
- Stays compliant over time via continuous policy auditing.

## 2. Solution overview — two layers

### Layer 1 — `nischal94/.github` (universal, auto-applied)

A repo with the magic name `.github`. GitHub auto-supplies *community files*
(SECURITY.md, CODE_OF_CONDUCT.md, PR/issue templates, CODEOWNERS) from this
repo to every other repo on the account with no copying. Workflows are *not*
auto-supplied — they're stored here as the canonical source and propagated to
each repo via the GitHub App's sync mechanism on repo creation, with the
weekly drift audit catching anything that falls behind.

Owns:

- Canonical universal CI workflows (apply to every repo regardless of stack).
- Default community files (auto-supplied).
- The continuous policy-audit workflow.
- The GitHub App configuration that handles server-side enforcement and
  workflow sync.

### Layer 2 — `nischal94/repo-template` (opt-in scaffold)

Clicked at `gh repo create --template`. Owns:

- The project skeleton (README/ARCHITECTURE/RUNBOOK/THREAT_MODEL/CLAUDE.md
  stubs, lefthook config, devcontainer, Makefile).
- Stack-detected CI workflows (Node, Python, Go, Shell, Docker, SQL, E2E,
  Docs).
- Stack-detected CD workflows (Vercel, Fly, Railway).
- The bootstrap script for stack scaffolding.

### Why two layers

- One source of truth for universal policy: a fix to `gitleaks` propagates to
  every repo on the next push, no PR-per-repo.
- Existing repos benefit from Layer 1 without ever being modified.
- Layer 2 stays opinionated and focused on *new* projects; it doesn't have to
  hedge against the diversity of past repos.

## 3. Layer 1 — `.github` repo

### 3.1 Mandatory workflows (block merge on every repo)

| Workflow | Purpose |
| --- | --- |
| `gitleaks.yml` | Secret scanning on diffs and full history |
| `dependency-review.yml` | GitHub-native PR-diff CVE check |
| `osv-scanner.yml` | Full lockfile CVE scan via [OSV](https://osv.dev) |
| `codeql.yml` | Per-PR CodeQL (replaces weekly Default Setup) |
| `actionlint.yml` | Workflow YAML lint |
| `pin-actions.yml` | Fails if any `uses:` references a tag/branch instead of a SHA |
| `pr-title.yml` | Conventional Commits enforcement on PR titles |
| `signed-commits.yml` | Requires Verified signature on every commit |
| `license-check.yml` | Blocking; allowlist-driven (see §3.5) |

### 3.2 Release-time mandatory workflows (block the release if they fail)

These do not block PRs (they have no PR trigger), but they block GitHub
Releases from being published if they fail. Their output is required for
the stated SLSA L3 / EO 14028 bar.

| Workflow | Purpose |
| --- | --- |
| `sbom-on-release.yml` | Generates [CycloneDX](https://cyclonedx.org) SBOM on every GitHub Release |
| `attest-build-provenance.yml` | Generates [SLSA build provenance](https://github.com/actions/attest-build-provenance) on every Release artifact |

### 3.2a Advisory workflows (run, don't block)

| Workflow | Purpose |
| --- | --- |
| `scorecard.yml` | Weekly OpenSSF Scorecard, uploads to Security tab |
| `harden-runner.yml` (composite) | `step-security/harden-runner` block-egress wrapper called by every other workflow |

### 3.3 Server-side enforcement (the GitHub App)

A custom GitHub App registered at the account level, installed once across all
repos. Owns admin-grade actions that PATs cannot safely perform.

**Permissions:** `administration: write`, `metadata: read`, `contents: read`,
`pull_requests: write`.

**Triggers:**
- `repository` event, action `created` → (1) applies the canonical branch
  protection ruleset to `main` within seconds of creation (closes the
  bootstrap race) and (2) opens a PR into the new repo that materializes the
  Layer 1 universal workflow files into `.github/workflows/`.
- Schedule: weekly drift audit (see §3.4); also weekly sync of any Layer 1
  workflow updates into all repos (a single grouped PR per repo, auto-merge
  when checks pass).

**Auth:** App private key stored in `nischal94/.github` repo secret
`APP_PRIVATE_KEY`. Installation tokens are 1-hour TTL, scoped to the target
repo.

### 3.4 Drift audit

A workflow in `.github/workflows/policy-audit.yml`, scheduled `0 9 * * 0` (Sundays 09:00 UTC).

For every repo on the account, the audit:
1. Fetches branch protection on `main`.
2. Compares the required-checks list to the canonical list in
   `policies/required-checks.yml`.
3. Fetches the workflow files; verifies the universal Layer 1 set is
   present in `.github/workflows/`. (Note: GitHub's `.github` repo provides
   *workflow templates* via a discovery UI, not auto-running workflows. Each
   repo still keeps its own copies — they're materialized by either the
   bootstrap script for Layer 2 repos, or by an App-driven sync workflow for
   non-Layer-2 repos. The drift audit is what detects when these copies have
   fallen behind the canonical source in `nischal94/.github`.)
4. Verifies CodeQL is configured.
5. For *recognized* drifts (renamed check, reformatted workflow, added
   trivially-safe step) → auto-remediates via API. No issue opened.
6. For *unrecognized* drifts → updates a single rolling issue per repo titled
   `policy: drift detected on main`. Severity tiered:
   - **Critical** (missing required check, protection disabled, push allowed
     without review): immediate notification.
   - **Major** (advisory check missing, workflow signature changed): batched
     in weekly digest.
   - **Minor** (cosmetic, version bump available): listed only.
7. Auto-closes the rolling issue when its checklist is empty.

### 3.5 License allowlist

Default allowed licenses (no first-PR friction for any sane dep):

```
MIT
Apache-2.0
BSD-2-Clause
BSD-3-Clause
ISC
0BSD
Unlicense
MPL-2.0
CC0-1.0
```

**Override mechanism:** A repo can ship `LICENSE-OVERRIDE.md` with entries of
the form `<package>@<version>: <real-license> — <reason>`. The check reads it.
Provides audit trail; prevents silent "just allowlist everything" drift.

**Blocking semantics:** copyleft (GPL family, AGPL) blocks merge always.
Unknown licenses block until either the allowlist or `LICENSE-OVERRIDE.md`
covers them.

### 3.6 Universal hardening defaults

Every workflow in Layer 1 declares:

```yaml
permissions:
  contents: read           # baseline; broader perms requested per-job
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Every job calls `step-security/harden-runner` with `egress-policy: block` and
an allowlist of needed hosts.

### 3.7 Org-level settings (one-time)

Set via the GitHub App's bootstrap routine on `nischal94/.github`:
- `secret_scanning_push_protection`: enabled (rejects pushes containing
  secrets at the remote, before they land).
- Default `actions.permissions`: `selected` with allowlist of pinned upstream
  actions.
- Default workflow permissions: read-only.

### 3.8 Community files

| File | Notes |
| --- | --- |
| `SECURITY.md` | Disclosure policy and contact |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 |
| `CODEOWNERS` | `* @nischal94` |
| `dependabot.yml` | npm + pip + go modules + actions + docker, weekly, grouped |
| `PULL_REQUEST_TEMPLATE.md` | Required sections checklist |
| `ISSUE_TEMPLATE/` | bug, feature, security |
| `FUNDING.yml` | Empty stub |

## 4. Layer 2 — `repo-template` repo

### 4.1 Project skeleton

```
.devcontainer/                 # ubuntu base + common toolchains
.github/
  scripts/
    ci-node.sh                 # stack-specific CI entry points
    ci-python.sh
    ci-go.sh
    ci-shell.sh
    ci-docker.sh
    ci-sql.sh
    ci-e2e.sh
    ci-docs.sh
    cd-deploy.sh
    cd-smoke.sh
  smoke.yml                    # routes to hit post-deploy
  stacks.yml                   # OPTIONAL manifest (see §4.3)
  workflows/                   # see §4.4
docs/
  ARCHITECTURE.md
  RUNBOOK.md
  THREAT_MODEL.md
.editorconfig
.gitattributes
.gitignore
.nvmrc / .python-version / .go-version  # tool-version files
.tool-versions                 # asdf
CHANGELOG.md                   # Keep-a-Changelog
CLAUDE.md                      # Claude Code conventions
LICENSE                        # MIT default
LICENSE-OVERRIDE.md            # license-check override file (empty by default)
Makefile                       # developer-facing wrapper, NOT the CI contract
README.md                      # required-sections template
commitlint.config.js
lefthook.yml                   # local pre-commit / pre-push hooks
release-please-config.json     # opt-in semver releases
release-please-manifest.json
scripts/
  bootstrap.sh                 # one-time, post-creation scaffolding
```

### 4.2 The Makefile is *not* the CI contract

CI workflows call stack-specific scripts in `.github/scripts/`, not Make
targets. Reasoning: `make build` is meaningless for Shell/SQL/Docs and
ambiguous for Python (build wheel? install deps? mypy?). When the contract is
"every project defines `make build`," some projects ship a no-op and CI
reports green when nothing actually ran.

The Makefile stays as a developer convenience wrapper for local commands. CI
ignores it.

### 4.3 Auto-detection with manifest escape hatch

**Default (auto-detect):** Each workflow's first step checks for a marker
file. If present, the workflow runs. If not, the workflow exits cleanly.

| Workflow | Marker file(s) |
| --- | --- |
| `ci-node.yml` | `package.json` |
| `ci-python.yml` | `pyproject.toml` or `requirements*.txt` |
| `ci-go.yml` | `go.mod` |
| `ci-shell.yml` | any `*.sh` or `*.bash` |
| `ci-docker.yml` | `Dockerfile` or `compose.yml` |
| `ci-sql.yml` | `migrations/` or `*.sql` |
| `ci-e2e.yml` | `playwright.config.*` or `cypress.config.*` |
| `ci-docs.yml` | `mkdocs.yml`, `docusaurus.config.*`, or root `docs/` |
| `cd-deploy.yml` | `vercel.json` or `fly.toml` or `railway.toml` |
| `cd-smoke.yml` | runs after `cd-deploy.yml` succeeds |

**Override (`.github/stacks.yml`):** When auto-detection produces wrong
results — monorepos, vendored deps in `third_party/`, package.json present
only as a tooling config — the manifest declares explicit `{stack: path}`
mappings. When `stacks.yml` exists, it wins; auto-detection is suppressed for
the stacks it covers.

```yaml
# .github/stacks.yml example
stacks:
  - kind: node
    path: services/web
  - kind: python
    path: services/api
  - kind: go
    path: services/edge
ignore:
  - third_party/
  - examples/
```

### 4.4 v1 language profiles

Eight profiles ship in v1: **Node, Python, Go, Shell, Docker, SQL, E2E, Docs.**

Skipped in v1: Rust (no current project to validate against), IaC (tool
choice not yet made), Extension (Manifest V3 timeline still moving). Easy to
add when first real project of that kind starts.

Each profile workflow:
- Detects via §4.3 mechanism.
- Calls `step-security/harden-runner`.
- Declares minimum-needed `permissions:` block.
- Declares concurrency cancellation.
- Calls `.github/scripts/ci-<stack>.sh` for the actual work.
- Default artifact retention: 14 days. Compliance artifacts (SBOM,
  provenance): 365 days.

### 4.5 Coverage ratchet

Per-repo, per-stack:
- **Floor:** repos older than 30 days must be ≥60% line coverage on `main`.
- **Per-PR ratchet:** a PR can only ratchet up by a maximum of +2 percentage
  points (prevents flake-induced gridlock when coverage temporarily spikes).
- **Stored state:** `.github/coverage-baseline.json` updated atomically by
  the `ci-node.yml` / `ci-python.yml` / `ci-go.yml` workflows.

### 4.6 CD: OIDC mandatory, never long-lived tokens

The OIDC mandate applies *whenever `cd-deploy.yml` runs* (i.e. when the
deploy-target marker file is present). Repos with no CD don't need OIDC
configured.

`cd-deploy.yml` uses [OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect):

- Vercel: federated identity via `vercel-token-action` with OIDC.
- Fly.io: OIDC via `flyctl auth tokens issue --oidc`.
- Railway: **exception**. Railway does not yet support OIDC. Long-lived
  `RAILWAY_TOKEN` allowed, with explicit comment in workflow + entry in repo
  threat model. Re-evaluate quarterly.

`actions/attest-build-provenance` runs on every release artifact, producing a
signed [in-toto](https://in-toto.io) attestation. This is the missing piece
that makes the SLSA L3 claim real, not aspirational.

### 4.7 Bootstrap script

`scripts/bootstrap.sh` runs *once* after `gh repo create --template`. Scope is
**stack scaffolding only** — branch protection is no longer its
responsibility (the GitHub App handles that on the `repository.created`
event).

Steps:
1. Prompt for project name, license, primary language.
2. Remove unused language profile workflows from `.github/workflows/` (purely
   cosmetic; auto-detect handles it either way).
3. Initialize toolchain (`npm init -y` / `uv init` / `go mod init`).
4. Wire developer-facing Makefile targets to language-appropriate commands.
5. Write seed `LICENSE-OVERRIDE.md`, `coverage-baseline.json`, `smoke.yml`.
6. Push initial commit to `main` (which is already protected by the App).
7. Open the bootstrap PR — first CI run gates the setup itself.

### 4.8 Release automation

`release-please.yml` runs on push to `main`. Detects Conventional Commits,
maintains a release PR, cuts GitHub Releases on merge of the release PR.
Triggers `sbom-on-release.yml` and `attest-build-provenance.yml`.

## 5. Stated supply-chain bar

The template, on day one of a new repo, is designed to satisfy:

| Standard | Target | Mechanism |
| --- | --- | --- |
| [SLSA](https://slsa.dev/spec/v1.0/levels) | Level 3 | OIDC + provenance attestation + isolated builds + signed releases |
| [OpenSSF Scorecard](https://scorecard.dev) | ≥ 7 | Pinned actions, signed commits, branch protection, CodeQL, dependency review, fuzzing-aware (deferred), license check |
| [US EO 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/) | SBOM provided | CycloneDX SBOM on every release |

These are *measurable* targets. The audit workflow surfaces score regressions.

## 6. Coverage of the reference image

Every row from the reference CI table the user provided maps into this
design:

| Image row | Where it lives |
| --- | --- |
| Local: lint, tsc, npm test, test:coverage, test:sql, test:e2e | Layer 2 — `lefthook.yml` pre-push hooks |
| CI: Lint & Typecheck | `ci-node.yml` |
| CI: Unit Tests | `ci-node.yml` |
| CI: Coverage Report | `ci-node.yml` (with ratchet, §4.5) |
| CI: Drizzle Migration Check | `ci-sql.yml` (auto-detected via `migrations/` + `drizzle.config.*`) |
| CI: pg-tap SQL Tests | `ci-sql.yml` (ephemeral Postgres, `pg_prove`) |
| CI: Next Build | `ci-node.yml` (stack script handles `next build` if detected) |
| CI: Playwright E2E | `ci-e2e.yml` |
| CI / Security: npm Audit | **Removed.** Redundant with `dependency-review` + `osv-scanner` in Layer 1 |
| CI / Security: Gitleaks | Layer 1 `gitleaks.yml` |
| Post-CI/CD: Vercel Deploy | `cd-deploy.yml` (OIDC, no `VERCEL_TOKEN`) |
| Post-CI/CD: Vercel Preview Comments | Same workflow |
| Advisory: Claude PR Review | Layer 1 `claude.yml` |
| Advisory: Changelog | Layer 2 `release-please.yml` |
| Advisory / Future: CodeRabbit Review | Layer 1, opt-in via `.coderabbit.yaml` |
| Post-CI/CD / Future: Preview Smoke Check | `cd-smoke.yml` |
| CI / Future: Supabase Integration Tests | `ci-sql.yml` extension via `supabase/config.toml` |

## 7. Known limitations and accepted risks

- **Railway long-lived token.** Until Railway ships OIDC, projects deploying
  to Railway will use `RAILWAY_TOKEN` in repo secrets. Lower bar than other
  providers. Documented per-repo in the threat model.
- **DCO dropped.** Sign-off is unnecessary friction for a solo account. Will
  be re-enabled if/when external contributors join a project.
- **Auto-detect breaks on monorepos without `stacks.yml`.** First-time
  monorepo authors must read the docs and create `stacks.yml`. Mitigation:
  `bootstrap.sh` detects multi-stack repos and offers to scaffold
  `stacks.yml` on creation.
- **Drift audit assumes the App stays installed.** If the App is uninstalled
  (intentionally or accidentally), enforcement and audit both stop. The App's
  own status is itself audited by a tiny PAT-driven workflow (the only PAT
  in the system) running daily.
- **License-check first-week friction.** First push of a new project may hit
  2-3 transitive deps with unfamiliar licenses. Author either allowlists,
  swaps, or adds to `LICENSE-OVERRIDE.md`. Cost is finite.

## 8. Out of scope (explicit non-goals)

- Retroactive migration of existing 14 repos. They keep their current CI;
  Layer 1 still applies via `.github` magic-name auto-supply.
- Multi-org governance / organization-wide policies (would require GHEC).
- Per-repo dashboards, build telemetry, or central observability. Each repo's
  Actions tab is the source of truth.
- Cost allocation / chargeback (single-account, no need).
- A rules engine like [OPA](https://www.openpolicyagent.org). The 50-line
  drift audit is sufficient at this scale.

## 9. Implementation outline (handed to writing-plans next)

In rough order of dependency:

1. Register the `nischal94-policy` GitHub App. Scopes per §3.3.
2. Create `nischal94/.github` repo (currently does not exist). Seed with
   community files and the universal workflows (§3.1, §3.2).
3. Wire the App's `repository.created` listener; verify with a throwaway
   test repo.
4. Build the drift audit workflow (§3.4) and validate against existing
   repos.
5. Refactor `nischal94/repo-template` per §4: add `.github/scripts/`,
   `stacks.yml` example, eight language profile workflows, OIDC-based
   `cd-deploy.yml`, `attest-build-provenance.yml`.
6. Replace `bootstrap.sh` per §4.7 (drop branch-protection logic, keep
   stack scaffolding).
7. Add `LICENSE-OVERRIDE.md` mechanism and the `license-check.yml`
   workflow.
8. Document the system in this repo's `README.md` and link from each new
   repo's auto-generated README.

A detailed implementation plan with task ordering, dependencies, and
verification steps will be produced by the `writing-plans` skill in the next
step.
