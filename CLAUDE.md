# Project context for nischal94 platform projects

This file is read automatically at the start of every Claude Code session in
this project. It carries platform-specific workflow context so Claude can act
correctly without the user re-explaining how the nischal94 CI platform works.

This file is part of the [`nischal94/repo-template`](https://github.com/nischal94/repo-template) baseline. Projects created from the template inherit it via `gh repo create --template`; the template repo itself carries it for self-application.

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
   Greenfield (no `.git/` yet): `git init -b main` first, then commit
   the working tree (`git add . && git commit -m "chore: initial commit"`),
   THEN run the create command. `gh repo create … --push` refuses to
   push if HEAD has no commits.
   ```
   gh repo create nischal94/<name> --<visibility> --source=. --remote=origin --push
   ```
   The default branch is assumed to be `main` (matches `git init -b main`
   and the canonical ruleset's target). This step is irreversible-ish
   (user can delete the repo but creation is a public action). Confirm
   name + visibility one more time before running.

c. **Open the enrollment PR on `nischal94/.github`** (Layer 1 enrollment):

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

d. **Tell the user the timeline.**
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
```
gh api -X PUT "repos/<owner>/<repo>/pulls/<n>/merge" -f merge_method=squash
```
Then delete the branch:
```
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"
```
(May 422 if the branch is the default or is protected — that's expected,
not a failure.)

If the merge returns HTTP 405 "rule violations — 7 of 7 required status
checks are expected", the branch is BEHIND `main` (strict mode). Fix:
```
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

## Known gap — local-first overlay flow not yet automated

If the user is in **state 2 (local-first: existing folder with files, no
GitHub repo, no template files)**, the right answer is to overlay missing
template files into their folder before running the ship-to-GitHub flow.
This overlay step is intentionally NOT yet automated by a script (a v1
attempt was deferred in 2026-05-11 review). If the user asks for the
local-first flow:

1. Surface this gap explicitly — don't pretend automation exists.
2. Offer to overlay specific files manually (`gh api … contents/<path>
   -H 'Accept: application/vnd.github.raw' > <path>` for each file from
   the template, skipping any path that already exists locally).
3. Suggest opening a follow-up PR on `repo-template` to add a hardened
   overlay script if the user does this more than twice.

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
