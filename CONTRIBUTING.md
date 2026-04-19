# Contributing

Thanks for considering a contribution.

## Workflow

1. Fork the repository (or create a feature branch if you have write access).
2. Create a branch using a Conventional Commits prefix:
   - `feat/short-description` for new functionality
   - `fix/short-description` for bug fixes
   - `docs/short-description` for documentation
   - `refactor/`, `test/`, `chore/`, `perf/`, `build/`, `ci/` per [Conventional Commits](https://www.conventionalcommits.org/).
3. Make your changes. Keep commits atomic (one logical change per commit).
4. Run tests locally before pushing.
5. Open a Pull Request. The PR title MUST follow Conventional Commits — `pr-title.yml` enforces this.

## Pull Request expectations

- All required status checks pass (CI, gitleaks, PR-title lint, etc).
- Conversation must be resolved.
- One approving review (project owner or collaborator).
- No secrets, debug statements, or commented-out code in the diff.

## Reporting security vulnerabilities

Use GitHub's private vulnerability reporting (Security tab → Report a vulnerability), not a public issue. See [SECURITY.md](SECURITY.md).

## Local development

Project-specific setup lives in the README. Cross-cutting tooling:

- **`.editorconfig`** is honored automatically by most editors. No setup needed.
- **Conventional Commits**: consider running `commitlint` locally as a pre-commit hook so violations are caught before you push.

## Code style

- Match existing patterns in the file you're editing rather than introducing a new style.
- Default to **no comments**. Add one only when the *why* is non-obvious — a hidden constraint, a workaround, behavior that would surprise a reader.
- Prefer editing existing files over creating new ones.
