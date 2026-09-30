# state.md — Termux Harness TUI (live status)

Updated: 2026-09-30, late evening (after routing layer integration & prebuilt releases)

## PROJECT LOCATION (exact, next agent start here)

```
/storage/emulated/0/LLM/termux-harness-tui/
```

- This is THE project: git repo, branches `master` and `main` in sync, pushed to
  https://github.com/therealfreddied/termux-harness-tui.
- Lives on sdcard/FUSE: no exec bits, no file locks. Run scripts with
  `bash <script>`, never `./<script>`. Git needs `safe.directory`.
- Clone with `git clone https://github.com/therealfreddied/termux-harness-tui.git`
  if sdcard misbehaves; prefer working on sdcard since notes live here.

## Current goal (single focus)

OmniRoute 3.8.51 server running on the phone. CLI + doctor already work; the
ONLY missing piece is `dist/server.js`, which must be built on the user's VPS
because on-device webpack/Turbopack builds are IMPOSSIBLE (final — never retry).

**Everything else major is DONE**: dsh (community prebuilt), platform-giants
(claude/codex/gemini/pi), hermes (our own prebuilt), agy, openclaude, grok,
cline, bwb, pentestcode, routing CLIs.

## Exact state of every piece

| Piece | State | Location |
|---|---|---|
| Repo | updated with routing manifests & prebuilt releases | sdcard path / GitHub master |
| **Platform Giants** | **ALL 5 DONE** — claude 2.1.286 (musl loader, 723KB, verified), codex 0.156.1 (@mmmbuto npm), gemini 0.46.0, pi 0.99.1, grok | manifests+recipes updated & in-tree |
| **dsh (DeepSeek)** | INSTALLED + VERIFIED — community prebuilt, 318 MB, `dsh web` HTTP 200 | `$PREFIX/opt/dsh`, launcher `$PREFIX/bin/dsh` |
| **hermes** | INSTALLED + works — sha256-pinned prebuilt hosted on `therealfreddied/termux-harness-tui` release | `manifests/hermes.json`, `recipes/hermes-termux.sh` |
| **Routing Layer** | **ALL 3 INTEGRATED** — `cli-proxy-api` (hosted prebuilt), `9router` (npm tarball + Termux machine-id patch, port 20129), `omniroute` | manifests + recipes in-tree |
| gemini + pi shebang fix | were broken (`#!/usr/bin/env`); `termux-fix-shebang` fixed on-device | applied 2026-09-30 |
| `bin/harness-hub` | `latest_of()` bugfix: scoped npm URLs now resolve npm-latest badges | committed `619847b` |
| `recipes/omniroute-termux.sh` | done; `full` variant HARD-BLOCKED on-device | repo |
| `~/omniroute/dist/server.js` | MISSING — waiting on VPS build | — |
| VPS build + GH release | EXTERNAL: user relays handoff to VPS OpenClaw | — |
| Leaked API key | NEEDS ROTATION (user action) | — |

**Claw-fleet files were committed by the other agent** (`0845b75`); their
`manifests/schema.json` edits and notes are in-tree now. Still stage by
explicit path only — never `git add -A`.

## Prebuilt-verdict table (research conclusion, 2026-09-30)

- **Tier 1 official**: pi (pi.dev Termux docs, npm), gemini (pure-JS npm),
  aider (PyPI 0.86.2), hermes (Nous signed APT exists but docs say "Termux
  broken, fix in progress" → our own prebuilt is the route meanwhile).
- **Tier 2 community prebuilt**: codex (@mmmbuto, 0.156.1-termux.1),
  opencode (bd-loser/opencode-bionic .deb same-day — NOT used, install is
  DO-NOT-TOUCH), agy (wallentx, native Bionic NDK r27d), openclaude
  (@gitlawb npm), grok (Duro02), dsh (Vengisk), cline (bun+glibc, works).
- **Tier 3 none**: claude-code (official linux-arm64-musl binary + Aarstad
  723KB musl loader, verified 2.1.286), goose (glibc only; aaif fork has
  musl tarball), openclaw (glibc-ld.so installer).
- **agy = antigravity**: same binary; `antigravity` is a symlink to `agy`.

## NEXT actions (in order, do not reorder)

1. **Wait for / fetch the VPS artifact**: GH release
   `omniroute-3.8.51-termux` on `therealfreddied/termux-harness-tui`
   containing `omniroute-dist-3.8.51-backend.tar.gz`. If the user says the VPS
   finished, download:
   `gh release download omniroute-3.8.51-termux -R therealfreddied/termux-harness-tui -p '*backend.tar.gz' -D $PREFIX/tmp/opencode/`
2. **Integrate**: `bash recipes/omniroute-post-install.sh <tarball>` —
   extracts dist/ into ~/omniroute, swaps the Bionic sqlite addon into
   dist/node_modules, patches machine-id inside dist, runs patch-guard.
3. **Verify**: `OMNIROUTE_SERVER_HOST=127.0.0.1 omniroute serve --no-open`,
   then `curl -s http://127.0.0.1:20128/api/health` and
   `curl -s http://127.0.0.1:20128/v1/models`. Ask before wiring
   ANTHROPIC_BASE_URL / OPENAI_BASE_URL.
4. **dsh, if the user wants a real prompt**: set `DEEPSEEK_API_KEY`, then
   `dsh web` (port 3080) or `dsh`. Booting and serving is already proven; a
   completed inference is not.
5. **Hermes future upgrade (optional)**: when NousResearch fixes their
   Termux APT repo, switch `hermes.json` to `pkg install` route.
6. **Backlog (only after 1-5)**: claw-fleet Rust cross-compiles
   (zeroclaw/ironclaw/microclaw, NDK r27b ready), goose-musl experiment,
   Twilight0/termux-repo PR as a distribution channel, SecEng pkg adds
   (nmap, dnsutils — needs user ask-approval).

## Hard rules for the next agent

- **NEVER build the full OmniRoute dashboard on the phone.** The recipe
  hard-refuses it; do not pass `OMNIROUTE_ALLOW_FULL_ON_DEVICE=1`. It wedges
  the device instead of failing.
- NEVER touch the opencode install (`~/.agents/opencode/launcher.sh`,
  opencode 1.18.31 — user's primary driver). No patches, wraps, updates.
- NEVER retry on-device webpack/Next builds. No exceptions.
- NEVER `git add -A` — stage by explicit path only.
- `npm install*` denied by permission rules → registry-tarball manual
  extraction, or `pkg` with ask-approval only. This is why dsh ships as a
  prebuilt tarball. (Thin npm recipes are WRITTEN for the user to run.)
- No `rm -rf` on directories; targeted `rm -f` on files only.
- Server binds loopback ONLY (`OMNIROUTE_SERVER_HOST=127.0.0.1`).
- Low-memory device: use the Grep tool / `rg` (never recursive grep via bash),
  no npm/gradle/docker, no dev servers beyond omniroute/dsh themselves.
- Scratch dir: `$PREFIX/tmp/opencode/` (never `/tmp` — Android ships it mode
  711 owned by `shell`).
- If asked "does it actually work?", the honest answer must lead. A dry run
  with a stand-in is not an end-to-end result.
