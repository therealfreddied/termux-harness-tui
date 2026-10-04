#!/data/data/com.termux/files/usr/bin/bash
# qwen-termux.sh — install Alibaba Qwen Code CLI natively on Termux (Node.js runtime).
set -euo pipefail

PKG="@qwen-code/qwen-code"
OPT_DIR="$PREFIX/opt/qwen"
BIN_DEST="$PREFIX/bin/qwen"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v node >/dev/null 2>&1 || { echo "FATAL: nodejs is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "FATAL: npm is required" >&2; exit 1; }

log "installing $PKG into $OPT_DIR..."
mkdir -p "$OPT_DIR"
npm install --no-audit --no-fund --omit=dev -g --prefix "$OPT_DIR" "$PKG"

PKGDIR="$OPT_DIR/lib/node_modules/@qwen-code/qwen-code"
if command -v termux-fix-shebang >/dev/null 2>&1; then
  log "fixing shebangs..."
  termux-fix-shebang "$PKGDIR"/cli-entry.js "$PKGDIR"/dist/* 2>/dev/null || true
fi

log "creating launcher wrapper ($BIN_DEST)..."
rm -f "$BIN_DEST" "$PREFIX/bin/qwen-code"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec node "$PREFIX/opt/qwen/lib/node_modules/@qwen-code/qwen-code/cli-entry.js" "$@"
EOF
chmod 755 "$BIN_DEST"
ln -sf "$BIN_DEST" "$PREFIX/bin/qwen-code"

log "verifying..."
command -v qwen >/dev/null 2>&1 || { echo "FATAL: qwen not on PATH" >&2; exit 1; }
qwen --help >/dev/null
log "qwen installed successfully -> $BIN_DEST (alias: qwen-code)"
