#!/data/data/com.termux/files/usr/bin/bash
# dsh-termux.sh — install the real DeepSeek Harness (dsh) natively on Termux.
#
#   DSH_TERMUX_ROUTE=prebuilt dsh-termux.sh   # DEFAULT — community patch set
#   DSH_TERMUX_ROUTE=patch dsh-termux.sh      # the route below, ours
#
# ─────────────────────────────────────────────────────────────────────────────
# DEFAULT ROUTE IS NOW SOMEONE ELSE'S WORK. Use it.
#
# Vengisk/deepseek-harness-termux (MIT) already solved this properly: nine
# per-package source patches, real prebuilt koffi and node-pty for android-arm64,
# a WASM sharp, a ripgrep platform shim, and --expose-internals on the shebang.
# Verified here: dsh web serves HTTP 200. Read notes/DSH-TERMUX.md.
#
# What follows is the patch layer we wrote first. It is kept only as the
# DSH_TERMUX_ROUTE=patch fallback, because it is the one that can follow npm
# `latest` (the community prebuilt bundles 0.1.0-rc.7, npm is at 0.2.0-rc.2).
# Do not use it by default: it was never installed or run, it stubs three
# native modules into loading-but-doing-nothing, and it misses fixes that only
# show up at boot — session persistence uses link(2) and dies on Android
# sepolicy, @vscode/ripgrep has no android-arm64 package so the grep/glob tools
# fail, and HMR needs --expose-internals.
# ─────────────────────────────────────────────────────────────────────────────
#
# The patch route installs the official package from the @deepseek-ai npm
# scope, unmodified, plus four thin Termux adaptations. No proot, no glibc, no
# fork.
#
#   DSH_TERMUX_ROUTE=patch dsh-termux.sh              # latest @deepseek-ai/dsh
#   DSH_TERMUX_ROUTE=patch dsh-termux.sh 0.2.0-rc.2  # pin a version
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

ROUTE="${DSH_TERMUX_ROUTE:-prebuilt}"

# ══════════════════════════════════════════════════════════════════════════════
# ROUTE: prebuilt — the community patch set (default, recommended)
# ══════════════════════════════════════════════════════════════════════════════
if [ "$ROUTE" = "prebuilt" ]; then
    TERMUX_REL="v0.1.0-termux.1"
    TGZ_URL="https://github.com/Vengisk/deepseek-harness-termux/releases/download/$TERMUX_REL/dsh-termux-full.tgz"
    TGZ_SHA="aa9f2ffc372c223a77ed38c08b76741533f7967cc19903815b3838d117e13b7f"
    TGZ_MB=50.9
    # Upstream dsh is bundled inside; it is not a separate install target.
    DSH_DIR="$PREFIX/opt/dsh"
    DSH_BIN_DEST="$PREFIX/bin/dsh"
    WORK="$PREFIX/tmp/opencode/dsh-install"
    mkdir -p "$WORK"

    log "route: prebuilt (Vengisk/deepseek-harness-termux, MIT, $TERMUX_REL)"

    [ "$(uname -m)" = "aarch64" ] || die "the prebuilt ships android-arm64 binaries only"
    command -v node >/dev/null || die "node missing: pkg install nodejs"
    NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
    [ "$NODE_MAJOR" -ge 22 ] || die "node >= 22.19 required; found $(node -v)"

    TGZ="$WORK/dsh-termux-full.tgz"
    if [ -f "$TGZ" ] && [ "$(sha256sum "$TGZ" | cut -d' ' -f1)" = "$TGZ_SHA" ]; then
        log "tarball already downloaded and verified — skipping"
    else
        log "downloading dsh-termux-full.tgz (${TGZ_MB} MB)..."
        curl -fSL --connect-timeout 20 --retry 3 -o "$TGZ.part" "$TGZ_URL" \
            || die "download failed: $TGZ_URL"
        mv "$TGZ.part" "$TGZ"
        GOT="$(sha256sum "$TGZ" | cut -d' ' -f1)"
        [ "$GOT" = "$TGZ_SHA" ] || die "sha256 mismatch
  expected $TGZ_SHA
  got      $GOT
  Refusing to install. Delete $TGZ and retry, or re-check the release notes."
        log "sha256 OK"
    fi

    log "extracting to $DSH_DIR..."
    STAGE="$WORK/stage"
    rm -rf "$STAGE" 2>/dev/null || true
    mkdir -p "$STAGE"
    tar -xzf "$TGZ" -C "$STAGE"
    [ -d "$STAGE/package" ] || die "unexpected tarball layout: no package/"

    # Replace the tree in one go so a failed extract cannot leave a half-dsh.
    NEW="$WORK/dsh.new"
    rm -rf "$NEW" 2>/dev/null || true
    mv "$STAGE/package" "$NEW"
    rm -rf "$DSH_DIR" 2>/dev/null || true
    mkdir -p "$(dirname "$DSH_DIR")"
    mv "$NEW" "$DSH_DIR"
    rm -rf "$STAGE" 2>/dev/null || true
    log "tree in place ($(du -sh "$DSH_DIR" 2>/dev/null | cut -f1))"

    mkdir -p "$(dirname "$DSH_BIN_DEST")"
    cat > "$DSH_BIN_DEST" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness (community Termux build). Generated by recipes/dsh-termux.sh.
DSH_PREFIX="\${DSH_PREFIX:-$DSH_DIR}"
# --expose-internals is required: cordis-plugin-hmr reads node:internal/modules,
# which Node has gated since v22. Upstream's bin.js shebang already carries it.
exec node --expose-internals "\$DSH_PREFIX/lib/bin.js" "\$@"
EOF
    chmod 755 "$DSH_BIN_DEST"
    printf '%s\n' "$TERMUX_REL" > "$DSH_DIR/.dsh-termux-build"
    log "launcher -> $DSH_BIN_DEST"

    # The @vscode/ripgrep shim is the one thing install.sh writes to disk and the
    # prebuilt tarball may not carry. Without it the glob/grep tools fail in
    # every fresh process, so create it here too.
    RG_SHIM="$DSH_DIR/node_modules/@vscode/ripgrep-android-arm64"
    if [ -x "$PREFIX/bin/rg" ] && [ ! -f "$RG_SHIM/package.json" ]; then
        mkdir -p "$RG_SHIM/bin"
        cat > "$RG_SHIM/package.json" <<EOF
{
  "name": "@vscode/ripgrep-android-arm64",
  "version": "1.18.0",
  "description": "Termux shim: rgPath -> system ripgrep. @vscode/ripgrep has no android platform package.",
  "license": "MIT",
  "bin": { "rg": "bin/rg" }
}
EOF
        ln -sf "$PREFIX/bin/rg" "$RG_SHIM/bin/rg"
        log "ripgrep android shim -> $PREFIX/bin/rg"
    fi

    log "verifying..."
    if "$DSH_BIN_DEST" --version >/dev/null 2>&1; then
        echo "  dsh         OK ($("$DSH_BIN_DEST" --version 2>&1 | head -1))"
    else
        echo "  dsh         WARN: --version failed; try 'dsh --help'"
    fi
    # Prove the natives really are Bionic and really dlopen here.
    if (cd "$DSH_DIR" && node -e "require('node-pty');process.exit(0)" >/dev/null 2>&1); then
        echo "  node-pty    OK (prebuilt, loads under Bionic)"
    else
        echo "  node-pty    FAIL: the prebuilt pty.node did not load"
    fi
    if (cd "$DSH_DIR" && node -e "require('koffi');process.exit(0)" >/dev/null 2>&1); then
        echo "  koffi       OK (prebuilt, loads under Bionic)"
    else
        echo "  koffi       WARN: did not load; FFI features (file dialogs) unavailable"
    fi
    GLIBC="$(strings -a "$DSH_DIR/node_modules/node-pty/build/Release/pty.node" 2>/dev/null | grep -c 'GLIBC_\|ld-linux-aarch64' || true)"
    [ "${GLIBC:-0}" -eq 0 ] && echo "  libc        OK (no glibc refs in pty.node)" \
                           || echo "  libc        FAIL: pty.node references glibc — wrong artifact"

    BUNDLED="$(node -p "require('$DSH_DIR/package.json').version" 2>/dev/null || echo '?')"
    echo
    log "done. 'dsh web' serves http://127.0.0.1:3080 ; 'dsh' for the CLI."
    log "bundle $BUNDLED (dsh 0.1.0-rc.7) vs npm latest 0.2.0-rc.2 — two generations behind,"
    log "and the patches were diffed against 0.1.0-rc.6. See notes/DSH-TERMUX.md."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# ROUTE: patch — our own layer (fallback, never installed, see header)
# ══════════════════════════════════════════════════════════════════════════════
[ "$ROUTE" = "patch" ] || die "unknown DSH_TERMUX_ROUTE='$ROUTE' (want 'prebuilt' or 'patch')"
log "route: patch (ours — unproven; the prebuilt route is the default for a reason)"

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