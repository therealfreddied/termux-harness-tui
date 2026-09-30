#!/data/data/com.termux/files/usr/bin/bash
# omniroute-termux.sh — install/patch OmniRoute on Termux (aarch64, no proot)
#
# Two variants:
#   full — complete build with dashboard UI (heavy: needs ~2GB heap + swap,
#          realistically built on a VPS then rsync dist/ + app/ over)
#   lite — OMNIROUTE_BUILD_BACKEND_ONLY=1: API + inference plane only,
#          dashboard stubbed. ~1.5GB heap, feasible on-device.
#
# Idempotent. Safe to re-run.
set -euo pipefail

OMNI_DIR="${OMNI_DIR:-$HOME/omniroute}"
VARIANT="${1:-lite}"
SRC_URL="https://github.com/diegosouzapw/OmniRoute.git"

log() { printf '\e[38;5;161m==>\e[0m %s\n' "$*"; }
die() { printf '\033[31mFATAL:\033[0m %s\n' "$*" >&2; exit 1; }

# ── HARD BLOCK: never build the full dashboard on this device ────────────────
# The Next.js dashboard compile asks for a 2GB heap and then thrashes swap on
# a 7GB phone until the kernel OOM-killer picks a victim. It does not fail, it
# wedges the whole device — do not run it here, do not "try it with more swap".
# Use `lite` on-device, or build `full` on a VPS (recipes/vps/build-omniroute.sh)
# and rsync dist/ + app/ across.
if [ "$VARIANT" = "full" ]; then
  if [ "${OMNIROUTE_ALLOW_FULL_ON_DEVICE:-0}" != "1" ]; then
    die "refusing to run the 'full' OmniRoute build on Termux — it will hang the device.
     On-device variant is 'lite' (backend only):
         bash \"\$(dirname \"\$0\")/omniroute-termux.sh\" lite
     For the dashboard, cross-build it:
         bash \"\$(dirname \"\$0\")/vps/build-omniroute.sh\"   # on the VPS
     Override is deliberately possible but only if you know what you are doing:
         OMNIROUTE_ALLOW_FULL_ON_DEVICE=1 bash omniroute-termux.sh full"
  fi
  log "WARNING: OMNIROUTE_ALLOW_FULL_ON_DEVICE=1 set — proceeding with the full build."
  log "WARNING: close every other app first. This can take longer than you expect."
fi

# 0. deps
for pkg in nodejs clang make python pkg-config; do
  command -v "${pkg%%-*}" >/dev/null 2>&1 || {
    log "missing dependency: $pkg (pkg install $pkg)"
    exit 1
  }
done

# 1. source
if [ ! -d "$OMNI_DIR/.git" ]; then
  log "cloning OmniRoute (shallow)..."
  git clone --depth 1 -b release/v3.8.51 "$SRC_URL" "$OMNI_DIR"
fi
cd "$OMNI_DIR"

# 2. node_modules: restore from lockfile if missing (npm ci with fallback)
if [ ! -d node_modules/better-sqlite3 ]; then
  log "installing node_modules (npm ci — ONE TIME, ~5min on device)..."
  npm ci --omit=dev --no-audit --no-fund 2>/dev/null \
    || npm ci --no-audit --no-fund
fi

# 3. better-sqlite3: MUST compile from source on Termux ('android' platform
#    never matches prebuilds; linux prebuilds segfault under Bionic node)
if [ ! -f node_modules/better-sqlite3/build/Release/better_sqlite3.node ]; then
  log "building better-sqlite3 from source (single -j1 job, low RAM)..."
  # 3a. sqlite amalgamation (pinned: 3.50.4)
  if [ ! -f node_modules/better-sqlite3/deps/sqlite3/sqlite3.c ]; then
    mkdir -p node_modules/better-sqlite3/deps/sqlite3-src
    curl -fsSL -o /tmp/sqlite.zip \
      "https://www.sqlite.org/2026/sqlite-src-3530400.zip"
    unzip -q -o /tmp/sqlite.zip -d node_modules/better-sqlite3/deps/sqlite3-src
    ( cd node_modules/better-sqlite3/deps/sqlite3-src/sqlite-src-3530400 &&
      sh configure >/dev/null 2>&1 && make sqlite3.c -j1 >/dev/null 2>&1 )
    mkdir -p node_modules/better-sqlite3/deps/sqlite3
    cp node_modules/better-sqlite3/deps/sqlite3-src/sqlite-src-3530400/sqlite3.{c,h} \
       node_modules/better-sqlite3/deps/sqlite3/
    cp node_modules/better-sqlite3/deps/sqlite3-src/sqlite-src-3530400/sqlite3ext.h \
       node_modules/better-sqlite3/deps/sqlite3/ 2>/dev/null || true
  fi
  # 3b. patch binding.js: android → no prebuild, use source build
  node - <<'EOF'
const fs = require('fs');
const p = 'node_modules/better-sqlite3/lib/binding.js';
let src = fs.readFileSync(p, 'utf8');
if (!src.includes("process.platform === 'android'")) {
  src = src.replace(
    'function getPrebuildPath() {',
    `function getPrebuildPath() {
	// Termux/Android: glibc prebuilds segfault under Bionic node — source build only.
	if (process.platform === 'android') return null;`
  );
  fs.writeFileSync(p, src);
  console.log('binding.js patched (android → source build)');
}
EOF
  # 3c. compile (-j1: bounded RAM; ~2-4 min)
  ( cd node_modules/better-sqlite3 &&
    node "$PREFIX/bin/node-gyp" configure --release &&
    make -j1 -C build )
  log "better-sqlite3 compiled OK"
fi

# 4. node-machine-id: add android case + persistent id file
mkdir -p "$HOME/.omniroute"
[ -f "$HOME/.omniroute/machine-id" ] ||
  cat /proc/sys/kernel/random/boot_id > "$HOME/.omniroute/machine-id"
chmod 600 "$HOME/.omniroute/machine-id"
node - <<'EOF'
const fs = require('fs');
// ESM copy (used via import in dev tree)
let p = 'node_modules/node-machine-id/index.js', src = fs.readFileSync(p, 'utf8');
if (!src.includes('android:')) {
  src = src.replace(
    "linux: '( cat /var/lib/dbus/machine-id",
    `android: '( cat "$HOME/.omniroute/machine-id" 2> /dev/null || ' +
            'cat /proc/sys/kernel/random/boot_id 2> /dev/null || hostname ) | head -n 1 || :',
        linux: '( cat /var/lib/dbus/machine-id`
  );
  fs.writeFileSync(p, src);
}
// minified dist copy (what the runtime actually requires)
p = 'node_modules/node-machine-id/dist/index.js';
src = fs.readFileSync(p, 'utf8');
if (!src.includes('.omniroute/machine-id')) {
  src = src.replace(
    'cat /var/lib/dbus/machine-id /etc/machine-id 2> /dev/null || hostname )',
    'cat /var/lib/dbus/machine-id /etc/machine-id 2> /dev/null || cat $HOME/.omniroute/machine-id 2> /dev/null || hostname )'
  ).replace(
    'case"linux":return',
    'case"android":case"linux":return'
  ).replace(
    'hostname ) | head -n 1 || :"',
    'hostname ) | head -n 1 || :",android:"( cat $HOME/.omniroute/machine-id 2> /dev/null || cat /proc/sys/kernel/random/boot_id 2> /dev/null || hostname ) | head -n 1 || :"'
  );
  fs.writeFileSync(p, src);
}
console.log('node-machine-id patched (android case + persistent id)');
EOF

# 5. build server bundle
if [ ! -f dist/server.js ]; then
  if [ "$VARIANT" = "full" ]; then
    log "FULL build (dashboard + API) — needs ~2GB heap; aborting on-device is likely"
    NODE_OPTIONS="--max-old-space-size=2048" npm run build
  else
    log "LITE build (backend-only, dashboard stubbed)..."
    NODE_OPTIONS="--max-old-space-size=1536" OMNIROUTE_BUILD_BACKEND_ONLY=1 \
      node scripts/build/build-next-isolated.mjs
  fi
fi

# 6. launcher
cat > "$PREFIX/bin/omniroute" <<EOF
#!/bin/sh
node "$OMNI_DIR/bin/omniroute.mjs" "\$@"
EOF
chmod +x "$PREFIX/bin/omniroute"

# 7. /v1/models visibility patch (phone-adapted patch-guard; see recipes/patch-guard-termux.js)
if [ -f "$(dirname "$0")/patch-guard-termux.js" ]; then
  log "applying /v1/models visibility patch..."
  SKIP_RESTART=1 node "$(dirname "$0")/patch-guard-termux.js" || log "patch failed (non-fatal, rerun later)"
fi

log "done. Start with: omniroute serve --no-open"
log "Lite variant note: dashboard URL serves a stub; use the CLI/API only."
