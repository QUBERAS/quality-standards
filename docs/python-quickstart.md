# Python quickstart

Get your Python repo compliant with QUBERAS quality standards in three steps: check where you stand, wire up CI, then raise the bar over time.

## 1. Run every check locally (before touching CI)

No install needed beyond pip. This runs the same checks CI will run — so you see exactly what will pass or fail.

### Quick setup

```bash
pip install ruff pre-commit
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/levels/standard.toml -o /tmp/qs-level.toml
```

Replace `standard` with `minimal` or `strict` depending on the level you're targeting.

### Run each check

```bash
# ── Lint (are there code issues?) ──────────────────────────────────────────
ruff check --config /tmp/qs-level.toml .

# ── Format (is the code formatted correctly?) ─────────────────────────────
ruff format --check --config /tmp/qs-level.toml .

# ── Secrets (any leaked keys/tokens?) ──────────────────────────────────────
# Requires docker OR: pip install trufflehog (Go binary, see https://github.com/trufflesecurity/trufflehog)
trufflehog git file://. --since-commit HEAD --only-verified --fail

# ── CVE scan (known vulnerabilities in your deps?) ────────────────────────
# Install trivy: brew install trivy (mac) or see https://github.com/aquasecurity/trivy
trivy fs --scanners vuln --severity CRITICAL,HIGH .

# ── Dependency audit (are your pinned deps safe?) ─────────────────────────
# Requires uv (https://docs.astral.sh/uv/) and a uv.lock in the project
uv audit
```

### Auto-fix what you can

```bash
ruff check --fix --config /tmp/qs-level.toml .    # fix lint violations
ruff format --config /tmp/qs-level.toml .          # reformat code
```

### See how bad it is at each level

```bash
QS="https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/levels"

# Check all three levels — see exactly how many violations each one adds
for level in minimal standard strict; do
  echo "=== $level ==="
  curl -fsSL "$QS/$level.toml" -o /tmp/qs-$level.toml
  ruff check --config /tmp/qs-$level.toml --statistics . 2>&1 | tail -20
  echo ""
done
```

Pick the level where you can fix everything in a reasonable timeframe. Start there.

### What the levels enforce

| Level | Rule groups | What it catches |
|-------|------------|-----------------|
| `minimal` | F, E | Unused imports, undefined names, syntax errors |
| `standard` | F, E, W, B, S, I, UP | All of minimal + warnings, likely bugs (bugbear), security (bandit), import sorting, pyupgrade |
| `strict` | All of standard + C90, N, D, ANN, TC, FA, PYI, Q | All of standard + complexity, naming, docstrings, type annotations, quotes |

Start wherever your code is clean. Most repos begin at `minimal` or `standard`.

## 2. Add CI and local hooks

### Should you enable pre-commit hooks?

Pre-commit hooks run checks **on every commit** before it's created. They catch issues early but add friction during development.

**Use pre-commit hooks if:**
- Your team commits directly to main/develop (no PR workflow)
- You want instant feedback without pushing and waiting for CI
- You care about clean git history (every commit passes checks, not just the PR)

**Skip pre-commit hooks (CI-only) if:**
- You iterate fast with WIP commits and clean up before PR
- Your team already has a strong PR review process
- You find hooks annoying — CI catches the same things on PR

Both options enforce the same rules. Pre-commits are a convenience, not a requirement. You can always add them later.

### Option A: Full bootstrap (recommended)

From your repo root:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/install.sh | bash
```

This sets up:
- `.pre-commit-config.yaml` — ruff format + lint, trufflehog secrets, general hygiene hooks
- `commitlint.config.js` — conventional commit rules
- `.github/workflows/quality.yml` — CI workflow calling the shared checks
- Pre-commit hooks installed locally

To verify hooks work, run them on all files before your first commit:

```bash
pre-commit run --all-files
```

Review and commit the generated files, then edit `.github/workflows/quality.yml` to match your repo:

```yaml
jobs:
  quality:
    uses: QUBERAS/quality-standards/.github/workflows/python.yml@main
    with:
      level: "minimal"                              # start here
      python-version: "3.12"
      # audit: true                                  # requires uv.lock in repo
      # typecheck-cmd: "ty check"                   # uncomment for type checking
      commitlint: true
    secrets: inherit
```

### Option B: CI only (no local hooks)

Create `.github/workflows/quality.yml` manually:

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
      level: "minimal"
      python-version: "3.12"
    secrets: inherit
```

### What runs in CI

| Check | Blocks merge | How to control |
|-------|-------------|----------------|
| Format (ruff) | yes | level config |
| Lint (ruff) | yes | level config |
| Secrets (trufflehog) | yes | always on |
| CVE scan (trivy) | yes | `trivy-severity` input (default: CRITICAL,HIGH) |
| Dependency audit (uv) | yes | `audit: true` (default), requires `uv.lock` |
| Complexity (C90) | no | warns only |
| Type check | no | set `typecheck-cmd` to enable |
| PR title (conventional) | configurable | `commitlint: true/false`, PR-only |

### Run all checks at once (with or without pre-commit)

If you installed pre-commit, this runs every hook on your entire codebase:

```bash
pre-commit run --all-files
```

Without pre-commit, run the checks individually as shown in [section 1](#1-run-every-check-locally-before-touching-ci).

## 3. Level up progressively

The path is `minimal` → `standard` → `strict`. Each level is a strict superset of the previous one.

### Step 1: Get clean on minimal

```yaml
# .github/workflows/quality.yml
level: "minimal"    # F, E — fix real errors first
```

Fix all violations. This is usually a small batch: unused imports, undefined names, syntax issues. Often auto-fixable:

```bash
ruff check --fix --config /tmp/qs-level.toml .
```

### Step 2: Move to standard

Once `minimal` is clean, bump the level:

```yaml
level: "standard"   # adds W, B, S, I, UP
```

Download the standard config and see what's new:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/levels/standard.toml -o /tmp/qs-level.toml
ruff check --config /tmp/qs-level.toml .
```

Common new violations and how to fix them:

| Rules | What to expect | Fix approach |
|-------|---------------|--------------|
| **W** (warnings) | Whitespace issues, bare excepts | Auto-fixable (`ruff check --fix`) |
| **B** (bugbear) | Mutable default args, `getattr` with constants, `strip` pitfalls | Manual — usually a few dozen fixes |
| **S** (bandit) | Hardcoded passwords, `subprocess` calls, `assert` in non-tests | Review each — some are `per-file-ignores`, not code changes |
| **I** (isort) | Import ordering | Auto-fixable |
| **UP** (pyupgrade) | Old-style string formatting, deprecated syntax | Auto-fixable |

### Step 3: Move to strict

```yaml
level: "strict"     # adds C90, N, D, ANN, TC, FA, PYI, Q
```

This is the biggest jump. Tackle one rule group at a time by checking selectively before committing to the full level:

```bash
# Check how bad naming violations are
ruff check --select N .

# Check docstring coverage
ruff check --select D .

# Check type annotation coverage
ruff check --select ANN .
```

Strict adds these rule groups:

| Rules | What it enforces | Effort |
|-------|-----------------|--------|
| **C90** | Function complexity (max 15) | Split complex functions |
| **N** | PEP 8 naming (classes, functions, variables) | Rename — can be invasive |
| **D** | Google-style docstrings on public functions/classes | Writing docs — biggest effort |
| **ANN** | Type annotations on function signatures | Add types incrementally |
| **TC** | Move type-only imports behind `TYPE_CHECKING` | Auto-fixable with `--fix` |
| **FA** | Use `from __future__ import annotations` | Auto-fixable |
| **PYI** | Stub file best practices | Rare — usually few hits |
| **Q** | Quote consistency (double quotes) | Auto-fixable |

Tests are exempted from `D`, `ANN`, and `TC` at all levels — no need to docstring or annotate test code.

### Tips for large codebases

- **Don't boil the ocean.** Fix auto-fixable rules first (`ruff check --fix`), then tackle manual fixes one rule group at a time.
- **Use per-file-ignores** for legitimate exceptions (migrations, generated code), not to avoid fixing real issues. Add them in your `pyproject.toml`:
  ```toml
  [tool.ruff.lint.per-file-ignores]
  "scripts/**" = ["D", "ANN"]        # scripts don't need docstrings
  "legacy_module/**" = ["N"]          # naming is grandfathered
  ```
- **Your `pyproject.toml` can add rules but cannot remove them.** The level config from CI is authoritative — repos choose their level, then follow it.
- **Run the target level locally** before bumping in CI to avoid surprise failures:
  ```bash
  make lint-standard   # or lint-strict
  ```

## IDE support

CI enforces the level config from this repo. For inline errors in your editor, copy the rules into your `pyproject.toml`:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/ruff.reference.toml
```

Copy the `[tool.ruff]` sections you need. The reference config matches `strict` — trim `select` to match your chosen level.

## Skipping hooks during dev

Pre-commit hooks run locally on every commit. When iterating on a feature branch:

```bash
SKIP=ruff,trufflehog git commit -m "wip: debugging"   # skip specific hooks
git commit --no-verify                                  # skip all hooks
```

This is fine for WIP commits. CI enforces on PR — clean up before opening one.
