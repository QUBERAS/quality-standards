REPO_URL := https://raw.githubusercontent.com/QUBERAS/quality-standards/main
RUFF := ruff

.PHONY: help quality-init quality-check quality-update quality-validate \
        lint-minimal lint-standard lint-strict lint format format-check

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Bootstrap & maintenance ────────────────────────────────────────────────

quality-init: ## Bootstrap this repo with QUBERAS quality standards
	@curl -fsSL $(REPO_URL)/install.sh | bash

quality-update: ## Update pre-commit hooks to latest versions
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found. Run: pip install pre-commit"; exit 1; }
	pre-commit autoupdate
	@echo "Updated .pre-commit-config.yaml — review changes and commit."

quality-check: ## Run all pre-commit hooks on all files
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found. Run: pip install pre-commit"; exit 1; }
	pre-commit run --all-files

# ── Python lint by level ───────────────────────────────────────────────────

lint-minimal: ## Ruff lint at minimal level (F, E)
	$(RUFF) check --config configs/python/levels/minimal.toml .

lint-standard: ## Ruff lint at standard level (F, E, W, B, S, I, UP)
	$(RUFF) check --config configs/python/levels/standard.toml .

lint-strict: ## Ruff lint at strict level (full suite)
	$(RUFF) check --config configs/python/levels/strict.toml .

lint: lint-standard ## Ruff lint at default level (standard)

# ── Python format ──────────────────────────────────────────────────────────

format: ## Ruff format (auto-fix)
	$(RUFF) format .

format-check: ## Ruff format check (no changes, CI mode)
	$(RUFF) format --check .

# ── Validation for this standards repo ─────────────────────────────────────

quality-validate: ## Validate all configs, workflows, and action pins
	@python3 scripts/validate.py
