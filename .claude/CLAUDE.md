# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Shared CI quality workflows and configs for all QUBERAS org repos. Consuming repos call reusable GitHub Actions workflows from here and get ruff lint/format, secret scanning, CVE scanning, uv audit, type checking, and commitlint — all controlled by enforcement levels (minimal/standard/strict).

This is a **standards repo, not an application**. Changes here affect every QUBERAS repo that uses these workflows.

## Common commands

```bash
make quality-validate       # validate all configs, workflows, and action pins (the main "test" for this repo)
make lint                   # ruff lint at standard level (alias for lint-standard)
make lint-minimal           # ruff lint: F, E only
make lint-standard          # ruff lint: F, E, W, B, S, I, UP
make lint-strict            # ruff lint: full suite
make format                 # ruff format (auto-fix)
make format-check           # ruff format check (CI mode)
make quality-check          # run all pre-commit hooks on all files
```

The validation script (`python3 scripts/validate.py`) checks: TOML/YAML syntax, action version pins (no @master/@latest), no relative workflow refs, and level config consistency (strict.toml select/ignore must match ruff.reference.toml). Requires `pyyaml` (and `tomli` on Python <3.11).

## Architecture

### Workflow composition

`python.yml` is the top-level reusable workflow. It composes individual check workflows that all run in parallel:
- **Merge-blocking**: `python-format.yml`, `python-lint.yml`, `secrets.yml`, `trivy.yml`, `python-audit.yml` (if audit enabled), `commitlint.yml` (PR title only, if enabled)
- **Non-blocking**: complexity (C90 via python-lint.yml with `continue-on-error`), typecheck (if typecheck-cmd provided)

All workflows must live flat in `.github/workflows/` — GitHub requires reusable workflows at this path, no subdirectories.

`python-lint.yml` has two modes: when `level` is set, it fetches the level config from this repo via sparse checkout; when `level` is empty, it uses the `rules` input for ad-hoc rule selectors (used by the complexity job with `rules: "C90"`).

### Level configs

`configs/python/levels/{minimal,standard,strict}.toml` are ruff configs fetched by CI at runtime. Consuming repos **cannot override** their chosen level's rules — they can only add extra checks on top. `ruff.reference.toml` is the full reference config and must stay in sync with `strict.toml` (validated by `validate.py`).

### Bootstrap flow

`install.sh` is the entry point for consuming repos. It downloads: `.pre-commit-config.yaml` (from `configs/python/`), `commitlint.config.js` (from `configs/common/`), `CLAUDE.md` and `.claude/settings.local.json` (from `configs/claude/`), and writes a starter CI workflow. Safe to re-run — prompts before overwriting.

### Two CLAUDE.md files

- `.claude/CLAUDE.md` — instructions for working **on this repo** (you're reading it)
- `configs/claude/CLAUDE.md` — template distributed to **consuming repos** via `install.sh`. Editing this affects all repos that bootstrap from here.

## Key constraints

- Action uses in workflows must be pinned to version tags (never @master or @latest)
- No relative workflow refs (`uses: ./`) — consuming repos call these with full `QUBERAS/quality-standards/.github/workflows/...@main`
- Level configs must use `line-length = 120` and include a `[format]` section
- Commits follow Conventional Commits: `<type>(<scope>): <subject>` — no trailing period, max 100 chars
- When adding a new language: create `configs/<language>/levels/`, check workflows, and a top-level composer workflow, keeping the same level names
