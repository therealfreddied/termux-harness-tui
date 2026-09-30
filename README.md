# Termux Harness TUI

Native Termux (no proot) installer hub for AI coding harnesses, routers, and
MCP tooling on Android (aarch64). Every install is checksum-verified and
smoke-tested on a Galaxy S23 (`SM-S911W`, Android 16, 8GB RAM).

## Install (on Termux)

```bash
git clone https://github.com/therealfreddied/termux-harness-tui.git
cd termux-harness-tui
bash bin/harness-hub          # TUI menu
bash recipes/doctor.sh        # health check (works standalone)
```

## What's verified working natively (no proot)

| Command | Version | Recipe | Note |
|---|---|---|---|
| `claude` | 2.1.286 | **musl-loader** | official `linux-arm64-musl` build, 723KB loader |
| `copilot` | latest | **custom-script** | GitHub Copilot CLI engine via native `gh copilot` |
| `cursor` | 2026.09.28 | **glibc-shim** | Anysphere official `linux-arm64` agent bundle via glibc loader |
| `kimi` | 2.1.1 | node-runner | Moonshot Kimi Code CLI (@moonshot-ai/kimi-code) |
| `qwen` | 0.24.7 | node-runner | Alibaba Qwen Code CLI (@qwen-code/qwen-code) |
| `vibe` | 2.25.8 | python-cli | Mistral Vibe minimal CLI coding agent (mistral-vibe) |
| `nanobot` | latest | python-cli | HKUDS Nanobot personal AI agent & multi-channel gateway |
| `clideck` | 2.4.0 | node-pty | Multi-agent parallel terminal web dashboard with mobile relay |
| `opencode` | 1.18.31 | glibc + DNS shim | DO NOT TOUCH (primary driver) |
| `kilo` | 7.8.1 | **musl-loader** | official `linux-arm64-musl` binary + libstdc++ rpath |
| `command-code` | 1.73.0 | node-runner | isolated prefix ($PREFIX/opt/command-code, no cmd collision) |
| `codex` | 0.156.1 | node-shebang | `@mmmbuto/codex-cli-termux` |
| `openclaude` | 0.31.0 | node-shebang | `termux-fix-shebang` |
| `agy` / `antigravity` | 1.2.14 | twin-binary | `wallentx/antigravity-cli-termux` |
| `cline` | 3.0.61 | custom-script | bun-termux wrapper + glibc |
| `grok` | 1.0.41 | bionic-rust | Duro02 port, sha256-verified |
| `dsh` | 0.1.0-rc.7-termux.1 | prebuilt-tarball | Vengisk port, 318MB, `dsh web` HTTP 200 |
| `bwb` | 4.0.1 | npm-tarball | MCP stdio, 26 tools verified |
| `pentestcode` | 0.2.6 | **musl-shim** | Alpine musl loader + libstdc++ |
| `cli-proxy-api` | 8.0.4 | go-android | on-device Go 1.27 rebuild |
| `9router` | 0.5.91 | npm-tarball | port 20129 (health verified) |
| `omniroute` | 3.8.51 | omniroute-full | CLI+doctor work; server bundle from VPS |

## Repo layout

```
bin/harness-hub          TUI menu (categories 1-9 + doctor)
recipes/                 per-recipe installers (glibc-bun, musl-shim, go-android…)
manifests/*.json         pinned manifests (schema.json = JSON Schema)
patches/                 Termux node_modules patches (better-sqlite3, machine-id, swc)
notes/PLAN.md            master plan + constraints
notes/WORKLOG.md         environment gotchas (node platform=android, seccomp, musl…)
notes/VPS-BUILD-HANDOFF.md  ← what your VPS OpenClaw instance needs to build
```

## Key environment facts (why this repo exists)

- `process.platform` is `android` in Termux node → no npm native prebuilds
  match; glibc prebuilds segfault. Native modules must compile from source.
- Go binaries built `GOOS=linux` (Go 1.26+) crash under Android seccomp
  (`faccessat2`, syscall 439) → rebuild with Termux Go (`GOOS=android`) and
  `-ldflags="-checklinkname=0"` when pion/anet is in the tree.
- musl ELF binaries run via a 3-line Alpine loader shim — no glibc needed.
- `npm install` is blocked by this workspace's permission rules → the
  recipes fetch registry tarballs directly and lay out node_modules by hand.

## Security

- Default bind for routers is loopback. Don't expose provider keys on LAN.
- Rotate any key that touched a chat log (see VPS-BUILD-HANDOFF).
