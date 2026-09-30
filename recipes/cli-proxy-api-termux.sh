#!/data/data/com.termux/files/usr/bin/bash
# cli-proxy-api-termux.sh — install CLIProxyAPI (native Termux aarch64 Go binary)
set -euo pipefail

URL="https://github.com/therealfreddied/termux-harness-tui/releases/download/cli-proxy-api-8.0.4-termux/cli-proxy-api-8.0.4-termux-aarch64.tar.gz"
EXPECTED_SHA="0782653b54e4a83adbe1480e49d6ad980a0d396fb0400caf06b51aab9a8ba187"
TMP_DIR="$PREFIX/tmp/opencode/cliproxyapi-install"
DEST_DIR="$PREFIX/lib/cliproxyapi"
BIN_LINK="$PREFIX/bin/cli-proxy-api"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading cli-proxy-api aarch64 bundle..."
mkdir -p "$TMP_DIR"
curl -fsSL "$URL" -o "$TMP_DIR/cli-proxy-api-8.0.4-termux-aarch64.tar.gz"

log "verifying checksum..."
ACTUAL_SHA=$(sha256sum "$TMP_DIR/cli-proxy-api-8.0.4-termux-aarch64.tar.gz" | cut -d' ' -f1)
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "FATAL: sha256 mismatch (expected $EXPECTED_SHA, got $ACTUAL_SHA)" >&2
  exit 1
fi

log "extracting to $DEST_DIR..."
mkdir -p "$DEST_DIR"
tar -xzf "$TMP_DIR/cli-proxy-api-8.0.4-termux-aarch64.tar.gz" -C "$DEST_DIR"
chmod 755 "$DEST_DIR/cli-proxy-api"

log "creating launcher link -> $BIN_LINK..."
ln -sf "$DEST_DIR/cli-proxy-api" "$BIN_LINK"

log "verifying installation..."
command -v cli-proxy-api >/dev/null 2>&1 || { echo "FATAL: cli-proxy-api not on PATH" >&2; exit 1; }
cli-proxy-api -v 2>&1 | grep -q "CLIProxyAPI Version" && log "cli-proxy-api installed successfully: $(command -v cli-proxy-api)"
