#!/data/data/com.termux/files/usr/bin/bash
# claude-termux.sh — install Claude Code via gtbuchanan/claude-code-termux.
# Anthropic publishes no android-arm64 binary (gh issue #72620), so this
# launcher enables the glibc package repo, downloads Anthropic's official
# linux-arm64 build and ELF-patches it for the glibc loader. Accepted route:
# stable and fast on this device (claude 2.1.285 verified 2026-09-30).
# Update path: the launcher self-manages versions in ~/.local/share/claude.
set -euo pipefail
log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "running gtbuchanan/claude-code-termux installer..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gtbuchanan/claude-code-termux/main/install.sh)"

log "verifying..."
command -v claude >/dev/null 2>&1 || { echo "FATAL: claude not on PATH after install" >&2; exit 1; }
claude --version
