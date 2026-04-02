# quality-standards

Shared code quality workflows and configs for QUBERAS repos. A lighthouse, not a law — repos adopt progressively and are never blocked during active development.

## Quick start

From your repo root:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/install.sh | bash
```

Or if you already have a Makefile:

```bash
make quality-init
```

This copies pre-commit hooks, commitlint config, and a starter CI workflow. Review and commit the generated files.

## Enforcement levels

Each repo chooses a level. The level config is fetched from this repo at CI time — repos **cannot override** the rules for their chosen level. Repos *can* add extra checks on top via their own `pyproject.toml`.

| Level | Rules | Use for |
|-------|-------|---------|
| `minimal` | F, E | Legacy repos, first-time onboarding |
| `standard` | F, E, W, B, S, I, UP | Active repos (recommended) |
| `strict` | All of the above + C90, N, D, ANN, TC, FA, PYI, Q | New repos, libraries |

Start with `minimal`, move to `standard` when clean. The goal is progress, not perfection.

## What blocks merge vs what warns

| Check | Blocks merge | Controlled by |
|-------|-------------|---------------|
| Format (ruff) | yes | level config |
| Lint (ruff) | yes | level config |
| Secrets (trufflehog) | yes | always on |
| CVE scan (trivy) | yes | `trivy-severity` input |
| Dependency audit | yes | omit `requirements-file` to skip |
| Complexity (C90) | no | repo's pyproject.toml |
| Type check | no | omit `typecheck-cmd` to skip |
| Commitlint | configurable | `commitlint: true/false` |

## CI workflow usage

### Full suite (recommended)

Create `.github/workflows/quality.yml` in your repo:

```yaml
name: Quality
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: ["**"]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    uses: QUBERAS/quality-standards/.github/workflows/python.yml@main
    with:
      level: "standard"
      python-version: "3.12"
      requirements-file: "requirements.lock"
      typecheck-cmd: "ty check"
      commitlint: true
    secrets: inherit
```

All checks run in parallel. Only `secrets: inherit` is needed if you don't use pip-audit — the other checks don't require secrets.

### Individual checks

Call checks independently for custom composition:

```yaml
jobs:
  lint:
    uses: QUBERAS/quality-standards/.github/workflows/python-lint.yml@main
    with:
      level: "standard"
      python-version: "3.12"
```

Or use repo config with explicit rules:

```yaml
jobs:
  complexity:
    uses: QUBERAS/quality-standards/.github/workflows/python-lint.yml@main
    with:
      rules: "C90"
      continue-on-error: true
```

## Branch strategy

- **`main` / `develop`**: CI runs on push — these are the branches that matter for compliance.
- **Feature branches**: CI runs on pull request only. Never gated on push — developers need to push freely.
- **Pre-commit hooks**: Run locally on every commit. Can be skipped when needed (see below).

The goal: catch issues early via hooks, enforce on PR, never block a developer's push to their feature branch.

## Local development

### Pre-commit hooks

Install hooks (done automatically by `install.sh`):

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

### Skipping hooks during dev

When you're iterating and need to push without fixing everything:

```bash
# Skip specific hooks
SKIP=ruff,trufflehog git commit -m "wip: debugging"

# Skip all hooks (use sparingly)
git commit --no-verify
```

This is a blessed escape hatch, not a workaround. Use it for WIP commits, then clean up before opening a PR.

### Running checks locally

```bash
# Run all pre-commit hooks on all files
make quality-check

# Lint at a specific level (matches what CI enforces)
make lint-minimal     # F, E only
make lint-standard    # F, E, W, B, S, I, UP (default)
make lint-strict      # full suite
make lint             # alias for lint-standard

# Format
make format           # auto-fix formatting
make format-check     # check only (CI mode)
```

## Ruff config for IDE support

CI enforces the level config from this repo. For IDE integration (autocomplete, inline errors), copy rules into your `pyproject.toml`:

```bash
# View the reference config:
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/ruff.reference.toml
```

Copy the relevant `[tool.ruff]` sections into your `pyproject.toml`. Adjust `line-length`, `target-version`, `src`, and `extend-exclude` per repo. The reference config matches the `strict` level.

## Structure

```
.github/workflows/
  python.yml                      # top-level Python workflow (composes all checks)
  python-format.yml               # ruff format --check
  python-lint.yml                 # ruff check (configurable rules or level)
  python-typecheck.yml            # ty / mypy / pyright
  python-audit.yml                # pip-audit
  secrets.yml                     # trufflehog (free for private repos)
  trivy.yml                       # CVE + misconfig (deps, Dockerfiles, Compose)
  commitlint.yml                  # conventional commits

configs/
  python/
    levels/
      minimal.toml                # level: minimal
      standard.toml               # level: standard
      strict.toml                 # level: strict
    ruff.reference.toml           # full reference config (copy into pyproject.toml)
    .pre-commit-config.yaml       # pre-commit hooks template
  common/
    commitlint.config.js          # shared commitlint rules
  claude/
    CLAUDE.md                     # Claude Code project instructions template
    settings.local.json           # allowed/denied tool permissions

scripts/
  validate.py                     # config & workflow validation

install.sh                        # one-liner bootstrap for consuming repos
Makefile                          # quality-init, quality-check, lint-*, format-*
```

## Adding a new language

1. Create level configs in `configs/<language>/levels/`
2. Create check workflows in `.github/workflows/` (must be flat — GitHub requires reusable workflows at this path, no subdirectories)
3. Create a top-level composer workflow (e.g. `go.yml`)
4. Keep the same level names (`minimal` / `standard` / `strict`) — consistency across languages matters

## Claude Code config

The bootstrap also installs Claude Code guardrails:

- **`CLAUDE.md`** — project instructions (commit conventions, quality rules, what not to do)
- **`.claude/settings.local.json`** — allowed/denied tool permissions (blocks force-push, `rm -rf`, `--no-verify`; allows standard git, ruff, pytest, make commands)

These ensure AI-assisted coding follows the same standards as human developers. Edit per-repo as needed.

## Updating hooks

To bump pre-commit hook versions in a consuming repo:

```bash
make quality-update
# or:
pre-commit autoupdate
```

Review the changes and commit.
