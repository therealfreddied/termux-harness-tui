#!/data/data/com.termux/files/usr/bin/bash
# rho-termux.sh — install Rho persistent AI operator natively on Termux (Node.js runtime).
set -euo pipefail

PKG="@rhobot-dev/rho"
OPT_DIR="$PREFIX/opt/rho"
BIN_DEST="$PREFIX/bin/rho"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "FATAL: nodejs is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "FATAL: npm is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "FATAL: curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

log "resolving latest $PKG..."
META="$(curl -fsSL "https://registry.npmjs.org/${PKG//\//%2f}/latest")"
VERSION="$(printf '%s' "$META" | jq -r '.version')"
TARBALL="$(printf '%s' "$META" | jq -r '.dist.tarball')"
log "found version $VERSION ($TARBALL)"

log "extracting to $OPT_DIR..."
mkdir -p "$OPT_DIR"
curl -fsSL "$TARBALL" | tar -xzf - -C "$OPT_DIR" --strip-components=1

log "installing npm dependencies..."
npm install --no-audit --no-fund --omit=dev -g --prefix "$OPT_DIR" "$PKG"

# Ensure top-level node_modules is symlinked for tsx resolution
if [ -d "$OPT_DIR/lib/node_modules/@rhobot-dev/rho/node_modules" ] && [ ! -e "$OPT_DIR/node_modules" ]; then
  ln -sf "$OPT_DIR/lib/node_modules/@rhobot-dev/rho/node_modules" "$OPT_DIR/node_modules"
fi

if command -v termux-fix-shebang >/dev/null 2>&1; then
  log "fixing shebangs..."
  termux-fix-shebang "$OPT_DIR/cli/"* 2>/dev/null || true
fi

log "creating launcher wrapper ($BIN_DEST)..."
rm -f "$BIN_DEST"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec node "$PREFIX/opt/rho/cli/rho.mjs" "$@"
EOF
chmod 755 "$BIN_DEST"

log "verifying..."
command -v rho >/dev/null 2>&1 || { echo "FATAL: rho not on PATH" >&2; exit 1; }
rho --help >/dev/null
log "rho installed successfully ($VERSION) -> $BIN_DEST"
