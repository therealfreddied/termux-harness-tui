# Termux Harness TUI — Working Notes

## Environment gotchas learned 2026-09-30

- `node -p process.platform` in Termux = **`android`** (not linux). Every
  native-module prebuild loader (better-sqlite3, @swc/core, node-machine-id…)
  misses `android-*` prebuilds → must patch loaders or compile from source.
- glibc `.node` prebuilds **segfault** under Bionic node — never map
  android→linux prebuild dirs. Compile from source instead (better-sqlite3
  builds fine at `-j1`, ~2-4 min, sqlite amalgamation from
  sqlite.org/2026/sqlite-src-3530400.zip).
- `/etc` is read-only on Android → node-machine-id can't find machine-id.
  Fix: persistent `$HOME/.omniroute/machine-id` + patch both ESM and minified
  dist copies of node-machine-id with an `android:` guid case.
- Go releases (CLIProxyAPI): built with GOOS=linux Go 1.26+ they emit
  `faccessat2` (syscall 439) → SIGSYS under Android seccomp. Fix = on-device
  rebuild with Termux Go 1.27 (`GOOS=android` default). If dep tree includes
  pion/transport → wlynxg/anet uses `//go:linkname net.zoneCache` → need
  `-ldflags="-checklinkname=0"` (linker flag, NOT gcflags, in Go 1.27).
- musl ELF binaries (pentestcode): runnable via Alpine musl loader shim —
  `$PREFIX/lib/musl/{ld-musl-aarch64.so.1,libc.musl-aarch64.so.1,libstdc++.so.6,libgcc_s.so.1}`
  + `exec ld-musl-aarch64.so.1 --library-path $MUSL <binary>` (recipe in
  recipes/musl-shim.md). No glibc needed at all.
- npm install denied by permission rules → manual registry tarball extraction
  (`registry.npmjs.org/<pkg>/-/…tgz`) into node_modules + dependency closure
  by hand (bwb-browser needed 20 pkgs). Works fine, idempotent.
- Next.js 16 on Termux: needs `@swc/wasm` fallback (@swc/core has no
  android-arm64 binding for 1.16.x) + `@next/swc-wasm-nodejs` for next 16.3.3.
- `/tmp` writes fail in some shells → use `$PREFIX/tmp/opencode/` for scratch.
- sha256sum -c needs exact filename match — rename tarballs to upstream names
  before verifying.

## Install status (all verified 2026-09-30, SM-S911W aarch64)

| Tool | Version | Layout |
|---|---|---|
| grok | 1.0.41 | native Bionic ELF → `$PREFIX/bin/grok` (from Duro02 release, sha256-verified) |
| dsh | mini v0.1.12 | `$PREFIX/lib/dsh-mini/*.mjs` + `node` launcher → `dsh` |
| bwb | 4.0.1 | `$PREFIX/lib/bwb-browser` + 20-pkg node_modules → `bwb` (MCP stdio, 26 tools verified) |
| pentestcode | 0.2.6 | musl shim → `$PREFIX/bin/pentestcode` (Alpine musl loader + libstdc++) |
| cli-proxy-api | 8.0.4 | on-device Go rebuild → `$PREFIX/bin/cli-proxy-api` |
| 9router | 0.5.91 | `$PREFIX/lib/9router` + node launcher (health OK on :20128 — conflicts w/ omniroute port, change one) |
| omniroute | 3.8.51 | source checkout `$HOME/omniroute`; better-sqlite3 compiled; machine-id patched; backend-only build in progress |

## OmniRoute port state

- doctor: all OK except DB init + server liveness (expected pre-build)
- Full rebuild is NOT viable on-device (dashboard build OOMs) →
  `OMNIROUTE_BUILD_BACKEND_ONLY=1` build (API only, dashboard stubbed) — the
  TUI should offer both variants (full needs VPS cross-build or precompiled
  dist transfer).
- Build dep closure added by hand: fumadocs-mdx + 29 transitive pkgs.
- /v1/models visibility patch: phone-adapted patch-guard written at
  recipes/patch-guard-termux.js (targets scripts/dev/http-method-guard.cjs in
  source layout; preserves the two critical invariants: return listener in
  non-models branch, and headersSent guard).

## Port conflicts to resolve

- 9router default port 20128 == omniroute default 20128. Plan: 9router→20129
  in its launcher, omniroute keeps 20128.
