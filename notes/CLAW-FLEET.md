# Claw Fleet — research notes (2026-09-30)

Goal: installer supports the most prevalent "*claw*" agents natively on
Termux. PLAN.md's six: openclaw, zeroclaw, picoclaw, nanoclaw, ironclaw,
microclaw. Sources: lushbinary.com 6-way comparison (2026-02), waelmansour
7-way comparison, GitHub, npm.

## The landscape (popularity ≈ stars / prevalence)

| Agent | Lang | Footprint | Stars | Notes | Termux fit |
|---|---|---|---|---|---|
| **OpenClaw** | TypeScript | ~28MB dist, 1GB+ RAM | 186K+ | The original (ex-Clawdbot/Moltbot, Peter Steinberger, Nov 2025). 10+ channels, ClawHub skills. CVE-2026-25253 (patched v2026.2.2). Node runtime. | Heavy but node-based → feasible natively (our dsh/bwb precedent). |
| **ZeroClaw** | Rust | 3.4MB bin, <5MB RAM, ~10ms boot | high | zeroclaw-labs. Trait-based; 22+ providers; SQLite hybrid memory; `zeroclaw migrate openclaw` import. v0.8.4. | Static Rust bin — ideal; NDK cross-compile already on wish-list (state.md #5). |
| **NanoClaw** | TypeScript | ~50MB, ~50MB RAM | 7K+ (Jan 2026) | Gavriel C; 700 LOC; container-per-chat-group **Docker** isolation; WhatsApp (Baileys) only; Claude Agent SDK. | ⚠ Docker required → no native Termux. Needs proot/Docker alternative or skip. |
| **PicoClaw** | Go | ~8MB bin, <10MB RAM | moderate | sipeed/picoclaw — independent Go rewrite (NOT a fork), for $10 boards (LicheeRV Nano RISC-V). Telegram+Discord. | Go static binary → on-device Termux Go rebuild (GOOS=android) or prebuilt arm64 release. |
| **IronClaw** | Rust | small, ~5MB RAM | moderate | NEAR AI (NEARCON 2026). TEE-backed, AES-256-GCM vault, per-tool sandbox, credential-leak scanning. | **`ironclaw-termux` exists on npm (v1.8.7)** — dedicated Termux port already! |
| **MicroClaw** | Rust | small | 727 | microclaw/microclaw — inspired by nanoclaw, channel-agnostic core + platform adapters (Telegram first). | Rust → same NDK cross-compile path as zeroclaw/ironclaw. |
| Nanobot (adjacent) | Python | 191MB on Pi | 9K+ | HKUDS, 4K LOC, not "*claw*"-named but in family. Docker-ish deploy. | Python on Termux OK but not in our six. |
| MaxClaw, KimiClaw | — | — | small | mentioned in waelmansour 7-way; too niche for now. | — |

## Key facts collected

- **OpenClaw**: WebSocket Gateway + Pi agent runtime; skills marketplace
  ClawHub; DM pairing/allowlist security; 430K LOC TS; MIT.
- **ZeroClaw**: `zeroclaw-labs/zeroclaw` releases; quickstart =
  `cargo build --release` OR prebuilt; onboard = `zeroclaw onboard
  --api-key …`; daemon mode. Config-swappable traits. Lower security risk
  (localhost bind, workspace scoping, encrypted secrets at rest).
- **NanoClaw**: launched 2026-01-31 MIT; container isolation per WhatsApp
  group; Anthropic-only. Docker is mandatory for its model → flag in
  manifest as proot/docker-needed.
- **PicoClaw**: single static Go binary, multi-arch (RISC-V/ARM/x86),
  ~1s startup.
- **IronClaw**: docs.ironclaw.com; NEAR AI Cloud TEE focus, but
  ironclaw-termux npm package proves native Android path exists.
- **MicroClaw**: Rust rewrite of nanoclaw's ideas without Docker
  (presumably) — verify install method.

## Install-method research (verified via registry/GitHub API 2026-09-30)

- [x] **OpenClaw** — `npm install -g openclaw` (npm `openclaw`, latest
  2026.9.7, published <24h ago → extremely active). Node 22+ required.
  Hosted curl installer at docs.openclaw.ai/install (clears npm
  min-release-age freshness filters). Repo has own installer internals
  (git checkout vs global install choice).
- [x] **ZeroClaw** — `zeroclaw-labs/zeroclaw` releases. Latest **v0.8.5**
  with **`zeroclaw-aarch64-linux-android.tar.gz`** ← NATIVE ANDROID asset,
  zero patching! Also aarch64-musl, aarch64-gnu, `install.sh`,
  `SHA256SUMS`, SBOM (cdx+spdx), verification tarball. `zeroclaw
  onboard --api-key …` then `zeroclaw daemon`.
- [x] **PicoClaw** — `sipeed/picoclaw` releases. Latest **v0.3.1** with
  **`picoclaw-android-universal.zip`** ← NATIVE ANDROID asset!
  Also `picoclaw_Linux_arm64.tar.gz` (fallback) + `picoclaw_0.3.1_checksums.txt`.
- [x] **MicroClaw** — `microclaw/microclaw` releases. Latest **v0.7.0**,
  assets: `microclaw-0.7.0-aarch64-linux-gnu.tar.gz` (glibc dynamic →
  needs our glibc loader recipe like claude; no android/musl asset),
  plus `-full-` and `-work-` variants (3 flavors) and `SHA256SUMS.txt`.
  Small: 727 stars. glibc shim recipe likely works (Bionic can't run it directly).
- [x] **NanoClaw** — `gavrielc/nanoclaw` (+ mirror `nanocoai/nanoclaw`),
  latest **v2.4.0**. **Docker is MANDATORY**: installer `nanoclaw.sh`
  provisions Node+pnpm+Docker, agents each run in their own Linux
  container, and onboarding hands off to Claude Code. No releases
  (git-clone flow). → **NOT native-Termux-installable** (no Docker on
  Android); proot only. Manifest documents this; no native recipe.
- [x] **IronClaw** — upstream `nearai/near-ironclaw` (no releases) and
  community `JoasASantos/ironclaw` (no releases → **no prebuilt bins
  anywhere**). `ironclaw-termux` npm (v1.8.7, mithun50) is a wizard that
  does **proot**: `pkg install proot-distro` → Ubuntu → rustup →
  `git clone JoasASantos/ironclaw` → cargo build inside proot. Also ships
  `bin/ironclawx` + `bin/openclawx` wrappers + `lib/bionic-bypass.js`.
  → Native path = NDK cross-compile (state.md backlog #5). Manifest
  documents proot route as the working one.

## Verified on-device facts (2026-09-30)

- Device node = **v24.18.0** → satisfies OpenClaw's `>=24.16 <25` ✓
  (native OpenClaw install viable; openclaw.bin = `openclaw.mjs`).
- **OpenClaw official installer confirmed live (HTTP 200)**:
  `curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard`
  (non-interactive flag verified in docs; also `install-cli.sh` for a
  `~/.openclaw` local prefix). In-tree updater: `openclaw update
  --channel stable`. npm `openclaw` = 2026.9.7.
- **ZeroClaw**: asset names are VERSIONLESS → permanent
  `/releases/latest/download/zeroclaw-aarch64-linux-android.tar.gz`
  works (same trick as codex/grok), plus `SHA256SUMS` (also stable name).
- **PicoClaw**: asset names VERSIONED (`picoclaw_0.3.1_checksums.txt`) →
  resolve tag via redirect scrape first, then tag-pinned URLs.
- **MicroClaw**: same — versioned asset names (`microclaw-0.7.0-…`),
  `SHA256SUMS.txt` stable. aarch64 asset is **linux-gnu (glibc
  dynamic)** → needs our glibc loader wrapper (claude precedent);
  3 flavors: base / -full / -work (install base, note the others).

## On-device probe results (2026-09-30, downloads via /releases/latest)

- **zeroclaw**: `zeroclaw-aarch64-linux-android.tar.gz` = `zeroclaw` binary
  (root) + `web/dist/` dashboard. Runs natively: **`zeroclaw 0.8.5`,
  exit 0, ZERO patching**. `SHA256SUMS` line matches download filename
  → plain `sha256sum -c` works.
- **picoclaw**: android zip = `arm64-v8a/libpicoclaw{,-web}.so` (actually
  bionic PIE execs w/ `/system/bin/linker64` — they run) BUT the
  checksums file **omits the android zip** (unverifiable). → Use
  **`picoclaw_Linux_arm64.tar.gz`: `picoclaw` is a STATICALLY linked
  aarch64 ELF (native, checksummed) AND is covered by
  `picoclaw_<ver>_checksums.txt`**. Tarball = `picoclaw` +
  `picoclaw-launcher` + LICENSE + README.
  **CLI quirk**: `picoclaw --version` prints banner then **exits 1**
  (unknown flag); `--help`, `-h`, `version`, no-args all exit 0
  → smoke test uses `--help`, manifest `post_install` likewise.
- **microclaw**: tarball = single `microclaw`, glibc dynamic
  (interp `/lib/ld-linux-aarch64.so.1` → direct exec fails). **Runs via
  loader wrapper**: `$PREFIX/glibc/lib/ld-linux-aarch64.so.1
  --library-path "$PREFIX/glibc/lib:$PREFIX/lib" microclaw` →
  **`microclaw 0.7.0`, exit 0**. `SHA256SUMS.txt` (stable name) covers it.
- **openclaw**: NOT installed (big node install — user opt-in). Node
  24.18.0 ✓ satisfies engines `>=24.16 <25 || >=26.1`; installer URL
  live (HTTP 200).

## Per-claw install plan for the hub

| Claw | Recipe | Method |
|---|---|---|
| openclaw | `recipes/openclaw-termux.sh` | official `install.sh \| bash -s -- --no-onboard` after node>=24.16 check; smoke `openclaw --version` |
| zeroclaw | `recipes/zeroclaw-termux.sh` | latest/download android tarball + SHA256SUMS → lib dir + bin wrapper (zero patch) |
| picoclaw | `recipes/picoclaw-termux.sh` | redirect-scrape tag → tag-pinned `picoclaw_Linux_arm64.tar.gz` (static!) + checksums → `$PREFIX/bin/picoclaw` |
| microclaw | `recipes/microclaw-termux.sh` | redirect-scrape tag → tag-pinned aarch64-linux-gnu tarball + SHA256SUMS.txt → glibc-loader wrapper (bionic can't exec glibc ELF) |
| ironclaw | manifest only | proot route documented (ironclaw-termux npm); native = NDK backlog |
| nanoclaw | manifest only | Docker-required → proot only; not natively installable |

## Hub integration — DONE + validated (2026-09-30)

- 6 manifests created (`category: claw-fleet`); hub menu [2] lists them
  with install status; numbered pick → `run_recipe` (parallel agent's
  runner: confirm prompt + `$PREFIX/bin/<name>` check + `post_install`
  smoke) → `recipes/<name>-termux.sh`.
- **Validated end-to-end through the hub on SM-S911W**:
  - `zeroclaw 0.8.5` — android asset, SHA256SUMS OK, wrapper + smoke OK
  - `picoclaw 0.3.1` — tag scrape v0.3.1, static arm64, checksums OK
  - `microclaw 0.7.0` — tag scrape, glibc-loader wrapper, checksums OK
- ironclaw/nanoclaw picks print "No recipe script" + source URL (honest,
  no false install attempt).
- `openclaw` recipe written but **not run** (heavy npm-backed install →
  user opt-in). Node gate 24.18 ✓ checked.
- schema.json: recipe enum += `prefab-android`, `glibc-shim`;
  `recipe_script` formalized (merged with parallel agent's entry — it
  was briefly duplicated, now single key).
