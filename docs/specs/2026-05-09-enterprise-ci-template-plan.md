# Enterprise CI Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two-layer enterprise CI template system specified in `2026-05-09-enterprise-ci-template-design.md` (v0.3), so that any future repo created from `nischal94/repo-template` is enterprise-grade by default.

**Architecture:** Layer 1 lives in `nischal94/.github` and ships universal CI workflows + a custom GitHub App (`nischal94-policy`) that polls every 5 minutes to apply rulesets, scaffold workflows, and audit drift across every repo on the account. Layer 2 lives in `nischal94/repo-template` and ships a stack-agnostic scaffold with auto-detection of 8 language profiles + OIDC-where-supported CD + `slsa-github-generator` releases. App private key lives as a repo secret in `nischal94/.github`, protected by GitHub-native hardening (branch protection + signed commits + TOTP MFA on the GitHub login + no `pull_request_target` workflows).

**Tech Stack:** GitHub Actions, GitHub Apps API, GitHub Rulesets API, `slsa-framework/slsa-github-generator`, `step-security/harden-runner`, `github/licensed`, Bash + GitHub CLI for scripting.

---

## How to read this plan

The plan is organized into **six phases**, each with a clear exit gate. Within each phase, tasks alternate between two markers:

- **[USER]** — work that requires the human (registering apps, configuring external services, clicking UI buttons, holding hardware keys). I cannot do these.
- **[CLAUDE]** — work I do via tool calls (writing files, opening PRs, running tests).

Phases are sequential. The exit gate of each phase is a smoke test that must pass before the next phase begins. If a gate fails, do NOT proceed — debug and re-run.

Within a phase, [CLAUDE] tasks are usually independent of each other and can interleave with [USER] tasks. Each task lists its files, follows TDD where applicable (failing test → implementation → passing test → commit), and shows the exact commands to run.

## Phase summary

| Phase | What | Owner | Exit gate |
|---|---|---|---|
| Phase 0 | Prerequisites: register App, choose secret manager, hardware MFA | [USER] | App registered, secret manager configured, hardware key bound |
| Phase 1 | `nischal94/.github` repo seeding (workflows, policies, state file scaffolding) | [CLAUDE] | All Layer 1 workflows pass actionlint locally |
| Phase 2 | App installation + first end-to-end smoke test | [USER] + [CLAUDE] | Throwaway repo gets ruleset applied within 10 min of creation |
| Phase 3 | `nischal94/repo-template` refactor (8 language profiles, CD, license-check, bootstrap) | [CLAUDE] | All Layer 2 workflows pass actionlint locally |
| Phase 4 | Full lifecycle smoke test (template instantiation → enforcement → CI green) | [USER] + [CLAUDE] | Fresh template-derived repo passes all CI on first PR |
| Phase 5 | Documentation: READMEs, runbooks, threat-model templates | [CLAUDE] | Docs link from each new repo's auto-generated README |

---

## Phase 0 — Prerequisites [USER]

These are inherently human steps. Each requires you to be logged in as `nischal94` on github.com and have access to your secret-manager-of-choice.

### Task 0.1: Register the `nischal94-policy` GitHub App

**Files:** None — this is configured in GitHub web UI.

- [ ] **Step 1: Open the GitHub App registration page**

  Navigate to: `https://github.com/settings/apps/new`

- [ ] **Step 2: Fill in the App's basic identity**

  - **GitHub App name**: `nischal94-policy`
  - **Homepage URL**: `https://github.com/nischal94/.github`
  - **Webhook URL**: leave blank (we use polling, not webhooks)
  - **Webhook → Active**: uncheck

- [ ] **Step 3: Set repository permissions**

  Set these permissions per the spec §3.3:

  - **Administration**: Read and write
  - **Metadata**: Read-only
  - **Contents**: Read and write
  - **Pull requests**: Read and write
  - **Issues**: Read and write
  - **Actions**: Read-only

  Leave all other permissions at "No access."

- [ ] **Step 4: Set "Where can this GitHub App be installed?"**

  Choose **"Only on this account"** (locks installation scope to `nischal94`).

- [ ] **Step 5: Click "Create GitHub App"**

  After creation, you land on the App's settings page at `https://github.com/settings/apps/nischal94-policy`.

- [ ] **Step 6: Generate a private key**

  On the App settings page, scroll to **"Private keys"** and click **"Generate a private key"**. A `.pem` file downloads.

  **Critical:** Move this file to a secure location immediately. Do NOT commit it to any repo. Do NOT email it to yourself. Treat it as you would an SSH private key.

- [ ] **Step 7: Note the App ID**

  At the top of the App settings page, find **"App ID"** (e.g., `1234567`). Save this number — you'll need it in Phase 1.

- [ ] **Step 8: Note the Client ID**

  Same page, find **"Client ID"** (e.g., `Iv1.abcdef0123456789`). Save it.

### Task 0.2: Enable TOTP MFA on the GitHub account

This is the v0.4 trust-boundary floor (per spec §3.3c and §7.2). The
App private key will live in a `nischal94/.github` repo secret,
protected by your GitHub login. TOTP MFA defends against password
reuse and credential stuffing.

- [ ] **Step 1: Choose a TOTP authenticator app**

  Use a TOTP authenticator app of your choice (e.g.
  [Google Authenticator](https://support.google.com/accounts/answer/1066447),
  [Authy](https://authy.com), or your password manager's built-in TOTP).
  Pick whichever you already use; all are equivalent for this purpose.

- [ ] **Step 2: Enable 2FA on GitHub**

  Navigate to: `https://github.com/settings/security`.

  Click **"Enable two-factor authentication"** → choose **"Set up using an app."**

  Scan the QR code with your authenticator app. Enter the 6-digit code
  to verify. GitHub displays 16 recovery codes — save them somewhere
  safe (password manager item is fine).

- [ ] **Step 3: Verify by signing out and back in**

  Confirm GitHub prompts for the TOTP code on the next login. If it
  doesn't, 2FA isn't actually active — re-do Step 2.

### Task 0.3: Store the App private key as a `nischal94/.github` repo secret

The spec §3.3c v0.4 design: App private key lives as a regular Actions
secret. Trust boundary is GitHub itself, hardened by branch protection
+ TOTP MFA + no `pull_request_target` workflows.

This task technically belongs in Phase 1 (the repo doesn't exist yet),
but is documented here as a Phase 0 *prerequisite to remember*: you'll
need the `.pem` file from Task 0.1 Step 6 still accessible when you
reach Task 1.1 / 2.2.

- [ ] **Step 1: Keep the `.pem` file in a temporary safe location**

  Move the downloaded `.pem` from your Downloads folder to a
  short-lived location:
  ```bash
  mkdir -p ~/secrets-staging && chmod 700 ~/secrets-staging
  mv ~/Downloads/nischal94-policy.*.private-key.pem ~/secrets-staging/
  chmod 600 ~/secrets-staging/nischal94-policy.*.private-key.pem
  ```

  This file is needed once in Task 2.2 Step 1 to populate the repo
  secret. After that, securely delete it.

- [ ] **Step 2: Confirm the App ID, Installation ID, Integration ID are noted**

  These three values are *not* secrets — they're public identifiers
  that appear in every API URL. They will become repo *variables*
  (not secrets) in Task 2.2:
  - **App ID**: from Task 0.1 Step 7 (e.g., `1234567`)
  - **Client ID**: from Task 0.1 Step 8
  - **Installation ID**: noted in Task 2.1 Step 3 (after you install
    the App in Phase 2)
  - **Integration ID**: noted in Task 2.1 Step 4

  Save these in a note/document — you'll paste them into the GitHub
  variables UI in Task 2.2.

### Phase 0 exit gate

Before proceeding to Phase 1, confirm:

- [ ] GitHub App `nischal94-policy` exists at `https://github.com/settings/apps/nischal94-policy`.
- [ ] App ID and Client ID noted.
- [ ] TOTP MFA enabled on `nischal94` GitHub account; verified by sign-out/sign-in.
- [ ] GitHub recovery codes saved.
- [ ] `.pem` private key file moved to `~/secrets-staging/` with `chmod 600` (will be uploaded to repo secrets in Task 2.2, then deleted).

If any of these is incomplete, do NOT proceed. The Phase 1 work assumes all of these are done.

**What changed from v0.3 plan**: dropped external secret manager
(1Password Connect) setup, OIDC trust policy configuration, and
hardware-MFA-on-secret-manager-root. Per spec v0.4 §3.3c, the App key
now lives as a repo secret in `nischal94/.github`, protected by
GitHub-native hardening rather than external secret management. See
spec changelog v0.4 entry for the full rationale.

---

## Phase 1 — Seed `nischal94/.github` repo [CLAUDE]

This phase creates the Layer 1 repo and populates it with all the universal infrastructure: community files, policies, four enforcement workflows, and the canary.

### Task 1.1: Create the `nischal94/.github` repo

**Files:** None locally yet — this creates a remote repo.

- [ ] **Step 1: Create the repo via gh CLI**

  ```bash
  gh repo create nischal94/.github \
    --public \
    --description "Account-level CI policy and community files for nischal94 repos." \
    --add-readme=false
  ```

  Expected: returns a URL like `https://github.com/nischal94/.github`.

- [ ] **Step 2: Clone it locally**

  ```bash
  git clone git@github.com:nischal94/.github.git ~/projects/nischal94-dot-github
  cd ~/projects/nischal94-dot-github
  ```

- [ ] **Step 3: Initialize a basic README**

  Create `README.md`:
  ```markdown
  # nischal94/.github

  Account-level CI policy + community files. Auto-supplied to every
  repo on this account. See `docs/POLICIES.md` for what enforces here.

  Implementation reference: [`nischal94/repo-template` v0.3 spec](https://github.com/nischal94/repo-template/blob/main/docs/specs/2026-05-09-enterprise-ci-template-design.md).
  ```

- [ ] **Step 4: Commit and push**

  ```bash
  git add README.md
  git commit -m "docs: initial README"
  git push origin main
  ```

### Task 1.2: Add community files (auto-supplied to every repo)

**Files:**
- Create: `SECURITY.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `CODEOWNERS`
- Create: `.github/dependabot.yml`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`
- Create: `.github/ISSUE_TEMPLATE/feature.yml`
- Create: `.github/ISSUE_TEMPLATE/security.yml`
- Create: `.github/FUNDING.yml`

- [ ] **Step 1: Create `SECURITY.md`**

  ```markdown
  # Security Policy

  ## Reporting

  Send disclosures privately to security@nischal.dev (or open a private
  security advisory at the affected repo's Security tab → Report a vulnerability).

  Do NOT open public issues for security bugs.

  ## Response time

  Acknowledgement within 48 hours. Triage within 7 days.

  ## Scope

  All public repos on github.com/nischal94 are in scope. Vendored
  dependencies are out of scope (report upstream).
  ```

- [ ] **Step 2: Create `CODE_OF_CONDUCT.md`**

  Use the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) verbatim. Replace the placeholder contact line with:
  ```
  Reports go to: security@nischal.dev
  ```

- [ ] **Step 3: Create `CODEOWNERS`**

  ```
  * @nischal94
  ```

- [ ] **Step 4: Create `.github/dependabot.yml`**

  ```yaml
  version: 2
  updates:
    - package-ecosystem: github-actions
      directory: /
      schedule:
        interval: weekly
      groups:
        gh-actions:
          patterns: ["*"]
    - package-ecosystem: npm
      directory: /
      schedule:
        interval: weekly
    - package-ecosystem: pip
      directory: /
      schedule:
        interval: weekly
    - package-ecosystem: gomod
      directory: /
      schedule:
        interval: weekly
    - package-ecosystem: docker
      directory: /
      schedule:
        interval: weekly
  ```

- [ ] **Step 5: Create `.github/PULL_REQUEST_TEMPLATE.md`**

  ```markdown
  ## Summary
  <!-- 1-3 bullets on what this PR does and why -->

  ## Test plan
  - [ ] <!-- how you verified this works -->

  ## Checklist
  - [ ] Conventional Commit title (feat:, fix:, docs:, etc.)
  - [ ] No unrelated changes
  - [ ] Tests added or updated
  - [ ] Threat model updated if security-relevant
  ```

- [ ] **Step 6: Create the three issue templates**

  `.github/ISSUE_TEMPLATE/bug.yml`:
  ```yaml
  name: Bug report
  description: Something works incorrectly
  labels: ["bug"]
  body:
    - type: textarea
      attributes:
        label: What happened?
      validations:
        required: true
    - type: textarea
      attributes:
        label: What did you expect to happen?
      validations:
        required: true
    - type: textarea
      attributes:
        label: Repro steps
        description: Numbered steps to reproduce
      validations:
        required: true
  ```

  `.github/ISSUE_TEMPLATE/feature.yml`:
  ```yaml
  name: Feature request
  description: Propose a change or addition
  labels: ["enhancement"]
  body:
    - type: textarea
      attributes:
        label: What problem are you solving?
      validations:
        required: true
    - type: textarea
      attributes:
        label: Proposed solution
      validations:
        required: false
  ```

  `.github/ISSUE_TEMPLATE/security.yml`:
  ```yaml
  name: Security report (use private advisory instead)
  description: Public security reports are NOT accepted here.
  labels: ["security"]
  body:
    - type: markdown
      attributes:
        value: |
          **STOP.** Do not file public security issues.
          Use the repo's Security tab → "Report a vulnerability"
          to file a private advisory instead, or email security@nischal.dev.
  ```

- [ ] **Step 7: Create `.github/FUNDING.yml`**

  ```yaml
  # Empty stub — populate when there's something to link.
  ```

- [ ] **Step 8: Commit and push**

  ```bash
  git add SECURITY.md CODE_OF_CONDUCT.md CODEOWNERS .github/
  git commit -m "feat: add community files (auto-supplied to every repo)"
  git push origin main
  ```

### Task 1.3: Add policies/canonical-ruleset.json

**Files:**
- Create: `policies/canonical-ruleset.json`
- Create: `policies/required-checks.yml`
- Create: `policies/license-config.yml`

This file is the source-of-truth ruleset that the App applies to every repo's `main`.

- [ ] **Step 1: Create `policies/canonical-ruleset.json`**

  ```json
  {
    "name": "nischal94 canonical main protection",
    "target": "branch",
    "enforcement": "active",
    "conditions": {
      "ref_name": {
        "include": ["refs/heads/main"],
        "exclude": []
      }
    },
    "rules": [
      { "type": "deletion" },
      { "type": "non_fast_forward" },
      { "type": "required_signatures" },
      {
        "type": "pull_request",
        "parameters": {
          "required_approving_review_count": 1,
          "dismiss_stale_reviews_on_push": true,
          "require_code_owner_review": true,
          "require_last_push_approval": false,
          "required_review_thread_resolution": true
        }
      },
      {
        "type": "required_status_checks",
        "parameters": {
          "strict_required_status_checks_policy": true,
          "required_status_checks": [
            { "context": "gitleaks" },
            { "context": "dependency-review" },
            { "context": "osv-scanner" },
            { "context": "actionlint" },
            { "context": "pin-actions" },
            { "context": "Validate PR title" },
            { "context": "license-check" }
          ]
        }
      }
    ],
    "bypass_actors": [
      {
        "actor_id": "REPLACE_WITH_APP_INTEGRATION_ID",
        "actor_type": "Integration",
        "bypass_mode": "always"
      }
    ]
  }
  ```

  **Note**: the `actor_id` placeholder will be replaced in Task 2.2 once the App is installed and you can read its integration ID. Leave it as the literal string for now.

- [ ] **Step 2: Create `policies/required-checks.yml`**

  This is a human-readable companion to the JSON ruleset, listing each required check and why.

  ```yaml
  # Required status checks for main on every nischal94 repo.
  # Source of truth: policies/canonical-ruleset.json
  # This file is the human-readable explanation.

  required_checks:
    - name: gitleaks
      purpose: Secret scanning on every diff and full history.
      blocks_on: high-entropy strings matching known secret patterns.
    - name: dependency-review
      purpose: GitHub-native PR-diff CVE check.
      blocks_on: any new dep with high-severity CVE.
    - name: osv-scanner
      purpose: Full lockfile CVE scan.
      blocks_on: any transitive dep with high-severity CVE.
    - name: actionlint
      purpose: Workflow YAML lint.
      blocks_on: malformed action references, invalid syntax.
    - name: pin-actions
      purpose: Supply-chain hardening.
      blocks_on: any 'uses:' referencing a tag/branch instead of SHA.
      exceptions:
        - slsa-framework/* (SLSA tag-pinning required, see spec §4.6)
    - name: Validate PR title
      purpose: Conventional Commits enforcement.
      blocks_on: PR titles not matching feat:/fix:/docs:/refactor:/test:/chore:.
    - name: license-check
      purpose: Block disallowed licenses.
      blocks_on: copyleft (GPL family) and unknown licenses absent from
        LICENSE-OVERRIDE.md.

  release_time_required:
    - name: sbom-on-release
      purpose: CycloneDX SBOM generation.
    - name: attest-build-provenance
      purpose: SLSA Build L3 in-toto attestation via slsa-github-generator.
  ```

- [ ] **Step 3: Create `policies/license-config.yml`**

  ```yaml
  # github/licensed v4 configuration.
  # See https://github.com/github/licensed/blob/main/docs/configuration.md

  sources:
    npm: true
    pip: true
    go: true
    cargo: true
    bundler: true

  allowed:
    - mit
    - apache-2.0
    - bsd-2-clause
    - bsd-3-clause
    - isc
    - 0bsd
    - unlicense
    - mpl-2.0
    - cc0-1.0

  reviewed:
    # Populated per-repo via LICENSE-OVERRIDE.md merging.

  ignored:
    # Test-only deps that cannot affect distribution.
    npm:
      - "@types/*"
  ```

- [ ] **Step 4: Commit and push**

  ```bash
  git add policies/
  git commit -m "feat: add canonical ruleset, required checks, license config"
  git push origin main
  ```

### Task 1.4: Add Layer 1 universal workflows — security gates

**Files:**
- Create: `.github/workflows/gitleaks.yml`
- Create: `.github/workflows/dependency-review.yml`
- Create: `.github/workflows/osv-scanner.yml`
- Create: `.github/workflows/actionlint.yml`
- Create: `.github/workflows/pin-actions.yml`
- Create: `.github/workflows/pr-title.yml`

These workflows live as **canonical sources** in `nischal94/.github` and are synced to every repo by `scaffold-on-poll.yml` (Task 1.6).

- [ ] **Step 1: Create `gitleaks.yml`**

  ```yaml
  name: gitleaks
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
    pull-requests: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    gitleaks:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
          with:
            fetch-depth: 0
        - uses: gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7 # v2.3.6
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

- [ ] **Step 2: Create `dependency-review.yml`**

  ```yaml
  name: dependency-review
  on:
    pull_request:
  permissions:
    contents: read
    pull-requests: write
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    dependency-review:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: actions/dependency-review-action@5a2ce3f5b92ee19cbb1541a4984c76d921601d7c # v4.3.4
          with:
            fail-on-severity: high
            comment-summary-in-pr: on-failure
  ```

- [ ] **Step 3: Create `osv-scanner.yml`**

  ```yaml
  name: osv-scanner
  on:
    pull_request:
    push:
      branches: [main]
    schedule:
      - cron: "0 12 * * 1"
  permissions:
    contents: read
    security-events: write
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    osv-scanner:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: google/osv-scanner-action/osv-scanner-action@75a3a445eddabfdb83b76814b16f917edc4b8cf2 # v1.9.0
          with:
            scan-args: |-
              --recursive
              --skip-git
              ./
  ```

- [ ] **Step 4: Create `actionlint.yml`**

  ```yaml
  name: actionlint
  on:
    pull_request:
      paths:
        - ".github/workflows/**"
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    actionlint:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Install actionlint
          run: |
            bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
        - name: Run actionlint
          run: ./actionlint -color
  ```

- [ ] **Step 5: Create `pin-actions.yml`**

  ```yaml
  name: pin-actions
  on:
    pull_request:
      paths:
        - ".github/workflows/**"
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    pin-actions:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Verify all uses: are SHA-pinned (with slsa-framework exception)
          run: |
            set -euo pipefail
            BAD=$(grep -rE '^\s*-\s*uses:\s+[^@]+@(v[0-9]|main|master|latest)' .github/workflows/ \
              | grep -vE 'slsa-framework/' || true)
            if [ -n "$BAD" ]; then
              echo "::error::Found tag-pinned actions (must be SHA-pinned):"
              echo "$BAD"
              exit 1
            fi
            echo "All actions SHA-pinned (slsa-framework excepted per spec §4.6)."
  ```

- [ ] **Step 6: Create `pr-title.yml`**

  ```yaml
  name: Validate PR title
  on:
    pull_request:
      types: [opened, edited, synchronize, reopened]
  permissions:
    contents: read
    pull-requests: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    validate-pr-title:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: amannn/action-semantic-pull-request@0723387faaf9b38adef4775cd42cfd5155ed6017 # v5.5.3
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          with:
            types: |
              feat
              fix
              docs
              refactor
              test
              chore
              build
              ci
              perf
              style
            requireScope: false
  ```

- [ ] **Step 7: Run actionlint locally on all six**

  ```bash
  curl -sSfL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash
  ./actionlint -color .github/workflows/*.yml
  ```

  Expected: no output (clean pass). If errors, fix the YAML and re-run.

- [ ] **Step 8: Commit and push**

  ```bash
  git add .github/workflows/{gitleaks,dependency-review,osv-scanner,actionlint,pin-actions,pr-title}.yml
  git commit -m "feat(workflows): add 6 universal security gates"
  git push origin main
  ```

### Task 1.5: Add Layer 1 universal workflows — codeql + license + scorecard

**Files:**
- Create: `.github/workflows/codeql.yml`
- Create: `.github/workflows/license-check.yml`
- Create: `.github/workflows/scorecard.yml`

- [ ] **Step 1: Create `codeql.yml`**

  ```yaml
  name: codeql
  on:
    pull_request:
      branches: [main]
    push:
      branches: [main]
    schedule:
      - cron: "0 14 * * 1"
  permissions:
    contents: read
    security-events: write
    actions: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    analyze:
      runs-on: ubuntu-latest
      strategy:
        fail-fast: false
        matrix:
          language: [actions, javascript-typescript, python, go]
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: github/codeql-action/init@b611370bb5703a7efb587f9d136a52ea24c5c38c # v3.25.11
          with:
            languages: ${{ matrix.language }}
            queries: security-extended
        - uses: github/codeql-action/analyze@b611370bb5703a7efb587f9d136a52ea24c5c38c # v3.25.11
          with:
            category: "/language:${{ matrix.language }}"
  ```

- [ ] **Step 2: Create `license-check.yml`**

  ```yaml
  name: license-check
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    license-check:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: ruby/setup-ruby@af848b40be8bb463a751551a1180d74782ba8a72 # v1.196.0
          with:
            ruby-version: "3.2"
        - name: Install github/licensed
          run: gem install licensed -v 4.4.0
        - name: Merge LICENSE-OVERRIDE.md into licensed config
          run: |
            if [ -f LICENSE-OVERRIDE.md ]; then
              echo "Found LICENSE-OVERRIDE.md; merging into reviewed list."
              # Expected format per line: <package>@<version>: <license> — <reason>
              # Parse and append to .licensed.yml's `reviewed:` section.
              # See policies/license-config.yml for the source schema.
              python3 -c "
            import yaml, re, sys
            override = open('LICENSE-OVERRIDE.md').read()
            cfg = yaml.safe_load(open('.licensed.yml')) if open('.licensed.yml', 'r').readable() else {}
            cfg.setdefault('reviewed', {})
            for line in override.splitlines():
                m = re.match(r'-\s+\`([^@]+)@([^\`]+)\`:\s+(\S+)\s+—', line)
                if m:
                    pkg, ver, lic = m.group(1), m.group(2), m.group(3)
                    cfg['reviewed'].setdefault('any', []).append(f'{pkg}@{ver}')
            yaml.safe_dump(cfg, open('.licensed.yml', 'w'))
            "
            fi
        - name: Run licensed
          run: licensed cache && licensed status
  ```

  **Note**: this workflow expects `.licensed.yml` in the repo (synced from
  `policies/license-config.yml` by scaffold-on-poll, Task 1.6). The
  `LICENSE-OVERRIDE.md` parsing is best-effort; if it errors, license-check
  fails closed (correct behavior for a security gate).

- [ ] **Step 3: Create `scorecard.yml`**

  ```yaml
  name: scorecard
  on:
    branch_protection_rule:
    schedule:
      - cron: "0 13 * * 1"
    push:
      branches: [main]
  permissions:
    contents: read
    security-events: write
    id-token: write
    actions: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    analysis:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
          with:
            persist-credentials: false
        - uses: ossf/scorecard-action@62b2cac7ed8198b15735ed49ab1e5cf35480ba46 # v2.4.0
          with:
            results_file: results.sarif
            results_format: sarif
            publish_results: true
        - uses: actions/upload-artifact@0b2256b8c012f0828dc542b3febcab082c67f72b # v4.3.4
          with:
            name: scorecard-results
            path: results.sarif
            retention-days: 5
        - uses: github/codeql-action/upload-sarif@b611370bb5703a7efb587f9d136a52ea24c5c38c # v3.25.11
          with:
            sarif_file: results.sarif
  ```

- [ ] **Step 4: Run actionlint and commit**

  ```bash
  ./actionlint -color .github/workflows/*.yml
  git add .github/workflows/{codeql,license-check,scorecard}.yml
  git commit -m "feat(workflows): add codeql, license-check, scorecard"
  git push origin main
  ```

### Task 1.6: Create the four enforcement workflows

**Files:**
- Create: `.github/workflows/enforce-on-poll.yml`
- Create: `.github/workflows/scaffold-on-poll.yml`
- Create: `.github/workflows/drift-audit.yml`
- Create: `.github/workflows/force-sync.yml`
- Create: `state/configured-repos.json` (initial empty state)
- Create: `scripts/policy/lib.sh` (shared bash helpers)

These are the App-driven workflows. Each mints an installation token, calls the GitHub API, and updates `state/configured-repos.json`.

- [ ] **Step 1: Create `state/configured-repos.json` with empty initial state**

  ```json
  {
    "schemaVersion": 1,
    "lastSyncAt": null,
    "appInstallationId": null,
    "repos": {}
  }
  ```

- [ ] **Step 2: Create `scripts/policy/lib.sh` with shared helpers**

  ```bash
  #!/usr/bin/env bash
  # Shared helpers for the four App-driven policy workflows.
  # Sourced by enforce-on-poll, scaffold-on-poll, drift-audit, force-sync.
  set -euo pipefail

  # mint_installation_token: produces a 1-hour scoped token from the App JWT.
  # Requires env: APP_ID, APP_PRIVATE_KEY (PEM), APP_INSTALLATION_ID.
  mint_installation_token() {
    local jwt
    jwt=$(generate_jwt)
    curl -sSf -X POST \
      -H "Authorization: Bearer $jwt" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/app/installations/${APP_INSTALLATION_ID}/access_tokens" \
      | jq -r .token
  }

  # generate_jwt: produces a 9-min JWT signed by the App's private key.
  # Requires env: APP_ID, APP_PRIVATE_KEY.
  generate_jwt() {
    local now iat exp header payload header_b64 payload_b64 sig
    now=$(date +%s)
    iat=$((now - 60))
    exp=$((now + 540))
    header='{"alg":"RS256","typ":"JWT"}'
    payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${APP_ID}\"}"
    header_b64=$(printf '%s' "$header" | base64 -w0 | tr '+/' '-_' | tr -d '=')
    payload_b64=$(printf '%s' "$payload" | base64 -w0 | tr '+/' '-_' | tr -d '=')
    sig=$(printf '%s.%s' "$header_b64" "$payload_b64" \
      | openssl dgst -sha256 -sign <(printf '%s' "$APP_PRIVATE_KEY") \
      | base64 -w0 | tr '+/' '-_' | tr -d '=')
    printf '%s.%s.%s' "$header_b64" "$payload_b64" "$sig"
  }

  # list_installation_repos: returns a JSON array of full_names for repos the
  # App is installed on.
  list_installation_repos() {
    local token=$1
    curl -sSf \
      -H "Authorization: token $token" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/installation/repositories?per_page=100" \
      | jq -r '.repositories[].full_name'
  }

  # apply_canonical_ruleset: PUTs the ruleset to the given repo.
  # Args: token, owner/repo, path-to-ruleset-json.
  apply_canonical_ruleset() {
    local token=$1
    local repo=$2
    local ruleset_file=$3
    # Validate APP_INTEGRATION_ID is set and numeric before substitution.
    # --argjson silently produces malformed JSON if given empty/non-numeric input.
    if [[ -z "${APP_INTEGRATION_ID:-}" ]] || ! [[ "$APP_INTEGRATION_ID" =~ ^[0-9]+$ ]]; then
      echo "::error::APP_INTEGRATION_ID is unset or non-numeric: '${APP_INTEGRATION_ID:-}'"
      return 1
    fi
    # Substitute the App integration ID into the bypass_actors placeholder.
    local ruleset
    ruleset=$(jq --argjson app_id "$APP_INTEGRATION_ID" \
      '(.bypass_actors[] | select(.actor_id == "REPLACE_WITH_APP_INTEGRATION_ID") | .actor_id) |= $app_id' \
      "$ruleset_file")
    # Try create; if 422 (already exists), update via PATCH.
    local existing_id
    existing_id=$(curl -sSf \
      -H "Authorization: token $token" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${repo}/rulesets" \
      | jq -r '.[] | select(.name == "nischal94 canonical main protection") | .id')
    if [ -n "$existing_id" ]; then
      curl -sSf -X PUT \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github+json" \
        -d "$ruleset" \
        "https://api.github.com/repos/${repo}/rulesets/${existing_id}"
    else
      curl -sSf -X POST \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github+json" \
        -d "$ruleset" \
        "https://api.github.com/repos/${repo}/rulesets"
    fi
  }

  # commit_state: rebases on origin/main, retries on conflict up to 3 times.
  commit_state() {
    local message=$1
    local attempt=1
    while [ $attempt -le 3 ]; do
      git add state/configured-repos.json
      if git diff --cached --quiet; then
        echo "No state changes to commit."
        return 0
      fi
      git commit -m "$message"
      if git pull --rebase origin main && git push origin main; then
        return 0
      fi
      echo "Push failed (attempt $attempt). Retrying with backoff..."
      sleep $((attempt * 5))
      attempt=$((attempt + 1))
    done
    echo "::error::Failed to commit state after 3 attempts. Manual intervention required."
    exit 1
  }
  ```

  Make it executable:
  ```bash
  chmod +x scripts/policy/lib.sh
  ```

- [ ] **Step 3: Create `enforce-on-poll.yml`**

  ```yaml
  name: enforce-on-poll
  on:
    schedule:
      - cron: "*/5 * * * *"
    workflow_dispatch:
  permissions:
    contents: write
    id-token: write
  concurrency:
    group: state-writer
    cancel-in-progress: false
  jobs:
    enforce:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
          with:
            token: ${{ secrets.GITHUB_TOKEN }}
        - name: Set App auth env vars
          env:
            APP_ID: ${{ vars.APP_ID }}
            APP_INSTALLATION_ID: ${{ vars.APP_INSTALLATION_ID }}
            APP_INTEGRATION_ID: ${{ vars.APP_INTEGRATION_ID }}
            APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
          run: |
            echo "APP_ID=$APP_ID" >> "$GITHUB_ENV"
            echo "APP_INSTALLATION_ID=$APP_INSTALLATION_ID" >> "$GITHUB_ENV"
            echo "APP_INTEGRATION_ID=$APP_INTEGRATION_ID" >> "$GITHUB_ENV"
            # APP_PRIVATE_KEY: pass via env: at the consuming step,
            # not via GITHUB_ENV (multi-line PEM doesn't survive
            # GITHUB_ENV's single-line-per-var format reliably).
        - name: Apply ruleset to all installation repos
          run: |
            source scripts/policy/lib.sh
            TOKEN=$(mint_installation_token)
            for REPO in $(list_installation_repos "$TOKEN"); do
              # Skip already-configured repos (per the §3.3b invariant).
              if jq -e --arg r "$REPO" '.repos[$r]' state/configured-repos.json > /dev/null; then
                echo "Skipping already-configured: $REPO"
                continue
              fi
              echo "Applying ruleset to: $REPO"
              apply_canonical_ruleset "$TOKEN" "$REPO" policies/canonical-ruleset.json
              # Record in state.
              jq --arg r "$REPO" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '.repos[$r] = {rulesetVersion: "v3", configuredAt: $now}' \
                state/configured-repos.json > state.tmp && mv state.tmp state/configured-repos.json
            done
            jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '.lastSyncAt = $now' \
              state/configured-repos.json > state.tmp && mv state.tmp state/configured-repos.json
        - name: Commit state changes
          run: |
            source scripts/policy/lib.sh
            git config user.name "nischal94-policy[bot]"
            git config user.email "nischal94-policy[bot]@users.noreply.github.com"
            commit_state "chore(policy): apply ruleset to new repos"
  ```

- [ ] **Step 4: Create `scaffold-on-poll.yml`**

  ```yaml
  name: scaffold-on-poll
  on:
    workflow_run:
      workflows: [enforce-on-poll]
      types: [completed]
  permissions:
    contents: read
    id-token: write
  concurrency:
    group: state-writer
    cancel-in-progress: false
  jobs:
    scaffold:
      if: ${{ github.event.workflow_run.conclusion == 'success' }}
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Set App auth env vars
          env:
            APP_ID: ${{ vars.APP_ID }}
            APP_INSTALLATION_ID: ${{ vars.APP_INSTALLATION_ID }}
            APP_INTEGRATION_ID: ${{ vars.APP_INTEGRATION_ID }}
            APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
          run: |
            echo "APP_ID=$APP_ID" >> "$GITHUB_ENV"
            echo "APP_INSTALLATION_ID=$APP_INSTALLATION_ID" >> "$GITHUB_ENV"
            echo "APP_INTEGRATION_ID=$APP_INTEGRATION_ID" >> "$GITHUB_ENV"
            # APP_PRIVATE_KEY: pass via env: at the consuming step,
            # not via GITHUB_ENV (multi-line PEM doesn't survive
            # GITHUB_ENV's single-line-per-var format reliably).
        - name: Open scaffold PRs into newly-configured repos
          run: |
            source scripts/policy/lib.sh
            TOKEN=$(mint_installation_token)
            # Find repos in state with no scaffoldedWorkflowsVersion key set.
            UNSCAFFOLDED=$(jq -r '.repos | to_entries[] | select(.value.scaffoldedWorkflowsVersion == null) | .key' \
              state/configured-repos.json)
            for REPO in $UNSCAFFOLDED; do
              echo "Scaffolding workflows into: $REPO"
              # Clone target repo.
              TMPDIR=$(mktemp -d)
              git clone "https://x-access-token:${TOKEN}@github.com/${REPO}.git" "$TMPDIR"
              cd "$TMPDIR"
              git checkout -b chore/scaffold-layer-1-workflows
              mkdir -p .github/workflows
              # Copy each Layer 1 workflow from the canonical source.
              cp -r ../../.github/workflows/{gitleaks,dependency-review,osv-scanner,actionlint,pin-actions,pr-title,codeql,license-check,scorecard}.yml \
                .github/workflows/
              cp ../../policies/license-config.yml .licensed.yml
              git add .github/ .licensed.yml
              git commit -m "chore: scaffold Layer 1 universal workflows"
              git push origin chore/scaffold-layer-1-workflows
              # Open PR.
              gh pr create --repo "$REPO" \
                --title "chore: scaffold Layer 1 universal workflows" \
                --body "Auto-opened by nischal94-policy. See policies/required-checks.yml in nischal94/.github for details."
              cd -
            done
  ```

- [ ] **Step 5: Create `drift-audit.yml`**

  ```yaml
  name: drift-audit
  on:
    schedule:
      - cron: "0 9 * * 0"
    workflow_dispatch:
  permissions:
    contents: write
    id-token: write
    issues: write
  concurrency:
    group: state-writer
    cancel-in-progress: false
  jobs:
    drift-audit:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Set App auth env vars
          env:
            APP_ID: ${{ vars.APP_ID }}
            APP_INSTALLATION_ID: ${{ vars.APP_INSTALLATION_ID }}
            APP_INTEGRATION_ID: ${{ vars.APP_INTEGRATION_ID }}
            APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
          run: |
            echo "APP_ID=$APP_ID" >> "$GITHUB_ENV"
            echo "APP_INSTALLATION_ID=$APP_INSTALLATION_ID" >> "$GITHUB_ENV"
            echo "APP_INTEGRATION_ID=$APP_INTEGRATION_ID" >> "$GITHUB_ENV"
            # APP_PRIVATE_KEY: pass via env: at the consuming step,
            # not via GITHUB_ENV (multi-line PEM doesn't survive
            # GITHUB_ENV's single-line-per-var format reliably).
        - name: Audit each configured repo for drift
          run: |
            source scripts/policy/lib.sh
            TOKEN=$(mint_installation_token)
            for REPO in $(jq -r '.repos | keys[]' state/configured-repos.json); do
              echo "Auditing: $REPO"
              # Fetch active ruleset.
              ACTIVE=$(curl -sSf \
                -H "Authorization: token $TOKEN" \
                "https://api.github.com/repos/${REPO}/rulesets" \
                | jq '.[] | select(.name == "nischal94 canonical main protection")')
              if [ -z "$ACTIVE" ]; then
                # Critical drift: ruleset deleted entirely.
                echo "::error::Critical drift on $REPO: ruleset missing"
                # Open or update rolling issue against nischal94/.github.
                gh issue create --repo nischal94/.github \
                  --title "policy: drift detected on $REPO/main" \
                  --body "Critical drift: canonical ruleset is missing on $REPO/main. Run force-sync to remediate." \
                  --label "drift-critical" || true
                continue
              fi
              # Note: this Phase 1 implementation only checks ruleset existence.
              # Rule-by-rule diff + auto-PR remediation (per spec §3.4) is added
              # in a follow-up commit after Phase 2 smoke-tests pass.
            done
  ```

- [ ] **Step 6: Create `force-sync.yml`**

  ```yaml
  name: force-sync
  on:
    workflow_dispatch:
      inputs:
        target:
          description: "Repo full name (owner/repo) or 'all'"
          required: true
          default: "all"
  permissions:
    contents: write
    id-token: write
  concurrency:
    group: state-writer
    cancel-in-progress: false
  jobs:
    force-sync:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
          with:
            token: ${{ secrets.GITHUB_TOKEN }}
        - name: Set App auth env vars
          env:
            APP_ID: ${{ vars.APP_ID }}
            APP_INSTALLATION_ID: ${{ vars.APP_INSTALLATION_ID }}
            APP_INTEGRATION_ID: ${{ vars.APP_INTEGRATION_ID }}
            APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
          run: |
            echo "APP_ID=$APP_ID" >> "$GITHUB_ENV"
            echo "APP_INSTALLATION_ID=$APP_INSTALLATION_ID" >> "$GITHUB_ENV"
            echo "APP_INTEGRATION_ID=$APP_INTEGRATION_ID" >> "$GITHUB_ENV"
            # APP_PRIVATE_KEY: pass via env: at the consuming step,
            # not via GITHUB_ENV (multi-line PEM doesn't survive
            # GITHUB_ENV's single-line-per-var format reliably).
        - name: Re-apply ruleset to target(s)
          run: |
            source scripts/policy/lib.sh
            TOKEN=$(mint_installation_token)
            if [ "${{ inputs.target }}" = "all" ]; then
              TARGETS=$(list_installation_repos "$TOKEN")
            else
              TARGETS="${{ inputs.target }}"
            fi
            for REPO in $TARGETS; do
              echo "Force-applying ruleset to: $REPO"
              apply_canonical_ruleset "$TOKEN" "$REPO" policies/canonical-ruleset.json
              # Reset state entry.
              jq --arg r "$REPO" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '.repos[$r] = {rulesetVersion: "v3", configuredAt: $now, forceSyncedAt: $now}' \
                state/configured-repos.json > state.tmp && mv state.tmp state/configured-repos.json
            done
        - name: Commit state changes
          run: |
            source scripts/policy/lib.sh
            git config user.name "nischal94-policy[bot]"
            git config user.email "nischal94-policy[bot]@users.noreply.github.com"
            commit_state "chore(policy): force-sync ruleset for ${{ inputs.target }}"
  ```

- [ ] **Step 7: Run actionlint and commit**

  ```bash
  ./actionlint -color .github/workflows/*.yml
  git add .github/workflows/{enforce-on-poll,scaffold-on-poll,drift-audit,force-sync}.yml \
          state/configured-repos.json scripts/policy/lib.sh
  git commit -m "feat(policy): add four enforcement workflows + state file + helpers"
  git push origin main
  ```

### Task 1.7: Create the App canary workflow

**Files:**
- Create: `.github/workflows/app-canary.yml`

This is the watchdog that detects if the App itself has been uninstalled. Uses a fine-grained PAT scoped to "Account: Installations: read" — the only PAT in the system per spec §7.6.

- [ ] **Step 1: Create `app-canary.yml`**

  ```yaml
  name: app-canary
  on:
    schedule:
      - cron: "0 11 * * *"
    workflow_dispatch:
  permissions:
    contents: read
    issues: write
  jobs:
    canary:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - name: Verify nischal94-policy App is still installed
          env:
            CANARY_PAT: ${{ secrets.CANARY_PAT }}
          run: |
            set -euo pipefail
            INSTALLATIONS=$(curl -sSf \
              -H "Authorization: token ${CANARY_PAT}" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/user/installations" \
              | jq -r '.installations[].app_slug')
            if echo "$INSTALLATIONS" | grep -q "nischal94-policy"; then
              echo "App is installed. Canary green."
            else
              echo "::error::App nischal94-policy is NOT installed!"
              gh issue create --repo nischal94/.github \
                --title "CRITICAL: nischal94-policy App is not installed" \
                --body "Daily canary detected the App is missing. Re-install from https://github.com/settings/apps/nischal94-policy/installations" \
                --label "canary-critical" || true
              exit 1
            fi
  ```

- [ ] **Step 2: Run actionlint and commit**

  ```bash
  ./actionlint .github/workflows/app-canary.yml
  git add .github/workflows/app-canary.yml
  git commit -m "feat(policy): add daily app-canary watchdog"
  git push origin main
  ```

### Phase 1 exit gate

Before proceeding to Phase 2, confirm:

- [ ] `nischal94/.github` repo exists and contains all community files.
- [ ] All 9 universal Layer 1 workflows pass `actionlint -color .github/workflows/*.yml` locally.
- [ ] All 4 enforcement workflows + 1 canary present.
- [ ] `state/configured-repos.json` exists with empty repos object.
- [ ] `scripts/policy/lib.sh` exists and is executable.
- [ ] `policies/canonical-ruleset.json` and `policies/required-checks.yml` exist.
- [ ] All commits pushed to `main`.

---

## Phase 2 — Install App + first end-to-end smoke test [USER] + [CLAUDE]

### Task 2.1: Install the App on the user account [USER]

- [ ] **Step 1: Open the App's installation page**

  Navigate to: `https://github.com/settings/apps/nischal94-policy/installations`

- [ ] **Step 2: Click "Install" next to your account**

  Choose **"All repositories"**. (You can change this later, but for the polling enforcer to work, it needs visibility into every repo it's expected to protect.)

- [ ] **Step 3: Note the installation ID**

  After installation, the URL contains the installation ID: `https://github.com/settings/installations/<NUMBER>`. Save that number.

- [ ] **Step 4: Note the App's integration ID**

  Run:
  ```bash
  gh api /user/installations --jq '.installations[] | select(.app_slug=="nischal94-policy") | .target_id'
  ```
  Save that number — this is the `actor_id` used in `bypass_actors`.

- [ ] **Step 5: Note installation_id and integration_id**

  Save these alongside the App ID and Client ID from Phase 0 Task 0.1.
  They'll be uploaded as repo *variables* (not secrets — they're public
  identifiers) in the next task.

### Task 2.2: Upload App credentials to `nischal94/.github` [USER]

- [ ] **Step 1: Upload the App private key as a repo secret**

  ```bash
  cd ~/projects/nischal94-dot-github
  gh secret set APP_PRIVATE_KEY < ~/secrets-staging/nischal94-policy.*.private-key.pem
  ```

  This reads the `.pem` file from the staging location (Phase 0 Task 0.3
  Step 1) and uploads its contents as the `APP_PRIVATE_KEY` repo secret.

- [ ] **Step 2: Upload App identifiers as repo variables**

  ```bash
  gh variable set APP_ID --body "<App ID from Task 0.1 Step 7>"
  gh variable set APP_INSTALLATION_ID --body "<Installation ID from Task 2.1 Step 3>"
  gh variable set APP_INTEGRATION_ID --body "<Integration ID from Task 2.1 Step 4>"
  ```

  Replace each `<...>` placeholder with the actual numeric value.
  These are not secrets — they appear in every API URL — but storing
  them as variables keeps the workflows clean.

- [ ] **Step 3: Securely delete the local `.pem` file**

  Now that the key is uploaded, remove the local copy:
  ```bash
  shred -u ~/secrets-staging/nischal94-policy.*.private-key.pem
  rmdir ~/secrets-staging
  ```

  (`shred` overwrites then unlinks. macOS users without `shred`:
  `rm -P` is the closest equivalent.)

- [ ] **Step 4: Create a fine-grained PAT for the canary**

  Navigate to: `https://github.com/settings/personal-access-tokens/new`.
  - **Token name**: `nischal94-policy canary`
  - **Resource owner**: `nischal94`
  - **Repository access**: `Public repositories (read-only)`
  - **Account permissions**: `Installations: Read-only`
  - **Expiration**: 1 year

  Create; copy the token.

- [ ] **Step 5: Set `CANARY_PAT` secret**

  ```bash
  gh secret set CANARY_PAT
  # paste the PAT
  ```

  Calendar reminder: rotate this PAT in 1 year (set for ~11 months
  to give you a buffer).

- [ ] **Step 6: Verify all repo secrets and variables are in place**

  ```bash
  gh secret list  # expect: APP_PRIVATE_KEY, CANARY_PAT
  gh variable list # expect: APP_ID, APP_INSTALLATION_ID, APP_INTEGRATION_ID
  ```

### Task 2.3: First smoke test — manual dispatch of enforce-on-poll [CLAUDE] + [USER]

- [ ] **Step 1: Manually dispatch the workflow [USER]**

  ```bash
  cd ~/projects/nischal94-dot-github
  gh workflow run enforce-on-poll.yml
  ```

- [ ] **Step 2: (No approval gate in v0.4)**

  Per spec v0.4 §3.3c, the protected-environment-with-required-reviewer
  approach was dropped. Workflows now run directly without a manual
  approval click. The trust boundary is GitHub login + TOTP MFA + branch
  protection on `nischal94/.github`, not an environment gate.

- [ ] **Step 3: Watch the run [CLAUDE]**

  ```bash
  gh run watch
  ```

  Expected: workflow completes successfully, `state/configured-repos.json` is populated with entries for every repo the App can see.

- [ ] **Step 4: Verify the ruleset was applied to `nischal94/.github` itself**

  ```bash
  gh api repos/nischal94/.github/rulesets --jq '.[] | {id, name, enforcement}'
  ```

  Expected: at least one ruleset named `"nischal94 canonical main protection"` with `"enforcement": "active"`.

### Task 2.4: Smoke test on a throwaway repo [USER] + [CLAUDE]

- [ ] **Step 1: Create a throwaway repo [USER]**

  ```bash
  gh repo create nischal94/test-enforcement-1 --public \
    --description "Throwaway smoke test for nischal94-policy enforcement."
  ```

- [ ] **Step 2: Wait up to 10 minutes [USER]**

  The App polls every 5 minutes, plus GitHub's cron is best-effort. Set a timer; do not push to the repo during this window.

- [ ] **Step 3: Verify the ruleset landed [CLAUDE]**

  ```bash
  gh api repos/nischal94/test-enforcement-1/rulesets --jq '.[] | {id, name, enforcement}'
  ```

  Expected: ruleset present and active.

- [ ] **Step 4: Verify the scaffold PR was opened [CLAUDE]**

  ```bash
  gh pr list --repo nischal94/test-enforcement-1
  ```

  Expected: one PR titled `"chore: scaffold Layer 1 universal workflows"`.

- [ ] **Step 5: Merge the scaffold PR [USER]**

  ```bash
  gh pr merge --repo nischal94/test-enforcement-1 1 --squash
  ```

  Wait for the workflows in `nischal94/test-enforcement-1` to run. They may fail (the test repo has no real code) but should at least *attempt* to run, proving they were synced correctly.

- [ ] **Step 6: Clean up the throwaway repo [USER]**

  ```bash
  gh repo delete nischal94/test-enforcement-1 --yes
  ```

### Phase 2 exit gate

Before proceeding to Phase 3, confirm:

- [ ] App installed on `nischal94` account.
- [ ] `APP_PRIVATE_KEY` and `CANARY_PAT` secrets set on `nischal94/.github`.
- [ ] `APP_ID`, `APP_INSTALLATION_ID`, `APP_INTEGRATION_ID` variables set on `nischal94/.github`.
- [ ] Local `.pem` file shredded after upload (Phase 0 staging dir empty).
- [ ] Manual `enforce-on-poll` dispatch succeeded (no approval gate in v0.4).
- [ ] Throwaway repo received the canonical ruleset within 10 min of creation.
- [ ] Throwaway repo received a scaffold PR with all Layer 1 workflows.

If any fail, debug. Common failure modes:
- `APP_PRIVATE_KEY` malformed → ensure the secret was uploaded via `gh secret set APP_PRIVATE_KEY < file.pem` (file redirection preserves newlines; copy-paste into the GitHub UI sometimes mangles them).
- App `bypass_actors` integration ID still says the placeholder string → check Task 2.1 Step 4 was completed and the value matches the App ID at https://github.com/settings/apps/nischal94-policy.
- Concurrency lock stuck → manually cancel any orphaned `state-writer` runs.

---

## Phase 3 — Refactor `nischal94/repo-template` [CLAUDE]

This phase rebuilds the Layer 2 scaffold per spec §4. Most tasks are file creation in the existing `nischal94/repo-template` repo on a feature branch.

### Task 3.1: Create the working branch in repo-template

- [ ] **Step 1: Switch to repo-template and create branch**

  ```bash
  cd ~/projects/repo-template
  git checkout main
  git pull origin main
  git checkout -b feat/layer-2-refactor
  ```

### Task 3.2: Add `.github/scripts/` stack-specific entry points

**Files:**
- Create: `.github/scripts/ci-node.sh`
- Create: `.github/scripts/ci-python.sh`
- Create: `.github/scripts/ci-go.sh`
- Create: `.github/scripts/ci-shell.sh`
- Create: `.github/scripts/ci-docker.sh`
- Create: `.github/scripts/ci-sql.sh`
- Create: `.github/scripts/ci-e2e.sh`
- Create: `.github/scripts/ci-docs.sh`
- Create: `.github/scripts/cd-deploy.sh`
- Create: `.github/scripts/cd-smoke.sh`

Each script is the actual CI contract called by the corresponding workflow. The Makefile is developer-only per spec §4.2.

- [ ] **Step 1: Create `ci-node.sh`**

  ```bash
  #!/usr/bin/env bash
  # CI entry point for Node projects. Called by .github/workflows/ci-node.yml.
  set -euo pipefail
  echo "==> Installing deps..."
  if [ -f package-lock.json ]; then
    npm ci
  elif [ -f pnpm-lock.yaml ]; then
    npx pnpm i --frozen-lockfile
  elif [ -f yarn.lock ]; then
    yarn install --frozen-lockfile
  else
    npm i
  fi
  echo "==> Lint..."
  npm run lint --if-present
  echo "==> Typecheck..."
  npm run typecheck --if-present || npx tsc --noEmit
  echo "==> Test..."
  npm test --if-present
  echo "==> Coverage..."
  npm run test:coverage --if-present
  echo "==> Build..."
  npm run build --if-present
  ```

- [ ] **Step 2: Create `ci-python.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> Installing deps..."
  if [ -f pyproject.toml ]; then
    pip install -e ".[dev,test]" || pip install -e .
  fi
  if [ -f requirements.txt ]; then
    pip install -r requirements.txt
  fi
  if [ -f requirements-dev.txt ]; then
    pip install -r requirements-dev.txt
  fi
  echo "==> Lint (ruff)..."
  ruff check .
  echo "==> Format check (ruff format)..."
  ruff format --check .
  echo "==> Typecheck (mypy)..."
  mypy . || true # mypy as advisory until type-clean
  echo "==> Test (pytest)..."
  pytest --cov --cov-report=xml --cov-report=term
  echo "==> Audit (pip-audit)..."
  pip-audit
  echo "==> Bandit..."
  bandit -r . -ll
  ```

- [ ] **Step 3: Create `ci-go.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> go mod download..."
  go mod download
  echo "==> go vet..."
  go vet ./...
  echo "==> staticcheck..."
  go install honnef.co/go/tools/cmd/staticcheck@latest
  staticcheck ./...
  echo "==> govulncheck..."
  go install golang.org/x/vuln/cmd/govulncheck@latest
  govulncheck ./...
  echo "==> Test with race + coverage..."
  go test -race -coverprofile=coverage.out -covermode=atomic ./...
  echo "==> Build..."
  go build ./...
  ```

- [ ] **Step 4: Create `ci-shell.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> shellcheck..."
  find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" \
    -exec shellcheck {} +
  echo "==> shfmt --diff..."
  find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" \
    -exec shfmt --diff {} +
  ```

- [ ] **Step 5: Create `ci-docker.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> hadolint..."
  if [ -f Dockerfile ]; then
    docker run --rm -i hadolint/hadolint < Dockerfile
  fi
  echo "==> Build image..."
  docker build -t local/test:ci .
  echo "==> trivy scan..."
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy:latest image --severity HIGH,CRITICAL --exit-code 1 local/test:ci
  ```

- [ ] **Step 6: Create `ci-sql.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> Apply migrations to ephemeral Postgres..."
  # Postgres service container provides $PGHOST, $PGPORT, $PGUSER, $PGPASSWORD.
  if [ -d migrations ]; then
    for f in migrations/*.sql; do
      psql -f "$f"
    done
  fi
  echo "==> drizzle-kit check (if configured)..."
  if [ -f drizzle.config.ts ] || [ -f drizzle.config.js ]; then
    npx drizzle-kit check || true # advisory in v1
  fi
  echo "==> Run pg-tap tests..."
  if find . -name "*.test.sql" | grep -q .; then
    pg_prove --recurse --pset tuples_only=1 --schema test \
      $(find . -name "*.test.sql")
  fi
  ```

- [ ] **Step 7: Create `ci-e2e.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
    echo "==> Install Playwright browsers..."
    npx playwright install --with-deps
    echo "==> Run Playwright..."
    npx playwright test
  elif [ -f cypress.config.ts ] || [ -f cypress.config.js ]; then
    echo "==> Run Cypress..."
    npx cypress run
  else
    echo "No E2E config detected; skipping."
  fi
  ```

- [ ] **Step 8: Create `ci-docs.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "==> Build docs..."
  if [ -f mkdocs.yml ]; then
    pip install mkdocs mkdocs-material
    mkdocs build --strict
  elif [ -f docusaurus.config.ts ] || [ -f docusaurus.config.js ]; then
    npm ci
    npm run build
  elif [ -d docs ]; then
    echo "Plain docs/ dir, no build step. Running link-check only."
  fi
  echo "==> Link check..."
  npx -y markdown-link-check **/*.md || true # advisory until tuned
  ```

- [ ] **Step 9: Create `cd-deploy.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -f vercel.json ]; then
    echo "==> Deploy to Vercel (long-lived token; documented gap §4.6)..."
    npx vercel --token="$VERCEL_TOKEN" --prebuilt --prod=false
  elif [ -f fly.toml ]; then
    echo "==> Deploy to Fly.io (long-lived token; documented gap §4.6)..."
    flyctl deploy --remote-only --access-token="$FLY_API_TOKEN"
  elif [ -f railway.toml ]; then
    echo "==> Deploy to Railway (long-lived token; documented gap §4.6)..."
    npx -y @railway/cli up --token="$RAILWAY_TOKEN"
  else
    echo "No CD target detected (no vercel.json / fly.toml / railway.toml). Skipping."
  fi
  ```

- [ ] **Step 10: Create `cd-smoke.sh`**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f .github/smoke.yml ]; then
    echo "No .github/smoke.yml; skipping smoke check."
    exit 0
  fi
  ROUTES=$(yq '.routes[]' .github/smoke.yml)
  BASE_URL="${PREVIEW_URL:-}"
  if [ -z "$BASE_URL" ]; then
    echo "::error::PREVIEW_URL not set; cannot smoke test."
    exit 1
  fi
  for ROUTE in $ROUTES; do
    URL="${BASE_URL}${ROUTE}"
    echo "==> GET $URL"
    HTTP=$(curl -sS -o /dev/null -w "%{http_code}" "$URL")
    if [ "$HTTP" -ge 400 ]; then
      echo "::error::$URL returned $HTTP"
      exit 1
    fi
    echo "    OK ($HTTP)"
  done
  ```

- [ ] **Step 11: Make all scripts executable**

  ```bash
  chmod +x .github/scripts/*.sh
  ```

- [ ] **Step 12: Smoke-test each script's syntax**

  ```bash
  for s in .github/scripts/*.sh; do
    bash -n "$s" && echo "OK: $s"
  done
  ```

  Expected: all 10 print `OK:`.

- [ ] **Step 13: Commit**

  ```bash
  git add .github/scripts/
  git commit -m "feat(layer2): add stack-specific CI/CD entry scripts"
  ```

### Task 3.3: Add 8 language-profile workflows

**Files:**
- Create: `.github/workflows/ci-node.yml`
- Create: `.github/workflows/ci-python.yml`
- Create: `.github/workflows/ci-go.yml`
- Create: `.github/workflows/ci-shell.yml`
- Create: `.github/workflows/ci-docker.yml`
- Create: `.github/workflows/ci-sql.yml`
- Create: `.github/workflows/ci-e2e.yml`
- Create: `.github/workflows/ci-docs.yml`

Each workflow checks for the marker file and exits cleanly if absent. Otherwise calls the matching script.

- [ ] **Step 1: Create `ci-node.yml`**

  ```yaml
  name: ci-node
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    detect:
      runs-on: ubuntu-latest
      outputs:
        applies: ${{ steps.check.outputs.applies }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: check
          run: |
            if [ -f .github/stacks.yml ]; then
              if yq '.stacks[] | select(.kind == "node")' .github/stacks.yml > /dev/null; then
                echo "applies=true" >> "$GITHUB_OUTPUT"
              else
                echo "applies=false" >> "$GITHUB_OUTPUT"
              fi
            elif [ -f package.json ]; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
            else
              echo "applies=false" >> "$GITHUB_OUTPUT"
            fi
    ci:
      needs: detect
      if: needs.detect.outputs.applies == 'true'
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: block
            allowed-endpoints: >
              registry.npmjs.org:443
              registry.yarnpkg.com:443
              github.com:443
              api.github.com:443
              objects.githubusercontent.com:443
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: actions/setup-node@1e60f620b9541d16bece96c5465dc8ee9832be0b # v4.0.3
          with:
            node-version-file: ".nvmrc"
            cache: npm
        - name: Run ci-node.sh
          run: bash .github/scripts/ci-node.sh
  ```

- [ ] **Step 2: Create `ci-python.yml`**

  ```yaml
  name: ci-python
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    detect:
      runs-on: ubuntu-latest
      outputs:
        applies: ${{ steps.check.outputs.applies }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: check
          run: |
            if [ -f .github/stacks.yml ]; then
              if yq '.stacks[] | select(.kind == "python")' .github/stacks.yml > /dev/null; then
                echo "applies=true" >> "$GITHUB_OUTPUT"
              else
                echo "applies=false" >> "$GITHUB_OUTPUT"
              fi
            elif [ -f pyproject.toml ] || ls requirements*.txt 2>/dev/null | grep -q .; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
            else
              echo "applies=false" >> "$GITHUB_OUTPUT"
            fi
    ci:
      needs: detect
      if: needs.detect.outputs.applies == 'true'
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: block
            allowed-endpoints: >
              pypi.org:443
              files.pythonhosted.org:443
              github.com:443
              api.github.com:443
              objects.githubusercontent.com:443
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: actions/setup-python@39cd14951b08e74b54015e9e001cdefcf80e669f # v5.1.1
          with:
            python-version-file: ".python-version"
            cache: pip
        - name: Run ci-python.sh
          run: bash .github/scripts/ci-python.sh
  ```

- [ ] **Step 3: Create `ci-go.yml`**

  ```yaml
  name: ci-go
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    detect:
      runs-on: ubuntu-latest
      outputs:
        applies: ${{ steps.check.outputs.applies }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: check
          run: |
            if [ -f .github/stacks.yml ] && yq '.stacks[] | select(.kind == "go")' .github/stacks.yml > /dev/null; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
            elif [ -f go.mod ]; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
            else
              echo "applies=false" >> "$GITHUB_OUTPUT"
            fi
    ci:
      needs: detect
      if: needs.detect.outputs.applies == 'true'
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: block
            allowed-endpoints: >
              proxy.golang.org:443
              sum.golang.org:443
              github.com:443
              api.github.com:443
              objects.githubusercontent.com:443
              storage.googleapis.com:443
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: actions/setup-go@0a12ed9d6a96ab950c8f026ed9f722fe0da7ef32 # v5.0.2
          with:
            go-version-file: ".go-version"
            cache: true
        - name: Run ci-go.sh
          run: bash .github/scripts/ci-go.sh
  ```

- [ ] **Step 4: Create `ci-shell.yml`**

  ```yaml
  name: ci-shell
  on:
    pull_request:
    push:
      branches: [main]
  permissions:
    contents: read
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  jobs:
    detect:
      runs-on: ubuntu-latest
      outputs:
        applies: ${{ steps.check.outputs.applies }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: check
          run: |
            # Per spec §4.4: shell triggers only when shell is the PRIMARY language
            # OR when stacks.yml explicitly opts in.
            if [ -f .github/stacks.yml ] && yq '.stacks[] | select(.kind == "shell")' .github/stacks.yml > /dev/null; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
            elif [ ! -f package.json ] && [ ! -f pyproject.toml ] && [ ! -f go.mod ] \
                 && [ ! -f Cargo.toml ] && find . -name "*.sh" -not -path "./.git/*" | head -1 | grep -q .; then
              # No other language detected, but shell scripts present → primary language is shell.
              echo "applies=true" >> "$GITHUB_OUTPUT"
            else
              echo "applies=false" >> "$GITHUB_OUTPUT"
            fi
    ci:
      needs: detect
      if: needs.detect.outputs.applies == 'true'
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: block
            allowed-endpoints: >
              github.com:443
              api.github.com:443
              objects.githubusercontent.com:443
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Install shfmt
          run: go install mvdan.cc/sh/v3/cmd/shfmt@latest
        - name: Run ci-shell.sh
          run: bash .github/scripts/ci-shell.sh
  ```

- [ ] **Step 5: Create `ci-docker.yml`, `ci-sql.yml`, `ci-e2e.yml`, `ci-docs.yml`**

  Each follows the same `detect → ci` pattern with stack-appropriate triggers and allowed-endpoints. To avoid bloating the plan, the full content of each is documented inline in the workflow files themselves; use the patterns from Steps 1-4 as a template:

  - `ci-docker.yml`: detect via `Dockerfile` or `compose.yml`; allowed-endpoints includes `*.docker.io` and `ghcr.io`.
  - `ci-sql.yml`: detect via `migrations/` or `*.sql` files; runs Postgres 16 service container; calls `ci-sql.sh`.
  - `ci-e2e.yml`: detect via `playwright.config.*` or `cypress.config.*`; allowed-endpoints includes `playwright.azureedge.net` for browser downloads.
  - `ci-docs.yml`: detect via `mkdocs.yml` / `docusaurus.config.*` / root `docs/` dir.

  When implementing each, copy the structural pattern from `ci-node.yml` and substitute the appropriate detect logic, allowed-endpoints, and `bash .github/scripts/ci-<stack>.sh` invocation.

- [ ] **Step 6: Run actionlint and commit all 8**

  ```bash
  ./actionlint -color .github/workflows/ci-*.yml
  git add .github/workflows/ci-*.yml
  git commit -m "feat(layer2): add 8 language profile workflows with auto-detection"
  ```

### Task 3.4: Add CD workflows + release pipeline

**Files:**
- Create: `.github/workflows/cd-deploy.yml`
- Create: `.github/workflows/cd-smoke.yml`
- Create: `.github/workflows/release.yml`
- Create: `.github/workflows/sbom-on-release.yml`

- [ ] **Step 1: Create `cd-deploy.yml`**

  ```yaml
  name: cd-deploy
  on:
    push:
      branches: [main]
    workflow_dispatch:
  permissions:
    contents: read
    deployments: write
  concurrency:
    group: cd-deploy
    cancel-in-progress: false
  jobs:
    detect:
      runs-on: ubuntu-latest
      outputs:
        applies: ${{ steps.check.outputs.applies }}
        target: ${{ steps.check.outputs.target }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: check
          run: |
            if [ -f vercel.json ]; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
              echo "target=vercel" >> "$GITHUB_OUTPUT"
            elif [ -f fly.toml ]; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
              echo "target=fly" >> "$GITHUB_OUTPUT"
            elif [ -f railway.toml ]; then
              echo "applies=true" >> "$GITHUB_OUTPUT"
              echo "target=railway" >> "$GITHUB_OUTPUT"
            else
              echo "applies=false" >> "$GITHUB_OUTPUT"
            fi
    deploy:
      needs: detect
      if: needs.detect.outputs.applies == 'true'
      runs-on: ubuntu-latest
      outputs:
        preview-url: ${{ steps.deploy.outputs.preview-url }}
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - id: deploy
          env:
            VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
            FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
            RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
          run: |
            URL=$(bash .github/scripts/cd-deploy.sh)
            echo "preview-url=$URL" >> "$GITHUB_OUTPUT"
  ```

- [ ] **Step 2: Add a `smoke` job to `cd-deploy.yml` (replaces standalone `cd-smoke.yml`)**

  The original v0.3 plan had `cd-smoke.yml` as a separate workflow
  triggered by `workflow_run`. **That doesn't actually work**:
  GitHub's `workflow_run` event payload does NOT include arbitrary
  job outputs from the upstream workflow — `${{ github.event.workflow_run.outputs.preview-url }}` is
  always empty.

  Fix: merge smoke into `cd-deploy.yml` as a second job that depends
  on `deploy` via `needs:`. Job outputs DO pass between jobs in the
  same workflow.

  Append this job to `cd-deploy.yml` (after the `deploy` job):

  ```yaml
    smoke:
      needs: deploy
      if: needs.deploy.outputs.preview-url != ''
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Run cd-smoke.sh
          env:
            PREVIEW_URL: ${{ needs.deploy.outputs.preview-url }}
          run: bash .github/scripts/cd-smoke.sh
  ```

  **Do NOT create a separate `cd-smoke.yml`.** The single-workflow
  pattern is the correct shape; the v0.3 plan's two-workflow pattern
  was a known broken design.

- [ ] **Step 3: Create `release.yml` using slsa-github-generator**

  ```yaml
  name: release
  on:
    push:
      tags: ["v*"]
  permissions:
    contents: write
    id-token: write
    actions: read
  jobs:
    build:
      runs-on: ubuntu-latest
      outputs:
        digest: ${{ steps.hash.outputs.digest }}
      steps:
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - name: Build
          run: |
            mkdir -p dist
            # Stack-specific build invoked here; for the template itself,
            # this is a no-op tarball of docs/.
            tar -czf "dist/release-${GITHUB_REF#refs/tags/}.tar.gz" docs/
        - id: hash
          run: |
            # slsa-github-generator's `base64-subjects` expects a
            # base64-encoded list of `<sha256>  <filename>` lines —
            # i.e., the literal output of `sha256sum`, base64-encoded
            # with no line wrapping. Single-file case only here; if
            # this template ever ships multiple release artifacts,
            # update the build to produce them all in dist/ first
            # (sha256sum * already handles multiple files correctly,
            # but the workflow's intent must be a single subjects blob).
            cd dist
            shopt -s nullglob
            FILES=( *.tar.gz )
            if [ ${#FILES[@]} -eq 0 ]; then
              echo "::error::No artifacts in dist/ to attest."
              exit 1
            fi
            DIGEST=$(sha256sum "${FILES[@]}" | base64 -w0)
            echo "digest=$DIGEST" >> "$GITHUB_OUTPUT"
            echo "Subjects (pre-base64):"
            sha256sum "${FILES[@]}"
        - uses: actions/upload-artifact@0b2256b8c012f0828dc542b3febcab082c67f72b # v4.3.4
          with:
            name: release-artifacts
            path: dist/
            retention-days: 365
    provenance:
      needs: build
      # Per spec §4.6 tag-pinning exception: SLSA generator MUST be tag-pinned.
      uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0
      with:
        base64-subjects: ${{ needs.build.outputs.digest }}
        provenance-name: release.intoto.jsonl
        upload-assets: true
    release:
      needs: [build, provenance]
      runs-on: ubuntu-latest
      steps:
        - uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16 # v4.1.8
          with:
            name: release-artifacts
            path: dist/
        - uses: softprops/action-gh-release@01570a1f39cb168c169c69a18e1c2398200e0fe1 # v2.0.6
          with:
            files: dist/*
            generate_release_notes: true
  ```

- [ ] **Step 4: Create `sbom-on-release.yml`**

  ```yaml
  name: sbom-on-release
  on:
    release:
      types: [published]
  permissions:
    contents: write
    id-token: write
  jobs:
    sbom:
      runs-on: ubuntu-latest
      steps:
        - name: Harden runner
          uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c # v2.9.0
          with:
            egress-policy: audit
        - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
        - uses: anchore/sbom-action@61119d458adab75f756bc0b9e4bde25725f86a7a # v0.17.2
          with:
            artifact-name: sbom.cdx.json
            format: cyclonedx-json
            upload-release-assets: true
  ```

- [ ] **Step 5: Run actionlint and commit**

  ```bash
  ./actionlint -color .github/workflows/cd-*.yml .github/workflows/release.yml .github/workflows/sbom-on-release.yml
  git add .github/workflows/{cd-deploy,cd-smoke,release,sbom-on-release}.yml
  git commit -m "feat(layer2): add CD pipeline + slsa-github-generator releases"
  ```

### Task 3.5: Add bootstrap script + skeleton files

**Files:**
- Replace: `scripts/bootstrap.sh` (drop branch-protection logic)
- Create: `.github/stacks.yml.example`
- Create: `.github/smoke.yml.example`
- Create: `LICENSE-OVERRIDE.md` (empty stub)
- Create: `.editorconfig`
- Create: `.gitattributes`
- Create: `.nvmrc`
- Create: `.python-version`
- Create: `.go-version`
- Create: `.tool-versions`
- Create: `Makefile` (developer-only)
- Create: `lefthook.yml`
- Create: `commitlint.config.js`
- Create: `release-please-config.json`
- Create: `release-please-manifest.json`

- [ ] **Step 1: Create `scripts/bootstrap.sh`**

  ```bash
  #!/usr/bin/env bash
  # Run once after `gh repo create --template`. Stack scaffolding only;
  # branch protection is the App's responsibility per spec §4.7.
  set -euo pipefail

  echo "==> Project name (default: current dir):"
  read -r PROJECT_NAME
  PROJECT_NAME=${PROJECT_NAME:-$(basename "$PWD")}

  echo "==> Primary language? [node|python|go|shell|other]:"
  read -r LANG

  echo "==> License? [MIT|Apache-2.0|BSD-3-Clause]:"
  read -r LICENSE
  LICENSE=${LICENSE:-MIT}

  # Initialize toolchain.
  case "$LANG" in
    node)   npm init -y > /dev/null ;;
    python) test -f pyproject.toml || python -m venv .venv && pip install uv && uv init . ;;
    go)     test -f go.mod || go mod init "github.com/nischal94/$PROJECT_NAME" ;;
    shell)  echo "Shell project; no toolchain init." ;;
    *)      echo "Unknown lang; skipping toolchain init." ;;
  esac

  # Remove unused profile workflows for a cleaner Actions tab.
  KEEP="$LANG"
  for w in .github/workflows/ci-*.yml; do
    base=$(basename "$w" .yml)
    stack=${base#ci-}
    case "$stack" in
      "$KEEP"|docker|sql|e2e|docs|shell) : ;; # keep cross-cutting + chosen
      *) rm -f "$w" ;;
    esac
  done

  # Wire Makefile to language-specific commands.
  cat > Makefile <<EOF
  .PHONY: install lint test build ci

  install:
  EOF
  case "$LANG" in
    node)   echo "	npm install" >> Makefile ;;
    python) echo "	pip install -e .[dev,test]" >> Makefile ;;
    go)     echo "	go mod download" >> Makefile ;;
    *)      echo "	@echo 'No install command configured.'" >> Makefile ;;
  esac
  # ... (lint, test, build, ci targets follow same pattern)

  echo "==> Bootstrap complete. Initial commit:"
  git add .
  git commit -m "chore: initial bootstrap from nischal94/repo-template"
  ```

- [ ] **Step 2: Create the example config files**

  `.github/stacks.yml.example`:
  ```yaml
  # Optional manifest for monorepos. Rename to stacks.yml to activate.
  # When present, stacks.yml overrides auto-detection (spec §4.3).
  stacks:
    - kind: node
      path: services/web
    - kind: python
      path: services/api
  ignore:
    - third_party/
    - examples/
  ```

  `.github/smoke.yml.example`:
  ```yaml
  # Routes hit by cd-smoke.yml after a successful deploy. Rename to smoke.yml.
  routes:
    - /
    - /api/healthz
    - /login
  ```

  `LICENSE-OVERRIDE.md`:
  ```markdown
  # License Overrides

  Add entries here when github/licensed flags an unfamiliar dep license.
  Format: `- \`<package>@<version>\`: <SPDX-id> — <reason>`

  Example:
  - `some-package@1.2.3`: MPL-2.0 — weak copyleft, file-level only
  ```

- [ ] **Step 3: Create the standard config files**

  `.editorconfig`:
  ```
  root = true

  [*]
  indent_style = space
  indent_size = 2
  end_of_line = lf
  charset = utf-8
  trim_trailing_whitespace = true
  insert_final_newline = true

  [*.{py,go}]
  indent_size = 4

  [Makefile]
  indent_style = tab
  ```

  `.gitattributes`:
  ```
  * text=auto eol=lf
  *.png binary
  *.jpg binary
  *.pdf binary
  ```

  `.nvmrc`:
  ```
  20
  ```

  `.python-version`:
  ```
  3.12
  ```

  `.go-version`:
  ```
  1.22
  ```

  `.tool-versions`:
  ```
  nodejs 20
  python 3.12
  golang 1.22
  ```

- [ ] **Step 4: Create `lefthook.yml`**

  ```yaml
  pre-commit:
    parallel: true
    commands:
      lint:
        glob: "*.{js,ts,jsx,tsx,py,go,sh}"
        run: make lint || true
      typecheck:
        glob: "*.{ts,tsx,py}"
        run: make typecheck || true

  pre-push:
    commands:
      test:
        run: make test
  ```

- [ ] **Step 5: Create `commitlint.config.js`**

  ```javascript
  module.exports = {
    extends: ["@commitlint/config-conventional"],
    rules: {
      "type-enum": [2, "always", [
        "feat", "fix", "docs", "refactor", "test", "chore",
        "build", "ci", "perf", "style"
      ]],
    },
  };
  ```

- [ ] **Step 6: Create release-please configs**

  `release-please-config.json`:
  ```json
  {
    "release-type": "simple",
    "include-component-in-tag": false,
    "bump-minor-pre-major": true,
    "bump-patch-for-minor-pre-major": true
  }
  ```

  `release-please-manifest.json`:
  ```json
  {
    ".": "0.1.0"
  }
  ```

- [ ] **Step 7: Make bootstrap executable, commit**

  ```bash
  chmod +x scripts/bootstrap.sh
  git add scripts/bootstrap.sh \
          .github/stacks.yml.example .github/smoke.yml.example \
          LICENSE-OVERRIDE.md \
          .editorconfig .gitattributes .nvmrc .python-version .go-version .tool-versions \
          Makefile lefthook.yml commitlint.config.js \
          release-please-config.json release-please-manifest.json
  git commit -m "feat(layer2): add bootstrap + skeleton config files"
  ```

### Task 3.6: Add ARCHITECTURE / RUNBOOK / THREAT_MODEL templates

**Files:**
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/RUNBOOK.md`
- Create: `docs/THREAT_MODEL.md`

These are *template stubs* — every project derived from this template starts with these three docs and fills them in.

- [ ] **Step 1: Create `docs/ARCHITECTURE.md`**

  ```markdown
  # Architecture

  > Replace this stub with your project's actual architecture overview.

  ## Components
  - <component 1>: <responsibility>
  - <component 2>: <responsibility>

  ## Data flow
  <describe how data moves between components>

  ## Trust boundaries
  <which components trust each other, and which don't>

  ## Tradeoffs
  <list 2-3 architectural choices and what alternatives were rejected>
  ```

- [ ] **Step 2: Create `docs/RUNBOOK.md`**

  ```markdown
  # Runbook

  > Replace with project-specific operational procedures.

  ## Deployment
  <how to deploy, who has access, what to do if it fails>

  ## Monitoring
  <where to look when something's wrong>

  ## Common incidents
  ### Symptom: <X>
  **Diagnosis**: <Y>
  **Mitigation**: <Z>

  ## Escalation
  <who to contact when self-mitigation fails>
  ```

- [ ] **Step 3: Create `docs/THREAT_MODEL.md`**

  ```markdown
  # Threat Model

  > Replace with project-specific threat analysis. Template inherits
  > the universal nischal94 baseline (see policies/required-checks.yml
  > in nischal94/.github).

  ## Assets
  <what we're protecting>

  ## Adversaries
  <who would want to attack this and why>

  ## Trust roots
  <what credentials, when compromised, give an attacker the most leverage>

  ## Documented gaps (per spec §4.6 if applicable)
  <e.g., long-lived deploy tokens for Vercel/Fly until provider OIDC ships>

  ## Mitigations
  <enumeration of defense-in-depth>
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add docs/ARCHITECTURE.md docs/RUNBOOK.md docs/THREAT_MODEL.md
  git commit -m "feat(layer2): add ARCHITECTURE/RUNBOOK/THREAT_MODEL stubs"
  ```

### Task 3.7: Push branch and open PR

- [ ] **Step 1: Push the feature branch**

  ```bash
  git push -u origin feat/layer-2-refactor
  ```

- [ ] **Step 2: Open the PR**

  ```bash
  gh pr create --base main \
    --title "feat: refactor to enterprise CI Layer 2 scaffold (v0.3 spec)" \
    --body "Implements §4 of the v0.3 spec. Adds 8 language profile workflows with auto-detection, OIDC-or-token CD, slsa-github-generator releases, license-check, and bootstrap script. Layer 1 enforcement comes from nischal94/.github (see Phase 1-2 of the implementation plan)."
  ```

### Phase 3 exit gate

Before proceeding to Phase 4, confirm:

- [ ] `feat/layer-2-refactor` branch contains all 12 new workflows.
- [ ] All workflows pass `actionlint -color`.
- [ ] All scripts in `.github/scripts/` pass `bash -n`.
- [ ] PR opened against `main` of `nischal94/repo-template`.
- [ ] Phase 1's universal workflows (synced via scaffold-on-poll) ran successfully on this PR — gitleaks, dependency-review, etc., all green.

---

## Phase 4 — Full lifecycle smoke test [USER] + [CLAUDE]

### Task 4.1: Merge the Layer 2 PR [USER]

- [ ] **Step 1: Review and merge**

  ```bash
  gh pr merge --repo nischal94/repo-template --squash <PR-number-from-3.7>
  ```

### Task 4.2: Create a fresh test repo from the template [USER]

- [ ] **Step 1: Use the template**

  ```bash
  gh repo create nischal94/test-fullstack-1 \
    --template nischal94/repo-template \
    --public \
    --description "Full-lifecycle smoke test."
  ```

- [ ] **Step 2: Clone it**

  ```bash
  git clone git@github.com:nischal94/test-fullstack-1.git
  cd test-fullstack-1
  ```

- [ ] **Step 3: Run bootstrap**

  ```bash
  bash scripts/bootstrap.sh
  # Answers: project name = test-fullstack-1, lang = node, license = MIT.
  ```

### Task 4.3: Verify the full lifecycle [CLAUDE]

- [ ] **Step 1: Wait up to 10 minutes for the App's first poll**

  ```bash
  sleep 600
  ```

- [ ] **Step 2: Verify ruleset applied**

  ```bash
  gh api repos/nischal94/test-fullstack-1/rulesets --jq '.[].name'
  ```

  Expected: `"nischal94 canonical main protection"`.

- [ ] **Step 3: Verify scaffold PR opened**

  ```bash
  gh pr list --repo nischal94/test-fullstack-1
  ```

  Expected: PR titled `"chore: scaffold Layer 1 universal workflows"`.

- [ ] **Step 4: Verify each workflow ran successfully**

  ```bash
  gh run list --repo nischal94/test-fullstack-1 --limit 20
  ```

  Expected: gitleaks, dependency-review, osv-scanner, actionlint, pin-actions, pr-title, license-check all completed (green or expected fail like license-check on a bare scaffold).

- [ ] **Step 5: Open a test PR and verify the gate works**

  ```bash
  cd test-fullstack-1
  git checkout -b test/verify-blocks
  echo "test" >> README.md
  git commit -am "test: trigger ci"
  git push -u origin test/verify-blocks
  gh pr create --title "BAD TITLE NO COLON" --body "should be blocked by pr-title"
  ```

  Expected: `Validate PR title` check fails. PR cannot be merged until title is fixed.

  Fix the title:
  ```bash
  gh pr edit --title "test: verify blocks work"
  ```

  Expected: now passes. Merge possible (after other required checks pass).

### Task 4.4: Cleanup [USER]

- [ ] **Step 1: Delete the test repo**

  ```bash
  gh repo delete nischal94/test-fullstack-1 --yes
  ```

### Phase 4 exit gate

- [ ] Fresh template-derived repo received canonical ruleset.
- [ ] Scaffold PR auto-opened with all Layer 1 workflows.
- [ ] All Layer 1 + Layer 2 workflows ran on first PR.
- [ ] PR-title gate demonstrably blocks bad titles.
- [ ] Test repo cleaned up.

---

## Phase 5 — Documentation [CLAUDE]

### Task 5.1: Update `nischal94/.github` README

**Files:**
- Modify: `~/projects/nischal94-dot-github/README.md`
- Create: `~/projects/nischal94-dot-github/docs/POLICIES.md`

- [ ] **Step 1: Replace the placeholder README**

  ```markdown
  # nischal94/.github

  Account-level CI policy + community files for every repo on
  github.com/nischal94. Auto-supplied to every repo on this account.

  ## What lives here

  - **Universal workflows** (`.github/workflows/*.yml`) — synced into
    every repo by `scaffold-on-poll.yml`.
  - **Policies** (`policies/*.{json,yml}`) — canonical ruleset and
    license allowlist applied by `enforce-on-poll.yml`.
  - **Community files** (`SECURITY.md`, `CODE_OF_CONDUCT.md`,
    `CODEOWNERS`, `.github/PULL_REQUEST_TEMPLATE.md`,
    `.github/ISSUE_TEMPLATE/`, `.github/dependabot.yml`,
    `.github/FUNDING.yml`) — auto-supplied to every repo via GitHub's
    `.github`-repo magic-name convention.
  - **State** (`state/configured-repos.json`) — cache of which repos
    have had the canonical ruleset applied. Authoritative source is
    `GET /installation/repositories`, not this file.

  ## Operations

  - **Add new policy → all repos**: edit `policies/canonical-ruleset.json`,
    open PR, merge. Drift audit picks up the change weekly; or trigger
    `force-sync.yml` manually for immediate propagation.
  - **App is uninstalled**: `app-canary.yml` opens a critical issue here
    daily. Re-install from
    https://github.com/settings/apps/nischal94-policy/installations.
  - **State file corrupted**: trigger `force-sync.yml` with `target=all`;
    rebuilds state from scratch via `GET /installation/repositories`.

  ## Reference

  Full design: [`nischal94/repo-template` v0.3 spec](https://github.com/nischal94/repo-template/blob/main/docs/specs/2026-05-09-enterprise-ci-template-design.md).
  Implementation: [the plan that built this](https://github.com/nischal94/repo-template/blob/main/docs/specs/2026-05-09-enterprise-ci-template-plan.md).
  ```

- [ ] **Step 2: Create `docs/POLICIES.md`**

  ```markdown
  # Policies enforced on every repo

  Source of truth: `policies/canonical-ruleset.json` and
  `policies/required-checks.yml`. This doc is the human-readable summary.

  ## Required checks (block merge)
  See `policies/required-checks.yml`. Currently 7 mandatory checks:
  gitleaks, dependency-review, osv-scanner, actionlint, pin-actions,
  Validate PR title, license-check.

  ## Branch protection rules
  See `policies/canonical-ruleset.json`. Currently enforces signed
  commits, no deletion, no force-push, 1 approving review on PRs,
  code-owner review required.

  ## Bypass actors
  Only `nischal94-policy` itself can bypass these rules, and only for
  scaffold PRs (which apply policy by definition).

  ## License allowlist
  See `policies/license-config.yml`. Default: 9 licenses
  (MIT, Apache-2.0, BSD family, ISC, MPL-2.0, CC0).
  Per-repo overrides go in each repo's `LICENSE-OVERRIDE.md`.
  ```

- [ ] **Step 3: Commit and push**

  ```bash
  cd ~/projects/nischal94-dot-github
  git add README.md docs/POLICIES.md
  git commit -m "docs: production-ready README + policies overview"
  git push origin main
  ```

### Task 5.2: Update `nischal94/repo-template` README

**Files:**
- Modify: `~/projects/repo-template/README.md`

- [ ] **Step 1: Rewrite README to describe what the template gives you**

  ```markdown
  # nischal94/repo-template

  Template repository: every new project on github.com/nischal94 starts
  here. Provides Layer 2 of the [enterprise CI template system](docs/specs/2026-05-09-enterprise-ci-template-design.md).

  ## What you get on day 0

  Click "Use this template" → bootstrap script asks for project name,
  language, license → creates a new repo with:

  - **8 language profile workflows** (auto-detect via marker files;
    only the relevant ones run): Node, Python, Go, Shell, Docker, SQL,
    E2E, Docs.
  - **CD pipeline** (`cd-deploy.yml` + `cd-smoke.yml`) with
    OIDC where supported (AWS / GCP / Azure / Cloudflare); long-lived
    project-scoped tokens for Vercel / Fly / Railway / Render
    (documented as gap in `docs/THREAT_MODEL.md`).
  - **Release pipeline** with [`slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator)
    SLSA Build L3 provenance + CycloneDX SBOM.
  - **License compliance** via [`github/licensed`](https://github.com/github/licensed)
    with per-repo `LICENSE-OVERRIDE.md` audit trail.
  - **Skeleton docs**: `ARCHITECTURE.md`, `RUNBOOK.md`, `THREAT_MODEL.md`.
  - **Pre-commit/pre-push hooks** via `lefthook.yml`.
  - **Conventional Commits** enforcement via `commitlint`.
  - **Semver releases** via `release-please`.

  ## What you get from Layer 1 ([nischal94/.github](https://github.com/nischal94/.github))

  Within ~5-30 min of repo creation (the App polls every 5 min):

  - Canonical branch protection ruleset on `main`.
  - 9 universal workflow files synced into `.github/workflows/`:
    gitleaks, dependency-review, osv-scanner, actionlint, pin-actions,
    pr-title, codeql, license-check, scorecard.
  - Drift audit watching for divergence from the canonical policy.

  ## Quick start

  ```bash
  gh repo create my-new-project \
    --template nischal94/repo-template \
    --public \
    --clone
  cd my-new-project
  bash scripts/bootstrap.sh
  ```

  ## Reference

  - [Design spec](docs/specs/2026-05-09-enterprise-ci-template-design.md) (v0.3)
  - [Implementation plan](docs/specs/2026-05-09-enterprise-ci-template-plan.md)
  ```

- [ ] **Step 2: Commit on main (after Phase 4 merged this branch)**

  ```bash
  cd ~/projects/repo-template
  git checkout main
  git pull
  git checkout -b docs/update-readme
  # apply the README changes
  git add README.md
  git commit -m "docs: rewrite README for v0.3 template"
  git push -u origin docs/update-readme
  gh pr create --title "docs: rewrite README for v0.3 template" --body "Reflects what the template actually provides post-refactor."
  ```

### Task 5.3: Add operational runbook for the App itself

**Files:**
- Create: `~/projects/nischal94-dot-github/docs/APP-RUNBOOK.md`

- [ ] **Step 1: Create the App-specific runbook**

  ```markdown
  # nischal94-policy App Runbook

  ## App identity
  - **Name**: nischal94-policy
  - **App ID**: see https://github.com/settings/apps/nischal94-policy (top of page)
  - **Settings**: https://github.com/settings/apps/nischal94-policy
  - **Installations**: https://github.com/settings/apps/nischal94-policy/installations

  ## Credentials trust chain
  1. 2FA on the `nischal94` GitHub login: passkeys (preferred), with
     Google Authenticator TOTP, GitHub Mobile, and security keys as
     fallbacks; recovery codes generated and stored offline.
  2. Branch protection on `nischal94/.github`'s `main` (signed commits
     required, PR review required, no force-push, no
     `pull_request_target` workflows).
  3. App private key as `APP_PRIVATE_KEY` repo secret in
     `nischal94/.github` (rotated annually via the App settings page →
     re-upload via `gh secret set APP_PRIVATE_KEY < new-key.pem`).
  4. CANARY_PAT (in nischal94/.github secrets; rotated annually,
     calendar reminder).

  ## Common operations

  ### Force re-apply ruleset to all repos
  Trigger `force-sync.yml` with `target=all`.

  ### Investigate a specific repo's enforcement state
  ```bash
  gh api repos/<owner>/<repo>/rulesets
  ```

  ### App stops enforcing (canary opens issue)
  1. Check https://github.com/settings/apps/nischal94-policy/installations
  2. If missing, re-install on `nischal94`. Pick "All repositories."
  3. Note the new installation ID (visible on the installation's
     settings page URL: `/installations/{installation_id}`); update
     this runbook and any workflow references.
  4. Note the new integration ID (= the App ID, top of the App
     settings page); update `bypass_actors` in
     `scripts/policy/canonical-ruleset.json` if it changed.
  5. Trigger `force-sync.yml` with `target=all` to rewrite all
     `bypass_actors` references with the new integration ID.

  ### State file corrupted
  ```bash
  cd ~/projects/nischal94-dot-github
  echo '{"schemaVersion":1,"lastSyncAt":null,"appInstallationId":null,"repos":{}}' > state/configured-repos.json
  git add state/configured-repos.json
  git commit -m "fix: reset state file"
  git push
  gh workflow run force-sync.yml -f target=all
  ```

  ### Migration to organization mode (someday)
  See spec §7.3. **Treat as a 1-day project, not an afternoon.**
  Required steps: re-register App on org, re-install, regenerate all
  PATs, re-upload SSH keys, re-enable Actions on every repo, rewrite
  every ruleset's `actor_id` reference.
  ```

- [ ] **Step 2: Commit and push**

  ```bash
  cd ~/projects/nischal94-dot-github
  git add docs/APP-RUNBOOK.md
  git commit -m "docs: add App operational runbook"
  git push origin main
  ```

### Phase 5 exit gate

- [ ] `nischal94/.github` README explains what the repo does.
- [ ] `nischal94/.github` has `docs/POLICIES.md` and `docs/APP-RUNBOOK.md`.
- [ ] `nischal94/repo-template` README rewritten and merged via PR.
- [ ] All docs cross-linked between repos.

---

## Project complete

After Phase 5 ships:

- Every new repo created on `nischal94` automatically gets enterprise
  CI within 5-30 min of creation.
- The system self-audits weekly via `drift-audit`.
- The App self-monitors via `app-canary`.
- Documentation is in place for every common operation.

The implementation plan ends here. Ongoing work (adding language profiles,
tightening policies, migrating to org mode if/when warranted) is captured
in the runbook and should be tracked as ordinary issues against
`nischal94/.github` going forward.
