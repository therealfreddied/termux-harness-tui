#!/data/data/com.termux/files/usr/bin/bash
# microclaw-termux.sh — install MicroClaw latest (glibc ELF via loader wrapper)
set -euo pipefail

REPO="microclaw/microclaw"
TMP_DIR="$PREFIX/tmp/opencode/microclaw-install"
LIB_DIR="$PREFIX/lib/microclaw"
GLIBC_LD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

[ -x "$GLIBC_LD" ] || {
  echo "FATAL: glibc loader missing at $GLIBC_LD (glibc-repo not installed)" >&2; exit 1; }

log "resolving latest release tag..."
TAG=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  "https://github.com/$REPO/releases/latest" | sed 's#.*/##')
case "$TAG" in
  v[0-9]*) ;;
  *) echo "FATAL: could not resolve latest tag (got: $TAG)" >&2; exit 1 ;;
esac
VER=${TAG#v}
log "latest: $TAG"

ASSET="microclaw-$VER-aarch64-linux-gnu.tar.gz"
mkdir -p "$TMP_DIR"
log "downloading $ASSET + SHA256SUMS.txt..."
curl -fsSL "https://github.com/$REPO/releases/download/$TAG/$ASSET" -o "$TMP_DIR/$ASSET"
curl -fsSL "https://github.com/$REPO/releases/download/$TAG/SHA256SUMS.txt" \
  -o "$TMP_DIR/SHA256SUMS.txt"

log "verifying checksum..."
(cd "$TMP_DIR" && grep "  $ASSET" SHA256SUMS.txt | sha256sum -c -) || {
  echo "FATAL: sha256 mismatch for $ASSET" >&2; exit 1; }

log "extracting to $LIB_DIR..."
mkdir -p "$LIB_DIR"
tar -xzf "$TMP_DIR/$ASSET" -C "$LIB_DIR"
chmod +x "$LIB_DIR/microclaw"

log "installing glibc loader wrapper..."
cat > "$PREFIX/bin/microclaw" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# MicroClaw is a glibc ELF: exec it through the Termux glibc loader.
exec "$GLIBC_LD" --library-path "$PREFIX/glibc/lib:$PREFIX/lib" \\
  "$LIB_DIR/microclaw" "\$@"
EOF
chmod 755 "$PREFIX/bin/microclaw"

log "smoke test..."
V=$(timeout 20 microclaw --version </dev/null 2>&1 | head -1) || {
  echo "FATAL: microclaw failed to launch via loader" >&2; exit 1; }
case "$V" in
  microclaw\ 0.*) log "installed: $V ($(command -v microclaw))" ;;
  *) echo "FATAL: unexpected output: $V" >&2; exit 1 ;;
esac

rm -f "$TMP_DIR/$ASSET" "$TMP_DIR/SHA256SUMS.txt"
