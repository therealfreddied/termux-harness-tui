#!/data/data/com.termux/files/usr/bin/bash
# command-code-termux.sh — install Command Code CLI natively on Termux (Node.js runtime).
#
# Installs into $PREFIX/opt/command-code to isolate dependencies and avoids
# colliding with Termux's native $PREFIX/bin/cmd wrapper.
set -euo pipefail

PKG="command-code"
OPT_DIR="$PREFIX/opt/command-code"
BIN_DEST="$PREFIX/bin/command-code"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "FATAL: nodejs is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "FATAL: npm is required" >&2; exit 1; }

log "installing $PKG into $OPT_DIR..."
mkdir -p "$OPT_DIR"
npm install --no-audit --no-fund --omit=dev -g --prefix "$OPT_DIR" "$PKG"

PKGDIR="$OPT_DIR/lib/node_modules/command-code"
if command -v termux-fix-shebang >/dev/null 2>&1 && [ -d "$PKGDIR/dist" ]; then
  log "fixing shebangs..."
  termux-fix-shebang "$PKGDIR/dist/"* 2>/dev/null || true
fi

log "creating launcher wrappers (command-code, commandcode, cmdc)..."
rm -f "$BIN_DEST" "$PREFIX/bin/commandcode" "$PREFIX/bin/cmdc"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec node "$PREFIX/opt/command-code/lib/node_modules/command-code/dist/index.mjs" "$@"
EOF
chmod 755 "$BIN_DEST"
ln -sf "$BIN_DEST" "$PREFIX/bin/commandcode"
ln -sf "$BIN_DEST" "$PREFIX/bin/cmdc"

log "verifying..."
command -v command-code >/dev/null 2>&1 || { echo "FATAL: command-code not on PATH" >&2; exit 1; }
command-code --help >/dev/null
log "command-code installed successfully -> $BIN_DEST (aliases: cmdc, commandcode)"
