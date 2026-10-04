#!/data/data/com.termux/files/usr/bin/bash
# codex-termux.sh — install Codex CLI via the community Termux npm build.
# OpenAI ships no android-arm64 binary; @mmmbuto/codex-cli-termux republishes
# upstream releases on npm as "X.Y.Z-termux.N". Update = re-run this recipe.
set -euo pipefail
PKG="@mmmbuto/codex-cli-termux"
log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "installing $PKG (npm global)..."
npm install --no-audit --no-fund --omit=dev -g "$PKG"

PKGDIR="$PREFIX/lib/node_modules/@mmmbuto/codex-cli-termux"
if command -v termux-fix-shebang >/dev/null 2>&1 && [ -d "$PKGDIR/bin" ]; then
  termux-fix-shebang "$PKGDIR/bin/"* 2>/dev/null || true
fi

log "verifying..."
command -v codex >/dev/null 2>&1 || { echo "FATAL: codex not on PATH after install" >&2; exit 1; }
codex --version
