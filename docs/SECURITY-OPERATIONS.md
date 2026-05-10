# Security Operations — Master Reference

Single source of truth for everything related to security, CI hygiene, and operational runbooks across all `nischal94` repos. Captures the decisions, defaults, and trade-offs from the security audit performed in 2026-04.

---

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [Post-creation checklist (per repo)](#2-post-creation-checklist-per-repo)
3. [Branch protection — required configuration](#3-branch-protection--required-configuration)
4. [Promotion path: advisory → required](#4-promotion-path-advisory--required)
5. [Dependabot operations](#5-dependabot-operations)
6. [Auto-merge for patch updates](#6-auto-merge-for-patch-updates)
7. [Tier 4 hardening additions](#7-tier-4-hardening-additions)
8. [Tier 5 conditional items (when X happens)](#8-tier-5-conditional-items-when-x-happens)
9. [Operational runbooks](#9-operational-runbooks)
10. [What's intentionally NOT here](#10-whats-intentionally-not-here)

---

## 1. Architecture overview

Layered security thinks in **prevention → detection → response**. The defaults below cover all three layers.

| Layer | Mechanism |
|---|---|
| **Prevention (pre-merge)** | `gitleaks`, `dependency-review`, `actionlint`, `pr-title`, branch protection, push protection |
| **Detection (post-merge / continuous)** | CodeQL, Dependabot security alerts, secret scanning, OpenSSF Scorecard, OSV-Scanner |
| **Response** | Private vulnerability reporting (`SECURITY.md`), Dependabot security updates, manual triage runbook (§9.1) |
| **Supply chain** | `harden-runner` (audit mode), pinned action versions via Dependabot, OpenSSF Scorecard score |

The template provides workflows for the prevention layer + scaffolds the detection/response toggles. The operational layer (manual triage, promotion decisions) is documented here.

---

## 2. Post-creation checklist (per repo)

After creating a new repo from this template, most setup is automated. The `nischal94-policy` GitHub App applies branch protection and delivers the 8 universal Layer-1 security workflows on enrollment — see [`.github/docs/POLICIES.md`](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md) for what gets enforced. The checklist below is what's still per-repo.

### 2.1 Repo-level security toggles
**Settings → Code security:**
- [ ] **Private vulnerability reporting** → Enable
- [ ] **Dependabot alerts** → Enable
- [ ] **Dependabot security updates** → Enable
- [ ] **Secret scanning** → Enable (free for public; requires GHAS for private)
- [ ] **Push protection** → Enable
- [ ] **CodeQL → Default setup** → Enable (auto-detects languages; preferred over a custom workflow file)

### 2.2 Layer-1 enrollment
**Required for branch protection + universal security workflows.** Edit [`SCAFFOLD_ALLOWLIST` in `nischal94/.github`'s `scaffold-on-poll.yml`](https://github.com/nischal94/.github/blob/main/.github/workflows/scaffold-on-poll.yml#L51) to add your repo's full name, open a PR there, merge.

Within ~5 minutes the App opens an auto-PR on your repo with the 8 Layer-1 workflows + the `.scaffolded-by-nischal94-policy` marker file. Merge it. On the next 5-min cron tick, `enforce-on-poll` applies the canonical ruleset to your `main` automatically.

After enrollment, **do not** create a classic branch protection rule via Settings → Branches; the canonical ruleset is the single source of truth and a duplicate classic rule will cause check-name mismatches that deadlock PRs.

### 2.3 Release-tag protection
**Settings → Rules → Rulesets → New ruleset:**
- [ ] Target: `Tag`, pattern `v*`
- [ ] Block deletion + block updates (prevents overwriting or removing published release tags)

This is per-repo because the canonical ruleset only targets `main`, not tags. A future improvement would extend the canonical ruleset to cover tags (see [`.github`#open-issue if filed]).

### 2.4 Actions security
**Settings → Actions → General:**
- [ ] **Require approval for first-time contributors** (stops drive-by malicious PRs from triggering secrets-using workflows)
- [ ] **Workflow permissions** → "Read repository contents and packages permissions" (least privilege; opt-in writes per workflow)
- [ ] (Optional) **Allow select actions** with allow-list of trusted creators

### 2.5 Secrets (only if needed)
- [ ] `ANTHROPIC_API_KEY` — required for `claude.yml` to function
  ```
  gh secret set ANTHROPIC_API_KEY -R <owner>/<repo>
  ```
- [ ] `VERCEL_TOKEN` / `FLY_API_TOKEN` / `RAILWAY_TOKEN` — only the one matching your CD target (`cd-deploy.yml` autodetects via `vercel.json` / `fly.toml` / `railway.toml`)

### 2.6 Dependabot ecosystem activation
Edit `.github/dependabot.yml` — uncomment the `pip` / `npm` / `docker` block(s) matching the repo's stack. The grouping config is pre-set to collapse update bursts. The `gh-actions` block is enabled by default and is delivered by Layer-1.

### 2.7 README badges (optional)
After the first Scorecard run completes (Mondays + on push to main):
```markdown
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/<owner>/<repo>/badge)](https://securityscorecards.dev/viewer/?uri=github.com/<owner>/<repo>)
```

---

## 3. Branch protection (canonical ruleset)

Branch protection on `main` is enforced by the **canonical ruleset** that the `nischal94-policy` GitHub App applies on enrollment. Authoritative source: [`policies/canonical-ruleset.json`](https://github.com/nischal94/.github/blob/main/policies/canonical-ruleset.json).

What's enforced (full detail in [`POLICIES.md`](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md)):

| Rule | Effect |
|---|---|
| `required_signatures` | All commits must be cryptographically signed |
| `non_fast_forward` | No force-pushes |
| `deletion` | Branch cannot be deleted |
| `creation` | Branch cannot be re-created from a different SHA |
| `pull_request` | PR-only changes; review thread resolution required |
| `required_status_checks` (strict) | All 7 Layer-1 checks must pass: `gitleaks`, `dependency-review`, `osv-scanner`, `actionlint`, `pin-actions`, `validate-pr-title`, `license-check` |

**Bypass:** only `nischal94-policy` (Integration ID 3656026). No human bypass — including the repo owner. This is the spec §7.2 trust boundary.

**Solo-account note:** `required_approving_review_count` is set to `0` because GitHub forbids approving your own PR; on a single-identity account a non-zero count would deadlock all merges. When taking on collaborators, edit `policies/canonical-ruleset.json` → `1` and merge — drift-audit propagates the change to all enrolled repos within a week, or run `force-sync.yml` for immediate.

**To modify the ruleset for all enrolled repos:** edit `policies/canonical-ruleset.json` on `nischal94/.github`, open a PR, merge. The next `enforce-on-poll` cron tick (`*/5` min) re-applies. To force immediate propagation, dispatch `force-sync.yml` manually with `target=all`.

---

## 4. Promotion path: advisory → required

When a new universal security workflow proves itself useful enough to be required across all repos, promote it to the canonical ruleset:

1. **Add the workflow to `nischal94/.github`** as a new file under `.github/workflows/` (SHA-pin all `uses:` refs per the canonical pin-actions rule).
2. **Add the workflow's filename to `scaffold-on-poll.yml`'s copy loop** (so future scaffold PRs deliver it). Optionally manually copy it into already-enrolled repos (or wait for drift-audit's next Sunday run to propagate it).
3. **Run advisory** for at least a week — workflow fires on every PR, surfaces a baseline of findings, doesn't block.
4. **Triage baseline** — fix true positives in a dedicated cleanup PR per repo; annotate false positives (`# nosec`, `.trivyignore`, etc).
5. **Add the check name to `policies/canonical-ruleset.json`'s `required_status_checks` array** + merge to `nischal94/.github`. The next `enforce-on-poll` propagates the new required check to every enrolled repo's ruleset.

Workflows that are good candidates for future promotion: `bandit` (Python SAST), `trivy` (container scan), `pip-audit`, `eslint-plugin-security`. Today's required list (the 7 above) is the floor, not the ceiling.

For a workflow that's stack-specific (only useful for repos using a particular language), keep it in `repo-template`'s Layer-2 tier rather than promoting to Layer-1 — Layer-1 is for *universal* workflows only.

---

## 5. Dependabot operations

### 5.1 The "3-group" pattern (default — for active repos)
This template's `dependabot.yml` ships with **three groups per ecosystem**:

| Group | Catches | Why separate |
|---|---|---|
| `<ecosystem>-security` | All vulnerability fixes | Urgent — needs prioritized review |
| `<ecosystem>-minor-patch` | Safe semver bumps | Single weekly digest of low-risk upgrades |
| (none — majors) | Major-version bumps | Each major gets its own PR so a v6→v7 breaking change can't take down a grouped PR's CI and block safe patches inside it |

**Trade-off**: when several majors are outdated, you get one PR per major. Worth the isolation for actively-iterated repos where merging a broken bundle is costly.

**Use this for**: actively-developed repos (sonar, your active personal projects). The per-major PR overhead is worth it because CI failures stay isolated.

### 5.2 Alternative: "FULL grouping" pattern (for dormant repos)
For repos you batch-review-and-pray (no active iteration, you scan deps once a quarter), collapse everything into TWO groups per ecosystem:

```yaml
groups:
  npm-security:
    applies-to: security-updates
    patterns: ["*"]
  npm-versions:
    applies-to: version-updates
    patterns: ["*"]
  # Majors are now grouped INTO npm-versions — no individual PRs ever
```

**Result**: maximum 2 PRs per ecosystem per week. True weekly digest. Burst-proof.

**Cost**: a grouped `<ecosystem>-versions` PR may bundle a major-version upgrade (with breaking changes) alongside safe patches. If the major breaks CI, the entire grouped PR fails — you can't merge ANY of the safe patches without splitting or fixing.

**Use this for**: dormant repos, static landing pages, archived-but-still-deployed projects.

### 5.3 Choosing between them
| Repo profile | Pattern | Reason |
|---|---|---|
| Active product with CI + tests | 3-group (default) | CI failure isolation matters |
| Personal active iteration | 3-group | Same |
| Dormant / static / batch-review | FULL grouping | Per-major review overhead not worth it |
| You don't know yet | Default to 3-group | Easier to migrate dormant→FULL later than to recover from a broken grouped major |

### 5.3 Hard cap: `open-pull-requests-limit: 2`
Independent of grouping, this caps the total open Dependabot PRs per ecosystem at 2. Protects against config drift if grouping breaks. Bump to 5 once you've cleared any backlog and want faster turnover.

### 5.4 Why initial bursts can still happen
The grouping config applies to **future scheduled scans**, not retroactively to deps that were already individually queued before the config landed. First-scan-after-enabling on an aged repo can produce a one-time burst of individual PRs. **Mitigation**:
- Set `open-pull-requests-limit: 1` on first activation
- Bump back to 2 after the initial backlog is cleared
- Dormant repos: archive instead of patching

### 5.5 Security vs. version updates
| Type | Trigger | Throttling | Grouping behavior |
|---|---|---|---|
| Security updates | Known vulnerability | Honors `open-pull-requests-limit` (per ecosystem) | Use `applies-to: security-updates` |
| Version updates | Outdated version | Honors `open-pull-requests-limit` | Use `applies-to: version-updates` |

### 5.6 Triage runbook for grouped security PRs
1. Filter PRs: `is:pr label:dependencies is:open`
2. Open the `<ecosystem>-security` PR (highest priority)
3. Verify CI passes (means upgrades are API-compatible)
4. Skim each embedded changelog for behavioral / API / license changes
5. For **critical-severity** deps specifically: read the linked CVE, verify the affected feature is actually used in this code
6. Merge if no red flags

### 5.7 The deeper truth
Dependabot is **noisy on first activation against any repo with deferred dep maintenance**. The fundamental fix is to keep deps fresh: daily/weekly merging of small upgrades = no burst ever happens because there's never a backlog to clear.

---

## 6. Auto-merge for patch updates

Recommended **only** for repos with good test coverage. Add `.github/workflows/dependabot-automerge.yml`:

```yaml
name: Dependabot auto-merge

on: pull_request_target

permissions:
  contents: write
  pull-requests: write

jobs:
  automerge:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Fetch Dependabot metadata
        id: meta
        uses: dependabot/fetch-metadata@v2
      - name: Auto-merge patch + dev minor
        if: |
          steps.meta.outputs.update-type == 'version-update:semver-patch' ||
          (steps.meta.outputs.update-type == 'version-update:semver-minor' &&
           steps.meta.outputs.dependency-type == 'direct:development')
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Trust model**: patch updates can ship CVE fixes silently — that's the *point*. Major and prod-minor still require human review.

---

## 7. Tier 4 hardening additions

Optional hardening — add per repo as needed.

### 7.1 `harden-runner` (egress firewall)
Already added to template workflows in **audit mode** (logs egress, doesn't block). After 2-3 weeks of audit data, flip to **block mode** with an explicit allow-list in each workflow:

```yaml
- name: Harden the runner
  uses: step-security/harden-runner@v2
  with:
    egress-policy: block
    allowed-endpoints: >
      github.com:443
      api.github.com:443
      objects.githubusercontent.com:443
      pypi.org:443
      files.pythonhosted.org:443
```

Audit data lives at: `https://app.stepsecurity.io/github/<owner>/<repo>`

### 7.2 SHA-pin third-party actions
Run `pinact` against `.github/workflows/`:
```bash
brew install suzuki-shunsuke/pinact/pinact
pinact run -u
```
Converts `actions/checkout@v6` → `actions/checkout@<full-sha>  # v6`. Dependabot keeps the SHA fresh.

### 7.3 Required signed commits
Branch protection → **Require signed commits**. Configure local git for SSH signing:
```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```
Add the public key to GitHub → Settings → SSH and GPG keys → New SSH key → "Signing key."

### 7.4 OSV-Scanner
Already added to template (`osv-scanner.yml`). Cross-ecosystem dep scan against Google's OSV database. Complements GitHub-native Dependabot.

### 7.5 OpenSSF Scorecard
Already added to template (`scorecard.yml`). Weekly audit of 18+ supply-chain best practices; SARIF results + public badge.

### 7.6 `zizmor` (workflow YAML security audit)
Run once during a security audit pass:
```bash
brew install zizmor
zizmor .github/workflows/
```
Flags `pull_request_target` misuses, untrusted-checkout patterns, expression-injection vectors. Not added as a workflow — runs once, fixes findings, done.

### 7.7 Frontend-specific (when applicable)
- **Lighthouse CI** action — perf/SEO/a11y gates on `vite build` output
- **`@axe-core/cli`** — accessibility violations as test failures

### 7.8 Shell-script repos
- **`shellcheck`** action — static analysis for `.sh` files

---

## 8. Tier 5 conditional items (when X happens)

These add **only** when the trigger condition is met.

| Item | Trigger condition |
|---|---|
| **`cosign` keyless signing** of release artifacts | When a repo publishes its Docker image to a registry, or any package to a registry |
| **SBOM generation** (`anchore/sbom-action`) | Same trigger as cosign — required by EU Cyber Resilience Act + most enterprise procurement |
| **SLSA provenance** (`slsa-framework/slsa-github-generator`) | Same trigger — generates Level 3 build provenance attestations |
| **Renovate** (alternative to Dependabot) | Only if Dependabot grouping isn't sufficient at scale |
| **Codecov** coverage floor | When a coverage gate is wanted on PRs (requires Codecov account/token) |
| **Mutation testing** (e.g., `mutmut` for Python) | Quarterly sanity check on test quality; not ongoing |
| **`gitleaks` license** | When a repo moves from public/personal to a private organization |
| **GitHub Advanced Security** | When private repos need secret-scanning push-protection (paid) |

---

## 9. Operational runbooks

### 9.1 Handling a Dependabot security alert burst
**Symptom**: enabling Dependabot security updates surfaces dozens of vulns at once.

1. **Don't disable.** The vulns existed before Dependabot found them; ignoring them keeps you exposed.
2. Add grouping config (§5.1) — converts burst into ~2-3 weekly grouped PRs.
3. Triage in one focused session per repo (§5.4).
4. For dormant repos, **archive** instead of patching — archived repos stop receiving alerts and the artifact is no longer being shipped.

### 9.2 Adding a new repo to the security baseline
1. Click **Use this template** on `nischal94/repo-template`.
2. Walk the post-creation checklist (§2).
3. Apply branch protection (§3).
4. Done.

### 9.3 Promoting an advisory check to required
See §4 — triage baseline → remove `continue-on-error` → add to required-checks list.

### 9.4 Investigating a failed `actionlint` check
- `actionlint` shells out to `shellcheck` for any `run:` blocks. Common findings:
  - SC2034: unused loop variable → rename to `_`
  - SC2046: unquoted command substitution → wrap in `"..."`
  - SC2086: unquoted variable → wrap in `"..."`
- Fix in a dedicated `chore: fix shellcheck warnings` PR.

### 9.5 Investigating a failed `gitleaks` check
- Read the leak fingerprint in the action output.
- If true positive: rotate the leaked credential immediately, then rewrite the offending commit.
- If false positive: add to `.gitleaksignore` with the fingerprint.

### 9.6 OpenSSF Scorecard low score
- Each Scorecard finding includes remediation. Read the SARIF in Security tab.
- Common low scores: `Branch-Protection` (require it), `Token-Permissions` (use least-privilege `permissions:` blocks), `Pinned-Dependencies` (run `pinact`).

---

## 10. What's intentionally NOT here

These were considered and excluded from the default baseline. Add per repo if needed.

| Excluded | Reason |
|---|---|
| **CodeQL workflow file** | Prefer GitHub's "default setup" — auto-detects languages, no YAML maintenance. Enable per repo via Settings → Code security. |
| **Snyk** | Overlaps with Dependabot + OSV-Scanner + dependency-review. Different advisory source but largely redundant. |
| **FOSSA / license-checker** | Overkill for personal repos. `dependency-review-action` already blocks restrictive licenses on PRs. |
| **`commitlint` workflow** | Local pre-commit hook is sufficient; PR-time `pr-title.yml` covers the gate. |
| **Stale issue/PR bot** | Personal repos don't accumulate enough issues to justify; hostile to legitimate slow-burn PRs. |
| **`.github/FUNDING.yml`** | Not seeking sponsorship. |

---

## Changelog

| Date | Change |
|---|---|
| 2026-04-19 | Initial version. Established Tier A/B/C/D framework, baseline workflows, Dependabot grouping, and operational runbooks. |
