# Project instructions for Claude Code

## Quality standards

This repo follows QUBERAS quality standards. Before committing:
- Code must pass `pre-commit run --all-files` (ruff format + lint, trufflehog, commitlint)
- Commits must follow Conventional Commits: `<type>(<scope>): <subject>`
  - Types: feat, fix, chore, docs, refactor, test, ci, perf, revert, style, build
  - Subject: lowercase, no trailing period, max 100 chars
- Do not disable or weaken ruff rules — the CI level config is authoritative
- Do not commit secrets, credentials, or .env files

## Code style

- Line length: 120
- Quote style: double
- Import sorting: isort (enforced by ruff)
- Docstrings: Google convention (if strict level)
- Type annotations: encouraged, enforced at strict level

## Testing

- Prefer real tests over mocks — test actual behavior
- Tests live in `tests/` or `**/tests/`
- Test files: `test_*.py` or `*_test.py`

## What NOT to do

- Do not add `# type: ignore` without a specific error code
- Do not add `# noqa` without a specific rule code
- Do not suppress linter warnings globally — use per-file-ignores for legitimate exceptions
- Do not modify `.pre-commit-config.yaml` to remove hooks
- Do not add `--no-verify` to any scripts or CI steps
