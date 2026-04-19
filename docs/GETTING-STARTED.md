# Getting started

This template is a **personal DevOps + security baseline** for new repos. It is NOT a project starter — there's no source code, no test framework, no CI for builds. What it gives you is the security/process scaffolding that every serious repo needs.

---

## 30-second mental model

When you create a repo from this template, you get:

```
your-new-repo/
├── .github/
│   ├── workflows/      ← 8 security/process workflows (no test/build CI)
│   ├── dependabot.yml  ← grouped weekly dep updates (gh-actions enabled; opt-in for your stack)
│   ├── CODEOWNERS, PR template, issue templates
├── docs/
│   ├── SECURITY-OPERATIONS.md  ← master operational reference
│   ├── GETTING-STARTED.md      ← (this file)
│   └── UPGRADING.md            ← how to pull in template improvements later
├── SECURITY.md, CONTRIBUTING.md, CHANGELOG.md
├── .editorconfig, .gitignore, LICENSE
└── README.md  ← workflow guide + post-creation checklist
```

You add: source code, language-specific test/build CI, language ecosystem in `dependabot.yml`.

---

## Step-by-step: create a repo from this template

### 1. Create
Go to https://github.com/nischal94/repo-template → click **Use this template** → **Create a new repository** → name it.

### 2. Walk the post-creation checklist (~10 minutes)
The condensed version is in the new repo's [`README.md`](../README.md#post-creation-checklist-tldr). The full version with rationale is in [`docs/SECURITY-OPERATIONS.md §2`](SECURITY-OPERATIONS.md#2-post-creation-checklist-per-repo).

The minimum to do today:
- [ ] Settings → Code security → enable: **Private vulnerability reporting**, **Dependabot alerts + security updates**, **Secret scanning + push protection**, **CodeQL default setup**
- [ ] Settings → Branches → add rule for `main`: require PR + 1 approval, require `gitleaks` + `Validate PR title` checks, block force-push, require conversation resolution
- [ ] Settings → Tags → add rule for `v*` pattern (prevent release-tag tampering)
- [ ] Settings → Actions → enable "Require approval for first-time contributors"
- [ ] Settings → General → enable "Allow auto-merge" + "Automatically delete head branches"

### 3. Add your stack-specific Dependabot block
Edit `.github/dependabot.yml` — uncomment the `pip`, `npm`, or `docker` block matching your project. The grouping config is pre-set; just uncomment.

### 4. Add your project's CI
The template ships **process** workflows (gitleaks, pr-title, actionlint, etc.) but **no test/build CI** — your project's tests and builds are stack-specific. Add `.github/workflows/ci.yml` for whatever your stack runs (`pytest`, `npm test`, `cargo test`, etc.).

For the typical pattern, look at how `nischal94/sonar` does it:
- `Backend — tests` (pytest with real Postgres + Redis services)
- `Frontend — tsc + vite build`
- `Docker — backend image build`
- `E2E — Playwright (chromium)`

### 5. Add your code
Now you have a secure, well-documented foundation. Add your source.

---

## What happens automatically

Once you've done steps 1-2 above:

- Every PR gets scanned by `gitleaks` for secrets in the diff
- PR titles enforce Conventional Commits (`feat:`, `fix:`, etc.)
- Workflow YAML changes get linted by `actionlint`
- Dependency PRs get vuln + license review via `dependency-review`
- Manifest changes trigger `osv-scanner` for cross-ecosystem vuln scans
- Weekly OpenSSF Scorecard audits supply-chain health
- Dependabot opens grouped weekly PRs for your stack (after step 3)
- Patch + dev-minor Dependabot PRs auto-merge once CI passes (`dependabot-automerge.yml`)
- @claude mentions in issues/PRs trigger AI review (after you set `ANTHROPIC_API_KEY` secret)
- New release tags (`v*`) are protected from deletion/overwrite

---

## What you still need to think about per-repo

**Stack-specific security** — the template doesn't ship language-specific scanners. Add as needed:
- Python: `bandit` (SAST), `pip-audit` (dep vulns)
- JavaScript: `eslint-plugin-security`
- Containers: `trivy image` step in your build job
- Frontend: `Lighthouse CI` for perf/a11y/SEO

See [`docs/SECURITY-OPERATIONS.md §7`](SECURITY-OPERATIONS.md#7-tier-4-hardening-additions) for the full Tier 4 catalog.

**Release publishing** — if your repo publishes artifacts (npm, pypi, docker registry), add `release-please` for versioning + `cosign` for keyless signing. See [`docs/SECURITY-OPERATIONS.md §8`](SECURITY-OPERATIONS.md#8-tier-5-conditional-items-when-x-happens).

**Dev experience** — the template is opinionated about CI/security but agnostic about formatters, linters, type-checkers, and test frameworks. Add per project.

---

## Where to go next

| If you want to... | Read |
|---|---|
| Understand a specific workflow | Inline comments at the top of `.github/workflows/<name>.yml` |
| Tune Dependabot grouping | [`docs/SECURITY-OPERATIONS.md §5`](SECURITY-OPERATIONS.md#5-dependabot-operations) |
| Promote an advisory check to required | [`docs/SECURITY-OPERATIONS.md §4`](SECURITY-OPERATIONS.md#4-promotion-path-advisory--required) |
| Pull in template updates later | [`docs/UPGRADING.md`](UPGRADING.md) |
| Write a good PR description | The PR template (`.github/PULL_REQUEST_TEMPLATE.md`) — has inline guidance |
| Triage Dependabot security PRs | [`docs/SECURITY-OPERATIONS.md §5.6`](SECURITY-OPERATIONS.md#56-triage-runbook-for-grouped-security-prs) |
