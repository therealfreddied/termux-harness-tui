#!/data/data/com.termux/files/usr/bin/bash
# vibe-termux.sh — install Mistral Vibe CLI natively on Termux (Python runtime).
set -euo pipefail

PKG="mistral-vibe"
BIN_DEST="$PREFIX/bin/vibe"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python is required" >&2; exit 1; }
command -v pip >/dev/null 2>&1 || { echo "FATAL: pip is required" >&2; exit 1; }

log "installing $PKG via pip..."
pip install --upgrade "$PKG"

if command -v termux-fix-shebang >/dev/null 2>&1 && [ -f "$BIN_DEST" ]; then
  log "fixing shebang..."
  termux-fix-shebang "$BIN_DEST" 2>/dev/null || true
fi

log "verifying..."
command -v vibe >/dev/null 2>&1 || { echo "FATAL: vibe not on PATH" >&2; exit 1; }
vibe --help >/dev/null
log "vibe installed successfully -> $BIN_DEST"
