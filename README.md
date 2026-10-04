# ⚡ Termux Harness Hub

<p align="center">
  <b>Native, ultra-lightweight installer and management hub for AI coding harnesses, swarms, routers, and MCP tooling on Android (Termux aarch64).</b><br/>
  <i>Zero PRoot overhead. Zero container bloat. Pure native Bionic execution.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Termux%20aarch64-brightgreen?style=flat-square&logo=android" alt="Platform" />
  <img src="https://img.shields.io/badge/Architecture-Native%20Bionic%20(No%20PRoot)-blue?style=flat-square" alt="Architecture" />
  <img src="https://img.shields.io/badge/Manifests-34%20Harnesses-crimson?style=flat-square" alt="Manifests" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="License" />
</p>

---

## 🚀 Quickstart

Run these directly inside Termux:

```bash
# 1. Clone the repository
git clone https://github.com/therealfreddied/termux-harness-tui.git
cd termux-harness-tui

# 2. Launch the interactive TUI installer
bash bin/harness-hub

# 3. (Optional) Run system health & dependency checks
bash recipes/doctor.sh
```

---

## ✨ Core Principles & Guarantees

1. **Pure Native Bionic Execution (Zero PRoot):**
   * PRoot chroots add 2–4× memory overhead and severe filesystem latency. All harnesses run directly on Termux's native Android Bionic libc.
2. **Minimal Footprint & Fast Install:**
   * Package recipes automatically strip devDependencies, audits, and fund prompts (`--omit=dev --no-audit --no-fund`), keeping disk and RAM usage as low as possible.
3. **Automated Shebang & Addon Patching:**
   * Missing `#!/usr/bin/env` headers are rewritten on the fly via `termux-fix-shebang`.
   * Dynamic native C++ addons (e.g. `better-sqlite3`, `node-pty`) are swapped with native Bionic builds automatically.
4. **Live Version Resolution:**
   * Integrated version resolver tracks live npm dist-tags, PyPI metadata, and GitHub releases.

---

## 📦 Curated Categories & Harness Catalog

The Hub indexes **34 manifests across 8 specialized categories**:

### 1. Platform Giants
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `claude` | `latest` | **musl-loader** | Anthropic Claude Code CLI via ultra-lightweight 723KB Alpine musl loader. Preserves `/proc/self/exe`. |
| `codex` | `latest` | **native-arm64** | OpenAI Codex CLI via `@mmmbuto/codex-cli-termux` native Android aarch64 binary. |
| `copilot` | `latest` | **custom-script** | GitHub Copilot CLI engine via native `gh copilot`. |
| `cursor` | `latest` | **glibc-shim** | Anysphere official Cursor CLI agent running in isolated `$PREFIX/opt/cursor`. |
| `gemini` | `latest` | **node-shebang** | Google Gemini CLI (`@google/gemini-cli`), pure JS with automated shebang fixes. |
| `grok` | `duro02-port` | **bionic-rust** | xAI Grok Build terminal agent compiled for native aarch64 Android. |
| `kimi` | `2.1.1` | **node-runner** | Moonshot Kimi Code CLI (`@moonshot-ai/kimi-code`) with Bionic `node-pty`. |
| `pi` | `latest` | **node-shebang** | Pi coding agent (`@earendil-works/pi-coding-agent`) with zero native module overhead. |
| `qwen` | `0.24.7` | **node-runner** | Alibaba Qwen Code CLI (`@qwen-code/qwen-code`) isolated in `$PREFIX/opt/qwen`. |
| `vibe` | `2.25.8` | **python-cli** | Mistral Vibe minimal terminal coding agent. |

### 2. Claw Fleet (Autonomous Agents)
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `openclaw` | `latest` | **node-shebang** | Autonomous multi-agent gateway engine natively running in Termux Node 24. |
| `droidclaw` | `latest` | **custom-script** | Native Android phone agent (perceives screen, taps, swipes, and uses Termux-API without root). |
| `microclaw` | `latest` | **glibc-shim** | High-speed Rust agent core with dynamic channel adapters. |
| `nanobot` | `latest` | **python-cli** | HKUDS personal AI agent with Telegram, Discord, and WhatsApp gateway support. |
| `nullclaw` | `latest` | **bionic-zig** | Ultra-lightweight autonomous agent runtime written in pure Zig. |
| `picoclaw` | `latest` | **custom-script** | Minimal embedded agent engine tailored for low-RAM devices. |

### 3. Open Engines
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `cline` | `3.0.61` | **custom-script** | Autonomous CLI coding agent with full workspace tooling. |
| `kilo` | `7.8.1` | **musl-loader** | Full-featured coding agent with multi-model streaming and workspace indexing. |
| `command-code` | `1.73.0` | **node-runner** | Command-line automated refactoring and developer loop agent. |
| `opencode` | `1.18.31` | **glibc-loader** | High-performance open engine with custom DNS shims. |

### 4. Standalone Cores
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `dsh` | `0.1.0-rc.7` | **prebuilt-bundle** | DeepSeek Harness (DeepSeek AI TUI agent) with precompiled aarch64 native bindings. |
| `agy` | `1.2.14` | **twin-binary** | Antigravity developer CLI core (`wallentx/antigravity-cli-termux`). |
| `openclaude` | `0.31.0` | **node-shebang** | Open-source Claude engine core with drop-in compatibility. |

### 5. Swarms & Orchestration
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `hermes` | `0.19.0` | **prebuilt-tarball** | NousResearch Hermes agent runtime with custom tool-calling loops. |
| `cmux` | `latest` | **custom-script** | Terminal multiplexer orchestrator for running multi-agent swarms concurrently. |
| `herdr` / `multica` | `latest` | **custom-script** | Concurrent sub-agent coordination and task dispatching harnesses. |

### 6. SecEng (Security Engineering)
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `pentestcode` | `latest` | **custom-script** | Automated penetration testing and vulnerability assessment CLI agent. |

### 7. Routing & Frontends
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `omniroute` | `3.8.51` | **prebuilt-dist** | Unified model router for pooling, failover, and protocol translation. Released as standalone backend bundle. |
| `9router` | `0.5.91` | **custom-script** | Lightweight multi-provider proxy router. |
| `cli-proxy-api` | `8.0.4` | **prebuilt-tarball** | Local API proxy for tunneling desktop/CLI credentials to standard endpoints. |
| `clideck` | `2.4.0` | **node-pty** | Multi-agent parallel terminal web dashboard with mobile relay. |
| `rho` | `latest` | **node-runner** | High-throughput local token router and proxy. |

### 8. MCP & Tooling
| Harness | Target Version | Engine / Recipe | Description & Key Features |
|---|---|---|---|
| `duckduckgo-mcp-server` | `latest` | **python-mcp** | Fast DuckDuckGo MCP search server with optional `curl_cffi` TLS browser impersonation. |
| `bwb-browser` | `v4-latest` | **custom-script** | 30KB MCP browser automation server with CDP and static-first fetch ladder. |
| `curl-cffi` | `0.16.0` | **python-cffi** | Python TLS fingerprint impersonation library precompiled for Android aarch64. |

---

## 🛠️ Diagnostics & Tooling Scripts

### Version Resolution (`scripts/resolve-latest.sh`)
Scan all 34 manifests against live npm, PyPI, and GitHub release endpoints:
```bash
bash scripts/resolve-latest.sh
```

### Health Check (`recipes/doctor.sh`)
Inspect your Termux architecture, memory availability, glibc loader status, and native module bindings:
```bash
bash recipes/doctor.sh
```

### Recipe Smoke Tests (`scripts/smoke-test-recipes.sh`)
Run automated smoke tests for thin recipes locally or in CI:
```bash
bash scripts/smoke-test-recipes.sh
```

---

## 🔒 Verification & Hardware Baseline

All recipes are verified on physical hardware:
* **Device:** Samsung Galaxy S23 (`SM-S911W`)
* **Architecture:** `aarch64` / Android 16
* **Environment:** Native Termux (`Node.js v24+`, `Python 3.10+`, `Clang 18+`)

---

## 📄 License
Released under the [MIT License](LICENSE).
