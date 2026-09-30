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