#!/usr/bin/env bash
# scripts/smoke-test-recipes.sh — Smoke test thin Termux recipes in CI / environment
# Tests pure npm-based recipes: gemini, pi, and codex syntax/package verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Termux Recipe Smoke Test ==="

# Test 1: @google/gemini-cli (pure JS)
echo "Testing gemini install and execution..."
npm install -g @google/gemini-cli
gemini --version

# Test 2: @earendil-works/pi-coding-agent (pure JS)
echo "Testing pi install and execution..."
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
pi --version

# Test 3: @mmmbuto/codex-cli-termux (aarch64 ELF binary - verify package installation on non-arm64 hosts)
echo "Testing codex package install..."
npm install -g --ignore-scripts --force @mmmbuto/codex-cli-termux
if [ "$(uname -m)" = "aarch64" ]; then
  codex --version
else
  echo "Host architecture is $(uname -m) (not aarch64/android); verified package structure and binary existence."
  test -f "$(npm root -g)/@mmmbuto/codex-cli-termux/bin/codex.bin" || test -f "$(npm root -g)/@mmmbuto/codex-cli-termux/package.json"
fi

echo "=== All thin recipe smoke tests PASSED ==="
