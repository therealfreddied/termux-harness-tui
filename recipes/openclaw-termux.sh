#!/data/data/com.termux/files/usr/bin/bash
# openclaw-termux.sh — install OpenClaw latest via official installer (non-interactive)
set -euo pipefail

INSTALLER="https://openclaw.ai/install.sh"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking Node (need >=24.16 <25 or >=26.1)..."
command -v node >/dev/null 2>&1 || {
  echo "FATAL: node not found (pkg install nodejs)" >&2; exit 1; }
if ! node -e 'const [M,m]=process.versions.node.split(".").map(Number);
  process.exit(((M===24&&m>=16)||(M>=26&&(M>26||m>=1)))?0:1)'; then
  echo "FATAL: node $(node -v) too old/unsupported for OpenClaw" >&2; exit 1
fi
log "node $(node -v) OK"

if command -v openclaw >/dev/null 2>&1; then
  log "openclaw already present ($(openclaw --version 2>/dev/null | head -1)); updating..."
  openclaw update --channel stable || true
else
  log "running official installer (--no-onboard)..."
  curl -fsSL --proto '=https' --tlsv1.2 "$INSTALLER" | bash -s -- --no-onboard
fi

log "smoke test..."
command -v openclaw >/dev/null 2>&1 || {
  echo "FATAL: openclaw not on PATH after install (npm global bin dir?)" >&2; exit 1; }
V=$(timeout 60 openclaw --version </dev/null 2>&1 | head -1) || {
  echo "FATAL: openclaw failed to launch" >&2; exit 1; }
log "installed: $V ($(command -v openclaw))"
log "next: openclaw onboard  (then: openclaw gateway install)"
