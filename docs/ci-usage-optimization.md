# CI usage optimization

Investigation into GitHub Actions billing and whether merging workflows would reduce costs.

## Current structure

`python.yml` composes 9 parallel runner VMs per quality run (all options enabled):

| Job | Workflow called | Always runs | Installs |
|-----|----------------|-------------|----------|
| format | python-format.yml | yes | python, ruff |
| lint | python-lint.yml | yes | python, ruff |
| complexity | python-lint.yml | yes | python, ruff |
| secrets | secrets.yml | yes | trufflehog |
| trivy (fs) | trivy.yml | yes | trivy |
| trivy (docker) | trivy.yml | yes (conditional skip) | trivy |
| audit | python-audit.yml | if audit: true (default) | uv |
| commitlint | commitlint.yml | if commitlint: true (PR only) | node, commitlint |
| typecheck | python-typecheck.yml | yes (ty check default, pass "" to skip) | uv, python, ty |

Each job independently boots a runner, checks out the repo, and installs its tools — ~40-60s setup overhead per job.

## GitHub Actions billing (private repos)

| Plan | Free minutes/month | Overage |
|------|-------------------|---------|
| Free | 2,000 | $0.008/min |
| Pro | 3,000 | $0.008/min |
| Team | 3,000 | $0.008/min |
| Enterprise | 50,000 | $0.008/min |

Public repos are free and unlimited. This repo (quality-standards) is public, so only consuming private repos accumulate minutes.

As of 2026-04, observed usage is ~80 minutes/month across consuming repos.

## Tradeoffs: parallel vs merged

| | Parallel (current) | Merged |
|---|---|---|
| Wall-clock time | ~1-2 min (all parallel) | ~3-5 min (sequential) |
| Billable minutes | ~9-12 min (9 jobs x avg) | ~4-5 min (1-2 jobs) |
| PR feedback | Each check reports separately | One pass/fail blob |
| Failure isolation | See exactly which check failed | Dig through logs |

## Recommended optimization

Merge format + lint + complexity into a single job — they all install python + ruff identically. Run sequentially in one runner:

1. `ruff format --check`
2. `ruff check` (level config)
3. `ruff check --select C90` (continue-on-error)

This cuts 3 runners to 1 (9 → 7 total), saving ~2 minutes of duplicated setup per run with no loss in failure visibility (each step still reports separately within the job).

Keep everything else separate — secrets, trivy, audit, commitlint, and typecheck use different tools and have different conditional logic. Merging them would complicate the workflows for minimal savings.

## Decision

Not yet implemented. Revisit if usage grows significantly or more repos onboard.
