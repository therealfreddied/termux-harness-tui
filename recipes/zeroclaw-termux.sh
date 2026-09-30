#!/data/data/com.termux/files/usr/bin/bash
# zeroclaw-termux.sh — install ZeroClaw latest (official aarch64-Android build, zero patch)
set -euo pipefail

BASE="https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download"
ASSET="zeroclaw-aarch64-linux-android.tar.gz"
TMP_DIR="$PREFIX/tmp/opencode/zeroclaw-install"
LIB_DIR="$PREFIX/lib/zeroclaw"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading $ASSET (latest channel)..."
mkdir -p "$TMP_DIR"
curl -fsSL "$BASE/$ASSET" -o "$TMP_DIR/$ASSET"
curl -fsSL "$BASE/SHA256SUMS" -o "$TMP_DIR/SHA256SUMS"

log "verifying checksum..."
(cd "$TMP_DIR" && grep "  $ASSET" SHA256SUMS | sha256sum -c -) || {
  echo "FATAL: sha256 mismatch for $ASSET" >&2; exit 1; }

log "extracting to $LIB_DIR (binary + web/dist dashboard)..."
mkdir -p "$LIB_DIR"
tar -xzf "$TMP_DIR/$ASSET" -C "$LIB_DIR"
chmod +x "$LIB_DIR/zeroclaw"

log "installing launcher (wrapper keeps web/dist resolvable)..."
cat > "$PREFIX/bin/zeroclaw" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec "$LIB_DIR/zeroclaw" "\$@"
EOF
chmod 755 "$PREFIX/bin/zeroclaw"

log "smoke test..."
V=$(timeout 20 zeroclaw --version </dev/null 2>&1 | head -1) || {
  echo "FATAL: zeroclaw failed to launch" >&2; exit 1; }
case "$V" in
  zeroclaw\ *) log "installed: $V ($(command -v zeroclaw))" ;;
  *) echo "FATAL: unexpected output: $V" >&2; exit 1 ;;
esac

rm -f "$TMP_DIR/$ASSET" "$TMP_DIR/SHA256SUMS"
