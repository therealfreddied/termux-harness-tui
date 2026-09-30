# DeepSeek Harness on Termux — port notes

Replaces the old `dsh-mini` entry with the official
[`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness)
published to npm as `@deepseek-ai/dsh`. Verified on SM-S911W (aarch64, Android 13,
Node 24.18.0) on 2026-09-30.

## What "real DeepSeek Harness" means here

`dsh-mini` was a third-party repack: 7.7 MB, 31 of ~90 plugins, engine locked to
one version. The official package is **562 packages** across the `@deepseek-ai`
scope (269 of them), all at the same release train, and it is pure JavaScript —
which is what makes it worth porting rather than wrapping.

Latest at time of writing: `0.2.0-rc.2` (developer preview, MIT).

## The four things that actually break

### 1. `process.platform === "android"` — the blocker

Node reports `android` on Termux. Almost all DSH dispatch is `=== "win32"`, so
that mostly does not matter. One place does:

```js
// @deepseek-ai/dsh-subprocess-local/lib/index.js
function createProcessInspector(platform = process.platform, arch = process.arch) {
  if (platform === "linux") return new LinuxProcessInspector(arch, internals);
  if (platform === "darwin") return new MacProcessInspector(internals);
  throw new Error(`subprocess-local: terminal inspection is unsupported on platform ${platform}`);
}
```

Every terminal allocation throws at plugin load without a shim. Android *is*
Linux with Bionic, and the Linux inspector reads `/proc` directly, which works
here — reporting `linux` is the correct ABI, not a lie.

**Fix:** `recipes/shims/dsh-termux-preload.cjs`, injected with
`NODE_OPTIONS="--require …"`.

`NODE_OPTIONS` specifically, not `node --require` on the command line: a
`worker_thread` gets a **fresh `process` object** from the platform bootstrap, so
a main-isolate-only override is invisible inside workers — and DSH runs subagents
in workers. Verified:

| injection | main | worker |
| --- | --- | --- |
| `node --import` | `linux` | `android` |
| `Worker({execArgv:['--require']})` | — | `linux` |
| `NODE_OPTIONS=--require` | `linux` | `linux` |

`NODE_OPTIONS` wins because Node applies it in every isolate without us patching
`Worker` construction.

Side effect, favourable: `dsh-node-addon-system` then resolves
`@deepseek-ai/node-addon-system-linux-arm64`, whose `landlock-run` is a
**static-musl** ELF and does execute on Termux. It still probes fail-closed —
this kernel does not enforce Landlock, so `probe()` returns `unusable` and DSH
runs unsandboxed, which is upstream's documented behaviour for unenforcing
kernels.

### 2. node-pty is glibc-linked and must be compiled

`node-pty@1.2.0-beta.15` publishes prebuilds for `linux-arm64`, `linux-x64`,
`darwin-*` and `win32-*` — **not** `android-arm64`. The Linux one is unusable:

```
$ strings -a node-pty/prebuilds/linux-arm64/pty.node | grep -m3 -E 'GLIBC_|ld-linux'
libc.so.6
ld-linux-aarch64.so.1
GLIBC_2.17
```

It cannot `dlopen` under Bionic, and its install script is
`node scripts/prebuild.js || node-gyp rebuild`, so a plain install tries to
cross-compile and fails.

Termux ships `pty.h` (from `ndk-sysroot`, `forkpty` `__INTRODUCED_IN(23)`) and
`libutil.so`, plus `clang`, `make`, `python` and `node-gyp`. So it builds:

```
$ node-gyp rebuild --nodedir="$PREFIX" -j 1      # run via `node`, its shebang
                                                    # hardcodes a foreign path
  CXX(target) Release/obj.target/pty/src/unix/pty.o
  SOLINK_MODULE(target) Release/obj.target/pty.node
  COPY Release/pty.node
```

```
pty.node: ELF 64-bit LSB shared object, ARM aarch64,
          dynamically linked, for Android 24, built by NDK r30
```

Live check on device:

```
pid: 18515
exitCode: 0 signal: 0
TERMUX_PTY_OK
/dev/pts/1
30 100          <- stty size honours the cols/rows dsh asked for
```

`lib/utils.js:loadNativeModule` checks `build/Release` **before**
`prebuilds/<platform>-<arch>`, so the compiled binary wins and the glibc prebuild
is never reached.

### 3. Three native modules have no Android build

Each is reachable from exactly one consumer, which is what makes stubbing honest
rather than a guess:

| module | consumer | reachable on Linux? |
| --- | --- | --- |
| `koffi` | `dsh-fs-local`, `dsh-win32-process`, `libreoffice-kit` | no — only inside `if (platform === "win32")` branches. Importing it is enough. |
| `sharp` | `dsh-attachment-local` | yes, but only for image decode/thumbnail |
| `sherpa-onnx` | `dsh-experimental-speech-to-text-sensevoice` | only the experimental voice plugin |

`koffi` also has an `install` script (`node ./cnoke.cjs … --release`) that would
try to build during `npm install` — one more reason the tree installs with
`--ignore-scripts`.

`recipes/dsh-termux-stubs.mjs` rewrites **every** entry point (not just `main` —
koffi and sharp are dual published, so `import("koffi")` reaches
`exports["."].import` and would walk straight past a `main`-only stub), picks the
CJS or ESM flavour by sniffing the file it is replacing, saves the original as
`*.termux-orig`, and is idempotent. Each stub rejects with
`code: "DSH_TERMUX_UNSUPPORTED"` and a message naming the real cause and the
opt-in fix.

Termux *does* have `libvips 8.18.7`, so `DSH_TERMUX_SHARP=1` builds real sharp
against it; it is opt-in because compiling sharp's C++ on a phone is slow and
image attachments are a niche feature.

### 4. Things that turned out not to need patching

- **SELinux and hardlinks.** The usual Android casualty. Upstream
  `dsh-atomic-write` already commits with write-sibling + `rename`, never
  `link`, so there is nothing to fix.
- **`/tmp`.** Android ships it mode 711 owned by `shell`, so a Termux process
  cannot write there — real, but only matters for scripts that hardcode it. The
  shim asserts `TMPDIR` anyway so children and libs that cache `os.tmpdir()`
  agree.
- **SQLite.** `dsh-session-query-sqlite` has no native dependency; it uses
  `node:sqlite`, built into Node 22+.
- **npm's platform filter.** `process.platform === "android"` means npm *skips*
  `os: ["linux"]` packages, which is what we want — no glibc prebuilds get
  downloaded in the first place.

## Why `--ignore-scripts`

Without it npm runs koffi's `cnoke` build and node-pty's
`prebuild.js || node-gyp rebuild` mid-install, both of which fail on Bionic and
leave a half-built tree. We want exactly one native build, and we run it
ourselves with the flags we control.

## Resulting layout

```
$PREFIX/opt/dsh/
  package.json                 { "dependencies": { "@deepseek-ai/dsh": "<resolved>" } }
  .dsh-termux-version          for idempotent upgrades
  node_modules/                upstream, unmodified except the stubbed entries
    node-pty/build/Release/    ← compiled here against Bionic
  shim/dsh-termux-preload.cjs  ← copied so the launcher is self-contained
$PREFIX/bin/dsh                launcher, sets NODE_OPTIONS then execs lib/bin.js
```

`recipes/doctor.sh` reports the installed version, whether the shim is present,
whether `pty.node` contains `GLIBC_` strings (i.e. someone reinstalled the
broken prebuild), and which native modules are stubbed.

## Not yet verified

The shim and the node-pty build are verified; a full `dsh` session has not been
run yet, because installing 562 packages on this phone is the user's call to
make. Run `recipes/dsh-termux.sh` (or pick **4 → 1** in `bin/harness-hub`).
---

# STOP: use the community patch set, not ours

Our own patch layer (`recipes/dsh-termux.sh` + shim + stubs) is **inferior and
unproven**. It was never installed or run. While looking for a pre-patched
build I found one that is better on every axis that matters. Verified on this
device, 2026-09-30.

## Vengisk/deepseek-harness-termux — MIT, 51 stars, actively used

<https://github.com/Vengisk/deepseek-harness-termux>
release `v0.1.0-termux.1`, `dsh-termux-full.tgz`, 50,954,949 bytes,
sha256 `aa9f2ffc372c223a77ed38c08b76741533f7967cc19903815b3838d117e13b7f`
(2,268 downloads). Both digests verified against the GitHub release metadata.

It ships two artifacts:

- **Plan B, `dsh-termux-full.tgz` (50.9 MB)** — the whole patched dsh plus
  `node_modules`, flattened: 196 `@deepseek-ai/*` packages in one tree.
  `npm i -g <url>` and you are done. No compile, no toolchain, no proot.
- **dsh-termux.tgz (367 KB)** — same patches + prebuilt natives, but a
  postinstall that fetches dsh itself. Pinned to `0.1.0-rc.6`, overridable
  with `DSH_VERSION`.
- **Plan A, `install.sh`** — clones the repo and patches `@deepseek-ai/dsh@latest`
  in place, compiling `koffi` and `node-pty` for real. 9 steps, idempotent.

## What it fixes that we missed entirely

Our shim was a blunt instrument: it lied about `process.platform` globally and
stubbed out three native modules so they would load but do nothing. Their
approach is per-package source patches, so the features keep working:

| Patch | Package | Fixes |
| --- | --- | --- |
| 01 | `dsh-terminal-bash` | resolves a real shell; there is no `/bin/bash` on Android |
| 02 | `dsh-session-persistence-jsonl` | `link(2)` → `rename(2)`; Android sepolicy returns EACCES |
| 03 | `dsh-subprocess-local` | treats `android` like `linux` for process-group inspection |
| 04 ×2 | `dsh-host-apiproxy` | opens paths/URLs via `termux-open` |
| 05 | `dsh-host-directory-picker-native` | routes dir picking down the Linux path |
| 06 | `dsh-workspace` | skips a session-known integrity check that fails on fresh installs |
| 07 | `dsh-sandbox-local` | uses `proot` as the sandbox runner |
| 08 | `dsh-tool-fs-search` | resolves ripgrep; `@vscode/ripgrep` ships no android-arm64 package |

Plus, outside the patch set:

- **`@vscode/ripgrep-android-arm64` shim** written to disk pointing at the
  system `rg`. Without it the glob/grep tools fail in every fresh process.
  We never noticed this at all.
- **`@img/sharp-wasm32`** instead of a sharp stub — real image processing in
  WebAssembly, no native build.
- **`koffi` compiled for real** with a `statx()` patch. Bionic has no
  `statx()`; we stubbed the whole module and lost FFI entirely.
- **`--expose-internals` on the `bin.js` shebang**, because
  `cordis-plugin-hmr` reaches into `node:internal/modules`, which Node gates
  since v22. We had HMR silently dead.
- **`dsh-web-mobile`** plugin for narrow screens.

Two of these are corrections to work I had already reported as "done":
`link(2)` in session persistence (I had concluded, from `dsh-atomic-write`, that
upstream was already rename-only and needed no patch — wrong package), and
`--expose-internals`.

## Verified on this device, from the extracted tarball, nothing installed

    pty.node      ELF 64-bit ARM aarch64, for Android 24, NDK r29, 0 GLIBC refs
    koffi.node    ELF 64-bit ARM aarch64, for Android 24, NDK r29, 0 GLIBC refs

    node-pty  -> spawned bash, tty=/dev/pts/1, MARKER=42, exit 0
    koffi     -> loaded libc.so, getpid()=10017, stat() rc=0 (statx bypassed)
    dsh -V    -> 0.1.0-rc.7-termux.1
    dsh --help, --profile web --dump-default-config -> clean
    dsh web --port 3197 -> HTTP 200 in ~15s, <title>DeepSeek Harness</title>,
                           12109 bytes, plugin bundle loaded

That is the thing our own patch set never got to: an actual running web UI.

## Caveats

- **Version skew.** The prebuilt bundles `0.1.0-rc.7`; npm `latest` is
  `0.2.0-rc.2` (published 2026-09-29). The version line moved
  `0.1.0-rc.6` → `0.1.5-rc` → `0.1.7-rc.2` → `0.2.0-rc.2`, so this is two
  minor generations behind, roughly two weeks. The patches were generated by
  `diff -u` against `0.1.0-rc.6`, so pointing them at `0.2.0-rc.2` is likely
  to fail — `patch --forward` skips what it cannot apply, so a partial patch
  set fails quietly.
- **sharp is still not really wired up.** `@img/sharp-wasm32` is bundled but
  nothing in `lib/` imports it, and there is no native `sharp` binding or
  `@img/sharp-*` platform package. Same practical outcome as our stub, reached
  a different way. Only bites if DSH hands images to a vision model.
- **No sandbox.** `bubblewrap` needs `user_namespaces`, which Android sepolicy
  denies. It degrades to `SandboxUnavailableError`, so bash commands the agent
  runs are not isolated. True of every Termux route.
- **Landlock** is unavailable on this kernel, same as ours.

## The rest of the field

| Repo | Stars | Form |
| --- | --- | --- |
| `woaiys3/deepseek-harness-android-app` | 166 | native APK, uses Shizuku/accessibility so the AI can actually drive the phone |
| **`Vengisk/deepseek-harness-termux`** | **51** | **patch set, native Termux — the one for us** |
| `thness/dsh-mobile` | 18 | 41 MB APK with embedded Node; 4 GB RAM, 500 MB, ~30 s first boot |
| `dphmoblie/deepseek-harness-android` | 5 | Capacitor + full PRoot Ubuntu 24.04 |

All MIT, all built on `0.1.0-rc.6`, all created 2026-08-13 to 08-16. The APK
routes bundle their own Node and do not use this `$PREFIX`, which rules them
out for a Termux harness repo.
