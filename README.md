# repo-template

Personal template for new repositories. Click **Use this template** → **Create a new repository** to start a project with these defaults baked in.

## What's included

### Workflows (`.github/workflows/`)
| Workflow | Trigger | Purpose |
|---|---|---|
| `gitleaks.yml` | every PR | Scans the diff for committed secrets (custom + provider patterns). Catches leaks GitHub's native scanner misses. |
| `pr-title.yml` | every PR | Enforces Conventional Commits on PR titles (`feat:`, `fix:`, etc.). Prerequisite for clean changelogs and release-please. |
| `actionlint.yml` | when `.github/workflows/` changes | Static analysis on workflow YAML — catches typos, bad expressions, shell-injection patterns. |
| `dependency-review.yml` | every PR | Blocks PRs that introduce vulnerable deps or restrictive licenses. Only runs when manifests change. |

### Community files
- `SECURITY.md` — vulnerability disclosure policy (points to GitHub's private reporting).
- `.github/CODEOWNERS` — auto-routes review requests.
- `.github/PULL_REQUEST_TEMPLATE.md` — keeps PR descriptions consistent.
- `.github/ISSUE_TEMPLATE/` — bug + feature templates.
- `.github/dependabot.yml` — weekly GitHub Actions updates (uncomment ecosystem blocks for pip/npm/etc).
- `LICENSE` — MIT.

## Post-creation checklist

GitHub workflows alone don't enforce anything. After creating a new repo from this template, complete the steps below to make the workflows binding.

### 1. Enable repo-level security features
Settings → Code security:
- [ ] **Private vulnerability reporting** → Enable
- [ ] **Dependabot alerts** → Enable
- [ ] **Dependabot security updates** → Enable
- [ ] **Secret scanning** → Enable (public repos: free)
- [ ] **Push protection** → Enable (blocks pushes that contain known-pattern secrets)
- [ ] **CodeQL default setup** → Enable (auto-detects languages; no workflow YAML needed)

### 2. Enable branch protection on `main`
Settings → Branches → Add rule for `main`:
- [ ] Require pull request before merging (1 approval)
- [ ] Dismiss stale approvals on new commits
- [ ] Require status checks: `Validate PR title`, `gitleaks`, `actionlint`, `dependency-review`, plus any project-specific CI jobs
- [ ] Require conversation resolution
- [ ] Block force pushes
- [ ] Block deletions

### 3. Add language-specific dependency tracking
Edit `.github/dependabot.yml` — uncomment the `pip`, `npm`, or other ecosystem blocks for your stack.

### 4. (Optional) Add Tier B security workflows
For repos with real users or shipped artifacts, layer in:
- `bandit` (Python SAST) / `eslint-plugin-security` (JS SAST)
- `pip-audit` (Python deps) / `npm audit` (npm deps)
- `trivy` (container/image scan if Dockerfile present)
- `harden-runner` (egress firewall on the runner)
- `codecov` (coverage gate)
- AI review: Claude Code Action / Greptile / CodeRabbit

### 5. (Optional) Add Tier C release-security
For repos publishing artifacts others depend on:
- `release-please` for versioning
- OpenSSF Scorecard (weekly + badge)
- SBOM generation (`anchore/sbom-action`)
- `cosign` keyless signing on release artifacts
- SLSA provenance

## Notes

- Third-party actions are pinned to **major version tags** (`@v6`) for readability. For supply-chain hardening, run [`pinact`](https://github.com/suzuki-shunsuke/pinact) to convert to commit SHAs.
- Dependabot will keep action versions current automatically.
