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

After creating a new repo from this template — or when retrofitting an existing repo — complete the following. Most are one-time UI clicks.

### 2.1 Repo-level security toggles
**Settings → Code security:**
- [ ] **Private vulnerability reporting** → Enable
- [ ] **Dependabot alerts** → Enable
- [ ] **Dependabot security updates** → Enable
- [ ] **Secret scanning** → Enable (free for public; requires GHAS for private)
- [ ] **Push protection** → Enable
- [ ] **CodeQL → Default setup** → Enable (auto-detects languages; preferred over a custom workflow file)

### 2.2 Branch protection on `main`
**Settings → Branches → Add rule for `main`:**
- [ ] Require pull request before merging (1 approval, dismiss stale on push)
- [ ] Require status checks: `gitleaks`, `Validate PR title`, plus any project-specific CI jobs
- [ ] Require conversation resolution
- [ ] Block force pushes
- [ ] Block deletions
- [ ] (Optional but recommended) Require signed commits
- [ ] Set `enforce_admins: false` so you can break-glass on solo repos

### 2.3 Tag protection
**Settings → Tags → Add rule:**
- [ ] Pattern `v*` (prevents overwriting/deleting release tags)

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

### 2.6 Dependabot ecosystem activation
Edit `.github/dependabot.yml` — uncomment the `pip` / `npm` / `docker` block(s) matching the repo's stack. The grouping config is pre-set to collapse update bursts.

### 2.7 README badges (optional)
After the first Scorecard run completes (Mondays + on push to main):
```markdown
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/<owner>/<repo>/badge)](https://securityscorecards.dev/viewer/?uri=github.com/<owner>/<repo>)
```

---

## 3. Branch protection — required configuration

The template's workflows produce these check names; not all should be required (path-scoped checks would deadlock doc-only PRs).

| Check | Required? | Reasoning |
|---|---|---|
| `gitleaks` | ✅ Required | Runs on every PR; blocks new secrets |
| `Validate PR title` | ✅ Required | Runs on every PR; enforces Conventional Commits |
| `actionlint` | ❌ Advisory | Only fires on `.github/workflows/**` changes; would block doc PRs |
| `dependency-review` | ❌ Advisory | Only fires on manifest changes; would block doc PRs |
| Project-specific CI | ✅ Required | Whatever runs on every PR (tests, build) |
| CodeQL | ✅ Required | Add once you enable CodeQL default setup |

API call to apply (replace `<repo>`):
```bash
gh api -X PUT repos/nischal94/<repo>/branches/main/protection \
  --input <(cat <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      {"context": "gitleaks"},
      {"context": "Validate PR title"}
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF
)
```

---

## 4. Promotion path: advisory → required

Many security workflows ship as advisory (`continue-on-error: true`) on first run because they surface a baseline of pre-existing issues. The promotion path:

1. **Run advisory** — workflow fires on every PR, surfaces findings, doesn't block.
2. **Triage baseline** — fix true positives in a dedicated cleanup PR; annotate false positives (`# nosec`, `.trivyignore`, etc).
3. **Remove `continue-on-error: true`** from the workflow.
4. **Add to required-checks list** via branch protection API.

Workflows that benefit from this pattern: `actionlint`, `bandit`, `trivy`, `pip-audit`, `ruff`.

---

## 5. Dependabot operations

### 5.1 The "FULL grouping" pattern (default)
This template's `dependabot.yml` ships with **two groups per ecosystem**:

| Group | Catches | Why separate |
|---|---|---|
| `<ecosystem>-security` | All vulnerability fixes | Urgent — needs prioritized review |
| `<ecosystem>-versions` | All version bumps INCLUDING majors | Routine — single weekly digest |

**Result**: maximum 2 PRs per ecosystem per week, regardless of how many deps are stale. Burst-proof.

**Trade-off**: a grouped `<ecosystem>-versions` PR may bundle a major-version upgrade with several minor/patch upgrades. The reviewer must glance at each embedded changelog rather than triage by PR title. For solo-dev / personal repos this is the right call. For larger teams that want per-major reviews, use the alternative pattern below.

### 5.2 Alternative: "majors stay individual" pattern
If you want major-version PRs to remain individual (so each major's changelog gets its own review thread), use a 3-group config:
```yaml
groups:
  pip-security:
    applies-to: security-updates
    patterns: ["*"]
  pip-minor-patch:
    applies-to: version-updates
    update-types: ["minor", "patch"]
  # Majors NOT in any group → individual PRs
```
This was the template's earlier default but was changed because solo-dev review cadence didn't justify the per-major PR overhead.

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
