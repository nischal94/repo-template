# Project context for nischal94 platform projects

This file is read automatically at the start of every Claude Code session in
this project. It carries platform-specific workflow context so Claude can act
correctly without the user re-explaining how the nischal94 CI platform works.

This file is part of the [`nischal94/repo-template`](https://github.com/nischal94/repo-template) baseline. Projects created from the template inherit it via `gh repo create --template`; the template repo itself carries it for self-application.

**Audience.** This template is currently scoped for personal use by
`nischal94` and AI collaborators operating on `nischal94/*` repos.
Several references below point at this user's local machine
(`~/.claude/...`, `~/.zshrc`, `gh-merge` shell function). If the
template is ever forked for external use, those references need
parametrizing — for now they're load-bearing because that's where the
actual config lives.

---

## The two-layer platform model

This project uses the nischal94 two-layer CI platform:

- **Layer 1 — universal security baseline.** 8 workflows scaffolded into
  every enrolled repo: `gitleaks`, `dependency-review`, `osv-scanner`,
  `actionlint`, `pin-actions`, `validate-pr-title` (from `pr-title.yml`),
  `license-check`, `scorecard`. **7 are required status checks** on
  `main` per the canonical ruleset; **`scorecard` is scaffolded but
  advisory-only** (runs on a schedule + push, surfaces signal in the
  Security tab, never gates merge).
  Canonical source of all 8 YAML files: `nischal94/.github/.github/workflows/`.
  Delivery into derived repos: the
  [`nischal94-policy` GitHub App](https://github.com/settings/apps/nischal94-policy)
  via [`scaffold-on-poll.yml`](https://github.com/nischal94/.github/blob/main/.github/workflows/scaffold-on-poll.yml).
  Note: `nischal94/repo-template` ALSO carries copies of all 8 Layer 1
  files for its own self-application — these are NOT redundant. The
  `cross-repo-drift` check enforces they stay byte-identical with the
  canonical source. Do not delete them from the template.
- **Layer 2 — per-stack CI + release pipeline.** 13 workflows in
  `.github/workflows/`: `ci-{node,python,go,shell,docker,sql,e2e,docs}.yml`
  (8), `cd-deploy.yml`, `release.yml`, `sbom-on-release.yml`, `claude.yml`,
  `dependabot-automerge.yml` (5 more = 13). **Delivered by this repo**
  (came from the template); not scaffolded by the App.

After both layers are wired up: every PR runs the 7 required Layer 1 checks +
whichever Layer 2 `ci-*` matches the project's stack. The canonical ruleset
on `main` blocks merge until all 7 required Layer 1 checks pass. Layer 2
checks are advisory at the canonical level — promote to required per-project
if you want them blocking.

---

## When the user says "ship to GitHub" / "push to GitHub" / "create the repo"

This is the most common platform-shaped request. Detect the project's state
first, then act:

### State detection

Check the working directory and classify the project into one of four states:

| State | Signals | Typical scenario |
|---|---|---|
| **A — Empty** | No files in cwd (or only `.DS_Store`) | Rare in this user's workflow — they always start by writing the spec first. |
| **B — Files-no-git** | Real files present, no `.git/` directory, no template files (no `CLAUDE.md`, no `Makefile`, no `.github/workflows/`) | **THE COMMON CASE.** User did `mkdir myproject && cd myproject`, wrote `spec.md`, then code, then said "ship this." |
| **C — Local-first** | Real files present, `.git/` exists, no `origin` remote | User initialized git themselves, hasn't pushed yet. Rare unless they explicitly `git init`d. |
| **D — Already-pushed** | `origin` remote exists | Skip to enrollment; everything before is done. |

**State B is what the user described as their workflow.** It needs the most care because:
- Their working tree has real content (spec, code) — must not be clobbered.
- The `git init` + initial commit is governed by their **Git-safety SCAR**
  (`~/.claude/CLAUDE.md` says: NEVER run `git init` / `git commit` /
  `git reset` / `git checkout .` / `git clean` inside a user's project
  folder). The SCAR overrides this file. ALWAYS ask before any of those.
- Template files (`CLAUDE.md`, `Makefile`, `.github/...`, hygiene configs)
  are NOT yet on disk. Need to be overlaid before bootstrap can run.

### Steps for State B (files-no-git)

This is the canonical flow. Run in order, ASK confirmation at each step
marked `[ASK]`.

a. **`[ASK]` Visibility — never default to public.**
   "Repo visibility? public/private?" If user picks public, scan the
   working tree for personal email/secrets/internal hostnames (the
   `.env` files, deploy tokens, API keys, etc.) before proceeding.
   Per the user's "Public repo safety" override in `~/.claude/CLAUDE.md`.

b. **`[ASK]` Overlay template files into the existing folder.**
   The local-first overlay is currently a one-liner you run from inside
   the project folder. It fetches files from
   `nischal94/repo-template` via the GitHub Contents API and writes
   them into the current directory, **skipping any path that already
   exists locally** so the user's spec/code is never clobbered:

   ```bash
   # Template-overlay one-liner. Run from inside the project folder.
   # Skips any path that already exists locally.
   curl -fsSL https://raw.githubusercontent.com/nischal94/repo-template/main/scripts/overlay.sh | bash
   ```

   `scripts/overlay.sh` lives in the template; it walks the curated
   overlay-files list (~40 files: hygiene configs, Layer 2 workflows,
   bootstrap.sh, CLAUDE.md itself, the example files) and `gh api`s
   each one in. NEVER use `gh repo clone` for this — clone overwrites
   the user's `.git/` state.

   If `scripts/overlay.sh` doesn't exist yet on the template (the
   overlay script PR may not have merged), fall back to a small
   manual overlay covering the high-value files only: `.gitignore`,
   `CLAUDE.md`, `scripts/bootstrap.sh`, and the single `ci-<lang>.yml`
   matching the project's primary language. Tell the user the
   abbreviated overlay landed and the rest can come later.

c. **`[ASK]` Initialize git and create the initial commit.**
   The user's Git-safety SCAR requires explicit confirmation for
   `git init`, `git add`, and `git commit` inside their folder.
   Show them exactly what will run and wait for `yes`:

   ```bash
   git init -b main
   git add .
   git commit -m "chore: initial commit"
   ```

   Note: `scripts/bootstrap.sh` (run in step d) ALSO does `git add . &&
   git commit` at its end. If the user prefers, skip this step and let
   bootstrap.sh do both — but in that case bootstrap.sh's commit is
   the initial commit, and its message is "chore: initial bootstrap
   from nischal94/repo-template", not "chore: initial commit". Either
   ordering works; pick one and tell the user which.

d. **Run `bash scripts/bootstrap.sh`** to do per-language setup +
   Makefile generation + workflow pruning. The script prompts for
   project name / language / license interactively. **The script
   currently runs `git init` + `git commit` non-interactively at its
   end** — if step c already ran git init, bootstrap's git init will
   noop, but its `git commit` will run; warn the user. (A patch to
   bootstrap.sh making this confirmable is queued separately.)

e. **`[ASK]` Create the GitHub repo.**
   By now the working tree has: user's content + template overlay +
   initial commit. Ready to push.

   ```bash
   gh repo create nischal94/<name> --<visibility> --source=. --remote=origin --push
   ```

   `--push` refuses if HEAD has no commits (caught in step c or d).
   Default branch is `main` (matches the canonical ruleset's target).
   This step creates a public/private record on GitHub; confirm name
   + visibility one more time before running.

f. **Open the enrollment PR on `nischal94/.github`** (Layer 1 enrollment):

   - Branch: `enroll/<name>` off `main`.
   - Edit `.github/workflows/scaffold-on-poll.yml`. Find the
     `SCAFFOLD_ALLOWLIST=` line and append `<name>` (space-separated).
   - Commit message: `chore(scaffold): enroll nischal94/<name>`.
   - PR title: same as commit message.
   - PR body: "Adds `nischal94/<name>` to `SCAFFOLD_ALLOWLIST`. App
     opens a scaffold PR on the new repo on the next poll cycle (~15 min)."
   - **DO NOT auto-merge.** Even though the canonical ruleset sets
     `required_approving_review_count: 0` (solo-account), enrollment PRs
     are operator-gated by convention — they extend the platform to a
     new repo and the user should eyeball which repo before granting
     enforcement. Surface the PR URL and let the user `gh-merge <pr#>`
     (their function, see `~/.zshrc`).

g. **Tell the user the timeline.**
   - ~15 min after enrollment PR merges: scaffold PR appears on new repo.
   - User merges the scaffold PR.
   - ~15 min after that: canonical ruleset auto-applies on the new repo's `main`.
   - From then on: 7 required checks gate every merge on `main`.

   The chain is `enforce-on-poll` (every 15 min) triggers
   `scaffold-on-poll` via `workflow_run`. If the user reports the
   scaffold PR hasn't appeared after ~20 min: check whether
   `enforce-on-poll`'s last run succeeded (`gh run list --repo
   nischal94/.github --workflow=enforce-on-poll.yml --limit 5`). If
   enforce-on-poll is broken, scaffold-on-poll never fires.

### Steps for State A (truly empty folder)

Use `gh repo create --template` directly — no overlay needed because
GitHub does the copy server-side:

```bash
gh repo create nischal94/<name> --template nischal94/repo-template --<visibility>
gh repo clone nischal94/<name> && cd <name>
bash scripts/bootstrap.sh
git push origin main
```

Then jump to step f (enrollment PR) above.

### Steps for State C (local-first: files + git, no remote)

Skip step c. Run b (overlay), d (bootstrap — its git commit will land
on top of user's existing commits), e (gh repo create), f (enrollment).

### Steps for State D (already pushed)

If the repo already exists on GitHub and origin is set, the user is
asking about Layer 1 enrollment. Skip directly to step f.

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
  Dispatch 2-3 agents in parallel with distinct framings. See the
  memory file's "Choosing the right Tier 2 agent(s)" section for the
  full roster — it covers `silent-failure-hunter`, `comment-analyzer`,
  `pr-test-analyzer`, `type-design-analyzer`, `code-simplifier`,
  `superpowers:code-reviewer`, `codex:codex-rescue`, plus the default
  `pr-review-toolkit:code-reviewer`.

Even under "auto mode" or "go fast" framing, Tier 2 review is required
by file location, not by how mechanical the change feels. The 2026-05-11
recurrence documented in the memory file is the cautionary tale.

After review: post an audit-trail comment on the PR summarizing findings
and dispositions per the rule's compliance clause.

---

## Merge mechanics

The user's `gh-merge` shell function in `~/.zshrc` is the standard merge
path. It bypasses `gh pr merge`'s `mergeStateStatus` cache pitfall by
calling `PUT /repos/.../pulls/<n>/merge` directly. **Symptom of the
cache pitfall:** GitHub UI shows the merge button greyed-out or
"Unknown merge state" even though all 7 required checks pass — Claude
would assume the PR isn't ready. Don't trust `mergeStateStatus`; trust
the check rollup directly (`gh pr checks <n> --required`).

For Claude-driven merges (different shell, can't source `~/.zshrc`):
```bash
gh api -X PUT "repos/<owner>/<repo>/pulls/<n>/merge" -f merge_method=squash
```
Then delete the branch:
```bash
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"
```
(May 422 if the branch is the default or is protected — that's expected,
not a failure.)

If the merge returns HTTP 405 "rule violations — 7 of 7 required status
checks are expected", the branch is BEHIND `main` (strict mode). Fix:
```bash
gh api -X PUT "repos/<owner>/<repo>/pulls/<n>/update-branch"
```
Wait for CI to re-run, then retry the merge. **If `--auto` is already
enabled on the PR, skip the manual `update-branch` call** — GitHub's
auto-merge controller handles strict-mode rebases on its own and racing
it with manual nudges can cause check noise. Only call `update-branch`
manually when auto-merge is NOT enabled.

**Concurrency pitfall to know about:** workflows with
`concurrency: cancel-in-progress: true` produce stale `CANCELLED`
check rows that pollute `mergeStateStatus` even when the latest per-name
run passed. Branch protection itself uses per-name latest (correct);
`mergeStateStatus` is a UI artifact. If a PR shows BLOCKED but
`gh pr checks <n> --required` shows all `pass`, this is the trap.

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

**Has bootstrap.sh already run on this repo?** Check signals:
- Presence of `Makefile` (bootstrap.sh generates it) → likely yes.
- Absence of `ci-*.yml` files for languages other than the project's
  primary (e.g. only `ci-python.yml` + cross-cutting profiles
  remaining, no `ci-node.yml`/`ci-go.yml`) → yes.
- Initial commit message includes "chore: initial bootstrap from
  nischal94/repo-template" → yes.

**Is Layer 1 already applied to this repo?** Check
`.github/policy/.scaffolded-by-nischal94-policy` — its presence means
the App has scaffolded its workflows and the canonical ruleset has
either applied or is pending the next enforce-on-poll cron tick.

---

## Open gaps in this workflow (known limits)

Two known gaps as of 2026-05-11; the platform works around them today
but each is worth knowing about:

1. **`scripts/overlay.sh` may not yet exist on the template.** A v1
   overlay-script PR was deferred during review. State B's step b
   above documents the fall-back: small manual overlay covering
   `.gitignore`, `CLAUDE.md`, `scripts/bootstrap.sh`, and the one
   `ci-<lang>.yml` matching the user's primary language. If `overlay.sh`
   has since landed, prefer the one-liner.

2. **`scripts/bootstrap.sh` runs `git init` + `git commit`
   non-interactively** even when the user's Git-safety SCAR requires
   explicit confirmation. A patch making this confirmable is queued
   in a separate PR (`fix(bootstrap): pause before git init/commit`).
   Until it merges, the workaround is to either:
   - Run `git init -b main && git add . && git commit -m "chore: initial
     commit"` yourself in step c (so bootstrap's commit is a no-op), OR
   - Run bootstrap fresh and let its commit be the initial commit
     (bootstrap message: `chore: initial bootstrap from
     nischal94/repo-template`).
   Either ordering works — pick one in confirmation with the user.

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
