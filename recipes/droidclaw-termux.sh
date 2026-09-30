#!/data/data/com.termux/files/usr/bin/bash
# droidclaw-termux.sh — install DroidClaw / Kira natively on Termux.
set -euo pipefail

REPO="https://github.com/levilyf/droidclaw.git"
OPT_DIR="$PREFIX/opt/droidclaw"
BIN_DEST="$PREFIX/bin/kira"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "FATAL: nodejs is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "FATAL: git is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "FATAL: npm is required" >&2; exit 1; }

log "syncing droidclaw repository..."
if [ -d "$OPT_DIR/.git" ]; then
  cd "$OPT_DIR"
  git pull -q origin main 2>/dev/null || true
else
  mkdir -p "$PREFIX/opt"
  git clone -q "$REPO" "$OPT_DIR"
fi

cd "$OPT_DIR"
log "installing dependencies..."
npm install -q --no-audit --no-fund 2>/dev/null || true

if command -v termux-fix-shebang >/dev/null 2>&1; then
  log "fixing shebangs..."
  termux-fix-shebang "$OPT_DIR/bin/"* 2>/dev/null || true
fi

# Ensure $HOME/droidclaw symlink exists for upstream path resolution
if [ ! -e "$HOME/droidclaw" ]; then
  ln -sf "$OPT_DIR" "$HOME/droidclaw"
fi

log "creating launcher wrapper ($BIN_DEST)..."
rm -f "$BIN_DEST" "$PREFIX/bin/droidclaw"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec node "$PREFIX/opt/droidclaw/bin/kira" "$@"
EOF
chmod 755 "$BIN_DEST"
ln -sf "$BIN_DEST" "$PREFIX/bin/droidclaw"

log "verifying..."
command -v kira >/dev/null 2>&1 || { echo "FATAL: kira not on PATH" >&2; exit 1; }
kira --help >/dev/null
log "droidclaw (kira) installed successfully -> $BIN_DEST (alias: droidclaw)"
