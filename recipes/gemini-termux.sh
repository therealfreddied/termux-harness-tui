#!/data/data/com.termux/files/usr/bin/bash
# gemini-termux.sh — install Google Gemini CLI (pure-JS npm, no native modules).
# Only Termux quirk: npm's bin stubs keep #!/usr/bin/env, which Bionic lacks;
# termux-fix-shebang rewrites them. Update = npm update -g + re-fix.
set -euo pipefail
PKG="@google/gemini-cli"
log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "installing $PKG (npm global)..."
npm install --no-audit --no-fund --omit=dev -g "$PKG"

BIN="$PREFIX/bin/gemini"
if command -v termux-fix-shebang >/dev/null 2>&1 && [ -e "$BIN" ]; then
  termux-fix-shebang "$BIN"
fi

log "verifying..."
command -v gemini >/dev/null 2>&1 || { echo "FATAL: gemini not on PATH after install" >&2; exit 1; }
gemini --version
