#!/data/data/com.termux/files/usr/bin/bash
# 9router-termux.sh — install 9router (pure-JS Node.js router) on Termux
set -euo pipefail

PKG="9router"
VERSION="0.5.91"
DEST_DIR="$PREFIX/lib/9router"
BIN="$PREFIX/bin/9router"
TMP_DIR="$PREFIX/tmp/opencode/9router-install"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading 9router@$VERSION npm tarball..."
mkdir -p "$TMP_DIR"
curl -fsSL "https://registry.npmjs.org/9router/-/9router-${VERSION}.tgz" -o "$TMP_DIR/9router.tgz"

log "extracting to $DEST_DIR..."
mkdir -p "$DEST_DIR"
tar -xzf "$TMP_DIR/9router.tgz" --strip-components=1 -C "$DEST_DIR"

log "creating launcher -> $BIN (port 20129 to avoid OmniRoute collision)..."
cat > "$BIN" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec node /data/data/com.termux/files/usr/lib/9router/cli.js --port 20129 --no-browser --skip-update "$@"
EOF
chmod 755 "$BIN"

log "verifying installation..."
command -v 9router >/dev/null 2>&1 || { echo "FATAL: 9router not on PATH" >&2; exit 1; }
9router --version && log "9router installed successfully: $(command -v 9router)"
