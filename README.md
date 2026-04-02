# quality-standards

Shared code quality workflows and configs for QUBERAS repos.

## Enforcement levels

Each repo chooses a level. The level config is fetched from this repo at CI time — repos **cannot override** the rules for their chosen level.

| Level | Rules | Use for |
|-------|-------|---------|
| `minimal` | F, E | Legacy repos, first-time onboarding |
| `standard` | F, E, W, B, S, I, UP | Active repos (recommended) |
| `strict` | All of the above + C90, N, D, ANN, TC, FA, PYI, Q | New repos, libraries |

Repos can still add extra checks on top via their own `pyproject.toml` (complexity thresholds, per-file-ignores, etc.). But the level baseline is non-negotiable.

## Structure

```
.github/workflows/
  python.yml                      # top-level Python workflow (composes all checks)
  python-format.yml               # ruff format --check
  python-lint.yml                 # ruff check (configurable rules or level)
  python-typecheck.yml            # ty / mypy / pyright
  python-audit.yml                # pip-audit
  secrets.yml                     # gitleaks
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
```

## Usage

### Quick start (Python repo)

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
      commitlint: false
    secrets: inherit
```

All checks run in parallel. Start with `minimal`, move to `standard` when clean.

### What blocks merge vs what warns

| Check | Blocks merge | Controlled by |
|-------|-------------|---------------|
| Format (ruff) | yes | level config |
| Lint (ruff) | yes | level config |
| Secrets (gitleaks) | yes | always on |
| CVE scan (trivy) | yes | `trivy-severity` input |
| Dependency audit | yes | omit `requirements-file` to skip |
| Complexity (C90) | no | repo's pyproject.toml |
| Type check | no | omit `typecheck-cmd` to skip |
| Commitlint | configurable | `commitlint: true/false` |

### Using individual checks

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

### Pre-commit hooks

Copy `configs/python/.pre-commit-config.yaml` to your repo root:

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

### Ruff config

Copy rules from `configs/python/ruff.reference.toml` into your `pyproject.toml` under `[tool.ruff]`. Adjust `line-length`, `target-version`, `src`, and `extend-exclude` per repo. The reference config matches the `strict` level.

## Adding a new language

1. Create level configs in `configs/<language>/levels/`
2. Create check workflows in `.github/workflows/checks/` (e.g. `go-lint.yml`)
3. Create a top-level composer in `.github/workflows/` (e.g. `go.yml`)
