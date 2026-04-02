REPO_URL := https://raw.githubusercontent.com/QUBERAS/quality-standards/main

.PHONY: help quality-init quality-check quality-update quality-validate

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Targets for consuming repos ────────────────────────────────────────────

quality-init: ## Bootstrap this repo with QUBERAS quality standards
	@curl -fsSL $(REPO_URL)/install.sh | bash

quality-update: ## Update pre-commit hooks to latest versions
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found. Run: pip install pre-commit"; exit 1; }
	pre-commit autoupdate
	@echo "Updated .pre-commit-config.yaml — review changes and commit."

quality-check: ## Run all quality checks locally (same as CI)
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found. Run: pip install pre-commit"; exit 1; }
	pre-commit run --all-files

# ── Targets for this standards repo ────────────────────────────────────────

quality-validate: ## Validate that level configs are well-formed TOML
	@echo "Validating level configs..."
	@for f in configs/python/levels/*.toml configs/python/ruff.reference.toml; do \
		python3 -c "import tomllib; tomllib.load(open('$$f', 'rb'))" && \
			echo "  OK: $$f" || echo "  FAIL: $$f"; \
	done
	@echo "Validating pre-commit config..."
	@python3 -c "import yaml; yaml.safe_load(open('configs/python/.pre-commit-config.yaml'))" && \
		echo "  OK: configs/python/.pre-commit-config.yaml" || \
		echo "  FAIL: configs/python/.pre-commit-config.yaml"
	@echo "Done."
