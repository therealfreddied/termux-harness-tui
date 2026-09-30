#!/data/data/com.termux/files/usr/bin/bash
# dsh-termux.sh — install the real DeepSeek Harness (dsh) natively on Termux.
#
# Replaces the old dsh-mini third-party repack. This installs the official
# package from the @deepseek-ai npm scope, unmodified, plus four thin Termux
# adaptations. No proot, no glibc, no fork.
#
#   dsh-termux.sh              # latest @deepseek-ai/dsh
#   dsh-termux.sh 0.2.0-rc.2  # pin a version
#   DSH_TERMUX_SHARP=1 dsh-termux.sh   # also build sharp against Termux libvips
#
# Why it needs adapting at all (all verified on SM-S911W, aarch64, Node 24.18):
#
#   1. process.platform is "android", and dsh-subprocess-local's process
#      inspector only accepts "linux" or "darwin" — every terminal allocation
#      throws at plugin load. Fixed by a preload shim, see step 5.
#   2. node-pty ships only a glibc-linked linux-arm64 prebuild, which cannot
#      dlopen under Bionic. Termux has pty.h + libutil, so we compile it.
#   3. koffi / sharp / sherpa-onnx have no usable Android build. Stubbed.
#
# Everything is idempotent: re-running after an upstream upgrade re-resolves the
# latest version and only redoes what changed.
set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DSH_DIR="${DSH_DIR:-$PREFIX/opt/dsh}"
DSH_BIN_DEST="${DSH_BIN_DEST:-$PREFIX/bin/dsh}"
SHIM_SRC="$HUB_DIR/recipes/shims/dsh-termux-preload.cjs"
PKG="@deepseek-ai/dsh"
PIN="${1:-}"
# Never /tmp: Android ships it mode 711 owned by `shell`, so a Termux process
# cannot create files there.
WORK="$PREFIX/tmp/opencode/dsh-install"

Crim=$'\e[38;5;161m'
Rst=$'\e[0m'
log() { printf '%s==>%s %s\n' "$Crim" "$Rst" "$*"; }
die() { printf '\033[31mFATAL:\033[0m %s\n' "$*" >&2; exit 1; }

# ── 0. preconditions ────────────────────────────────────────────────────────
[ "$(uname -m)" = "aarch64" ] || die "this recipe is aarch64-only"
command -v node >/dev/null || die "node missing: pkg install nodejs"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || die "node >= 22.15 required (zstd in node:zlib); found $(node -v)"
for tool in clang make python; do
  command -v "$tool" >/dev/null || die "$tool missing: pkg install clang make python"
done
[ -f "$SHIM_SRC" ] || die "missing shim: $SHIM_SRC"

mkdir -p "$WORK"

# Exported so an npm wrapper (proxy, cache, or a dry-run stand-in) sees where
# the tree is going; the subshell that runs npm inherits these.
export DSH_DIR WORK DSH_BIN_DEST

# ── 1. resolve the version we are going to install ───────────────────────────
log "resolving latest ${PKG} from the npm registry..."
REGISTRY_JSON="$WORK/dsh-packument.json"
if ! curl -fsSL --max-time 60 "https://registry.npmjs.org/${PKG//\//%2f}" -o "$REGISTRY_JSON"; then
  die "cannot reach registry.npmjs.org"
fi
LATEST="$(jq -r '."dist-tags".latest' "$REGISTRY_JSON")"
VERSION="${PIN:-$LATEST}"
if [ -n "$PIN" ] && ! jq -e --arg v "$PIN" '.versions[$v]' "$REGISTRY_JSON" >/dev/null; then
  die "version $PIN not published (latest is $LATEST)"
fi
log "target version: $VERSION${PIN:+ (pinned)}"

INSTALLED_VERSION=""
[ -f "$DSH_DIR/.dsh-termux-version" ] && INSTALLED_VERSION="$(cat "$DSH_DIR/.dsh-termux-version")"

# ── 2. dependency tree ───────────────────────────────────────────────────────
# --ignore-scripts is the important flag: without it npm tries to run koffi's
# cnoke build and node-pty's "prebuild.js || node-gyp rebuild" during install,
# which fails on Bionic and leaves a half-broken tree. We do the one build we
# actually want by hand in step 4.
if [ "$INSTALLED_VERSION" != "$VERSION" ] || [ ! -d "$DSH_DIR/node_modules/@deepseek-ai/dsh" ]; then
  if [ "$INSTALLED_VERSION" != "$VERSION" ] && [ -n "$INSTALLED_VERSION" ]; then
    log "upgrading $INSTALLED_VERSION -> $VERSION"
  fi
  mkdir -p "$DSH_DIR"
  cat > "$DSH_DIR/package.json" <<EOF
{
  "name": "dsh-termux",
  "version": "1.0.0",
  "private": true,
  "description": "DeepSeek Harness installed natively on Termux (Bionic)",
  "dependencies": {
    "${PKG}": "$VERSION"
  }
}
EOF
  log "installing the tree — ~560 packages, one time, this takes a while on a phone..."
  log "  (watch memory: if the phone stutters, close apps and wait it out)"
  ( cd "$DSH_DIR" && npm install --omit=dev --ignore-scripts --no-audit --no-fund )
  printf '%s' "$VERSION" > "$DSH_DIR/.dsh-termux-version"
else
  log "tree already at $VERSION — skipping npm install"
fi

DSH_BIN="$DSH_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
[ -f "$DSH_BIN" ] || die "expected $DSH_BIN to exist after install"

# ── 3. native module stubs ───────────────────────────────────────────────────
log "stubbing native modules with no Android/Bionic build..."
node "$HUB_DIR/recipes/dsh-termux-stubs.mjs" "$DSH_DIR/node_modules"

# ── 4. node-pty: compile against Bionic ──────────────────────────────────────
# The published linux-arm64 prebuild is glibc-linked (libc.so.6 +
# ld-linux-aarch64.so.1 + GLIBC_2.17) so it cannot load here. Termux ships
# pty.h and libutil.so via ndk-sysroot, so a from-source build is both possible
# and strictly better than stubbing: real PTY, real winsize, real signals.
PTY_DIR="$DSH_DIR/node_modules/node-pty"
if [ -f "$PTY_DIR/build/Release/pty.node" ]; then
  log "node-pty already built for Bionic"
else
  if [ ! -d "$PTY_DIR" ]; then
    log "node-pty not in the tree (upstream moved it?) — persistent terminals may be limited"
  elif [ ! -d "$PTY_DIR/node_modules/node-addon-api" ]; then
    # binding.gyp resolves it via `node -p "require('node-addon-api').targets"`,
    # so it must be resolvable from node-pty's own directory.
    log "node-pty is missing node-addon-api, fetching headers..."
    mkdir -p "$PTY_DIR/node_modules/node-addon-api"
    ADDON_VER="$(npm view node-addon-api version 2>/dev/null || echo 8.9.2)"
    curl -fsSL "https://registry.npmjs.org/node-addon-api/-/node-addon-api-${ADDON_VER}.tgz" \
      | tar -xz -C "$PTY_DIR/node_modules/node-addon-api" --strip-components=1
  fi
  log "compiling node-pty against Bionic (single job, ~1 min)..."
  # -j1 keeps peak RAM low. --nodedir points node-gyp at Termux's own headers
  # ($PREFIX/include/node) because there are no prebuilt android-arm64 headers
  # to download. $PREFIX/bin/node-gyp must be run through `node`: its shebang
  # hardcodes an interpreter path that does not exist on other accounts.
  ( cd "$PTY_DIR" && node "$PREFIX/bin/node-gyp" rebuild --nodedir="$PREFIX" -j 1 ) \
    || die "node-pty failed to compile — persistent bash terminals will not work"
  log "node-pty compiled OK"
fi

# Restore the exec bit the upstream postinstall would have set. Harmless if the
# helper is absent, which it is on Linux.
if [ -f "$PTY_DIR/build/Release/spawn-helper" ]; then
  chmod 755 "$PTY_DIR/build/Release/spawn-helper" || true
fi

# Optional: real sharp instead of the stub. Needs Termux's libvips, and builds
# sharp from source, so it is opt-in.
if [ "${DSH_TERMUX_SHARP:-0}" = "1" ]; then
  if pkg list-installed 2>/dev/null | grep -q '^libvips/'; then
    log "building sharp against Termux libvips (DSH_TERMUX_SHARP=1)..."
    ( cd "$DSH_DIR/node_modules/sharp" \
      && SHARP_FORCE_GLOBAL_LIBVIPS=1 npm run install --fallback-to-build 2>/dev/null ) \
      && log "sharp built" \
      || log "sharp build failed — keeping the stub (image attachments stay off)"
    for f in "$DSH_DIR"/node_modules/sharp/dist/index.cjs.termux-orig \
             "$DSH_DIR"/node_modules/sharp/dist/index.mjs.termux-orig; do
      [ -f "$f" ] || continue
      rel="$(basename "$f" .termux-orig)"
      mv "$f" "$DSH_DIR/node_modules/sharp/dist/$rel"
      log "restored real sharp/$rel"
    done
  else
    log "DSH_TERMUX_SHARP=1 but libvips is not installed — run: pkg install libvips"
  fi
fi

# ── 5. preload shim + launcher ───────────────────────────────────────────────
# NODE_OPTIONS rather than a `node --require` on the command line: Node
# propagates NODE_OPTIONS into every worker_thread, and DSH runs subagents in
# workers. A worker gets a fresh `process` object, so a main-isolate-only
# override would be invisible to them and they would go back to "android".
mkdir -p "$DSH_DIR/shim"
cp -f "$SHIM_SRC" "$DSH_DIR/shim/dsh-termux-preload.cjs"

mkdir -p "$(dirname "$DSH_BIN_DEST")"
cat > "$DSH_BIN_DEST" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness on Termux. Generated by recipes/dsh-termux.sh — do not edit.
DSH_PREFIX="\${DSH_PREFIX:-$DSH_DIR}"
PRELOAD="\$DSH_PREFIX/shim/dsh-termux-preload.cjs"
export NODE_OPTIONS="--require \$PRELOAD\${NODE_OPTIONS:+ \$NODE_OPTIONS}"
exec node "\$DSH_PREFIX/node_modules/@deepseek-ai/dsh/lib/bin.js" "\$@"
EOF
chmod 755 "$DSH_BIN_DEST"

# ── 6. verify ────────────────────────────────────────────────────────────────
log "verifying..."
FAILED=0
node -e "
  require('$DSH_DIR/shim/dsh-termux-preload.cjs');
  if (process.platform !== 'linux') { console.error('  shim: platform is ' + process.platform); process.exit(1); }
  console.log('  shim        OK (platform -> ' + process.platform + ')');
" || FAILED=1

if [ -f "$PTY_DIR/build/Release/pty.node" ]; then
  node -e "
    const pty = require('$PTY_DIR/lib/index.js');
    const p = pty.spawn('$PREFIX/bin/bash', ['-lc', 'tty'], { name: 'xterm', cols: 80, rows: 24, cwd: process.env.HOME, env: process.env });
    p.onData(() => {});
    p.onExit(({ exitCode }) => { console.log('  node-pty    ' + (exitCode === 0 ? 'OK (real pty on Bionic)' : 'FAIL exit ' + exitCode)); process.exit(exitCode === 0 ? 0 : 1); });
  " || { echo "  node-pty    FAIL"; FAILED=1; }
else
  echo "  node-pty    SKIPPED (not built)"
fi

if command -v dsh >/dev/null && "$DSH_BIN_DEST" --version >/dev/null 2>&1; then
  echo "  dsh         OK ($("$DSH_BIN_DEST" --version 2>&1 | head -1))"
else
  echo "  dsh         WARN: '$DSH_BIN_DEST --version' did not succeed; try running it directly"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  log "done. Run 'dsh' to start (first run asks for a DeepSeek API key)."
  log "installed: $VERSION"
  du -sh "$DSH_DIR" 2>/dev/null | sed 's/^/disk used: /'
else
  die "one or more checks failed — see above"
fi