# Enterprise CI Template Design

- **Status:** Draft v0.2, pending implementation plan
- **Date:** 2026-05-09 (v0.1) · 2026-05-09 (v0.2 revision)
- **Author:** Nischal (`@nischal94`)
- **Scope:** Future repos created on the `nischal94` GitHub account
- **Non-goals:** Retroactive migration of existing repos; multi-org governance; GHEC-specific features

## Changelog

### v0.2 — 2026-05-09

Material revisions in response to two independent review passes:

- **§3.3 enforcement model**: replaced event-driven `repository.created`
  webhook (which does not fire for user-owned repos) with a polling-based
  scheduled workflow. App installation tokens minted at job start; no PAT
  used for cross-repo writes.
- **§3.3a rulesets API**: adopted as primary mechanism (vs legacy
  branch-protection-rules) for cleaner schema and bypass-actor support.
  Verified against [GitHub docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) — only "Required reviewers" (team-based) is
  unavailable on user-owned repos; signed-commits and other rules work.
- **§3.3b workflow decomposition**: split into four workflows
  (`enforce-on-poll`, `scaffold-on-poll`, `drift-audit`, `force-sync`)
  rather than three; sync is decoupled from policy enforcement.
- **§3.3c App private key**: documented the trust-root question honestly.
  External secret manager (1Password Connect / AWS KMS) is *one* option;
  the alternative is environment-protection-with-required-reviewer on
  `nischal94/.github`. Both are explicitly characterized.
- **§3.3d race window**: corrected from "5-minute worst case" to
  "typically 5-30 min, unbounded under load" per GitHub's own scheduled
  workflow caveats. Added optional webhook-receiver fallback for projects
  that need sub-minute response.
- **§3.4 drift audit**: auto-remediation now opens PRs, never direct-pushes.
- **§3.5 license-check**: clarified bot bypass via `bypass_actors` only
  works for the App's own pushes; documented the Dependabot-specific
  approach.
- **§4.5 coverage ratchet**: resolved floor/cap contradiction. Floor is
  enforced after 30 days of activity; cap of +2pp/PR applies only after
  the floor is met.
- **§4.6 CD/SLSA**: specified `slsa-framework/slsa-github-generator` for
  Build L3, with required `slsa-verifier` step on consumer side and
  documented tag-pinning exception (conflicts with general SHA-pin rule).
- **§4.4 shell auto-detection**: tightened from "any *.sh file present"
  to "shell is the primary language OR explicit `stacks.yml` opt-in."
- **§3.6 → §4.x harden-runner**: moved from Layer 1 to Layer 2 since
  egress allowlists are stack-specific.
- **§7 limitations**: rewrote the migration-to-org section honestly.
  Conversion uninstalls all GitHub Apps, voids OAuth tokens, requires
  manual Actions re-enablement, and is one-way. No "easy upgrade."

### v0.1 — 2026-05-09

Initial draft. Findings from review (now addressed in v0.2):
event-webhook misuse on user accounts; SLSA L3 misclaim;
single-point-of-compromise app key; ambiguous cross-repo token strategy;
coverage ratchet contradiction; harden-runner egress allowlist scope
mismatch; shell auto-detection too broad; signed-commits blocking
Dependabot; silent-direct-push drift remediation.

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

### 3.3 Enforcement architecture

A custom GitHub App registered at the user account level, installed once
across all repos. Owns admin-grade actions that PATs cannot safely perform.

**Permissions:** `administration: write` (rulesets API),
`metadata: read`, `contents: write` (for sync PRs), `pull_requests: write`,
`issues: write` (for drift-audit issues), `actions: read`.

**Why polling, not webhooks:** GitHub's `repository` webhook event with
action `created` does not fire for user-owned repos — it is documented as
organization-only. `nischal94` is a user account (see §7 for the rationale
behind staying a user account). Polling is the only mechanism that works on
this account shape today.

#### 3.3a Rulesets API as primary enforcement mechanism

Branch protection is applied via the [rulesets API](https://docs.github.com/en/rest/repos/rules)
(`POST /repos/{owner}/{repo}/rulesets`), not the legacy
`branch-protection-rules` API. Reasons:

- **Bypass actors** are first-class — explicit list of integrations or
  roles allowed to bypass specific rules. (Note: this is *narrower* than
  it sounds — see §3.5 for what bypass-actors actually does and doesn't
  resolve.)
- **Multiple rulesets per repo** can be composed (one for `main`, another
  for `release/*`).
- **Cleaner JSON schema** than the legacy API.
- **Forward-compatibility** with org-mode is partial — at the rule
  definition level the schema is the same, but org-mode adds the
  ability to define one ruleset that targets many repos via patterns.
  See §7 for the honest migration story.

**Verified user-account compatibility** (against [GitHub docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)):
the only rule documented as unavailable on user-owned repos is
"Required reviewers" (team-based — user accounts have no teams). All
other rule types (signed-commits, status checks, push restrictions, file
paths, linear history, deployments, signature verification, restrict
deletions, restrict force-pushes) work on user-owned repos.

The canonical ruleset for `main` includes:
- `required_signatures`
- `required_status_checks` (the Layer 1 mandatory list from §3.1)
- `pull_request` (1 approving review, dismiss stale, require code-owner
  review)
- `deletion` (block branch deletion)
- `non_fast_forward` (block force-push)
- `creation` (require PR via `bypass_actors` for the App itself)

Smoke-tested on a throwaway user-owned repo before declaring the schema
final.

#### 3.3b Four workflows in `nischal94/.github`

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `enforce-on-poll.yml` | `*/5 * * * *` cron + manual dispatch | Apply canonical ruleset to new repos |
| `scaffold-on-poll.yml` | `workflow_run` after `enforce-on-poll` succeeds | Materialize Layer 1 workflows into the new repo via PR |
| `drift-audit.yml` | Weekly cron + manual dispatch | Detect ruleset/workflow drift, open PRs (never direct-push) |
| `force-sync.yml` | `workflow_dispatch` only | Manual escape hatch — re-apply ruleset and re-sync workflows for a specific repo |

Splitting `enforce-on-poll` from `scaffold-on-poll` decouples policy
(ruleset application — security-critical) from file delivery (workflow
sync — best-effort idempotent). A transient git error during scaffolding
no longer rolls back ruleset application, and vice versa.

All four workflows declare:

```yaml
concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false
permissions:
  contents: read
  id-token: write   # for OIDC to the secret manager
```

`cancel-in-progress: false` is intentional — overlapping `*/5` polls
must serialize, never cancel each other (would corrupt state).

#### 3.3c App private key — the trust-root question

The App's private key is the root of trust for all enforcement. Where
it lives determines who can compromise the entire system.

Three placements considered, with their trust roots stated honestly:

**Option 3.3c-A — Repo secret in `nischal94/.github`** (the v0.1 design):
trust root is "anyone who can land a workflow change in `nischal94/.github`,
including via a malicious PR using `pull_request_target`." Rejected.

**Option 3.3c-B — External secret manager (1Password Connect / AWS KMS /
GCP Secret Manager) pulled at runtime via OIDC**: trust root is
"GitHub's OIDC issuer + the trust policy on the secret manager." The trust
policy must pin both the repo and the environment, e.g.:

```json
{
  "sub": "repo:nischal94/.github:environment:prod-app-key",
  "aud": "https://github.com/nischal94"
}
```

The workflow declares `environment: prod-app-key` to mint a token whose
OIDC claim includes that environment binding. The environment must require
*manual approval* before the deployment runs.

**Honest caveat**: as a solo dev, "manual approval by self" is a
self-approval. GitHub's environment-protection feature lets you require
approval but cannot prevent self-approval on a personal account. So the
environment gate becomes a "click-to-approve" speed bump, not a true
two-person rule. It still buys real value: it converts compromise from
"silent push to main steals the key" to "attacker must trigger the
workflow and click the approval button while logged in as you."

**Option 3.3c-C — Repo secret + protected environment + branch protection
on `nischal94/.github`** (no external manager): trust root is
"push-to-main on `nischal94/.github`, gated by required PR review +
required signed commits + required status checks." Solo-dev limitation:
required-PR-review with self-approval-disabled is not enforceable on
personal accounts.

**Decision for v0.2**: ship 3.3c-B. The environment+OIDC approach is
the strongest available on a user account today. The "self-approval"
caveat is documented in §7 as a known limitation. If you ever convert
to org mode, replace the environment gate with required-reviewer-not-self
on the org's `.github` repo (which orgs *can* enforce).

#### 3.3d Race window characterization

GitHub's [scheduled workflow documentation](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
is explicit: cron schedules "may be delayed during periods of high load"
and run time "is not guaranteed." Community-observed delays of
15–60 minutes are routine, especially at top-of-hour.

**Honest characterization**:
- Best case: ~30 seconds (cron fires on time, App runs fast).
- Typical case: 2–10 minutes.
- Worst case: 60+ minutes during peak hours.
- **The race window is unbounded by GitHub's own SLA.**

For solo work, this is acceptable: you do not push secrets to a brand-new
repo in its first hour. You are still scaffolding.

For projects that require sub-minute response (e.g., a future product
where any user-facing repo must be protected on creation), an opt-in
**webhook receiver** is documented as future work:
- A small Cloudflare Worker / Fly app receives GitHub repo creation
  webhooks (which *do* fire for the App at the user-account level — the
  App receives them even when the repo isn't org-owned).
- The Worker fires a `repository_dispatch` event back to
  `nischal94/.github`, triggering `enforce-on-poll` immediately.
- Sub-minute response in exchange for one tiny external service.

This is **not in v1**. Polling is sufficient until you have a project
that demonstrably needs the tighter window.

#### 3.3e State management

A single JSON file at `nischal94/.github/state/configured-repos.json`,
committed by the App on each successful enforcement run. Schema:

```json
{
  "schemaVersion": 1,
  "lastSyncAt": "2026-05-09T12:34:56Z",
  "appInstallationId": 12345678,
  "repos": {
    "owner/repo-name": {
      "rulesetId": 999,
      "configuredAt": "2026-05-09T12:34:56Z",
      "rulesetVersion": "v3",
      "scaffoldedWorkflowsVersion": "v3"
    }
  }
}
```

**Authoritative source for "what repos exist"**: `GET /installation/repositories`
(the App's installation manifest), NOT the state file. The state file is
*cache only* — used to skip redundant API calls, never to determine policy.

**Failure modes addressed:**

| Failure mode | Mitigation |
| --- | --- |
| Two `*/5` runs overlap | `concurrency: enforce-on-poll, cancel-in-progress: false` serializes them |
| Repo deleted then recreated with same name | State file entry stale; reconciliation against `GET /installation/repositories` detects mismatched `rulesetId`, re-applies |
| Repo transferred *out* | Detected as missing from installation manifest; entry archived (not deleted, for audit) |
| Repo transferred *in* | Detected as new; ruleset applied via merge (PUT semantics) on top of any existing rules |
| State file corrupted | App fails loudly with `policy: state-file-corrupt` issue; recovery via `force-sync` against full installation |
| App uninstalled and reinstalled | New installation ID detected; existing rulesets retain old `actor_id` references; `force-sync` rewrites bypass-actors |
| Concurrent state file commit conflicts | Run uses `git pull --rebase` before commit; on conflict, retries with backoff; after 3 failures, fails loudly |

### 3.4 Drift audit

`drift-audit.yml`, scheduled `0 9 * * 0` (Sundays 09:00 UTC), plus
manual dispatch.

For every repo in the App's installation manifest, the audit:

1. Fetches the active ruleset on `main`.
2. Compares to the canonical ruleset definition in
   `policies/canonical-ruleset.json`.
3. Fetches the Layer 1 workflow files in `.github/workflows/`; verifies
   each matches the canonical version (by SHA) in
   `nischal94/.github/.github/workflows/`.
4. For *recognized* drifts (renamed required check, reformatted workflow,
   trivially-safe added step) → opens an auto-mergeable PR against
   `main` of the affected repo with the canonical content. **Never
   direct-pushes.** PR auto-merges when the repo's own checks pass;
   otherwise sits open for human review.
5. For *unrecognized* drifts → updates a single rolling issue per repo
   titled `policy: drift detected on main`. Severity tiered:
   - **Critical** (missing required check, protection disabled, push
     allowed without review): immediate notification via dispatch to
     `nischal94/.github` issues.
   - **Major** (advisory check missing, workflow signature changed):
     batched in the weekly issue.
   - **Minor** (cosmetic, version bump available): listed only.
6. Auto-closes the rolling issue when its checklist is empty.

**Why auto-PR not auto-push**: a direct push to `main` from privileged
automation is a silent privileged write path. If the canonical policy
itself has a bug, it propagates instantly to every repo without review.
PRs preserve the audit trail and let the repo's own checks gate the
remediation. The "auto-merge when checks pass" behavior keeps the
ergonomics close to direct-push for the common case.

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

**Bot interaction with required-signed-commits and required-status-checks**:

The naive plan ("add Dependabot to `bypass_actors` to let it skip
signed-commits") does NOT work. `bypass_actors` with `actor_type: Integration`
only bypasses rules for pushes by *that App's installation token*.
Dependabot pushes as `dependabot[bot]` (its own App, different installation),
so adding "Dependabot" to *this* App's bypass list is a no-op.

The actual mechanisms:

| Bot | Signed commits | Status checks | Approach |
| --- | --- | --- | --- |
| Dependabot | ✅ already signed by GitHub web-flow key | ❌ runs as `dependabot[bot]`, status checks apply normally | Let PRs go through normal flow; auto-approve via Dependabot's allow-list config |
| Renovate | ✅ if configured to sign | ❌ same as Dependabot | Same |
| The custom App itself | Configurable — sign commits when authoring PRs | Bypass via `actor_type: Integration, actor_id: <our-app-installation-id>` | Bypass works because the App pushes as itself |
| Squash-merge bot (built-in) | ✅ GitHub auto-signs squash commits | n/a | No special handling needed |
| Manual web edits | ✅ GitHub auto-signs web-flow commits | n/a | No special handling needed |

So in practice, signed-commits is only an obstacle for *unsigned local
commits pushed via `git push`*. Dependabot, Renovate, web edits, and
squash-merges all produce GitHub-signed commits automatically.

### 3.6 Universal hardening defaults

Every workflow in Layer 1 declares:

```yaml
permissions:
  contents: read           # baseline; broader perms requested per-job
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**`step-security/harden-runner` placement**: in `audit` mode for Layer 1
workflows, in `block` mode with stack-specific allowlists for Layer 2
workflows. Reasoning: Layer 1 workflows are universal (e.g., `gitleaks`
runs on every repo regardless of stack), so a single allowlist would
either include every package registry under the sun (defeating egress
blocking) or break stack-specific jobs the first time they touch
PyPI/npm/proxy.golang.org. `audit` mode in Layer 1 still produces the
egress report — useful signal — without false-positive failures. The
real `block` mode lives next to the stack-aware allowlist in Layer 2's
`.github/scripts/ci-<stack>.sh` (see §4.4).

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
| `ci-shell.yml` | shell is the *primary* language (`scripts/`-only repo, or `stacks.yml` opt-in); not triggered by ambient `*.sh` files in Node/Python/Go projects |
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

Per-repo, per-stack. Two phases:

**Phase 1 — onboarding (first 30 days OR until floor met, whichever
comes first):** No upper cap on coverage increases. PRs can land
arbitrary coverage jumps. The repo is ratcheting UP toward the floor.
Regressions of more than -1pp still block merge.

**Phase 2 — steady state (after floor met):** Floor is 60% line
coverage. PRs that would drop coverage below the floor block merge.
PRs that would *raise* coverage by more than +2pp still merge — the
+2pp/PR cap was originally proposed to prevent flake-induced gridlock,
but on reflection it would also block a single PR that legitimately
adds a large new well-tested module. Replaced with: PRs can ratchet
up freely; flake protection comes from running tests with
`--retry=2` rather than from a per-PR cap.

**Stored state:** `.github/coverage-baseline.json` updated atomically
by the `ci-node.yml` / `ci-python.yml` / `ci-go.yml` workflows. Tracks
current floor, current `main` coverage, and phase.

**Why these specific numbers:** 60% is industry baseline for
"the project takes testing seriously." 30 days is enough time to
retrofit tests on a greenfield project. Both are configurable per-repo
in `.github/coverage-config.yml` if you have a reason to deviate.

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

**SLSA Build L3 via `slsa-github-generator`:** the
[`slsa-framework/slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator)
reusable workflow is what actually delivers SLSA Build L3 on
GitHub-hosted runners. `actions/attest-build-provenance` alone produces
provenance but does not satisfy L3's isolation requirements;
`slsa-github-generator` runs the build in a SLSA-compliant isolated
runner and produces the in-toto attestation.

**Two implementation caveats** that must be stated explicitly:

1. **Verifier is required to close the loop.** Generated-but-unverified
   provenance is L2-equivalent. Any consumer of release artifacts
   (the deploy step, the user pulling a binary, an automated
   integration test) must run [`slsa-verifier`](https://github.com/slsa-framework/slsa-verifier)
   before trusting the artifact. The release pipeline ships
   `slsa-verifier` invocations in `cd-deploy.yml` and documents the
   verification command in `RELEASE.md` for downstream consumers.

2. **Tag-pinning exception.** The general supply-chain rule (§3.1's
   `pin-actions`) requires every `uses:` to reference a SHA, not a
   tag. `slsa-github-generator` is the documented exception: SLSA
   requires consumers pin to a *tag* (`@v2.0.0`) so the generator's
   own provenance subject can be verified. The `pin-actions.yml`
   workflow's allowlist explicitly covers `slsa-framework/*`. This
   tradeoff is documented in the threat model.

The image's "Verifies app builds in CI" row from the user's reference
image is satisfied by the generator's build step; provenance attestation
is the additional artifact.

### 4.7 Bootstrap script

`scripts/bootstrap.sh` runs *once* after `gh repo create --template`. Scope is
**stack scaffolding only** — branch protection is no longer its
responsibility (the GitHub App's `enforce-on-poll.yml` workflow handles that
on the next poll cycle, typically within 5-30 minutes; see §3.3d).

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

### 7.1 Race window is unbounded

Per §3.3d: GitHub's scheduled workflow SLA is "best-effort, not
guaranteed." Race window between repo creation and ruleset application
is typically 5-30 min, occasionally 60+ min during peak hours. For solo
work this is acceptable (you don't push secrets to a brand-new repo in
its first hour). For projects requiring sub-minute response, the opt-in
webhook receiver path is documented as future work in §3.3d.

### 7.2 App private key trust root has a self-approval caveat

Per §3.3c: the environment-protection-with-required-reviewer pattern
mitigates "compromise of `.github/main` push access" but cannot enforce
two-person-rule on a personal account (you can self-approve your own
deployments). Treat the environment gate as a click-to-approve speed
bump, not a true authorization. If you ever convert to org mode, this
limitation goes away (orgs can require non-self approvers).

### 7.3 Migration to organization mode is a substantial project, not an upgrade

Per [GitHub's documented side effects](https://docs.github.com/en/account-and-profile/reference/personal-account-reference)
of converting a user account to an organization:

- "Any GitHub Apps installed on the converted personal account will be
  uninstalled." → The custom enforcement App must be re-registered and
  re-installed; the new installation has a different ID, which voids
  every `actor_id: <integration_id>` reference in existing rulesets
  across all repos. Every ruleset must be rewritten.
- "SSH keys, OAuth tokens, job profile, reactions, and associated user
  information will not be transferred." → All PATs regenerated, all
  SSH keys re-uploaded, all OAuth integrations re-authorized.
- "GitHub Actions requires manual re-enablement." → Every repo's
  Actions tab must be manually re-enabled.
- "Any commits made with the converted personal account will no longer
  be linked to that account." → Your contribution graph for past commits
  shows them as unattributed.
- "Organization cannot convert back to user." → The migration is one-way.

**What this means for v1**: design for staying a user account. The
"forward-compat to org" framing is *partial* — the rulesets schema is
identical, so the ruleset definitions in `policies/canonical-ruleset.json`
transfer cleanly. But the enforcement plumbing (App, state file,
workflows) must be rebuilt against the new installation. Plan it as a
1-day project, not an afternoon, when you eventually do it.

### 7.4 Railway long-lived token

Until Railway ships OIDC, projects deploying to Railway will use
`RAILWAY_TOKEN` in repo secrets. Lower bar than other providers.
Documented per-repo in the threat model. Re-evaluate quarterly.

### 7.5 Auto-detect breaks on monorepos without `stacks.yml`

First-time monorepo authors must read the docs and create `stacks.yml`
on creation. The bootstrap script detects multi-stack repos at
creation time and offers to scaffold `stacks.yml` automatically.

### 7.6 Enforcement requires the App to stay installed

If the App is uninstalled (intentionally or accidentally), enforcement
and audit both stop. The App's own installation status is itself
audited by a tiny scheduled workflow that pings
`GET /installation/repositories` daily and opens an issue against
`nischal94/.github` if it fails. This sub-audit uses a fine-grained PAT
with read-only scope on the App's metadata — the only PAT in the
system, scoped narrowly enough to be safe.

### 7.7 License-check first-week friction

First push of a new project may hit 2-3 transitive deps with unfamiliar
licenses. Author either allowlists, swaps, or adds to
`LICENSE-OVERRIDE.md`. Cost is finite, friction is concentrated in the
first week of a new project's life.

### 7.8 DCO dropped

Sign-off is unnecessary friction for a solo account. Will be re-enabled
if/when external contributors join a specific project.

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

1. Register the `nischal94-policy` GitHub App. Permissions per §3.3.
   Generate private key; store in 1Password Connect / AWS KMS / GCP
   Secret Manager (one chosen during implementation, not specified
   here). Configure OIDC trust policy per §3.3c.
2. Create `nischal94/.github` repo (currently does not exist). Seed with:
   - Community files (§3.8)
   - Layer 1 universal workflows (§3.1, §3.2)
   - `policies/canonical-ruleset.json`
   - `policies/required-checks.yml`
   - `state/configured-repos.json` (initially empty)
   - `protected environment: prod-app-key` configured with required
     reviewer + manual approval
3. Implement `enforce-on-poll.yml` (§3.3b). Smoke-test:
   - Create throwaway repo `nischal94/test-enforcement-1`
   - Wait for the next poll
   - Verify the canonical ruleset is applied via
     `gh api repos/nischal94/test-enforcement-1/rulesets`
   - Verify the state file is updated
   - Verify a second poll is a no-op
4. Implement `scaffold-on-poll.yml` (§3.3b). Smoke-test that it opens a
   PR into `test-enforcement-1` materializing the Layer 1 workflows.
5. Implement `drift-audit.yml` (§3.4). Smoke-test by manually corrupting
   the ruleset on `test-enforcement-1` and verifying drift is detected
   and a PR is opened.
6. Implement `force-sync.yml` (§3.3b). Smoke-test manual dispatch.
7. Refactor `nischal94/repo-template` per §4: add `.github/scripts/`,
   `stacks.yml` example, eight language profile workflows, OIDC-based
   `cd-deploy.yml`, `slsa-github-generator`-based release workflow.
8. Replace `bootstrap.sh` per §4.7 (drop branch-protection logic, keep
   stack scaffolding).
9. Add `LICENSE-OVERRIDE.md` mechanism and the `license-check.yml`
   workflow.
10. Smoke-test end-to-end: create `nischal94/test-fullstack-1` from the
    template, wait for the polling cycle, verify ruleset + workflows +
    bootstrap PR all land correctly.
11. Document the system in this repo's `README.md` and link from each
    new repo's auto-generated README.

A detailed implementation plan with task ordering, dependencies, and
verification steps will be produced by the `writing-plans` skill in the
next step.
