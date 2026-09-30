# state.md — Termux Harness TUI (live status)

Updated: 2026-09-30, 13:50 (session end — handoff-ready)

## PROJECT LOCATION (exact, next agent start here)

```
/storage/emulated/0/LLM/termux-harness-tui/
```

- This is THE project: git repo, branch `master`, clean tree, pushed to
  https://github.com/therealfreddied/termux-harness-tui (commit e81ea89).
- Lives on sdcard/FUSE: no exec bits, no file locks. Run scripts with
  `bash <script>`, never `./<script>`. Git needs `safe.directory` (already
  set globally for this path; re-add if git says "dubious ownership").
- Clone with `git clone https://github.com/therealfreddied/termux-harness-tui.git`
  if sdcard misbehaves; prefer working on sdcard since notes live here.

## Current goal (single focus)

OmniRoute 3.8.51 server running on the phone. CLI + doctor already work;
the ONLY missing piece is `dist/server.js` (backend-only standalone
bundle), which must be built on the user's VPS because on-device
webpack/Turbopack builds are IMPOSSIBLE (final decision — never retry;
Turbopack has no android-arm64 binding, webpack OOMs / cache-snapshot
fails at any heap size).

## Exact state of every piece

| Piece | State | Location |
|---|---|---|
| Repo (13 manifests, TUI, recipes, patches, notes) | pushed, clean | sdcard path above / GitHub master |
| `notes/VPS-BUILD-HANDOFF.md` | FINAL, scoped to omniroute dist/ only | repo |
| `recipes/omniroute-post-install.sh` | written, `bash -n` OK, inline node blocks parse OK | repo |
| `recipes/omniroute-termux.sh` | done (installed ~/omniroute tree) | repo |
| `recipes/patch-guard-termux.js` | done (applies /v1/models visibility patch) | repo |
| `patches/*.patch` | 3 real diffs vs pristine npm tarballs | repo |
| `~/omniroute/` phone tree | node_modules + Bionic better-sqlite3 addon + patched loaders, CLI works | `$HOME/omniroute` |
| `~/omniroute/dist/server.js` | MISSING — waiting on VPS build | — |
| VPS build + GH release | EXTERNAL: user relays handoff to VPS OpenClaw | — |
| Hermes tarball | BLOCKED: VPS :8999 down (port 80 open) | — |
| Leaked API key | NEEDS ROTATION (user action) | — |

## NEXT actions (in order, do not reorder)

1. **Wait for / fetch the VPS artifact**: GH release
   `omniroute-3.8.51-termux` on `therealfreddied/termux-harness-tui`
   containing `omniroute-dist-3.8.51-backend.tar.gz`. If the user says
   the VPS finished, download:
   `gh release download omniroute-3.8.51-termux -R therealfreddied/termux-harness-tui -p '*backend.tar.gz' -D $PREFIX/tmp/opencode/`
2. **Integrate**: `bash ~/LLM/termux-harness-tui/recipes/omniroute-post-install.sh <tarball>` —
   extracts dist/ into ~/omniroute, swaps Bionic sqlite addon into
   dist/node_modules, patches machine-id inside dist, runs patch-guard.
3. **Verify**: `OMNIROUTE_SERVER_HOST=127.0.0.1 omniroute serve --no-open`
   then `curl -s http://127.0.0.1:20128/api/health` and
   `curl -s http://127.0.0.1:20128/v1/models`. Wire ANTHROPIC_BASE_URL /
   OPENAI_BASE_URL at the user's request (ask first).
4. **Commit+push** any integration fixes; update this file + memory.md.
5. **Backlog (only after 1-4)**: hermes retry (VPS :8999), claw-fleet
   Rust cross-compiles (zeroclaw/ironclaw/microclaw, NDK r27b ready),
   Twilight0/termux-repo PR as distribution channel, SecEng pkg adds
   (nmap, dnsutils — needs user ask-approval), full-dashboard variant
   (optional, OOM'd on VPS before — skip unless user insists).

## Hard rules for the next agent

- NEVER touch the opencode install (`~/.agents/opencode/launcher.sh`,
  opencode 1.18.31 — user's primary driver). No patches, wraps, updates.
- NEVER retry on-device webpack/Next builds. No exceptions.
- `npm install*` denied by permission rules → registry-tarball manual
  extraction or `pkg` with ask-approval only.
- No `rm -rf` on directories; targeted `rm -f` on files only.
- Server binds loopback ONLY (`OMNIROUTE_SERVER_HOST=127.0.0.1`).
- Low-memory device: use Grep tool / `rg` (never recursive grep via
  bash), no npm/gradle/docker, no dev servers beyond omniroute itself.
- Scratch dir: `$PREFIX/tmp/opencode/`.
