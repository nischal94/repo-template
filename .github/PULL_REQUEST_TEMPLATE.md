<!--
  PR description guide. Delete sections that genuinely don't apply
  (most PRs need most sections). Keep section headers; reviewers scan
  for them.
-->

## Context — why this change exists

<!--
  The problem this solves. What prompted it: a bug report, a security
  audit finding, a user request, a scar from past incident. Link the
  source if there is one (issue, advisory, conversation, log line).
  The diff shows WHAT; this section explains WHY THIS, WHY NOW.
-->

## What changed

<!--
  Section-by-section or file-by-file summary. For multi-component PRs,
  group by component. Use a table when comparing before/after for >3
  fields.
-->

## How — implementation choices and trade-offs

<!--
  Key decisions made and what alternatives were considered. Examples:
  - "Chose X over Y because Y would have required Z."
  - "Trade-off: A is faster but B is safer; we picked B because <reason>."
  Don't restate the diff; explain the reasoning behind it.
-->

## Risk assessment

<!--
  What could break, and how badly. Categories:
  - Blast radius: this repo only / downstream consumers / production
  - Reversibility: trivial revert / requires data migration / one-way
  - Likelihood: well-tested path / new code path / first time in prod
  Be specific. "Low risk" with no detail is worse than no statement.
-->

## Test plan

<!--
  Explicit verification steps. Each item should be checkable.
  Examples that count:
    - [ ] `pytest backend/tests/test_auth.py::test_token_expiry` passes
    - [ ] Manually tested signup flow on preview URL
    - [ ] CI's `Backend — tests` check passes (visible above)
  Examples that don't count:
    - [ ] Tests pass (which tests? where?)
    - [ ] Code reviewed (by whom, focused on what?)
-->

- [ ]
- [ ]

## Reviewer focus

<!--
  Where to look first. Especially useful for large PRs.
  Examples:
  - "Start with the migration in `backend/alembic/versions/004_*.py` —
     that's the only behavior-changing piece. The rest is config plumbing."
  - "Pay attention to `permissions:` blocks in the new workflows —
     wrong scope = security issue."
-->

## Rollback plan

<!--
  How to undo this if it breaks. Examples:
  - "Pure config change — `git revert <sha>` is safe."
  - "Schema change — `alembic downgrade -1` reverses, but data added
     after this PR's merge will be lost."
  - "Action workflow change — disable the workflow in Settings → Actions
     while you investigate; revert later."
-->

## Post-merge actions

<!--
  Anything to do AFTER merge that doesn't happen automatically. Examples:
  - Run `gh secret set FOO -R owner/repo`
  - Watch the deploy in Vercel for 10min for error rate
  - Add the new check to required-status-checks via branch protection
  - Create a release tag
  - Notify <stakeholder>
-->

## References

<!--
  Links the reviewer might need:
  - Issues: closes #123, related to #456
  - External: CVE-2025-XXXX, RFC link, vendor docs
  - Prior PRs in the same thread
  - docs/SECURITY-OPERATIONS.md §X if applicable
-->

## Follow-ups intentionally NOT in this PR

<!--
  Known incomplete work. Either link to a tracking issue or note it
  here so reviewers don't ask "what about X?".
-->

---

## Checklist

- [ ] PR title follows Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `perf:`, `build:`, `ci:`)
- [ ] Tests pass locally + CI is green (or advisory failures explained above)
- [ ] No secrets, debug statements, or commented-out code in the diff
- [ ] Docs updated if behavior changed (README, ARCHITECTURE, CHANGELOG, etc.)
- [ ] Required-status-checks list updated if a new blocking check was added
- [ ] Follow-up items captured as GitHub Issues (per `feedback_pr_followups_auto_track.md`)
