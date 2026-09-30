#!/data/data/com.termux/files/usr/bin/bash
# claude-termux.sh — install official Claude Code via musl loader (Aarstad/claude-code-termux-musl).
#
# Runs Anthropic's official linux-arm64-musl build natively on Bionic with a 723KB
# Alpine musl loader (no 449MB glibc-runner required).
# Preserves /proc/self/exe integrity for sub-process tools, and routes network DNS
# through a lightweight single-threaded C proxy (termux-http-proxy).
#
# Update path: claude-musl-update
set -euo pipefail
log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

TMP_DIR="$PREFIX/tmp/opencode/claude-musl-install"
mkdir -p "$TMP_DIR"

log "fetching Aarstad/claude-code-termux-musl installer..."
if [ -d "$TMP_DIR/repo/.git" ]; then
  git -C "$TMP_DIR/repo" pull --ff-only
else
  rm -rf "$TMP_DIR/repo"
  git clone --depth 1 https://github.com/Aarstad/claude-code-termux-musl.git "$TMP_DIR/repo"
fi

log "running musl installer (promotes to $PREFIX/bin/claude)..."
cd "$TMP_DIR/repo"
bash ./install.sh --promote

log "verifying..."
command -v claude >/dev/null 2>&1 || { echo "FATAL: claude not on PATH after install" >&2; exit 1; }
claude --version
