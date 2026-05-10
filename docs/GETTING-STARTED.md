# Getting started

A walk-through of what happens when you create a repo from this template, what ships in the box, and what you need to do per-project. For the high-level overview see the [README](../README.md); this doc is the deeper-dive.

---

## 30-second mental model

This template is the **Layer 2** half of a two-layer system:

- **Layer 1** — the [`nischal94-policy` GitHub App](https://github.com/nischal94/.github) auto-applies a canonical branch ruleset and 8 universal security workflows (gitleaks, dependency-review, osv-scanner, actionlint, pin-actions, pr-title, license-check, scorecard) to every enrolled repo. You don't configure any of this per-project.
- **Layer 2** — this template — ships the **stack-detected CI/CD pipeline**: lint/typecheck/test/build per language, plus `cd-deploy.yml`, `release.yml` (with SLSA provenance), and `sbom-on-release.yml`.

When you create a repo from this template, you get:

```
your-new-repo/
├── .github/
│   ├── workflows/
│   │   ├── ci-node.yml, ci-python.yml, ci-go.yml, ci-shell.yml,
│   │   │   ci-docker.yml, ci-sql.yml, ci-e2e.yml, ci-docs.yml
│   │   ├── cd-deploy.yml         ← detects vercel/fly/railway markers
│   │   ├── release.yml           ← v* tag → SLSA provenance + GitHub Release
│   │   ├── sbom-on-release.yml   ← CycloneDX SBOM on every release
│   │   ├── claude.yml            ← @claude AI code review (needs ANTHROPIC_API_KEY)
│   │   └── dependabot-automerge.yml
│   ├── scripts/                  ← one ci-*.sh per language profile
│   ├── dependabot.yml, CODEOWNERS, ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md
│   ├── stacks.yml.example        ← optional: monorepo / multi-stack override
│   └── smoke.yml.example         ← optional: post-deploy smoke test config
├── docs/
│   ├── ARCHITECTURE.md, RUNBOOK.md, THREAT_MODEL.md  ← stubs to fill in
│   ├── SECURITY-OPERATIONS.md    ← runbooks + promotion paths
│   ├── GETTING-STARTED.md        ← (this file)
│   └── UPGRADING.md              ← how to pull in template updates later
├── scripts/bootstrap.sh          ← one-shot stack init
├── lefthook.yml                  ← pre-commit / pre-push hooks
├── commitlint.config.js          ← Conventional Commits enforcement
├── release-please-config.json    ← automated semver + CHANGELOG
├── .editorconfig, .gitattributes, .gitignore, LICENSE
├── .nvmrc, .python-version, .go-version, .tool-versions  ← toolchain pins
└── README.md, SECURITY.md, CONTRIBUTING.md, CHANGELOG.md
```

You don't add Layer 1 workflows manually — the App delivers them. You don't configure branch protection manually — the App applies the canonical ruleset. **You add: source code, the stack's `ci-*.sh` script body if it needs customization, and your project's secrets (deploy tokens, ANTHROPIC_API_KEY, etc.).**

---

## Step-by-step: create a repo from this template

### 1. Create

```bash
gh repo create nischal94/<your-project> --template nischal94/repo-template --public
gh repo clone nischal94/<your-project> && cd <your-project>
```

Or use the GitHub UI: visit https://github.com/nischal94/repo-template → **Use this template** → **Create a new repository**.

### 2. Run the bootstrap script

```bash
bash scripts/bootstrap.sh
```

It asks for project name, primary language (`node|python|go|shell|other`), and license. Then:

- Initializes the toolchain (`npm init`, `python -m venv`, `go mod init`, etc.)
- Removes language-profile workflows for languages you're not using (cleaner Actions tab)
- Generates a `Makefile` wired to your stack's standard commands: `install`, `lint`, `test`, `build`, `ci` (where `ci` chains the previous four). For node: `npm install` / `npm run lint` / `npm test` / `npm run build`. For python: `pip install -e .[dev,test]` / `ruff check .` / `pytest` / `python -m build`. For go: `go mod download` / `go vet ./...` / `go test ./...` / `go build ./...`. Customize after bootstrap.

### 3. Push the first commit

```bash
git push origin main
```

### 4. Enroll in Layer 1 (one line edit on `nischal94/.github`)

Open [`.github/workflows/scaffold-on-poll.yml`](https://github.com/nischal94/.github/blob/main/.github/workflows/scaffold-on-poll.yml), find the `SCAFFOLD_ALLOWLIST=""` line, add your repo's full name (space-separated), open a PR, merge.

Within ~5 minutes, the App opens a scaffold PR on your new repo with the 8 Layer 1 workflows + the `.scaffolded-by-nischal94-policy` marker file. Merge it. On the next 5-minute cron tick, the canonical ruleset auto-applies. **No manual branch protection setup required.**

### 5. Add per-project secrets

| Secret | Why | Set with |
|---|---|---|
| `ANTHROPIC_API_KEY` | `@claude` AI review in issues/PRs | `gh secret set ANTHROPIC_API_KEY -R nischal94/<your-project>` |
| `VERCEL_TOKEN` / `FLY_API_TOKEN` / `RAILWAY_TOKEN` | only the one matching your CD target | same pattern |

Without these the relevant workflows still exist but no-op — `claude.yml` won't fire on `@claude`, `cd-deploy.yml` won't deploy.

### 6. Add your code

You have a secure, ruleset-protected, CI-wired foundation. Add source.

---

## What happens automatically once Layer 1 + Layer 2 are wired up

**On every PR**: gitleaks · dependency-review · osv-scanner · actionlint · pin-actions · validate-pr-title · license-check · whichever `ci-*` matches your stack. All 7 Layer 1 checks are required by the canonical ruleset and block merge if any fail.

**On every push to `main`**: `cd-deploy.yml` runs if a Vercel/Fly/Railway marker file is present, posts a preview URL, and runs the inline smoke job.

**On every `v*` tag push**: `release.yml` builds the artifact, generates [SLSA build provenance](https://slsa.dev/spec/v1.0/levels#build-l3), uploads to a GitHub Release. `sbom-on-release.yml` then attaches a CycloneDX SBOM.

**Weekly**: OpenSSF Scorecard reports supply-chain health to GitHub Security tab. The drift audit on `nischal94/.github` checks every enrolled repo against the canonical ruleset and opens a PR (never direct-pushes) for any drift.

**Continuously**: Dependabot opens grouped weekly PRs for `gh-actions` plus your stack's ecosystem (after you uncomment the relevant block in `dependabot.yml`). Patch + dev-minor Dependabot PRs auto-merge once Layer 1 checks pass.

**On `@claude` mentions** (after step 5 secret): AI review fires from `claude.yml`.

---

## What you still need to think about per-repo

**Stack-specific scanners not covered by Layer 1**:
- Python: `bandit` (SAST) — add as a step in `ci-python.sh`
- JavaScript: `eslint-plugin-security` — add to your eslint config
- Containers: `trivy image` step in `ci-docker.sh`
- Frontend: `Lighthouse CI` — add as a `ci-e2e.sh` extension

See [`docs/SECURITY-OPERATIONS.md §7`](SECURITY-OPERATIONS.md#7-tier-4-hardening-additions) for the full Tier 4 catalog.

**Release publishing to external registries** (npm, PyPI, Docker Hub, etc.) — add the publish step to `release.yml` after the `provenance` job. See [`docs/SECURITY-OPERATIONS.md §8`](SECURITY-OPERATIONS.md#8-tier-5-conditional-items-when-x-happens).

**Dev experience** — the template is opinionated about CI/security/release but agnostic about formatters, linters, and type-checkers. Wire your preferences into `lefthook.yml` and the relevant `ci-*.sh` script.

**Monorepos / multi-stack repos** — auto-detect picks the most prominent language. To override, copy `.github/stacks.yml.example` to `.github/stacks.yml` and declare per-path stacks explicitly.

---

## Where to go next

| If you want to... | Read |
|---|---|
| Understand a specific workflow | Inline comments at the top of `.github/workflows/<name>.yml` |
| Customize a CI script | The matching `.github/scripts/ci-*.sh` file |
| Tune Dependabot grouping | [`docs/SECURITY-OPERATIONS.md §5`](SECURITY-OPERATIONS.md#5-dependabot-operations) |
| See what Layer 1 enforces and why | [`nischal94/.github/docs/POLICIES.md`](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md) |
| Operate the policy App | [`nischal94/.github/docs/APP-RUNBOOK.md`](https://github.com/nischal94/.github/blob/main/docs/APP-RUNBOOK.md) |
| Understand the design rationale | [`docs/specs/2026-05-09-enterprise-ci-template-design.md`](specs/2026-05-09-enterprise-ci-template-design.md) (currently v0.6) |
| Pull in template updates later | [`docs/UPGRADING.md`](UPGRADING.md) |
| Write a good PR description | The PR template (`.github/PULL_REQUEST_TEMPLATE.md`) — has inline guidance |
