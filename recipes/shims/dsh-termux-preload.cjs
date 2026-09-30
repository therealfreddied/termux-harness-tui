/*
 * dsh-termux-preload.cjs — Termux compatibility shim for DeepSeek Harness.
 *
 * Applied with `NODE_OPTIONS="--require <this file>"`, which Node propagates
 * into every worker_thread, child_process and cluster it spawns. That matters:
 * a Worker gets a fresh `process` object from the platform bootstrap, so a
 * shim applied only to the main isolate is invisible to subagents. NODE_OPTIONS
 * is the one injection point that reaches all of them without patching code.
 *
 * ── What this fixes ────────────────────────────────────────────────────────
 *
 * 1. process.platform
 *    Node on Termux reports `android`. The DSH tree dispatches on `win32` in
 *    almost every branch, but `@deepseek-ai/dsh-subprocess-local` *requires*
 *    `linux`:
 *
 *        if (platform === "linux") return new LinuxProcessInspector(...)
 *        if (platform === "darwin") return new MacProcessInspector(...)
 *        throw new Error(`subprocess-local: terminal inspection is
 *                         unsupported on platform ${platform}`)
 *
 *    So on Termux every terminal allocation dies at plugin load. Android *is*
 *    Linux (Bionic), and the Linux inspector reads /proc directly, which works
 *    here — so reporting `linux` is not a lie, it is the correct ABI.
 *
 *    Side benefit: `dsh-node-addon-system` resolves
 *    `@deepseek-ai/node-addon-system-linux-arm64`, whose `landlock-run` is a
 *    static-musl ELF and does execute on Termux. Without the shim it would
 *    look for a nonexistent `android-arm64` package. Landlock is still probed
 *    fail-closed, so on kernels without it the sandbox reports `unusable`
 *    and dsh runs unsandboxed — upstream's documented behaviour.
 *
 * 2. TMPDIR
 *    Android ships `/tmp` as mode 711 owned by `shell`, so a Termux process
 *    cannot create files in it. Any dependency doing the POSIX-default dance
 *    (`/tmp` unless TMPDIR is set) silently fails. Termux's own tmp is correct,
 *    but only because Node already sets TMPDIR for us — we re-assert it so
 *    that child processes and libraries that cache os.tmpdir() agree.
 *
 * ── Deliberately NOT patched ───────────────────────────────────────────────
 *
 * `fs.link` — Android SELinux denies hardlinks across some storage domains.
 * Upstream `@deepseek-ai/dsh-atomic-write` already commits with
 * write-sibling + `rename`, never `link`, so there is nothing to fix.
 *
 * Idempotent: safe to require twice, and safe under `node --require` chains.
 */
'use strict';

if (process.env.DSH_TERMUX_SHIM === '1') return;

// 1. Platform identity. Bionic is Linux; tell the tree so.
Object.defineProperty(process, 'platform', {
	value: 'linux',
	writable: false,
	enumerable: true,
	configurable: true,
});

// 2. Writable temp dir for this process and everything it spawns.
const tmpdir = process.env.TMPDIR && process.env.TMPDIR !== '/tmp' ? process.env.TMPDIR : null;
if (tmpdir === null) {
	const prefix = process.env.PREFIX;
	if (prefix) {
		process.env.TMPDIR = `${prefix}/tmp`;
	} else {
		// No Termux: fall back to the OS temp dir Node resolved for us.
		try {
			process.env.TMPDIR = require('node:os').tmpdir();
		} catch {}
	}
}

// 3. Marker for the companion tree patches (recipes/dsh-termux.sh step 5) and
//    for diagnosing a misconfigured launcher.
process.env.DSH_TERMUX_SHIM = '1';