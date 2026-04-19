# Upgrading a derived repo from this template

GitHub templates are **one-time copies** — clicking "Use this template" gives you the contents at that moment, but there's no live link. When this template ships improvements (new workflows, doc updates, security tweaks), your derived repo doesn't automatically pull them in.

This doc tells you how to pull in template updates manually, and which template version you should compare against.

---

## 1. Find which template version you started from

Check `CHANGELOG.md` in your derived repo (if you copied it during creation) — the topmost dated entry is the template version you have. If you didn't copy `CHANGELOG.md`, check the creation date of your repo's `.github/workflows/gitleaks.yml` (or any other template-shipped workflow):

```bash
git log --diff-filter=A --follow --format="%aI" .github/workflows/gitleaks.yml | tail -1
```

Compare that date against the [template's `CHANGELOG.md`](../CHANGELOG.md) to find your version.

---

## 2. See what's changed since your version

```bash
# In your derived repo:
git remote add template https://github.com/nischal94/repo-template.git
git fetch template main
git log --oneline template/main --since="<your-template-date>"
```

Or browse the template's commits directly: https://github.com/nischal94/repo-template/commits/main

Or just diff the directories you care about:

```bash
git diff template/main -- .github/workflows
git diff template/main -- docs/
```

---

## 3. Cherry-pick the changes you want

For most changes (new workflows, doc updates), the simplest path is direct copy:

```bash
# Add a new workflow that the template added since you forked
git checkout template/main -- .github/workflows/<new-workflow>.yml
git checkout template/main -- docs/SECURITY-OPERATIONS.md  # if docs changed

# Review what got pulled in
git diff --cached

# Commit
git commit -m "ci: pull in new <workflow> from repo-template baseline"
```

For workflow changes that touched files you've already customized, **review per-file**:

```bash
git diff template/main -- .github/workflows/<file>.yml
# Then merge manually — your customizations may conflict
```

---

## 4. What does NOT auto-propagate (per-repo manual setup)

Even if you copy all workflow files, these settings have to be re-applied in your repo's GitHub UI / API:

| Setting | Where |
|---|---|
| Branch protection on `main` | Settings → Branches |
| Tag protection ruleset | Settings → Tags |
| CodeQL default setup | Settings → Code security |
| Secret scanning + push protection | Settings → Code security |
| Dependabot security updates | Settings → Code security |
| Private vulnerability reporting | Settings → Code security |
| `allow_auto_merge` | Settings → General |
| `delete_branch_on_merge` | Settings → General |
| First-time contributor approval | Settings → Actions |

The [post-creation checklist in `README.md`](../README.md#post-creation-checklist-tldr) walks through these. The full reference with rationale is in [`SECURITY-OPERATIONS.md §2`](SECURITY-OPERATIONS.md#2-post-creation-checklist-per-repo).

---

## 5. Recommended cadence

| Frequency | What |
|---|---|
| Per template release (see `CHANGELOG.md`) | Skim the entries; pull in anything that matters for your repo |
| Quarterly | Sweep `git diff template/main` against your repo; pull in any drift |
| Before every release | Re-run the post-creation checklist (catch any settings that drifted) |

---

## 6. When NOT to upgrade

Some template additions are **opt-in for active repos**, not blanket adoption:

- **`harden-runner` block-mode** — needs audit data first (per [SECURITY-OPERATIONS §7.1](SECURITY-OPERATIONS.md#71-harden-runner-egress-firewall))
- **SHA-pinning via `pinact`** — friction>value at solo-dev scale until you've been hit by a marketplace-action incident
- **`cosign` / SLSA / SBOM** — only when you publish artifacts that downstream consumers depend on
- **FULL Dependabot grouping** — only for dormant repos; active repos benefit from the default 3-group pattern

When in doubt: read [`SECURITY-OPERATIONS.md`](SECURITY-OPERATIONS.md) for the trade-off discussion before adopting.
