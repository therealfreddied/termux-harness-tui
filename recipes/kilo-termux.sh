#!/data/data/com.termux/files/usr/bin/bash
# kilo-termux.sh — install Kilo Code CLI natively on Termux via Alpine musl loader.
#
# Kilo Code provides a precompiled linux-arm64-musl binary in @kilocode/cli-linux-arm64-musl.
# We patchelf it to use $PREFIX/lib/musl/ld-musl-aarch64.so.1 with rpath to $PREFIX/lib/musl.
set -euo pipefail

PKG="@kilocode/cli-linux-arm64-musl"
OPT_DIR="$PREFIX/opt/kilo"
BIN_DEST="$PREFIX/bin/kilo"
MUSL_LIB="$PREFIX/lib/musl"
LOADER="$MUSL_LIB/ld-musl-aarch64.so.1"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "checking prerequisites..."
command -v patchelf >/dev/null 2>&1 || { log "installing patchelf..."; pkg install -y patchelf; }
command -v jq >/dev/null 2>&1 || { log "installing jq..."; pkg install -y jq; }
command -v curl >/dev/null 2>&1 || { log "installing curl..."; pkg install -y curl; }
command -v tar >/dev/null 2>&1 || { log "installing tar..."; pkg install -y tar; }

if [ ! -f "$LOADER" ] || [ ! -f "$MUSL_LIB/libstdc++.so.6" ]; then
  log "setting up musl runtime in $MUSL_LIB..."
  mkdir -p "$MUSL_LIB"
  TMP_MUSL="$(mktemp -d)"
  ALPINE="https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64"
  MUSL_APK="$(curl -fsSL "$ALPINE/" | sed -n 's/.*href="\(musl-[0-9][^"]*\.apk\)".*/\1/p' | head -1)"
  CPP_APK="$(curl -fsSL "$ALPINE/" | sed -n 's/.*href="\(libstdc++-[0-9][^"]*\.apk\)".*/\1/p' | head -1)"
  GCC_APK="$(curl -fsSL "$ALPINE/" | sed -n 's/.*href="\(libgcc-[0-9][^"]*\.apk\)".*/\1/p' | head -1)"
  
  [ -n "$MUSL_APK" ] && curl -fsSL -o "$TMP_MUSL/musl.apk" "$ALPINE/$MUSL_APK" && tar xzf "$TMP_MUSL/musl.apk" -C "$TMP_MUSL" 2>/dev/null || true
  [ -n "$CPP_APK" ] && curl -fsSL -o "$TMP_MUSL/cpp.apk" "$ALPINE/$CPP_APK" && tar xzf "$TMP_MUSL/cpp.apk" -C "$TMP_MUSL" 2>/dev/null || true
  [ -n "$GCC_APK" ] && curl -fsSL -o "$TMP_MUSL/gcc.apk" "$ALPINE/$GCC_APK" && tar xzf "$TMP_MUSL/gcc.apk" -C "$TMP_MUSL" 2>/dev/null || true
  
  [ -f "$TMP_MUSL/lib/ld-musl-aarch64.so.1" ] && install -m 755 "$TMP_MUSL/lib/ld-musl-aarch64.so.1" "$LOADER"
  [ -f "$TMP_MUSL/usr/lib/libstdc++.so.6" ] && cp -P "$TMP_MUSL"/usr/lib/libstdc++.so* "$MUSL_LIB/"
  [ -f "$TMP_MUSL/usr/lib/libgcc_s.so.1" ] && install -m 755 "$TMP_MUSL/usr/lib/libgcc_s.so.1" "$MUSL_LIB/libgcc_s.so.1"
  rm -rf "$TMP_MUSL"
fi

log "resolving latest $PKG..."
META="$(curl -fsSL "https://registry.npmjs.org/${PKG//\//%2f}/latest")"
VERSION="$(printf '%s' "$META" | jq -r '.version')"
TARBALL="$(printf '%s' "$META" | jq -r '.dist.tarball')"
log "found version $VERSION"

log "downloading and extracting to $OPT_DIR..."
TMP_DIR="$(mktemp -d "$PREFIX/tmp/opencode/kilo-install.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

curl -fSL --retry 3 -o "$TMP_DIR/pkg.tgz" "$TARBALL"
mkdir -p "$OPT_DIR"
tar xzf "$TMP_DIR/pkg.tgz" -C "$OPT_DIR" --strip-components=1

log "patching kilo binary with musl loader and rpath..."
KILO_BIN="$OPT_DIR/bin/kilo"
if [ -f "$KILO_BIN" ]; then
  patchelf --set-rpath "$MUSL_LIB" --set-interpreter "$LOADER" "$KILO_BIN"
  chmod 755 "$KILO_BIN"
fi

log "creating launcher wrappers..."
rm -f "$BIN_DEST" "$PREFIX/bin/kilocode"
cat <<'EOF' > "$BIN_DEST"
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PREFIX/etc/tls/cert.pem}"
exec env -u LD_PRELOAD "$PREFIX/opt/kilo/bin/kilo" "$@"
EOF
chmod 755 "$BIN_DEST"
ln -sf "$BIN_DEST" "$PREFIX/bin/kilocode"

log "verifying..."
command -v kilo >/dev/null 2>&1 || { echo "FATAL: kilo not on PATH" >&2; exit 1; }
kilo --version
log "kilo installed successfully ($VERSION) -> $BIN_DEST"
