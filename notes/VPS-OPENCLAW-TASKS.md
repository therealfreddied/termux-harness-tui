# VPS OpenClaw — Task Brief (paste-ready)

Date: 2026-09-30. Repo: `therealfreddied/termux-harness-tui` (master @ `f94d332`).

## Context — what is already done, do not redo

- The Termux harness hub is feature-complete on-device: 33 manifests, 28
  recipes, all validated; TUI (`bin/harness-hub`) renders 8 categories with
  live npm-latest badges. Harnesses installed and verified on the phone
  (SM-S911W aarch64, Bionic, Node 24.18): claude 2.1.285, codex 0.156.1,
  gemini 0.46.0, pi 0.99.1, grok, dsh 0.1.0-rc.7 (318 MB prebuilt), hermes
  0.19.0 (our own prebuilt), agy 1.2.14, openclaude 0.31.0, cline, bwb,
  pentestcode, cli-proxy-api 8.0.4, 9router, omniroute CLI.
- Releases already published on this repo: `hermes-0.19.0-termux` (Latest),
  `cli-proxy-api-8.0.4-termux`, `vps-kit-omniroute-3.8.51` (build kit only —
  no backend artifact yet).
- `.github/workflows/build-omniroute.yml` exists but its two runs FAILED:
  both canceled ~7.5 min in with a runner shutdown SIGTERM (not a compile
  error; the `test -f dist/server.js` guard never fired).

## Ground rules (hard)

1. Work on a **feature branch**; never push master directly.
2. Never `git add -A` — stage files explicitly.
3. You cannot verify anything on the phone. Do not claim on-device results.
   Final integration is done by the user's Termux agent.
4. Never attempt a full Next.js dashboard build — backend `dist/server.js`
   only. The on-device recipe hard-blocks full builds for a reason.
5. Be honest in reports: a canceled run or missing artifact is a failure,
   not "almost done".

## Task 1 (P0) — OmniRoute backend dist

Goal: release `omniroute-3.8.51-termux` on this repo containing
`omniroute-dist-3.8.51-backend.tar.gz` (the compiled `dist/server.js` tree
for linux/arm64 Node 24, backend only, no dashboard bundles).

Two acceptable paths, pick whichever works first:
- **A. Fix CI**: diagnose why `Build OmniRoute Termux Standalone` runs get
  SIGTERM-canceled at ~7.5 min (runner shutdown, 2×). Consider reducing
  build memory/work, splitting the job, or self-hosting a runner on the VPS.
- **B. Build directly on the VPS**: follow `notes/VPS-BUILD-HANDOFF.md`,
  then `gh release create omniroute-3.8.51-termux <tarball>` with the exact
  asset name above. The on-device integrator already exists:
  `recipes/omniroute-post-install.sh` (extracts dist/, swaps Bionic sqlite
  addon, patches machine-id, runs patch-guard).

Definition of done: release exists with the tarball; `tar -tzf` on the
tarball shows `dist/server.js` and `dist/node_modules/` with the
`better-sqlite3` addon present.

## Task 2 (P1) — recipe CI smoke test

In termux-docker (or a proot Termux rootfs) on the VPS, run the thin recipes
from a clean image: `recipes/{codex,gemini,pi}-termux.sh` (npm routes) and
record pass/fail + versions. Add as a second workflow job or a script under
`scripts/`. Do NOT run the claude recipe (needs glibc loader + interactive
installer) or any recipe that spawns dev servers.

Definition of done: green log proving `codex --version`, `gemini --version`,
`pi --version` work from a bare Termux image, committed on a branch.

## Task 3 (P2) — release-tag resolver

`scripts/resolve-latest.sh`: for every manifest whose `source.url` points at
registry.npmjs.org or a GitHub repo, fetch the current latest (npm
dist-tag / GitHub release tag) and print `name<TAB>manifest-version<TAB>live-latest`
(e.g. for a later `--update-manifests` mode). Bash + jq + curl only — it
runs on Termux too.

Definition of done: script committed; run against the repo prints a correct
table for at least the npm-sourced manifests (codex/gemini/pi/openclaude).

## Out of scope

Anything on the phone (dsh API key, doctor additions, omniroute integration),
the claw-fleet Rust cross-compiles, and the Hermes official-APT switch (parked
until NousResearch fixes their repo).
