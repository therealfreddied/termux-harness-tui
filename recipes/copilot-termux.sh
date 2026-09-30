#!/data/data/com.termux/files/usr/bin/bash
# copilot-termux.sh — install GitHub Copilot CLI launcher natively on Termux.
#
# Provides the standalone 'copilot' CLI command powered by GitHub CLI (gh copilot).
set -euo pipefail

BIN_DEST="$PREFIX/bin/copilot"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v gh >/dev/null 2>&1 || {
  log "installing gh (GitHub CLI)..."
  pkg install -y gh
}

log "creating copilot launcher at $BIN_DEST..."
rm -f "$BIN_DEST"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
# copilot — GitHub Copilot CLI launcher on Termux
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec gh copilot "$@"
EOF
chmod 755 "$BIN_DEST"

log "verifying..."
command -v copilot >/dev/null 2>&1 || { echo "FATAL: copilot not on PATH" >&2; exit 1; }
copilot --help >/dev/null
log "copilot installed successfully -> $BIN_DEST"
