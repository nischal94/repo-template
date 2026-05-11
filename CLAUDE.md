# Project context for nischal94 platform projects

This file is read automatically at the start of every Claude Code session in
this project. It carries platform-specific workflow context so Claude can act
correctly without the user re-explaining how the nischal94 CI platform works.

Inherited from [`nischal94/repo-template`](https://github.com/nischal94/repo-template).

---

## The two-layer platform model

This project uses the nischal94 two-layer CI platform:

- **Layer 1 — universal security baseline.** 8 workflows: `gitleaks`,
  `dependency-review`, `osv-scanner`, `actionlint`, `pin-actions`,
  `validate-pr-title` (from `pr-title.yml`), `license-check`, `scorecard`.
  **NOT delivered by this repo.** Delivered by the
  [`nischal94-policy` GitHub App](https://github.com/settings/apps/nischal94-policy)
  via [`scaffold-on-poll.yml`](https://github.com/nischal94/.github/blob/main/.github/workflows/scaffold-on-poll.yml).
- **Layer 2 — per-stack CI + release pipeline.** 13 workflows in
  `.github/workflows/`: `ci-{node,python,go,shell,docker,sql,e2e,docs}.yml`,
  `cd-deploy.yml`, `release.yml`, `sbom-on-release.yml`, `claude.yml`,
  `dependabot-automerge.yml`. **Delivered by this repo** (came from the
  template).

After both layers are wired up: every PR runs the 7 required Layer 1 checks +
whichever Layer 2 `ci-*` matches the project's stack. The canonical ruleset
on `main` blocks merge until all 7 pass.

---

## When the user says "ship to GitHub" / "push to GitHub" / "create the repo"

This is the most common platform-shaped request. Detect the project's state
first, then act:

### State detection

1. No `.git/` directory and no GitHub repo exists → **greenfield**.
2. `.git/` exists but no `origin` remote → **local-first** (typical:
   user worked in the folder for a while, now wants it on GitHub).
3. `origin` remote exists → already pushed; skip ahead to enrollment.

### Steps (run in order, ASK confirmation at each irreversible step)

a. **Visibility — always ask, never default to public.**
   "Repo visibility? public/private?" If user picks public, scan the diff
   for personal email/secrets/internal hostnames before proceeding. Per
   the user's "Public repo safety" override in `~/.claude/CLAUDE.md`.

b. **Create the GitHub repo.**
   ```
   gh repo create nischal94/<name> --<visibility> --source=. --remote=origin --push
   ```
   This is irreversible-ish (user can delete the repo but creation is a
   public action). Confirm name + visibility one more time before running.

c. **Open the enrollment PR on `nischal94/.github`** (Layer 1 enrollment):

   - Branch: `enroll/<name>` off `main`.
   - Edit `.github/workflows/scaffold-on-poll.yml`. Find the
     `SCAFFOLD_ALLOWLIST=` line and append `<name>` (space-separated).
   - Commit message: `chore(scaffold): enroll nischal94/<name>`.
   - PR title: same as commit message.
   - PR body: "Adds `nischal94/<name>` to `SCAFFOLD_ALLOWLIST`. App
     opens a scaffold PR on the new repo on the next poll cycle (~15 min)."
   - **DO NOT auto-merge.** Surface the PR URL and let the user
     `gh-merge <pr#>` (their function, see `~/.zshrc`).

d. **Tell the user the timeline.**
   - ~15 min after enrollment PR merges: scaffold PR appears on new repo.
   - User merges the scaffold PR.
   - ~15 min after that: canonical ruleset auto-applies on the new repo's `main`.
   - From then on: 7 required checks gate every merge on `main`.

---

## PR review discipline

The documented rule is in `~/.claude/projects/-Users-nischal/memory/feedback_pr_review_before_merge.md`.
Three tiers:

- **Tier 0 — skip review.** Doc-only PRs, Dependabot patch + dev-minor,
  single-line config edits, auto-generated bot PRs.
- **Tier 1 — one agent pass.** Scripts in `scripts/`, Makefile, dev
  workflows, refactors, non-critical features. Dispatch
  `pr-review-toolkit:code-reviewer` (default).
- **Tier 2 — adversarial review (REQUIRED).** Anything touching:
  state files, library code that other workflows source, policy config,
  branch protection, ruleset definitions, security workflows, deploy
  paths, auth, payments, schemas, secrets, tokens, signing keys.
  Dispatch 2-3 agents in parallel with distinct framings — at minimum
  `pr-review-toolkit:code-reviewer` + one specialist
  (`silent-failure-hunter` for fallback chains, `pr-test-analyzer` for
  new untested behavior, etc.).

Even under "auto mode" or "go fast" framing, Tier 2 review is required
by file location, not by how mechanical the change feels. The 2026-05-11
recurrence documented in the memory file is the cautionary tale.

After review: post an audit-trail comment on the PR summarizing findings
and dispositions per the rule's compliance clause.

---

## Merge mechanics

The user's `gh-merge` shell function in `~/.zshrc` is the standard merge
path. It bypasses `gh pr merge`'s `mergeStateStatus` cache pitfall by
calling `PUT /repos/.../pulls/<n>/merge` directly.

For Claude-driven merges (different shell, can't source `~/.zshrc`):
```
gh api -X PUT "repos/<owner>/<repo>/pulls/<n>/merge" -f merge_method=squash
```
Then delete the branch:
```
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"
```

If the merge returns HTTP 405 "rule violations — 7 of 7 required status
checks are expected", the branch is BEHIND `main` (strict mode). Fix:
```
gh api -X PUT "repos/<owner>/<repo>/pulls/<n>/update-branch"
```
Wait for CI to re-run, then retry the merge. Auto-merge (`--auto`) is
enabled on all template-created repos and will handle this automatically.

---

## Workflow hardening conventions (when adding/editing workflows)

Per [`nischal94/.github/docs/POLICIES.md` → Workflow hardening defaults](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md#workflow-hardening-defaults).
Every workflow MUST:

1. **SHA-pin every `uses:`** — never `@v5`, never `@main`. Trailing
   `# vX.Y.Z` comment is for human readability; Dependabot updates both.
   The `pin-actions` required check grep-validates this on every PR.
2. **Start every job with `step-security/harden-runner`** — `audit` mode
   for workflows with unpredictable egress (release pipelines,
   third-party deploys); `block` mode with explicit `allowed-endpoints`
   for everything else.
3. **`persist-credentials: false` on every `actions/checkout`** —
   removes `GITHUB_TOKEN` from `.git/config` after checkout. Documented
   exceptions only.
4. **Minimum-required `permissions:` at workflow level** — escalate
   per-job only where genuinely needed.

These four defaults compound. Don't drop one as "cleanup" — each
mitigates a different attack class.

---

## Stack detection (Layer 2 `ci-*.yml` files)

Each `ci-*.yml` has a `detect` job that exits clean if the language
doesn't apply (no `package.json` → `ci-node` skips). For monorepos,
copy `.github/stacks.yml.example` to `.github/stacks.yml` and declare
per-path stacks explicitly. `scripts/bootstrap.sh` prunes unused
profiles at init time based on user's primary language.

---

## Useful pointers

- Full design: [`docs/specs/2026-05-09-enterprise-ci-template-design.md`](docs/specs/2026-05-09-enterprise-ci-template-design.md)
- Per-stack CI scripts: `.github/scripts/ci-*.sh`
- Layer 1 source: [`nischal94/.github`](https://github.com/nischal94/.github)
- Policy docs: [`nischal94/.github/docs/POLICIES.md`](https://github.com/nischal94/.github/blob/main/docs/POLICIES.md)
- App operations: [`nischal94/.github/docs/APP-RUNBOOK.md`](https://github.com/nischal94/.github/blob/main/docs/APP-RUNBOOK.md)
- Security ops + runbooks: [`docs/SECURITY-OPERATIONS.md`](docs/SECURITY-OPERATIONS.md)
- Getting started: [`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md)
- This project's CHANGELOG: [`CHANGELOG.md`](CHANGELOG.md)
