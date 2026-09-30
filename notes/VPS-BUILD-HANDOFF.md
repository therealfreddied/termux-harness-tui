# VPS BUILD HANDOFF — OmniRoute for Termux (aarch64)

**Mission:** compile the OmniRoute standalone server bundle on your VPS and
ship the artifacts back so the phone can run it without building anything.

Phone status (all verified working, 2026-09-30): CLI (`omniroute --version`),
doctor, better-sqlite3 (source-compiled against Bionic), machine-id patch.
**Missing piece: `dist/server.js`** — on-device webpack build is impossible
(Turbopack has no android-arm64 binding; webpack OOMs / cache-snapshot fails
even at 3GB heap with 12GB swap). DO NOT retry on-device builds.

---

## What to build on the VPS

Repo: https://github.com/therealfreddied/termux-harness-tui
(contains `notes/VPS-BUILD-HANDOFF.md` = this file, plus all Termux patches
in `patches/` that the VPS build must apply)

```bash
git clone --depth 1 -b release/v3.8.51 https://github.com/diegosouzapw/OmniRoute.git
cd OmniRoute
npm ci                       # full dev deps
# Apply the 3 Termux patches from termux-harness-tui/patches/ (see below)

# Build BACKEND-ONLY (dashboard stubbed) — this is what the phone needs.
# Full dashboard build also welcome but optional.
OMNIROUTE_BUILD_BACKEND_ONLY=1 OMNIROUTE_BUILD_SHA=$(git rev-parse --short HEAD) \
  npm run build:release
```

Notes for the VPS build:
- Use the **webpack/turbopack default** — VPS has RAM, no Termux patches to
  the bundler are needed there.
- If the full `build:release` OOMs (it did on the smaller VPS), use
  `OMNIROUTE_BUILD_BACKEND_ONLY=1 npm run build:backend` plus
  `npm run build:cli` and copy the precompiled dashboard static assets from
  an npm 3.8.50 install if the dashboard is wanted (per the earlier writeup).

## The 3 patches (in `patches/`, apply AFTER `npm ci`)

1. **`patches/better-sqlite3-binding-android.patch`** —
   `node_modules/better-sqlite3/lib/binding.js`: return `null` from
   `getPrebuildPath()` when `process.platform === 'android'` so the addon
   loads from `build/Release/`. The phone ALREADY has the compiled
   `better_sqlite3.node` (2.1MB, Bionic-compatible) — the VPS should ALSO
   cross-compile a fresh one to be safe:
   ```bash
   # on VPS with Termux NDK toolchain (or ship us the amalgamation):
   cd node_modules/better-sqlite3
   node-gyp configure --release && make -j1 -C build \
     CC=aarch64-linux-android24-clang CXX=aarch64-linux-android24-clang++ \
     -e V=1
   ```
   (Phone-side fallback already works: we compile it on-device with clang,
   takes ~3 min at -j1. The VPS copy is a nice-to-have.)
   The sqlite amalgamation is pinned 3.50.4: `sqlite-src-3530400`.

2. **`patches/node-machine-id-android.patch`** — both `index.js` (ESM copy)
   and `dist/index.js` (minified runtime copy) need:
   - an `android:` guid entry: `cat $HOME/.omniroute/machine-id ||
     cat /proc/sys/kernel/random/boot_id || hostname`
   - a `case"android":` in the switch falling through to the linux case
   The phone writes a persistent `$HOME/.omniroute/machine-id` (boot_id).

3. **`patches/swc-core-android-wasm.patch`** — `node_modules/@swc/core/`:
   - `binding.js` has no `swc.android-arm64.node` — irrelevant on VPS, but
     the phone needs `index.js` patched:
     `var binding_1 = require("./binding")` (top-level, line ~69) becomes
     wasm-aware on android (loads `@swc/wasm`), AND the `bindings` IIFE
     `finally { return binding }` bug fixed to `return binding ||
     fallbackBindings`.
   - This patch ONLY matters if the shipped `dist/server.js` somehow
     re-requires @swc/core at runtime — it should not (Next standalone
     bundles everything). Include it for completeness.

## What to ship back (the artifact manifest)

From the built OmniRoute tree, tar these:

```bash
tar -czf omniroute-termux-aarch64-3.8.51.tar.gz \
  dist/ \           # standalone server bundle (the actual goal)
  bin/ \            # omniroute.mjs + cli tree (already runs on phone)
  scripts/ \        # dev/http-method-guard.cjs + runtime helpers the CLI needs
  package.json
```

Plus optionally (dashboard variant):
```bash
tar -czf omniroute-termux-aarch64-3.8.51-full.tar.gz \
  dist/ app/ bin/ scripts/ package.json   # if full dashboard build succeeded
```

Deliver either as a GitHub release asset on
`therealfreddied/termux-harness-tui` (release tag `omniroute-3.8.51-termux`)
or via the existing HTTP server at 66.179.82.231 (port 8999 was down last
we tried — restart it or use GH releases, preferred).

## Phone-side install after artifacts arrive

```bash
tar -xzf omniroute-termux-aarch64-3.8.51.tar.gz -C $HOME/omniroute/
omniroute doctor          # should show DB + server liveness OK after serve
omniroute serve --no-open # port 20128, /api/health, /v1/models
# then apply the /v1/models visibility patch:
SKIP_RESTART=1 node ~/LLM/termux-harness-tui/recipes/patch-guard-termux.js
```

## Also on the plate (same VPS session, if time permits)

1. **Hermes Agent** — the earlier `hermes-termux-aarch64.tar.gz` server on
   port 8999 was unreachable from the phone (port 80 open, 8999 filtered).
   Re-serve + verify with `nc -lz 8999` from the VPS and curl from phone.
2. **PentestCode tools layer** — `pkg install nmap dnsutils netcat-openbsd`
   equivalents on-device are fine; nothing needed from VPS.
3. **Cross-compile wish list** (Rust/Bionic via NDK r27b, already set up):
   zeroclaw, ironclaw, microclaw (all Rust claw-fleet) — release binaries
   into the same GitHub release for the harness-hub TUI to fetch.

## Security notes

- The API key `sk-8e13760a136607a1-587f11-10dd428d` leaked into chat/logs —
  **rotate it** before/after this session.
- OmniRoute on 0.0.0.0 without API key on a phone hotspot = anyone on LAN
  can use your providers. Phone-side launcher sets `OMNIROUTE_SERVER_HOST`
  to loopback by default; keep it that way.
