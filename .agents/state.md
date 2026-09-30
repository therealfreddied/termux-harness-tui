# state.md — Termux Harness TUI (live status)

Updated: 2026-09-30 (session end)

## Current goal

Get OmniRoute 3.8.51's server running on the phone by having the VPS
compile `dist/` (backend-only). Repo is public at
https://github.com/therealfreddied/termux-harness-tui — the VPS OpenClaw
instance reads `notes/VPS-BUILD-HANDOFF.md` and executes it.

## Done this session (all pushed to GitHub, commit 357470c + follow-ups)

- Repo created + pushed: manifests (13 tools, schema-validated), recipes
  (`doctor.sh`, `omniroute-termux.sh`, `patch-guard-termux.js`),
  README, PLAN/WORKLOG notes.
- `patches/` — 3 real context diffs generated against pristine npm
  tarballs: better-sqlite3 binding.js (android→source build),
  node-machine-id (android guid case, ESM copy; dist copy is patched
  in-place on-device), @swc/core index.js (wasm fallback).
- `notes/VPS-BUILD-HANDOFF.md` — scoped to OmniRoute ONLY: build
  `dist/` backend-only on VPS (pure JS, no NDK/patches needed there),
  ship tarball as GH release, phone integrates via post-install script.
- README rewritten around the verified-installs table + security notes.
- On-device webpack build ABANDONED (user decision, final): Turbopack has
  no android-arm64 binding; webpack OOMs / fails cache-snapshot even at
  3GB heap + 12GB swap. Never retry on-device.

## Blockers

- VPS side must run the build + create the GH release (user passes the
  handoff to their VPS OpenClaw instance).
- `recipes/omniroute-post-install.sh` — write it (small; see NEXT).
- Hermes tarball still stuck: VPS HTTP server on 8999 was down.
- Leaked API key in chat logs needs rotation (user action).

## NEXT actions (in order)

1. Write `recipes/omniroute-post-install.sh` (extract dist tarball →
   `~/omniroute/`, swap Bionic better-sqlite3 addon in, apply android
   patches inside `dist/node_modules/`, run patch-guard, print serve cmd).
2. Wait for VPS tarball → run post-install → `omniroute serve --no-open`
   → verify `/api/health` + `/v1/models`.
3. Commit + push everything (sdcard FUSE shows exec-bit loss — re-add).
4. Later: Twilight0 repo PR as distribution channel; claw-fleet Rust
   cross-compiles; hermes retry.
