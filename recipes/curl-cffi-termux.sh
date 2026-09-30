#!/data/data/com.termux/files/usr/bin/bash
# curl-cffi-termux.sh — install curl_cffi on ANY Python 3.10+ via the proven
# abi3 source build (therealfreddied/curl-cffi-termux). Forwards --force.
set -euo pipefail

REPO="therealfreddied/curl-cffi-termux"
COMMIT="85b5f4f8072d60a104854c860c3942684d79686c"
SCRIPT="install-curl-cffi.sh"
URL="https://raw.githubusercontent.com/$REPO/$COMMIT/$SCRIPT"
EXPECTED_SHA="0c3e8867a104f4a9b802c70c1c22df5815e6c875c88585b34fd32bafa4303b2d"
TMP_DIR="$PREFIX/tmp/opencode/curl-cffi-install"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading installer (pinned $COMMIT)..."
mkdir -p "$TMP_DIR"
curl -fsSL "$URL" -o "$TMP_DIR/$SCRIPT"

log "verifying checksum..."
ACTUAL_SHA=$(sha256sum "$TMP_DIR/$SCRIPT" | cut -d' ' -f1)
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "FATAL: sha256 mismatch (expected $EXPECTED_SHA, got $ACTUAL_SHA)" >&2
  rm -f "$TMP_DIR/$SCRIPT"
  exit 1
fi

log "running upstream installer (idempotent; live-impersonation gate)..."
bash "$TMP_DIR/$SCRIPT" "$@"

log "installing version shim (\$PREFIX/bin/curl-cffi)..."
cat > "$PREFIX/bin/curl-cffi" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec python3 -c 'import curl_cffi; print("curl_cffi", curl_cffi.__version__)'
EOF
chmod 755 "$PREFIX/bin/curl-cffi"

log "smoke test..."
V=$(timeout 30 curl-cffi </dev/null 2>&1 | head -1) || {
  echo "FATAL: curl-cffi shim failed (curl_cffi not importable)" >&2; exit 1; }
case "$V" in
  curl_cffi\ *) log "installed: $V ($(command -v curl-cffi))" ;;
  *) echo "FATAL: unexpected output: $V" >&2; exit 1 ;;
esac

rm -f "$TMP_DIR/$SCRIPT"
