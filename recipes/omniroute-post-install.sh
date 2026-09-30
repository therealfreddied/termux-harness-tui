#!/data/data/com.termux/files/usr/bin/bash
# omniroute-post-install.sh — integrate a VPS-built omniroute dist tarball
# into the on-device ~/omniroute tree.
#
# Usage: bash omniroute-post-install.sh <omniroute-dist-*.tar.gz>
#
# Expects the phone tree from recipes/omniroute-termux.sh to already exist
# (node_modules + Bionic-compiled better-sqlite3 + patched loaders).
# Idempotent. Safe to re-run.
set -euo pipefail

OMNI_DIR="${OMNI_DIR:-$HOME/omniroute}"
TARBALL="${1:-}"
[ -n "$TARBALL" ] && [ -f "$TARBALL" ] || { echo "usage: $0 <dist tarball>" >&2; exit 1; }

log() { printf '\e[38;5;161m==>\e[0m %s\n' "$*"; }

# 1. extract dist/ over the tree (tarball root is dist/)
log "extracting $(basename "$TARBALL") into $OMNI_DIR..."
tar -xzf "$TARBALL" -C "$OMNI_DIR"
test -f "$OMNI_DIR/dist/server.js" || {
  # standalone output may be nested one level
  if [ -d "$OMNI_DIR/dist/standalone" ]; then
    cp -a "$OMNI_DIR/dist/standalone/." "$OMNI_DIR/dist/"
  fi
}
test -f "$OMNI_DIR/dist/server.js" || { log "FATAL: dist/server.js not found" >&2; exit 1; }

# 2. swap glibc better-sqlite3 addon for the phone-built Bionic one
BS3="$OMNI_DIR/node_modules/better-sqlite3"
if [ -f "$BS3/build/Release/better_sqlite3.node" ] && [ -d "$OMNI_DIR/dist/node_modules/better-sqlite3" ]; then
  log "swapping Bionic sqlite addon into dist/node_modules..."
  mkdir -p "$OMNI_DIR/dist/node_modules/better-sqlite3/build/Release"
  cp -f "$BS3/build/Release/better_sqlite3.node" \
        "$OMNI_DIR/dist/node_modules/better-sqlite3/build/Release/"
  # binding.js must return null for android (no prebuild lookup)
  if ! grep -q "platform === 'android'" "$OMNI_DIR/dist/node_modules/better-sqlite3/lib/binding.js" 2>/dev/null; then
    node - "$OMNI_DIR" <<'EOF'
const fs = require('fs');
const p = process.argv[2] + '/dist/node_modules/better-sqlite3/lib/binding.js';
let src = fs.readFileSync(p, 'utf8');
src = src.replace(
  'function getPrebuildPath() {',
  `function getPrebuildPath() {
	if (process.platform === 'android') return null;`
);
fs.writeFileSync(p, src);
console.log('dist binding.js patched (android → source build)');
EOF
  fi
fi

# 3. node-machine-id inside dist: android guid case + persistent id file
mkdir -p "$HOME/.omniroute"
[ -f "$HOME/.omniroute/machine-id" ] ||
  cat /proc/sys/kernel/random/boot_id > "$HOME/.omniroute/machine-id"
chmod 600 "$HOME/.omniroute/machine-id" 2>/dev/null || true
node - "$OMNI_DIR" <<'EOF'
const fs = require('fs');
const dir = process.argv[2] + '/dist/node_modules/node-machine-id';
for (const name of ['index.js', 'dist/index.js']) {
  const p = `${dir}/${name}`;
  if (!fs.existsSync(p)) continue;
  let src = fs.readFileSync(p, 'utf8');
  if (!src.includes('android:')) {
    src = src.replace(
      /(\w+)\s*=\s*`cat \/etc\/var\/db\/machine-id \/etc\/machine-id 2>\/dev\/null`/,
      (m, v) => `${v} = \`cat $HOME/.omniroute/machine-id 2>/dev/null\``
    );
    src = src.replace(/case\s*"linux"\s*:/, 'case"android":case"linux":');
    fs.writeFileSync(p, src);
    console.log(`machine-id patched: ${name}`);
  }
}
EOF

# 4. /v1/models visibility patch (idempotent; SKIP_RESTART honored)
export SKIP_RESTART=1
if [ -f "$HOME/LLM/termux-harness-tui/recipes/patch-guard-termux.js" ]; then
  log "applying /v1/models visibility patch..."
  node "$HOME/LLM/termux-harness-tui/recipes/patch-guard-termux.js" || log "patch-guard reported issues (non-fatal)"
fi

# 5. smoke test
log "done. start it with:"
echo "  OMNIROUTE_SERVER_HOST=127.0.0.1 omniroute serve --no-open"
echo "  then: curl -s http://127.0.0.1:20128/api/health && curl -s http://127.0.0.1:20128/v1/models"
