#!/data/data/com.termux/files/usr/bin/bash
# pi-termux.sh — install the Pi coding agent, per pi.dev's official Termux
# docs: npm install -g --ignore-scripts @earendil-works/pi-coding-agent.
# No native modules; only quirk is npm's #!/usr/bin/env bin stubs.
set -euo pipefail
PKG="@earendil-works/pi-coding-agent"
log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "installing $PKG (npm global, --ignore-scripts per upstream docs)..."
npm install -g --ignore-scripts "$PKG"

BIN="$PREFIX/bin/pi"
if command -v termux-fix-shebang >/dev/null 2>&1 && [ -e "$BIN" ]; then
  termux-fix-shebang "$BIN"
fi

log "verifying..."
command -v pi >/dev/null 2>&1 || { echo "FATAL: pi not on PATH after install" >&2; exit 1; }
pi --version
