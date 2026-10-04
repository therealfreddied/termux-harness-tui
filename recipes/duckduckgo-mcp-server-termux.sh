#!/data/data/com.termux/files/usr/bin/bash
# duckduckgo-mcp-server-termux.sh — install DuckDuckGo MCP Server natively on Termux.
# Integrates with curl_cffi for TLS-fingerprint-based scraping when available.
set -euo pipefail

PKG="duckduckgo-mcp-server"
BIN_DEST="$PREFIX/bin/duckduckgo-mcp-server"
HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python is required (run: pkg install python)" >&2; exit 1; }
command -v pip >/dev/null 2>&1 || { echo "FATAL: pip is required" >&2; exit 1; }

# Check if curl_cffi is available for the browser extra
if python3 -c "import curl_cffi" >/dev/null 2>&1; then
  log "curl_cffi detected — installing duckduckgo-mcp-server with [browser] backend..."
  pip install --no-audit --no-fund --upgrade "duckduckgo-mcp-server[browser]"
else
  log "curl_cffi not yet installed."
  if [ -f "$HUB_DIR/recipes/curl-cffi-termux.sh" ]; then
    log "triggering curl-cffi recipe first for TLS fingerprint impersonation..."
    bash "$HUB_DIR/recipes/curl-cffi-termux.sh" || {
      log "curl_cffi build skipped or failed; installing standard duckduckgo-mcp-server..."
    }
  fi
  pip install --no-audit --no-fund --upgrade duckduckgo-mcp-server
fi

if command -v termux-fix-shebang >/dev/null 2>&1 && [ -f "$BIN_DEST" ]; then
  log "fixing shebang..."
  termux-fix-shebang "$BIN_DEST" 2>/dev/null || true
fi

log "verifying..."
command -v duckduckgo-mcp-server >/dev/null 2>&1 || { echo "FATAL: duckduckgo-mcp-server not found on PATH" >&2; exit 1; }
duckduckgo-mcp-server --help >/dev/null
log "duckduckgo-mcp-server installed successfully -> $BIN_DEST (run: duckduckgo-mcp-server --help)"
