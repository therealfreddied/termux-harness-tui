#!/usr/bin/env bash
# scripts/smoke-test-recipes.sh — Smoke test thin Termux recipes in CI / environment
# Tests pure npm-based recipes: gemini, pi, codex (with --force for platform overrides in testing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Termux Recipe Smoke Test ==="

# Test 1: @google/gemini-cli
echo "Testing gemini install and execution..."
npm install -g @google/gemini-cli
gemini --version || npx @google/gemini-cli --version

# Test 2: @earendil-works/pi-coding-agent
echo "Testing pi install and execution..."
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
pi --version || npx @earendil-works/pi-coding-agent --version

# Test 3: @mmmbuto/codex-cli-termux (requires --force when smoke testing outside Android)
echo "Testing codex install and execution..."
npm install -g --ignore-scripts --force @mmmbuto/codex-cli-termux
codex --version || npx --force @mmmbuto/codex-cli-termux --version

echo "=== All thin recipe smoke tests PASSED ==="
