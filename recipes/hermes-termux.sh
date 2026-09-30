#!/data/data/com.termux/files/usr/bin/bash
# hermes-termux.sh — install cross-compiled Hermes Agent on Termux (aarch64)
set -euo pipefail

URL="https://github.com/therealfreddied/termux-harness-tui/releases/download/hermes-0.19.0-termux/hermes-termux-aarch64.tar.gz"
EXPECTED_SHA="6a720499a8d68eb62e96b050991f1f712ecc715e47907de56a8731c7b767bc5f"
TMP_DIR="$PREFIX/tmp/opencode/hermes-install"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading hermes aarch64 bundle..."
mkdir -p "$TMP_DIR"
curl -fsSL "$URL" -o "$TMP_DIR/hermes-termux-aarch64.tar.gz"

log "verifying checksum..."
ACTUAL_SHA=$(sha256sum "$TMP_DIR/hermes-termux-aarch64.tar.gz" | cut -d' ' -f1)
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "FATAL: sha256 mismatch (expected $EXPECTED_SHA, got $ACTUAL_SHA)" >&2
  exit 1
fi

log "extracting in $HOME (needs native filesystem for execution)..."
tar -xzf "$TMP_DIR/hermes-termux-aarch64.tar.gz" -C "$HOME"

cd "$HOME/hermes-termux-aarch64"
log "running installer..."
bash ./install.sh

log "verifying installation..."
hermes --help >/dev/null 2>&1 && log "hermes installed successfully: $(command -v hermes)"
