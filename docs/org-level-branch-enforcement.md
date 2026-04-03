# Org-level branch enforcement

How to enforce quality checks across all QUBERAS repos using GitHub org-level rulesets — so every repo gets branch protection by default without configuring each one manually.

## Two approaches

| | Per-repo branch protection | Org-level rulesets |
|---|---|---|
| Where | Settings → Branches (per repo) | Org Settings → Rulesets |
| Scope | One repo at a time | All repos (or matching pattern) |
| Who can configure | Repo admin | Org owner/admin |
| Override | Repo admin can weaken | Only org admin can bypass |
| Recommended for | One-off exceptions | Default enforcement across org |

**Use org-level rulesets.** Per-repo rules are fine for testing, but they don't scale and can be weakened by repo admins.

## Setting up org-level rulesets

### 1. Go to org rulesets

GitHub.com → **QUBERAS** org → **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**

### 2. Configure the ruleset

**Name:** `Quality checks required`

**Enforcement status:** Active

**Target repositories:**
- "All repositories" — applies to every repo in the org
- Or use "Dynamic list by name" with a pattern like `*` (all) or specific names

**Target branches:**
- Add target → Include default branch (covers `main`)
- Optionally add: Include by pattern → `develop` (if you protect develop too)

### 3. Set branch rules

Enable these rules:

#### Require a pull request before merging
- Required approvals: 1 (or 0 if you trust CI alone)
- Dismiss stale pull request approvals when new commits are pushed: yes
- Require approval of the most recent reviewable push: optional

#### Require status checks to pass
This is the key one. Add the quality check names that must pass:

**For Python repos:**
- `quality / lint / Lint (ruff)`
- `quality / format / Format (ruff)`
- `quality / typecheck / Type check`
- `quality / secrets / Secrets (trufflehog)`
- `quality / trivy / CVE scan (filesystem)`

**For Node.js repos:**
- `quality / lint / Lint (eslint)`
- `quality / format / Format (prettier)`
- `quality / typecheck / Type check`
- `quality / secrets / Secrets (trufflehog)`
- `quality / trivy / CVE scan (filesystem)`

**Shared (add if repos use these):**
- `quality / audit / Dependency audit (uv)` or `quality / audit / Dependency audit (npm)`
- `quality / commitlint / PR title (conventional commits)`

> **Important:** Status checks only appear in the search after the workflow has run at least once in a repo. Push a PR first, let CI run, then come back and add the check names.

#### Require signed commits
Optional. Skip unless your org mandates it.

#### Block force pushes
Enable — prevents rewriting history on protected branches.

#### Restrict deletions
Enable — prevents deleting protected branches.

### 4. Bypass list (who can skip the rules)

Add bypass actors for emergencies:
- Org admins (always have bypass by default)
- Optionally: a "release bot" or deploy key if you have automated releases

Keep this list minimal. The whole point is that rules apply to everyone.

### 5. Save

Click **Create**. The ruleset is now active across all targeted repos.

## Managing rulesets after creation

### Viewing active rulesets

Org Settings → Rules → Rulesets — shows all active rulesets with their status and target scope.

### Temporarily disabling

Set enforcement status to **Evaluate** (logs violations without blocking) or **Disabled**. Useful during large migrations.

### Adding a new repo

If the ruleset targets "All repositories", new repos get protection automatically. If using a pattern, ensure the new repo name matches.

### Adding new checks

When you add a new workflow job to quality-standards (e.g., a new scanner), update the ruleset to require that check too:
1. First: push a PR in at least one repo so the new check name appears
2. Then: edit the ruleset → add the new status check name

### Per-repo overrides

Org rulesets **cannot be weakened** at the repo level — that's the point. But repos can add **additional** branch protection rules on top (stricter, not looser).

If a specific repo needs an exception (e.g., skip typecheck during migration), the org admin can:
- Add the repo to the bypass list temporarily
- Create a second ruleset with different targets that excludes that repo
- Set the ruleset to "Evaluate" mode temporarily

## Common issues

### "Status check not found" when adding check names

The check must have run at least once in a repo under that org. Push a PR with the quality workflow, let it complete, then the check name becomes searchable.

### Checks pass but PR still blocked

Look for other blocking requirements:
- **Code Scanning results** — this is CodeQL / GitHub Advanced Security, separate from quality-standards. Either add a CodeQL workflow or remove this requirement from branch protection.
- **Signed commits** — if required, all commits in the PR must be GPG-signed.
- **Review approvals** — if required, someone must approve the PR.

### Workflow not running on a new repo

The repo needs a `.github/workflows/quality.yml` that calls the quality-standards reusable workflow. The org ruleset enforces that checks pass — it doesn't create the workflow. Each repo must opt in to CI by adding the workflow file.

### Mixed Python + Node repos

If your org has both Python and Node repos, the status check names differ (`Lint (ruff)` vs `Lint (eslint)`). Two options:

1. **Two rulesets** — one targeting Python repos (by name pattern), one targeting Node repos
2. **One broad ruleset** — only require the language-agnostic checks (secrets, trivy) at org level, let per-repo rules handle language-specific checks

Option 1 is cleaner if you can distinguish repos by naming convention (e.g., `py-*` vs `js-*`).

## Recommended setup for QUBERAS

```
Ruleset: "Quality — all repos"
  Target: all repositories
  Branches: default branch
  Rules:
    ✓ Require pull request (1 approval)
    ✓ Require status checks:
      - quality / secrets / Secrets (trufflehog)
      - quality / trivy / CVE scan (filesystem)
    ✓ Block force pushes
    ✓ Restrict deletions

Ruleset: "Quality — Python repos"
  Target: py-*, quality-standards
  Branches: default branch
  Rules:
    ✓ Require status checks:
      - quality / lint / Lint (ruff)
      - quality / format / Format (ruff)

Ruleset: "Quality — Node repos"
  Target: js-*, *-frontend, *-backend
  Branches: default branch
  Rules:
    ✓ Require status checks:
      - quality / lint / Lint (eslint)
      - quality / format / Format (prettier)
```

This gives you: universal security scanning, language-specific lint/format enforcement, and PRs required on all repos. Add typecheck and audit checks per-ruleset as repos adopt them.
