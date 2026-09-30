#!/data/data/com.termux/files/usr/bin/bash
# nullclaw-termux.sh — install NullClaw latest (native static Zig arm64 Android build, zero patch)
set -euo pipefail

REPO="nullclaw/nullclaw"
ASSET="nullclaw-android-aarch64.bin"
TMP_DIR="$PREFIX/tmp/opencode/nullclaw-install"
BIN_DEST="$PREFIX/bin/nullclaw"

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

mkdir -p "$TMP_DIR"
log "downloading $ASSET..."
curl -fsSL "https://github.com/$REPO/releases/download/$TAG/$ASSET" -o "$TMP_DIR/$ASSET"

log "installing binary to $BIN_DEST..."
install -m 755 "$TMP_DIR/$ASSET" "$BIN_DEST"

log "smoke test..."
"$BIN_DEST" --version || {
  echo "FATAL: nullclaw failed to launch" >&2; exit 1; }
log "installed: nullclaw $VER ($BIN_DEST)"

rm -rf "$TMP_DIR"
