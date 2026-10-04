#!/data/data/com.termux/files/usr/bin/bash
# clideck-termux.sh — install CLIdeck web dashboard for coding harnesses on Termux.
set -euo pipefail

PKG="clideck"
OPT_DIR="$PREFIX/opt/clideck"
BIN_DEST="$PREFIX/bin/clideck"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "FATAL: nodejs is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "FATAL: npm is required" >&2; exit 1; }

log "installing $PKG into $OPT_DIR..."
mkdir -p "$OPT_DIR"
npm install --no-audit --no-fund --omit=dev -g --prefix "$OPT_DIR" "$PKG"

PKGDIR="$OPT_DIR/lib/node_modules/clideck"
if command -v termux-fix-shebang >/dev/null 2>&1 && [ -d "$PKGDIR/bin" ]; then
  log "fixing shebangs..."
  termux-fix-shebang "$PKGDIR/bin/"* 2>/dev/null || true
fi

log "creating launcher wrapper ($BIN_DEST)..."
rm -f "$BIN_DEST"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec node "$PREFIX/opt/clideck/lib/node_modules/clideck/bin/clideck.js" "$@"
EOF
chmod 755 "$BIN_DEST"

log "verifying..."
command -v clideck >/dev/null 2>&1 || { echo "FATAL: clideck not on PATH" >&2; exit 1; }
clideck --help >/dev/null
log "clideck installed successfully -> $BIN_DEST (launch with 'clideck' to open web dashboard)"
