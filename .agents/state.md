# state.md — Termux Harness TUI (live status)

Updated: 2026-09-30, 15:20 (after dsh swap to the community pre-patched build)

## PROJECT LOCATION (exact, next agent start here)

```
/storage/emulated/0/LLM/termux-harness-tui/
```

- This is THE project: git repo, branch `master`, pushed to
  https://github.com/therealfreddied/termux-harness-tui (commit `b91b3bd`).
- Lives on sdcard/FUSE: no exec bits, no file locks. Run scripts with
  `bash <script>`, never `./<script>`. Git needs `safe.directory`.
- Clone with `git clone https://github.com/therealfreddied/termux-harness-tui.git`
  if sdcard misbehaves; prefer working on sdcard since notes live here.

## Current goal (single focus)

OmniRoute 3.8.51 server running on the phone. CLI + doctor already work; the
ONLY missing piece is `dist/server.js`, which must be built on the user's VPS
because on-device webpack/Turbopack builds are IMPOSSIBLE (final — never retry).

**dsh is DONE and installed.** Do not revisit it unless the user asks; the
remaining dsh items are a nicety (API key) and a known-broken nicety (sharp).

## Exact state of every piece

| Piece | State | Location |
|---|---|---|
| Repo (manifests, TUI, recipes, patches, notes) | pushed @ `b91b3bd` | sdcard path / GitHub master |
| **dsh** | **INSTALLED + VERIFIED** — community prebuilt, 318 MB, `dsh web` HTTP 200 | `$PREFIX/opt/dsh`, launcher `$PREFIX/bin/dsh` |
| dsh our-own patch layer | abandoned, kept only as `DSH_TERMUX_ROUTE=patch` | `recipes/dsh-termux.sh` |
| dsh-mini (old 3rd-party repack) | RETIRED; launcher saved, data left on disk | `$PREFIX/tmp/dsh-mini-launcher.bak`, `$PREFIX/lib/dsh-mini`, `~/.dsh-mini` |
| `recipes/omniroute-post-install.sh` | written, `bash -n` OK | repo |
| `recipes/omniroute-termux.sh` | done; `full` variant now HARD-BLOCKED on-device | repo |
| `~/omniroute/dist/server.js` | MISSING — waiting on VPS build | — |
| VPS build + GH release | EXTERNAL: user relays handoff to VPS OpenClaw | — |
| Hermes tarball | BLOCKED: VPS :8999 down (port 80 open) | — |
| Leaked API key | NEEDS ROTATION (user action) | — |

**Untracked, owned by ANOTHER agent — do not touch, do not commit:**
`notes/CLAW-FLEET.md`, `manifests/{ironclaw,microclaw,nanoclaw,openclaw,picoclaw,zeroclaw}.json`,
`recipes/{microclaw,openclaw,picoclaw,zeroclaw}-termux.sh`, plus an unstaged
`manifests/schema.json` edit adding `prefab-android` / `glibc-shim` to the
`recipe` enum. User confirmed these are intentional and working. Stage by
explicit path only — never `git add -A`.

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
5. **Cleanup, only after the user is satisfied with dsh**: remove
   `$PREFIX/lib/dsh-mini` and `~/.dsh-mini` (old third-party repack + its
   sessions). Deliberately left in place so the change is reversible.
6. **Backlog (only after 1-5)**: hermes retry (VPS :8999), claw-fleet Rust
   cross-compiles (zeroclaw/ironclaw/microclaw, NDK r27b ready),
   Twilight0/termux-repo PR as a distribution channel, SecEng pkg adds
   (nmap, dnsutils — needs user ask-approval).

## Hard rules for the next agent

- **NEVER build the full OmniRoute dashboard on the phone.** The recipe
  hard-refuses it; do not pass `OMNIROUTE_ALLOW_FULL_ON_DEVICE=1`. It wedges
  the device instead of failing.
- NEVER touch the opencode install (`~/.agents/opencode/launcher.sh`,
  opencode 1.18.31 — user's primary driver). No patches, wraps, updates.
- NEVER retry on-device webpack/Next builds. No exceptions.
- NEVER `git add -A` — another agent has uncommitted work in this tree.
- `npm install*` denied by permission rules → registry-tarball manual
  extraction, or `pkg` with ask-approval only. This is why dsh ships as a
  prebuilt tarball.
- No `rm -rf` on directories; targeted `rm -f` on files only.
- Server binds loopback ONLY (`OMNIROUTE_SERVER_HOST=127.0.0.1`).
- Low-memory device: use the Grep tool / `rg` (never recursive grep via bash),
  no npm/gradle/docker, no dev servers beyond omniroute/dsh themselves.
- Scratch dir: `$PREFIX/tmp/opencode/` (never `/tmp` — Android ships it mode
  711 owned by `shell`).
- If asked "does it actually work?", the honest answer must lead. A dry run
  with a stand-in is not an end-to-end result.
