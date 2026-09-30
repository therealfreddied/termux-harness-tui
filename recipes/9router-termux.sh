#!/data/data/com.termux/files/usr/bin/bash
# 9router-termux.sh — install 9router (pure-JS Node.js router) on Termux
set -euo pipefail

PKG="9router"
VERSION="0.5.91"
DEST_DIR="$PREFIX/lib/9router"
BIN="$PREFIX/bin/9router"
TMP_DIR="$PREFIX/tmp/opencode/9router-install"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "downloading 9router@$VERSION npm tarball..."
mkdir -p "$TMP_DIR"
curl -fsSL "https://registry.npmjs.org/9router/-/9router-${VERSION}.tgz" -o "$TMP_DIR/9router.tgz"

log "extracting to $DEST_DIR..."
mkdir -p "$DEST_DIR"
tar -xzf "$TMP_DIR/9router.tgz" --strip-components=1 -C "$DEST_DIR"

log "ensuring persistent machine-id in ~/.9router/machine-id..."
mkdir -p "$HOME/.9router"
if [ ! -f "$HOME/.9router/machine-id" ]; then
  if [ -r /proc/sys/kernel/random/boot_id ]; then
    cat /proc/sys/kernel/random/boot_id > "$HOME/.9router/machine-id"
  else
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$HOME/.9router/machine-id"
  fi
  chmod 600 "$HOME/.9router/machine-id" 2>/dev/null || true
fi

log "patching $DEST_DIR/src/cli/api/client.js for Android/Termux machine-id..."
node - "$DEST_DIR" <<'EOF'
const fs = require('fs');
const path = require('path');
const p = path.join(process.argv[2], 'src', 'cli', 'api', 'client.js');
if (fs.existsSync(p)) {
  let src = fs.readFileSync(p, 'utf8');
  // 1. Remove unconditional top-level require("node-machine-id")
  src = src.replace(/const\s*\{\s*machineIdSync\s*\}\s*=\s*require\(["']node-machine-id["']\);?\r?\n?/, '');
  // 2. Wrap lookup inside loadRawMachineId with safe lazy require
  if (!src.includes('const { machineIdSync } = require("node-machine-id");')) {
    src = src.replace(
      /try\s*\{\s*return\s+machineIdSync\(\);\s*\}\s*catch\s*\{\s*return\s+["']["'];\s*\}/,
      `try {\n    const { machineIdSync } = require("node-machine-id");\n    return machineIdSync();\n  } catch {\n    return "";\n  }`
    );
  }
  fs.writeFileSync(p, src);
  console.log('src/cli/api/client.js patched for Termux runtime');
}
EOF

log "creating launcher -> $BIN (port 20129 to avoid OmniRoute collision)..."
cat > "$BIN" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec node /data/data/com.termux/files/usr/lib/9router/cli.js --port 20129 --no-browser --skip-update "$@"
EOF
chmod 755 "$BIN"

log "verifying installation..."
command -v 9router >/dev/null 2>&1 || { echo "FATAL: 9router not on PATH" >&2; exit 1; }
9router --version && log "9router installed successfully: $(command -v 9router)"
