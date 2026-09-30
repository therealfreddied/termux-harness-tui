# Termux Harness TUI — Master Plan Notes

Project: redistributable GitHub repo + TUI installer that patches/installs
AI coding harnesses natively on Termux (no proot). Target dir:
`/storage/emulated/0/LLM/termux-harness-tui/`

Status: RESEARCH / PLANNING — nothing published, nothing wired up yet.

## Hard constraints (from working session)

- NEVER touch OpenCode install (user's primary driver). Launcher:
  `~/.agents/opencode/launcher.sh`. Do not patch, wrap, or auto-update it.
- `npm install*` is DENIED by permission rules → installers must use
  `curl|bash` scripts, tarball extraction, or `pkg` (with ask approval).
- `rm -rf` forbidden in tool calls — installers should use targeted
  `rm -f` / `rm -P` on specific files only.
- Phone has ~1–2GB free RAM. Installer must NOT clone big repos on-device;
  download prebuilt release tarballs only.
- Fish config theme files must pass `fish -n` before sourcing.

## Verified working installs (tested on this phone)

| Harness | Version | Method | Status |
|---|---|---|---|
| claude-code | 2.1.285 | glibc loader (`~/.local/share/claude/versions`) | works |
| opencode | 1.18.31 | glibc + DNS shim (DO NOT TOUCH) | works |
| codex | 0.156.1 | `@mmmbuto/codex-cli-termux` npm pkg | works |
| openclaude | 0.31.0 | `@gitlawb/openclaude` + termux-fix-shebang | works |
| agy (antigravity) | 1.2.14 | `wallentx/antigravity-cli-termux` curl\|sh (twin binary agy + agy.va39) | works |
| cline | 3.0.61 | `gamihardik2009-crypto/cline-termux` install.sh (bun-termux wrapper + glibc) | works, just installed |
| grok-build | Duro02 port | prebuilt tarball `Duro02/grok-build-termux` releases | NOT yet installed |
| dsh-mini | LouisYang841 | single 7.7MB file, `curl\|sh`, Node ≥22.15 | NOT yet installed |
| hermes | VPS build | `66.179.82.231:8999` HTTP server | BLOCKED — port 8999 unreachable, port 80 open; ask VPS admin to restart server |

## Candidate harnesses (researched, not yet tested)

- **grok-build-termux** (`Duro02/grok-build-termux`) — xAI Grok Build Rust
  TUI, aarch64 tarball + sha256 in Releases. Install: sha256sum -c → tar →
  `install -m 755 grok $PREFIX/bin/grok`.
- **dsh-mini** (`LouisYang841/dsh-mini`) — DeepSeek Harness mini engine,
  7.7MB self-contained JS, no native modules, works on Node 24 (installed).
- **cline-termux** (`gamihardik2009-crypto/cline-termux`) — INSTALLED above.
- **pentestcode** (`s0ld13rr/pentestcode`) — OpenCode hard fork for offensive
  security. Needs same glibc+DNS shim recipe as opencode. Category:
  "Specialized & SecEng". (User approval pending; do not auto-install.)
- **claude-code-termux-musl** (`Aarstad/claude-code-termux-musl`) — alt
  Claude Code route via musl instead of glibc. Backup option if glibc
  route breaks upstream.
- **bwb-browser** (`krshforever/bwb-browser`) — 30KB MCP browser automation
  server, static-first fetch ladder, survives Android OOM killer. Good MCP
  add-on for any harness. Runs on Termux (author built it on Termux).
- **Twilight0/termux-repo** — community APT repo with prebuilt debs:
  muse-code, opencode v2, antigravity-cli, oh-my-pi, 9router, wrangler,
  curl-cffi wheels, yt-dlp-git. Weekly GH Actions builds. This could be a
  *distribution channel* for our own recipes, and a source of prebuilt
  deps (curl-cffi especially).

## Routing / proxy layer (user wants these eventually — NOT yet)

- **OmniRoute** (`diegosouzapw/OmniRoute`) — LLM router, dashboard-stripped
  on this phone; can intercept ANTHROPIC_BASE_URL/OPENAI_BASE_URL.
- **9router** (`decolua/9router`) — AI model router w/ smart fallback,
  OpenAI-compatible endpoint. Also packaged in Twilight0 repo.
- **CLIProxyAPI** (`router-for-me/CLIProxyAPI`) — proxies CLI auth into
  OpenAI-compatible API endpoints. "Port to Termux properly" pending.

## Repo layout (planned)

```
termux-harness-tui/
├── install.sh              # entry: deps check, glibc repo setup, TUI menu
├── bin/
│   └── harness-hub         # main TUI (fish or bash dialog-style)
├── recipes/
│   ├── glibc-bun/          # claude-code, opencode, cline, pentestcode
│   │   └── install.sh      # patchelf + LD_PRELOAD resolv shim
│   ├── bionic-rust/        # grok-build, ironclaw, zeroclaw
│   ├── node-shebang/       # openclaude, codex (termux-fix-shebang)
│   ├── twin-binary/        # antigravity (agy + agy.va39)
│   └── python-cffi/        # curl-cffi wheel builds
├── manifests/
│   └── *.json              # name, version, url, sha256, recipe, deps
└── notes/
    └── PLAN.md             # this file
```

## TUI menu categories (draft)

1. Platform Giants (claude, codex, gemini, grok)
2. Claw Fleet (openclaw, zeroclaw, picoclaw, nanoclaw, ironclaw, microclaw)
3. Open Engines (opencode, cline, aider, goose, plandex, pi)
4. Standalone Cores (dsh-mini, antigravity, openclaude)
5. Swarms / Parallel (cmux, herdr, multica)
6. Specialized & SecEng (pentestcode, aider-sec)
7. Routing & Proxies (omniroute, 9router, cliproxyapi)
8. MCP & Tooling (bwb-browser, duckduckgo-mcp, curl-cffi)
9. Doctor (check installed versions, glibc health, disk/RAM)

## Next actions

1. ✅ Install cline-termux (done, 3.0.61 works)
2. Install grok-build from Duro02 releases (needs user go-ahead)
3. Install dsh-mini (needs user go-ahead)
4. Get VPS admin to restart HTTP server on 8999 for hermes tarball
5. Scaffold install.sh + harness-hub TUI skeleton
6. Write manifest JSON schema + first manifests (cline, grok, dsh-mini)
7. Consider Twilight0 repo as distribution channel / PR our recipes there
