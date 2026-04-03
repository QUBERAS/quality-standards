#!/usr/bin/env bash
# Bootstrap a repo for QUBERAS quality standards.
#
# Usage (from your repo root):
#   curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/install.sh | bash
#   # or:
#   bash <(curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/install.sh)
#
# What it does:
#   1. Detects language (Python for now)
#   2. Copies pre-commit config
#   3. Copies commitlint config
#   4. Writes a starter CI workflow
#   5. Installs pre-commit hooks
#
# Safe to re-run — prompts before overwriting existing files.

set -euo pipefail

REPO="https://raw.githubusercontent.com/QUBERAS/quality-standards/main"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${BLUE}[quality]${NC} $1"; }
ok()    { echo -e "${GREEN}[quality]${NC} $1"; }
warn()  { echo -e "${YELLOW}[quality]${NC} $1"; }

confirm_overwrite() {
  local file="$1"
  if [ -f "$file" ]; then
    read -rp "[quality] $file already exists. Overwrite? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 1
  fi
  return 0
}

# ── Detect language ────────────────────────────────────────────────────────
detect_language() {
  if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    echo "python"
  elif [ -f "go.mod" ]; then
    echo "go"
  elif [ -f "package.json" ]; then
    echo "node"
  else
    echo "unknown"
  fi
}

LANG=$(detect_language)
info "Detected language: $LANG"

if [ "$LANG" != "python" ]; then
  warn "Only Python is supported right now. Configs will be Python-flavored."
  warn "Adjust manually for other languages."
fi

# ── Pre-commit config ──────────────────────────────────────────────────────
if confirm_overwrite ".pre-commit-config.yaml"; then
  info "Downloading .pre-commit-config.yaml..."
  curl -fsSL "$REPO/configs/python/.pre-commit-config.yaml" -o .pre-commit-config.yaml
  ok "Wrote .pre-commit-config.yaml"
fi

# ── Commitlint config ─────────────────────────────────────────────────────
if confirm_overwrite "commitlint.config.js"; then
  info "Downloading commitlint.config.js..."
  curl -fsSL "$REPO/configs/common/commitlint.config.js" -o commitlint.config.js
  ok "Wrote commitlint.config.js"
fi

# ── Claude Code config ─────────────────────────────────────────────────────
if confirm_overwrite "CLAUDE.md"; then
  info "Downloading CLAUDE.md..."
  curl -fsSL "$REPO/configs/claude/CLAUDE.md" -o CLAUDE.md
  ok "Wrote CLAUDE.md"
fi

CLAUDE_DIR=".claude"
mkdir -p "$CLAUDE_DIR"

if confirm_overwrite "$CLAUDE_DIR/settings.local.json"; then
  info "Downloading .claude/settings.local.json..."
  curl -fsSL "$REPO/configs/claude/settings.local.json" -o "$CLAUDE_DIR/settings.local.json"
  ok "Wrote $CLAUDE_DIR/settings.local.json"
fi

# ── CI workflow stub ───────────────────────────────────────────────────────
WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/quality.yml"

mkdir -p "$WORKFLOW_DIR"

if confirm_overwrite "$WORKFLOW_FILE"; then
  info "Writing CI workflow..."
  cat > "$WORKFLOW_FILE" << 'YAML'
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
      # audit: true                              # requires uv.lock in repo
      # typecheck-cmd: "ty check"               # uncomment for type checking
    secrets: inherit
YAML
  ok "Wrote $WORKFLOW_FILE"
fi

# ── Install pre-commit hooks ──────────────────────────────────────────────
if command -v pre-commit &>/dev/null; then
  info "Installing pre-commit hooks..."
  pre-commit install
  ok "Pre-commit hooks installed"
else
  warn "pre-commit not found. Install it first:"
  warn "  pip install pre-commit"
  warn "Then run:"
  warn "  pre-commit install"
fi

echo ""
ok "Done! Your repo is set up for QUBERAS quality standards."
echo ""
info "Next steps:"
info "  1. Review .github/workflows/quality.yml — adjust level and options"
info "  2. Copy ruff rules into your pyproject.toml (optional, for IDE support):"
info "     curl -fsSL $REPO/configs/python/ruff.reference.toml"
info "  3. Commit the new config files"
echo ""
info "Escape hatches for local dev:"
info "  SKIP=ruff,trufflehog git commit -m 'wip: something'"
info "  git commit --no-verify  # skip ALL hooks"
