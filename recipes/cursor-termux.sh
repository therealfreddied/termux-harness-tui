#!/data/data/com.termux/files/usr/bin/bash
# cursor-termux.sh — install official Cursor CLI agent natively on Termux via glibc loader wrapper.
set -euo pipefail

OPT_DIR="$PREFIX/opt/cursor"
BIN_DEST="$PREFIX/bin/cursor"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LIB_PATH="$PREFIX/glibc/lib:$PREFIX/lib"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v curl >/dev/null 2>&1 || { echo "FATAL: curl is required" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "FATAL: tar is required" >&2; exit 1; }

if [ ! -f "$LOADER" ]; then
  echo "FATAL: glibc loader missing at $LOADER (pkg install glibc-repo && pkg install glibc)" >&2
  exit 1
fi

log "resolving latest Cursor agent release URL..."
INSTALLER_SCRIPT="$(curl -fsSL https://cursor.com/install 2>/dev/null || true)"
DOWNLOAD_URL="$(printf '%s' "$INSTALLER_SCRIPT" | sed -n 's/.*DOWNLOAD_URL="\(https:[^"]*linux\/arm64[^"]*\)".*/\1/p' | head -1)"

if [ -z "$DOWNLOAD_URL" ]; then
  DOWNLOAD_URL="https://downloads.cursor.com/lab/2026.09.28-64d2043/linux/arm64/agent-cli-package.tar.gz"
fi
log "download URL: $DOWNLOAD_URL"

log "downloading and extracting Cursor agent to $OPT_DIR..."
mkdir -p "$OPT_DIR"
curl -fSL "$DOWNLOAD_URL" | tar -xzf - -C "$OPT_DIR" --strip-components=1

log "creating cursor launcher wrapper ($BIN_DEST)..."
rm -f "$BIN_DEST" "$PREFIX/bin/cursor-agent"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" \
  --library-path "$PREFIX/glibc/lib:$PREFIX/lib" \
  "$PREFIX/opt/cursor/node" "$PREFIX/opt/cursor/index.js" "$@"
EOF
chmod 755 "$BIN_DEST"
ln -sf "$BIN_DEST" "$PREFIX/bin/cursor-agent"

log "verifying..."
command -v cursor >/dev/null 2>&1 || { echo "FATAL: cursor not on PATH" >&2; exit 1; }
cursor -v
log "cursor installed successfully -> $BIN_DEST (alias: cursor-agent)"
