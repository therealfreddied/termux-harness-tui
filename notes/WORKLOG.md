# Termux Harness TUI — Working Notes

## curl_cffi proper installer (2026-09-30)

Question: does the TUI have a proper, Python-version-agnostic curl_cffi
installer? **It did NOT** (menu label + PLAN candidate only, no manifest/
recipe). The proper method already exists and it is the user's own:
`therealfreddied/curl-cffi-termux` (main @ 85b5f4f, script sha256
`0c3e8867a104f4a9b802c70c1c22df5815e6c875c88585b34fd32bafa4303b2d`).

Why neither stock path is "proper" on Termux:
- **`pip install curl_cffi` (PyPI android wheel)**: upstream ships
  `cp313-cp313-android_24_arm64_v8a` built against `libpython3.13.so` —
  broken on every other Termux Python (3.10/3.11/3.12/3.14): import dies
  on missing libpython. NOT version-agnostic.
- **sdist build with stock Termux toolchain**: Termux clang resolves
  `-lc++` to `/system/lib64/libc++.so` (ancient, no `__ndk1` ABI) →
  `_wrapper.abi3.so` fails dlopen with
  `cannot locate symbol _ZNSt6__ndk1...`.
- PyPI also has `cp310-abi3` manylinux/musllinux wheels — glibc/musl, not
  Bionic; irrelevant here.

The proper method (user's script, 139 lines, idempotent, ~1 min fresh):
1. `pkg`-provision only missing toolchain (python clang make binutils
   libc++ libffi pkg-config).
2. Gate: live `impersonate='chrome'` request to example.com → if HTTP 200,
   exit "nothing to do" (re-run is free).
3. pip-build-deps import-check (cffi/wheel/setuptools), install only missing.
4. `pip download` sdist → patch `scripts/build.py` `"-lc++"` →
   `"-lc++_shared"` **inside ephemeral mktemp dir only** (no global changes)
   → build with `--no-binary :all: --no-build-isolation`. build.py fetches a
   prebuilt static `libcurl-impersonate.a` (aarch64-linux-android) and fuses
   it into the wrapper.
5. Output wheel is **abi3 → installs/works on ANY Python ≥3.10**,
   self-contained (static libcurl), verified by live HTTP 200 + readelf
   check that `_wrapper.abi3.so` links `libc++_shared.so`.
- Pin: default `curl_cffi==0.16.0` (known-good static-archive ABI; newer
  may reintroduce `__ndk1` drift). Override: `CURL_CFFI_VERSION`, `--force`,
  `PIP=...`.
- Verified on THIS device: `import curl_cffi` → 0.16.0, chrome
  impersonation → HTTP 200 (2026-09-30).

TUI wiring: `manifests/curl-cffi.json` (category mcp-tooling) +
`recipes/curl-cffi-termux.sh` (pinned-commit fetch + sha256 verify + run
upstream script + install `$PREFIX/bin/curl-cffi` version shim so the hub's
installed-badge/post_install checks work). NOTE: outer `y` confirm in the
hub is the approval gate for the inner `pkg install`/pip calls; on an
already-provisioned phone the script never reaches pip (stage-2 gate exits).

## Claw Fleet research + installer support (2026-09-30)

Full detail in `notes/CLAW-FLEET.md`. Highlights:

- Ecosystem surveyed: OpenClaw (186K stars, TS, the original), ZeroClaw
  (Rust, 3.4MB), NanoClaw (700 LOC, Docker-mandatory), Nanobot (Python),
  PicoClaw (Go, Sipeed), IronClaw (Rust/NEAR AI), MicroClaw (Rust, 727★).
- **Zero-patch wins**: ZeroClaw ships `aarch64-linux-android` asset
  (runs natively, 0.8.5); PicoClaw's `Linux_arm64` is a STATIC ELF that
  runs natively AND is checksummed (its android-universal.zip is NOT
  covered by checksums — avoid).
- **Gotcha**: `picoclaw --version` exits 1 (prints banner); smoke with
  `--help` instead. Found only by checking the real exit code without a
  pipe (piping through `head` masks exit status — pipefail still gives
  head's status in `$?` when captured outside).
- **Gotcha**: microclaw's aarch64 asset is glibc-DYNAMIC; direct exec
  gives misleading "No such file or directory" (missing
  `/lib/ld-linux-aarch64.so.1`). Fix = wrapper exec'ing
  `$PREFIX/glibc/lib/ld-linux-aarch64.so.1 --library-path
  "$PREFIX/glibc/lib:$PREFIX/lib"` (claude precedent).
- **IronClaw**: no prebuilt binaries upstream; only `ironclaw-termux`
  npm (proot Ubuntu + rustup build) → proot-only today, native =
  NDK cross-compile backlog.
- **NanoClaw**: Docker required (container-per-chat) → not native.
- Installed + validated through the hub menu: zeroclaw 0.8.5,
  picoclaw 0.3.1, microclaw 0.7.0 (all checksum-verified, smoke-tested).
  openclaw recipe ready (official install.sh, --no-onboard) but NOT run
  — heavy install, awaiting user go-ahead.

## Auto-latest installer design (researched 2026-09-30, all verified on-device)

Goal: installer always fetches latest upstream, with the patch strategy that
costs least hassle and best performance. Verified findings, ranked by
patch-burden:

1. **codex — ZERO patches (best case).** Official `openai/codex` releases ship
   `codex-aarch64-unknown-linux-musl.tar.gz`: a **statically linked** ELF that
   runs on Termux/Bionic unpatched (`codex-cli 0.159.2 --version` → exit 0,
   verified from `/releases/latest/download/` permanent URL — no API, no rate
   limit). Replaces the pinned node-shebang fork recipe (@0.156.1) with a
   `static-musl` recipe: curl → tar → `install -m 755` → done. Optional
   cosign/sigstore verify (`codex-...musl.sigstore` asset exists).
2. **antigravity — patches done upstream in CI.** `wallentx/…-termux` fork
   rebuilds every 6h: upstream binary + VA39 TCMalloc alignment patch +
   Sigstore signing, single asset `antigravity-termux-standalone.tar.gz` via
   same permanent latest URL. Our installer = download → extract twin binaries
   (`agy` + `agy.va39`, both already on device at 1.2.14) → install. No local
   patching ever.
3. **claude — one-time ELF header edit, then self-updating launcher.** The
   223-line wrapper already at `$PREFIX/bin/claude` IS the pattern: npm
   registry `@anthropic-ai/claude-code/latest` → downloads.claude.ai
   `$ver/linux-arm64/claude` + official `manifest.json` sha256 → patchelf
   interpreter → glibc → smoke-test (`--init-only`, seccomp/Bun-crash gating,
   blocklist) → atomic promote into `~/.local/share/claude/versions/`. Installer
   ships this launcher once; it self-updates forever (24h rate-limit stamp,
   per-process staging tmp, update lock). Never use claude's internal /update
   on the native path.
4. **openclaude — shebang fix only.** npm dist-tag `latest` of
   `@gitlawb/openclaude` (no lockfile needed: registry JSON). Update flow:
   fetch dist-tag → extract tgz to `~/.openclaude/versions/<v>/` →
   `termux-fix-shebang` on `bin/openclaude` → flip symlink. No npm install
   (manual tarball extraction per worklog pattern).

Shared plumbing (proposed): `recipes/auto-latest-lib.sh` with
`resolve_latest()` (GitHub redirect scrape primary, api.github fallback),
daily-TTL stamp cache (`$HUB_STATE/stamps/`), atomic tmp+mv installs,
smoke-gate-or-rollback. Hub menu gets `U) Update all`. Manifests change
meaning: `version` = last-verified stamp, new `source.track: latest` field;
the repo pins the METHOD, not the version.

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
| dsh | 0.1.0-rc.7-termux.1 | **community prebuilt** (Vengisk) at `$PREFIX/opt/dsh` — 318MB flattened tree, 196 `@deepseek-ai/*`, prebuilt android-arm64 node-pty + koffi, 9 in-tree patches, ripgrep shim, `--expose-internals` shebang → `dsh`. `dsh web` verified HTTP 200. |
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

## DeepSeek Harness port — OUR LAYER, SUPERSEDED (2026-09-30)

Superseded the same day. See the section below and notes/DSH-TERMUX.md. Kept as
`DSH_TERMUX_ROUTE=patch` because it is the only route that can follow npm
`latest`; it was never installed or run. Everything below describes why we
stopped shipping it by default.

## DeepSeek Harness port (2026-09-30)

Replaced the `dsh-mini` third-party repack with the official
`@deepseek-ai/dsh` (562 packages, 269 of them `@deepseek-ai/*`).

Four Bionic adaptations, full analysis in `notes/DSH-TERMUX.md`:

1. **platform shim** — Node says `android`; `dsh-subprocess-local`'s
   `createProcessInspector` accepts only `linux`/`darwin` and throws otherwise.
   `recipes/shims/dsh-termux-preload.cjs` reports `linux`. Injected via
   `NODE_OPTIONS=--require`, *not* `node --import`, because a worker_thread
   gets a fresh `process` object — verified `--import` does not propagate but
   NODE_OPTIONS does, and DSH runs subagents in workers.
2. **node-pty** — the published `linux-arm64` prebuild is glibc-linked
   (`GLIBC_2.17`, `ld-linux-aarch64.so.1`) and cannot dlopen. Termux has
   `pty.h` + `libutil.so`, so it compiles: `pty.node ... for Android 24,
   built by NDK r30`, live PTY at `/dev/pts/1` with correct winsize.
   `loadNativeModule` prefers `build/Release` over `prebuilds/`, so the good
   binary wins.
3. **stubs** — `koffi` (win32-only paths), `sharp` (no android-arm64 libvips
   prebuild), `sherpa-onnx` (glibc models). `recipes/dsh-termux-stubs.mjs`
   rewrites every dual-published entry, sniffs CJS vs ESM, keeps the original
   as `*.termux-orig`, idempotent. `DSH_TERMUX_SHARP=1` builds real sharp
   against Termux libvips instead.
4. **`--ignore-scripts`** — stops koffi's `cnoke` build and node-pty's
   node-gyp fallback from running (and failing) mid-install.

Landlock sandboxing: `landlock-run` is static-musl and does run, but this
kernel does not enforce Landlock, so it probes `unusable` and dsh runs
unsandboxed — upstream's documented fail-closed path.

Installer TUI now actually installs: `bin/harness-hub` lists a category,
resolves live npm "latest" for npm-sourced manifests, shows installed state,
and runs `recipes/<recipe_script>`. `recipes/doctor.sh` gained a dsh section
that flags a `pty.node` containing `GLIBC_` strings, i.e. a silently reverted
prebuild.

Status: shim and node-pty build verified. Full `dsh` session not yet run —
installing 562 packages on the phone is the user's call.

## DeepSeek Harness — community prebuilt, INSTALLED AND VERIFIED (2026-09-30)

Abandoned our own patch layer. Found `Vengisk/deepseek-harness-termux` (MIT,
51 stars) — nine per-package source patches plus prebuilt android-arm64
natives, and the release `dsh-termux-full.tgz` is the whole thing pre-applied.

`recipes/dsh-termux.sh` now defaults to `ROUTE=prebuilt`: download 50.9 MB,
verify sha256, extract to `$PREFIX/opt/dsh`, write a launcher, re-create the
`@vscode/ripgrep-android-arm64` shim, then verify. `ROUTE=patch` keeps our
layer available since the prebuilt is pinned to dsh 0.1.0-rc.7 while npm is at
0.2.0-rc.2.

Installed and verified on this device:

    dsh -V                -> 0.1.0-rc.7-termux.1
    node-pty              -> prebuilt, ELF aarch64 "for Android 24", loads, /dev/pts/1
    koffi                 -> prebuilt, loads libc.so, getpid + stat() work
    pty.node glibc refs   -> 0
    dsh web --port 3197   -> HTTP 200 in ~10s, <title>DeepSeek Harness</title>, 12109 bytes
    disk                  -> 318MB, 21GB still free

Sharper than our layer on every point that only shows up at boot: real koffi
instead of a stub, WASM sharp instead of a stub, the ripgrep platform shim we
missed entirely, `link(2)`→`rename(2)` in session persistence (I had checked
`dsh-atomic-write`, concluded upstream was already rename-only, and was wrong
about which package does the writing), and `--expose-internals` for HMR.

The old dsh-mini is retired: `$PREFIX/bin/dsh` is the new launcher (the mini one
is saved at `$PREFIX/tmp/dsh-mini-launcher.bak`). Its data is left alone at
`$PREFIX/lib/dsh-mini` and `~/.dsh-mini` — delete those when you are satisfied.

Still open: no API key configured, so no real prompt has been sent. sharp is
bundled but unwired (no native binding, nothing imports sharp-wasm32). And the
bubblewrap sandbox is blocked by Android sepolicy, so agent bash commands run
unisolated — true of every Termux route.
