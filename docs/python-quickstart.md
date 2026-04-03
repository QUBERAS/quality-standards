# Python quickstart

Get your Python repo compliant with QUBERAS quality standards in four steps: run checks locally, add pre-commit hooks, wire up CI, then enforce it on PRs.

## Step 1. Run checks locally

No install needed beyond pip. This runs the same checks CI will run — so you see exactly what will pass or fail.

### Quick setup

```bash
# Install uv if you don't have it: https://docs.astral.sh/uv/
uv tool install ruff
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
# Install: brew install trufflehog (mac) or see https://github.com/trufflesecurity/trufflehog
trufflehog git file://. --since-commit HEAD --only-verified --fail

# ── CVE scan (known vulnerabilities in your deps?) ────────────────────────
# Install: brew install trivy (mac) or see https://github.com/aquasecurity/trivy
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

## Step 2. Add pre-commit hooks

Pre-commit hooks run checks on every commit before it's created. They catch issues early so you don't push broken code and wait for CI.

### Install

```bash
uv tool install pre-commit
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/.pre-commit-config.yaml -o .pre-commit-config.yaml
pre-commit install
```

Or use the full bootstrap script which does this plus more:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/install.sh | bash
```

### Verify it works

```bash
pre-commit run --all-files
```

### What the hooks run

| Hook | What it does |
|------|-------------|
| ruff-format | Auto-formats code |
| ruff | Lints + auto-fixes (import sort, etc.) |
| trufflehog | Scans for leaked secrets |
| trailing-whitespace | Removes trailing whitespace |
| end-of-file-fixer | Ensures files end with newline |
| check-yaml / check-toml | Validates config file syntax |
| check-added-large-files | Blocks files > 500KB |
| check-merge-conflict | Catches unresolved merge markers |
| debug-statements | Catches leftover `breakpoint()` / `pdb` |

### Skip hooks when needed

```bash
SKIP=ruff,trufflehog git commit -m "wip: debugging"   # skip specific hooks
git commit --no-verify                                  # skip all hooks
```

This is fine for WIP commits. CI catches the same things on PR.

### Should you use pre-commit hooks?

Hooks are optional. CI enforces the same rules. Use hooks if you want instant feedback; skip them if you find them annoying and trust your PR process.

## Step 3. Add the CI workflow

This makes quality checks run automatically on every push and PR — but doesn't block merging yet.

### Create `.github/workflows/quality.yml`

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
      level: "minimal"                              # start here, level up later
      python-version: "3.12"
      audit: true                                   # requires uv.lock in repo
      typecheck-cmd: "ty check"                     # ty check runs by default — pass "" to skip
      commitlint: true                              # enforce conventional commits on PR titles
    secrets: inherit
```

Commit and push. The workflow will run on the next push or PR — you'll see results in the Actions tab.

### What runs in CI

| Check | Tool | Blocks merge (step 4) | How to control |
|-------|------|-----------------------|----------------|
| Format | ruff | yes | level config |
| Lint | ruff | yes | level config |
| Complexity (C90) | ruff | no (warn only) | always runs |
| Type check | ty | yes | `typecheck-cmd: "ty check"` (default), pass `""` to skip |
| Secrets | TruffleHog | yes | always on |
| CVE scan | Trivy | yes | `trivy-severity` input (default: CRITICAL,HIGH) |
| Dependency audit | uv audit | yes | `audit: true/false` |
| PR title | commitlint | yes (PR only) | `commitlint: true/false` |

### Run manually via workflow_dispatch

To also allow manual runs from the Actions tab, add `workflow_dispatch`:

```yaml
on:
  workflow_dispatch:
    inputs:
      level:
        description: "Enforcement level"
        type: choice
        options: [minimal, standard, strict]
        default: "standard"
  push:
    branches: [main, develop]
  pull_request:
    branches: ["**"]
```

Then use the input in the job: `level: ${{ inputs.level || 'minimal' }}`.

## Step 4. Make it block merges

The workflow from step 3 runs and reports results, but doesn't prevent merging if checks fail. To enforce it, configure branch protection rules in GitHub.

See [org-level-branch-enforcement.md](org-level-branch-enforcement.md) for full instructions, but the short version:

### Per-repo setup (quick)

1. Go to **Settings → Branches → Add branch protection rule** (or **Settings → Rules → Rulesets** for newer repos)
2. Branch name pattern: `main` (or `main` and `develop`)
3. Enable **Require status checks to pass before merging**
4. Search and add these status checks (they appear after the workflow has run at least once):
   - `quality / lint / Lint (ruff)`
   - `quality / format / Format (ruff)`
   - `quality / typecheck / Type check`
   - `quality / secrets / Secrets (trufflehog)`
   - `quality / trivy / CVE scan (filesystem)`
   - `quality / audit / Dependency audit (uv)` (if audit enabled)
   - `quality / commitlint / PR title (conventional commits)` (if commitlint enabled)
5. Save

Now PRs can't merge unless all selected checks pass.

### Org-level setup (recommended)

If you want this enforced across all QUBERAS repos by default, use org-level rulesets instead. See [org-level-branch-enforcement.md](org-level-branch-enforcement.md).

## Level up progressively

The path is `minimal` → `standard` → `strict`. Each level is a strict superset of the previous one.

### Get clean on minimal first

```yaml
level: "minimal"    # F, E — fix real errors first
```

Fix all violations — usually a small batch. Often auto-fixable:

```bash
ruff check --fix --config /tmp/qs-level.toml .
```

### Move to standard

Once minimal is clean, bump the level:

```yaml
level: "standard"   # adds W, B, S, I, UP
```

Common new violations:

| Rules | What to expect | Fix approach |
|-------|---------------|--------------|
| **W** (warnings) | Whitespace issues, bare excepts | Auto-fixable (`ruff check --fix`) |
| **B** (bugbear) | Mutable default args, `getattr` with constants | Manual — usually a few dozen fixes |
| **S** (bandit) | Hardcoded passwords, `subprocess` calls, `assert` in non-tests | Review each — some need `per-file-ignores` |
| **I** (isort) | Import ordering | Auto-fixable |
| **UP** (pyupgrade) | Old-style string formatting, deprecated syntax | Auto-fixable |

### Move to strict

```yaml
level: "strict"     # adds C90, N, D, ANN, TC, FA, PYI, Q
```

Biggest jump. Tackle one rule group at a time:

```bash
ruff check --select N .      # naming violations
ruff check --select D .      # docstring coverage
ruff check --select ANN .    # type annotation coverage
```

| Rules | What it enforces | Effort |
|-------|-----------------|--------|
| **C90** | Function complexity (max 15) | Split complex functions |
| **N** | PEP 8 naming | Rename — can be invasive |
| **D** | Google-style docstrings | Writing docs — biggest effort |
| **ANN** | Type annotations on function signatures | Add types incrementally |
| **TC** | Move type-only imports behind `TYPE_CHECKING` | Auto-fixable |
| **FA** | `from __future__ import annotations` | Auto-fixable |
| **PYI** | Stub file best practices | Rare |
| **Q** | Quote consistency (double quotes) | Auto-fixable |

Tests are exempted from `D`, `ANN`, and `TC` at all levels.

### Tips for large codebases

- **Don't boil the ocean.** Auto-fix first (`ruff check --fix`), then manual fixes one rule group at a time.
- **Use per-file-ignores** for legitimate exceptions (migrations, generated code):
  ```toml
  [tool.ruff.lint.per-file-ignores]
  "scripts/**" = ["D", "ANN"]
  "legacy_module/**" = ["N"]
  ```
- **Your `pyproject.toml` can add rules but cannot remove them.** The level config from CI is authoritative.
- **Run the target level locally** before bumping in CI.

## IDE support

CI enforces the level config from this repo. For inline errors in your editor, copy the rules into your `pyproject.toml`:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/python/ruff.reference.toml
```

Copy the `[tool.ruff]` sections you need. The reference config matches `strict` — trim `select` to match your chosen level.
