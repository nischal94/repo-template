# Enterprise CI Template Design

- **Status:** Draft v0.5, pending implementation plan
- **Date:** 2026-05-09 (v0.1 → v0.5, same-day revisions)
- **Author:** Nischal (`@nischal94`)
- **Scope:** Future repos created on the `nischal94` GitHub account
- **Non-goals:** Retroactive migration of existing repos; multi-org governance; GHEC-specific features

## Changelog

### v0.5 — 2026-05-09

Surgical consistency pass after the v0.4 review. No architecture changes.
Eight findings (2 MAJOR, 4 MINOR, 2 NITPICK) addressed in one edit pass:

- **§6**: corrected stale "Vercel Deploy: cd-deploy.yml (OIDC, no
  VERCEL_TOKEN)" to match §4.6's honest gap framing. The "OIDC for
  Vercel" claim was a v0.1/v0.2 artifact that survived through three
  reviews undetected.
- **v0.4 changelog correction note**: clarified that v0.4 is *not* a
  downgrade of the SLSA L3 / Scorecard ≥ 7 bar — those are unchanged
  because they live in build provenance, not secret storage. Only the
  App-key trust root simplified.
- **§7.2**: clarified that GitHub session compromise allows direct
  `APP_PRIVATE_KEY` exfiltration via the secrets API or a self-approved
  workflow PR. Branch protection is a code-path gate, not a
  secrets-path gate.
- **§3.3a**: corrected `creation` rule mis-description. The rule
  restricts who can create matching branches, it does not "require PR"
  (that comes from the `pull_request` rule already listed).
- **§9 step 2**: documented bootstrap circularity. The App can't
  protect its own host repo before its first run; humans must apply
  `policies/canonical-ruleset.json` to `nischal94/.github` manually
  via `gh api` once during bootstrap.
- **§3.3c**: noted that mechanical `pull_request_target` enforcement
  via an actionlint custom rule is a future hardening; v1 ships with
  social enforcement only.
- **§3.3c**: justified annual key rotation cadence (low-frequency
  rotation matches the App's low blast radius — single account, no
  cross-tenant exposure; quarterly is conventional for shared
  enterprise systems where blast radius is broader).
- **§3.3c**: added explicit reference to v0.3's recursive-trust
  analysis where v0.4 collapses the argument to one sentence
  ("more surface, not less").
- **§5**: scoped "OIDC" qualifier in the SLSA Build L3 mechanism cell
  to "OIDC where supported (§4.6)" — Vercel/Fly/Railway/Render are
  documented gaps.
- **§3.3c item 3**: added TOTP recovery-codes storage guidance
  (password manager, not in `nischal94/.github`).
- **NITPICK fixes**: §3.3 introduces `nischal94-policy` by name on
  first mention; §3.3e failure-mode table corrected to use the
  `state-writer` shared concurrency group; v0.4 changelog's
  unverifiable "~80 lines net reduction" claim removed.

### v0.4 — 2026-05-09

**Pragmatic simplification for solo-dev scope.** v0.3 mandated 1Password
Connect + OIDC + hardware MFA on the secret-manager root, citing a
"world-class enterprise" framing. After honest reassessment for the
actual user (solo developer, no contributors, no `pull_request_target`
workflows planned), the cost/benefit shifted toward GitHub-native
hardening:

- **§3.3c rewritten**: App private key now lives in `nischal94/.github`
  as a regular Actions secret named `APP_PRIVATE_KEY`. External secret
  manager dropped. The threat model that justified Connect + hardware
  MFA (untrusted contributors with PR access) does not currently apply.
  When it does, upgrade path is documented.
- **TOTP MFA on the GitHub account login** is the new authentication
  floor. Stronger than password-only, weaker than a YubiKey. Documented
  honestly. YubiKey upgrade path noted as future improvement.
- **Branch protection on `nischal94/.github`'s `main`** carries the
  trust boundary: signed commits required, PR review required, no
  force-push, no deletion, no `pull_request_target` workflows ever.
- **Environment-protection-with-required-reviewer dropped**. On a solo
  account it was a self-approval click, not a real authorization gate.
  The honest move is to remove the false sense of security and
  document the actual trust boundary instead.
- **§7.2 rewritten** to reflect the new (simpler, more honest) trust
  model. The recursive-trust analysis collapses: there's no external
  secret manager root credential to worry about anymore; the only
  trust root is "your GitHub login + TOTP."
- **Spec is simpler overall**: the OIDC trust policy JSON, the
  1Password Connect setup flow, the recursive trust paragraphs, and
  the environment-gate caveat all leave with the v0.3 design.

**v0.5 correction**: this paragraph in the original v0.4 changelog
mis-stated the change as a "deliberate downgrade from v0.3's stated
bar (SLSA L3 / Scorecard ≥ 7)." That framing is wrong. SLSA Build L3
and OpenSSF Scorecard are both **independent of secret storage**:
- SLSA L3 lives in build provenance (`slsa-github-generator` produces
  the in-toto attestation regardless of where the App key lives).
- OpenSSF Scorecard scores supply-chain hygiene per repo and never
  inspects how secrets are stored.

What v0.4 actually downgraded is the **App-key trust root only**: from
"external secret manager protected by hardware MFA" to "GitHub repo
secret protected by branch protection + TOTP MFA." The SLSA L3 and
Scorecard ≥ 7 targets in §5 are unchanged.

### v0.3 — 2026-05-09

Surgical fixes from the third review pass. No architecture changes.

- **§3.3c**: named the secret-manager root credential as a new SPOC on
  solo accounts; mitigation = hardware MFA on the root credential.
  Reframed the OIDC JSON example as "claim values to bind in your
  trust policy," with provider-specific structure references for AWS /
  GCP / 1Password.
- **§3.3b**: added cross-workflow `state-writer` concurrency group so
  enforce-on-poll, drift-audit, and force-sync serialize their state
  file writes against each other (not just within each workflow).
- **§3.3b**: documented the invariant that enforce-on-poll never
  mutates state for already-configured repos — keeps scaffold-on-poll
  safe to overlap with the next enforce cycle.
- **§3.1**: named the license-check tool ([`github/licensed`](https://github.com/github/licensed))
  rather than treating "license-check.yml" as a label.
- **§3.7**: added `allow_auto_merge: true` to the org-level settings
  list — required for §3.4's drift-PR auto-merge to function.
- **§4.5**: clarified coverage regression handling — floor freezes at
  current value if `main` drops below; PRs always blocked on delta,
  never absolute.
- **§4.6**: replaced invented Vercel/Fly OIDC action names with honest
  language. Vercel and Fly OIDC are not yet first-party. Both providers
  are documented as **using long-lived tokens until OIDC ships
  natively**, treated as a known gap and re-evaluated quarterly.
- **§7.6**: replaced incorrect sub-audit auth (fine-grained PAT
  reading App-installation state, which doesn't work) with
  `GET /users/nischal94/installations` via a fine-grained PAT scoped
  to the user account.
- Cross-reference fixes: §3.6 → §4.1 (correct location), §3.3c → §7.2.
- Removed process-language leak from §4.6.

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
| `license-check.yml` | Blocking; allowlist-driven (see §3.5). Uses [`github/licensed`](https://github.com/github/licensed) v4 with SPDX expression mode. Per-ecosystem detection mappings live in `policies/license-config.yml`. |

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

A custom GitHub App named **`nischal94-policy`**, registered at the
user account level, installed once across all repos. Owns admin-grade
actions that PATs cannot safely perform. Subsequent prose in this spec
refers to it as "the App" or "the policy App" — same entity throughout.

**Permissions:** `administration: write` (rulesets API),
`metadata: read`, `contents: write` (for sync PRs), `pull_requests: write`,
`issues: write` (for drift-audit issues), `actions: read`.

**Why polling, not webhooks:** GitHub's `repository` webhook event with
action `created` does not fire for user-owned repos — it is documented as
organization-only. `nischal94` is a user account (see §7.3 for the rationale
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
- `creation` (restrict who can create branches matching `main` to the
  App's installation; on a fresh repo this prevents an attacker from
  pushing a brand-new `main` ref before the App applies the rest of
  the ruleset). Note: `pull_request` (above) is what enforces PR-only
  changes; `creation` is a separate guard against ref creation, not
  about PRs.

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
  group: state-writer        # SHARED across all four workflows
  cancel-in-progress: false
permissions:
  contents: write             # for state-file commits + scaffold PRs
  pull-requests: write        # for drift PRs and scaffold PRs
  issues: write               # for drift-audit issues
```

`cancel-in-progress: false` is intentional — overlapping runs must
serialize, never cancel each other (would corrupt state).

**Shared concurrency group is critical.** Each workflow alone using
`group: ${{ github.workflow }}` would only serialize *within* its own
workflow. With three workflows (`enforce-on-poll`, `drift-audit`,
`force-sync`) all writing `state/configured-repos.json`, a manual
`force-sync` dispatched mid-`drift-audit` would race the audit's commit
and risk state-file corruption. Using a single shared group named
`state-writer` is the global lock that makes all state writes serial
across the entire system.

`scaffold-on-poll` does NOT write state, so it could in principle have
its own group — but joining `state-writer` keeps the system simple
(at the cost of a small amount of unnecessary serialization, which is
fine because scaffold runs are infrequent).

**Cross-workflow invariant** (load-bearing): `enforce-on-poll` must
NEVER mutate state for repos already present in the state file. This
keeps `scaffold-on-poll` (triggered by `workflow_run` after enforce)
safe to overlap with the next `enforce-on-poll` cycle — the next
enforce sees "already configured, skip," and reconciliation that
genuinely needs to write back to state is the responsibility of
`force-sync`, never enforce.

#### 3.3c App private key — the trust-root question

The App's private key is the root of trust for all enforcement. Where
it lives determines who can compromise the entire system.

**Decision for v0.4: GitHub repo secret + GitHub-native hardening.**

The key lives in `nischal94/.github` as a regular Actions secret named
`APP_PRIVATE_KEY`. The trust boundary is GitHub itself, hardened by
specific controls listed below. No external secret manager.

**Why this and not external secret management:**

The earlier v0.3 design mandated 1Password Connect + OIDC + hardware
MFA on the secret-manager root. That defended against threats which
do not currently apply to this account: untrusted contributors with
PR-trigger access, multi-tenant secret stores, regulated-environment
audit requirements. None of these apply to a solo developer with no
collaborators, no `pull_request_target` workflows, and no enterprise
customers doing security due diligence yet.

The honest trade is: the v0.4 design is **measurably weaker** than
v0.3 against an attacker who compromises the GitHub session, but
**measurably stronger** against operational complexity (a Connect
server can fail; an external secret manager adds vendor risk; recursive
trust through additional credentials creates more surface, not less,
on a solo account — see the v0.3 changelog entry below for the full
recursive-trust analysis we collapsed into this paragraph). For the
actual threat model, this is the right trade.

**Required protections on `nischal94/.github`** (these are the trust
boundary):

1. **Branch protection on `main`** (already enforced as part of the
   canonical ruleset that the App applies to itself): signed commits
   required, 1 PR review required, no force-push, no deletion, all
   required status checks must pass.
2. **No `pull_request_target` workflows ever in this repo.** This
   trigger lets PRs from forks run with secret access — exactly the
   attack vector that justified external secret management. Documented
   here as a never-do; enforced by review discipline in v1 (the App
   canary does not detect this; humans must). **Future hardening**:
   add a custom [actionlint](https://github.com/rhysd/actionlint)
   rule or a tiny `grep` step in `enforce-on-poll` that mechanically
   rejects any workflow file in `nischal94/.github` containing
   `pull_request_target:`. Tracked as a v2 improvement; v1 ships
   without it because the social-enforcement bar is acceptable on a
   solo account where every workflow change passes through the author.
3. **TOTP MFA on the GitHub account login** (`nischal94`). Authenticator
   app such as Authy, 1Password, or Google Authenticator. Stronger than
   password-only; weaker than a hardware security key. See §7.2 for the
   honest trade and the YubiKey upgrade path. **Recovery codes**: when
   you enable TOTP, GitHub displays 16 single-use recovery codes. Store
   them in your password manager (1Password, Bitwarden, Keychain) — NOT
   in `nischal94/.github` (would defeat the point) and NOT only on the
   device that holds the TOTP authenticator (loss of that device leaves
   you locked out). If the TOTP device is later lost, recovery codes
   are the only path back to the account.
4. **Annual rotation of the App private key.** Generate a new key in
   the App settings, replace `APP_PRIVATE_KEY` in repo secrets, revoke
   the old key. ~5-minute task, calendar reminder. **Why annual and
   not quarterly**: the conventional quarterly cadence is sized for
   shared enterprise systems where blast radius covers many tenants
   and a leaked key may be unnoticed for months. Here the blast radius
   is one account, the key is consumed only by workflows in
   `nischal94/.github` (which the canary watches daily), and a leaked
   key would surface fast through the drift audit detecting unexpected
   ruleset changes. Annual is sufficient for v1 scope. If this account
   ever takes on collaborators or paying users, tighten to quarterly.

**What workflows do at runtime:**

```yaml
# In each of the four enforcement workflows in nischal94/.github:
permissions:
  contents: write     # for state-file commits + scaffold PRs
env:
  APP_ID: ${{ vars.APP_ID }}
  APP_INSTALLATION_ID: ${{ vars.APP_INSTALLATION_ID }}
  APP_INTEGRATION_ID: ${{ vars.APP_INTEGRATION_ID }}
  APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

`APP_ID`, `APP_INSTALLATION_ID`, `APP_INTEGRATION_ID` are stored as
*repository variables* (not secrets — they're not sensitive; they're
account-level identifiers that appear in every API URL). Only the
private key needs `secrets:` treatment.

**Upgrade path** (when threat model changes):

If you later have collaborators, ship a public-facing product, or take
on enterprise customers who do security due diligence, upgrade in
this order — each step independently improves security:

1. **Hardware security key (YubiKey) on GitHub login** — replaces
   TOTP. ~$50 one-time. Phishing-resistant.
2. **External secret manager** (1Password Connect or AWS KMS) — moves
   the App key off GitHub. Re-introduces the recursive-trust complexity
   v0.3 documented, so only worth doing when threat model justifies it.
3. **Convert to organization mode** — see §7.3. Substantial migration,
   but unlocks org-level rulesets, required-reviewer-not-self gates,
   and audit log retention.

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
| Two `*/5` runs overlap | shared `concurrency: state-writer, cancel-in-progress: false` (across all four state-writing workflows per §3.3b) serializes them |
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
`.github/scripts/ci-<stack>.sh` (see §4.1 for the file layout, §4.4 for
the per-profile contents).

### 3.7 Account-level and per-repo settings (one-time + per-repo)

Set via the GitHub App on the user account once, and per-repo on each
`enforce-on-poll` cycle:

**Account-level (one-time):**
- `secret_scanning_push_protection`: enabled (rejects pushes containing
  secrets at the remote, before they land).
- Default `actions.permissions`: `selected` with allowlist of pinned upstream
  actions.
- Default workflow permissions: read-only.

**Per-repo (set by App's enforcement routine):**
- `allow_auto_merge: true` — required for §3.4's drift-PR auto-merge
  to function. Without this setting, drift PRs would sit open
  indefinitely instead of merging when checks pass.
- `allow_squash_merge: true`, `allow_merge_commit: false`,
  `allow_rebase_merge: false` — squash-only merge policy (consistent
  Conventional Commit history on `main`).
- `delete_branch_on_merge: true` — automatic feature-branch cleanup.
- `web_commit_signoff_required: false` (we use Conventional Commits
  + signed-commits, not DCO sign-off — see §7.8).

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

**Regression semantics under flake.** If `main` coverage drops below
floor after a flake or merge-commit measurement issue, the floor
*freezes at the new value* until the project recovers, then re-ratchets.
PRs are always blocked on **delta** (PR-introduced regression of more
than 1 percentage point), not on absolute floor compliance once steady
state is broken. This avoids the trap where a single flake permanently
blocks every subsequent PR. Recovery rule: when `main` re-crosses the
original floor, the floor un-freezes and resumes its original value.

### 4.6 CD: OIDC where supported, long-lived tokens elsewhere (documented gap)

The OIDC preference applies *whenever `cd-deploy.yml` runs* (i.e. when
the deploy-target marker file is present). Repos with no CD don't need
deploy auth configured at all.

`cd-deploy.yml` uses [OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
where the deploy provider supports it natively. As of 2026-05, the
provider OIDC landscape is **uneven**:

| Provider | OIDC status | Mechanism in `cd-deploy.yml` |
| --- | --- | --- |
| AWS | ✅ Native | `aws-actions/configure-aws-credentials@v4` with OIDC role |
| GCP | ✅ Native | `google-github-actions/auth@v2` with Workload Identity Federation |
| Azure | ✅ Native | `azure/login@v2` with OIDC subject |
| Cloudflare | ✅ Native | `cloudflare/wrangler-action@v3` (uses scoped API tokens, OIDC support being rolled out) |
| **Vercel** | ❌ **No first-party OIDC action** as of 2026-05 | Uses Vercel CLI with project-scoped token from `VERCEL_TOKEN` repo secret. Documented as a gap. |
| **Fly.io** | ❌ **OIDC integration incomplete** as of 2026-05 (macaroon-based deploy tokens, no `flyctl --oidc` subcommand) | Uses `superfly/flyctl-actions/setup-flyctl@master` with `FLY_API_TOKEN` repo secret. Documented as a gap. |
| Railway | ❌ No OIDC support | `RAILWAY_TOKEN` repo secret; documented as a gap. |
| Render | ❌ No OIDC support | Render deploy hook URL stored in repo secret; documented as a gap. |

**Documented-gap policy for Vercel / Fly / Railway / Render:**

These providers are popular for solo / small-team products and dropping
them entirely would push every project toward AWS-shaped infrastructure
that's overkill for most use cases. So they're allowed in v1 with these
explicit guardrails:

1. The repo's `THREAT_MODEL.md` lists each long-lived deploy token as a
   "credentials-at-rest" risk with the line: *"Compromise of GitHub
   repo secrets discloses the deploy token; recovery requires rotating
   the token and re-deploying."*
2. Each token is **project-scoped** (not account-scoped) at the
   provider — so a leaked Vercel token can only redeploy that one
   project, not exfiltrate other projects' secrets or deploy
   destructive payloads to siblings.
3. Tokens are **rotated quarterly** via a scheduled workflow that
   opens an issue reminding to rotate. Rotation is manual today;
   automated when the provider ships an API for it.
4. The provider's OIDC status is **re-evaluated quarterly**. When any
   provider in the gap list ships first-party OIDC, that repo's CD
   migrates to OIDC in a single PR.

This is honest "we'll get there when the provider gets there"
documentation, not pretending OIDC works when it doesn't.

**SLSA L3 build provenance is NOT affected by this gap.** Build
attestation lives in the `release.yml` workflow (using
`slsa-github-generator` as documented below) and runs *before* deploy.
A compromised deploy token can re-deploy an old artifact, but cannot
forge build provenance for a new artifact — the provenance chain stays
intact.

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

The "Verifies app builds in CI" row from the reference CI table in §6
is satisfied by the generator's build step; provenance attestation is
the additional artifact produced alongside the build output.

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
| [SLSA](https://slsa.dev/spec/v1.0/levels) | Build L3 | `slsa-github-generator` for in-toto provenance + `slsa-verifier` on the consumer side + isolated hosted-runner builds + OIDC where the deploy provider supports it (§4.6 documents per-provider gaps) |
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
| Post-CI/CD: Vercel Deploy | `cd-deploy.yml` (project-scoped `VERCEL_TOKEN`; OIDC gap, see §4.6) |
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

### 7.2 App private key trust root is "your GitHub login + TOTP"

Per §3.3c: the App private key lives in `nischal94/.github` as a
regular Actions secret. The trust boundary is therefore:

1. **GitHub session compromise** → attacker has at least three direct
   exfiltration paths, none of which branch protection mediates:
   - Read `APP_PRIVATE_KEY` via the GitHub Settings UI (repo →
     Settings → Secrets — secrets ARE re-displayable when the
     "show value" / "update" UI surfaces; on certain account states
     they're written to clipboards).
   - Read via the [secrets REST API](https://docs.github.com/en/rest/actions/secrets)
     (returns metadata only — values are write-only — so this path is
     blocked, but the attacker can *overwrite* the secret with their
     own key).
   - Open a self-approved workflow PR that exfiltrates the secret to
     an external endpoint (`echo "$APP_PRIVATE_KEY" | curl`) — branch
     protection requires PR + signed commit but on a solo account
     self-approval makes this a speed bump, not an authorization gate.
2. **GitHub login compromise** (no live session yet) → attacker
   bypasses TOTP via real-time phishing, then has all the paths above.

**Branch protection is a code-path gate, not a secrets-path gate.**
The honest risk is that anyone holding a live `nischal94` session
cookie or who can authenticate as `nischal94` can read or replace
`APP_PRIVATE_KEY` — the only mitigation against that is keeping the
session/login itself uncompromised.

The login compromise vector is the bigger risk. Mitigations in v0.4:

- **TOTP MFA on the GitHub account** (Authy / 1Password / Google
  Authenticator). Defends against passive password reuse and most
  credential-stuffing attacks. Vulnerable to real-time phishing — an
  attacker who tricks you into typing both password and TOTP code on
  a fake page within ~30 seconds wins.
- **Branch protection on `nischal94/.github`** ensures even with push
  access, code changes need PR + signed commit. Self-approval limits
  this to "speed bump" not "two-person rule."
- **No `pull_request_target` workflows** in `nischal94/.github` —
  closes the malicious-PR exfiltration path.

**YubiKey upgrade path**: enrolling a hardware security key on the
GitHub account login closes the real-time phishing vector. Cost: ~$50
one-time, ~10 min enrollment. Strongly recommended when this account
ever touches anything sensitive (real customer data, paying users,
production systems with revenue impact). Until then, TOTP is the
honest middle.

**Honest summary**: a determined attacker who phishes you in real-time
and gets through TOTP can compromise the App key. This is the same
threat that compromises every other secret you have on GitHub today
(repo secrets, PATs, OAuth tokens). The App key is not specially
protected; it inherits whatever security your GitHub login has.

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
and audit both stop. The App's own installation status is therefore
audited by a tiny scheduled workflow (`app-canary.yml` in
`nischal94/.github`) that runs daily and asks GitHub *as the user*,
not as the App, "is `nischal94-policy` still installed?"

The correct API call is **not** the App's own
`GET /installation/repositories` (which fails the moment the App is
uninstalled — an obvious chicken-and-egg). The canary uses
[`GET /users/{username}/installation`](https://docs.github.com/en/rest/apps/apps#get-a-user-installation-for-the-authenticated-app)
or, more directly, the user-token-authenticated endpoint
`GET /user/installations`, called with a fine-grained PAT scoped to
**Account permissions: "Installations: read"** (a real, documented
fine-grained PAT scope on user accounts).

Logic:
1. Fetch `GET /user/installations`.
2. If `nischal94-policy` is missing from the result → open an
   `app-uninstalled` issue against `nischal94/.github` (manual
   re-install required; the App cannot reinstall itself).
3. If present → no-op.

This is the **only PAT in the system**. Scope is read-only on a single
metadata endpoint; cannot read repo contents, cannot write anything.
Stored in `nischal94/.github` repo secret `CANARY_PAT`. Rotated
annually via a calendar reminder.

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
   Generate private key; store as `APP_PRIVATE_KEY` repo secret in
   `nischal94/.github` per §3.3c. Enable TOTP MFA on the GitHub
   account login if not already.
2. Create `nischal94/.github` repo (currently does not exist). Seed with:
   - Community files (§3.8)
   - Layer 1 universal workflows (§3.1, §3.2)
   - `policies/canonical-ruleset.json`
   - `policies/required-checks.yml`
   - `state/configured-repos.json` (initially empty)
   - Repository secret: `APP_PRIVATE_KEY` (the App's `.pem` contents)
   - Repository variables: `APP_ID`, `APP_INSTALLATION_ID`,
     `APP_INTEGRATION_ID`

   **Bootstrap circularity** (must be handled here): the App is
   *housed in* `nischal94/.github`, so it cannot self-protect that
   repo before its first run. Manually apply
   `policies/canonical-ruleset.json` to `nischal94/.github` itself
   via `gh api -X POST repos/nischal94/.github/rulesets -F @policies/canonical-ruleset.json`
   immediately after seeding, BEFORE pushing the App's first commit.
   Otherwise the trust-root repo sits unprotected through the
   first poll cycle. After this manual application, all future
   ruleset updates flow through the standard `force-sync.yml` /
   `enforce-on-poll.yml` paths.
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
