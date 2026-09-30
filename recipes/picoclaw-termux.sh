#!/data/data/com.termux/files/usr/bin/bash
# picoclaw-termux.sh — install PicoClaw latest (static Go arm64 build, checksummed, zero patch)
set -euo pipefail

REPO="sipeed/picoclaw"
ASSET="picoclaw_Linux_arm64.tar.gz"
TMP_DIR="$PREFIX/tmp/opencode/picoclaw-install"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "resolving latest release tag..."
TAG=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  "https://github.com/$REPO/releases/latest" | sed 's#.*/##')
case "$TAG" in
  v[0-9]*) ;;
  *) echo "FATAL: could not resolve latest tag (got: $TAG)" >&2; exit 1 ;;
esac
VER=${TAG#v}
log "latest: $TAG"

SUMS="picoclaw_${VER}_checksums.txt"
mkdir -p "$TMP_DIR"
log "downloading $ASSET + $SUMS..."
curl -fsSL "https://github.com/$REPO/releases/download/$TAG/$ASSET" -o "$TMP_DIR/$ASSET"
curl -fsSL "https://github.com/$REPO/releases/download/$TAG/$SUMS" -o "$TMP_DIR/$SUMS"

log "verifying checksum..."
(cd "$TMP_DIR" && grep "  $ASSET" "$SUMS" | sha256sum -c -) || {
  echo "FATAL: sha256 mismatch for $ASSET" >&2; exit 1; }

log "extracting..."
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

log "installing binaries..."
install -m 755 "$TMP_DIR/picoclaw" "$PREFIX/bin/picoclaw"
[ -f "$TMP_DIR/picoclaw-launcher" ] && \
  install -m 755 "$TMP_DIR/picoclaw-launcher" "$PREFIX/bin/picoclaw-launcher"

log "smoke test..."
timeout 20 picoclaw --help </dev/null >/dev/null 2>&1 || {
  echo "FATAL: picoclaw failed to launch" >&2; exit 1; }
log "installed: picoclaw $VER ($(command -v picoclaw))"

rm -f "$TMP_DIR/$ASSET" "$TMP_DIR/$SUMS" "$TMP_DIR/picoclaw" "$TMP_DIR/picoclaw-launcher" \
      "$TMP_DIR/LICENSE" "$TMP_DIR/README.md"
