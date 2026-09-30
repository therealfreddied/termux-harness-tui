# memory.md — Termux Harness TUI (persistent knowledge, append-only)

## 2026-09-30 — session record

### What HAD been done (before this session, per notes/PLAN.md + WORKLOG.md)

- 13 harnesses verified working natively on Termux aarch64 (SM-S911W,
  Android 16, 8GB RAM, no proot): claude 2.1.285, opencode 1.18.31
  (DO-NOT-TOUCH primary driver), codex 0.156.1, openclaude 0.31.0,
  agy/antigravity 1.2.14, cline 3.0.61, grok 1.0.41, dsh-mini 0.1.12,
  bwb 4.0.1 (MCP, 26 tools verified), pentestcode 0.2.6 (musl shim),
  cli-proxy-api 8.0.4 (on-device Go rebuild), 9router 0.5.91,
  omniroute 3.8.51 (CLI+doctor; server bundle pending VPS build).
- Routing layer: 9router health-verified on :20129; CLIProxyAPI 8.0.4
  rebuilt on-device; omniroute install recipe done end-to-end except
  dist/server.js.
- Repo scaffolding: bin/harness-hub TUI, manifests/*.json + schema.json,
  recipes/doctor.sh.

### What was done THIS session

- Killed the on-device webpack build attempts for good (see gotcha below).
- Created GitHub repo `therealfreddied/termux-harness-tui`, pushed
  commit 357470c (manifests, recipes, notes, README).
- Generated `patches/` as real context diffs vs pristine npm tarballs:
  better-sqlite3-13.0.3 binding.js (android→null prebuild), node-machine-id
  1.1.12 index.js (android guid case + $HOME/.omniroute/machine-id),
  @swc/core 1.16.1 index.js (wasm fallback).
- Rewrote `notes/VPS-BUILD-HANDOFF.md` scoped to OmniRoute only, after
  user corrected scope: NOT the whole harness repo — just the omniroute
  files to compile + how to compile them. Key insight recorded there:
  dist/ is pure JS → VPS needs NO Termux patches, NO NDK; better-sqlite3
  is already Bionic-compiled on the phone.
- Wrote `.agents/` memory bank (this file + state.md) via /init.

### Plans (agreed, not started)

- VPS OpenClaw instance builds omniroute `dist/` backend-only
  (`OMNIROUTE_BUILD_BACKEND_ONLY=1 npm run build:backend` after
  `npm ci`), ships tarball as GH release on termux-harness-tui.
- Phone-side `recipes/omniroute-post-install.sh` integrates it (TODO,
  next action #1 in state.md).
- Full dashboard variant optional (OOM'd on VPS before — skip unless
  headroom; phone only needs the API plane).
- Distribution idea: PR recipes to Twilight0/termux-repo (community APT
  repo) later.

### STILL needed / open

1. `recipes/omniroute-post-install.sh` — the only missing phone-side
   piece (see state.md NEXT #1 for spec).
2. VPS build + GH release (external dependency, user relays handoff).
3. Hermes agent tarball (VPS :8999 was down; port 80 open).
4. Rotate the API key that leaked into chat logs.
5. Claw-fleet Rust cross-compiles (zeroclaw, ironclaw, microclaw) —
   NDK r27b toolchain already set up, wish-list item.
6. pkg additions for SecEng tooling (nmap, dnsutils, netcat-openbsd) —
   user go-ahead pending (permission rules require ask approval).

### Environment gotchas (consolidated — details in notes/WORKLOG.md)

- `process.platform` = `android` in Termux node → npm native prebuilds
  never match; glibc prebuilds segfault under Bionic node. Compile from
  source or patch loaders.
- Next.js 16 on-device build: IMPOSSIBLE (user verdict, final). Turbopack
  lacks android-arm64 binding; webpack fails "Unable to snapshot resolve
  dependencies" + OOM at any heap size tried. Server bundles come from
  the VPS.
- Go: GOOS=linux binaries hit seccomp (faccessat2/439) → rebuild
  GOOS=android with Termux Go; pion/anet dep needs
  `-ldflags="-checklinkname=0"`.
- musl ELFs run via Alpine loader shim ($PREFIX/lib/musl/) — no glibc.
- `npm install` blocked by permission rules → registry-tarball manual
  extraction into node_modules (worked for 20-pkg bwb closure).
- sdcard storage (this repo): no exec bits, no locks — run via
  `bash script.sh`; git needs `safe.directory` config.
- Scratch space: `$PREFIX/tmp/opencode/` (not /tmp).
- sha256sum -c needs upstream filenames — rename tarballs first.
