/*
 * dsh-termux-stubs.mjs — replace the native modules DeepSeek Harness pulls in
 * that cannot exist on Android/Bionic.
 *
 * Run by recipes/dsh-termux.sh after `npm install --ignore-scripts`. Every
 * upstream package is left byte-identical except the one entry file that the
 * import graph actually reaches, and every replacement is idempotent. If a
 * future DSH release drops one of these deps the patch is simply skipped.
 *
 * Why each one is unavoidable:
 *
 *   koffi        FFI bindings whose install script builds/downloads a native
 *                binary. Only ever reached from `if (platform === "win32")`
 *                branches in dsh-fs-local / dsh-win32-process / libreoffice-kit
 *                — never on Linux, so an inert stub is behaviourally exact.
 *
 *   sharp        Prebuilt libvips binaries exist for linux-arm64 (glibc) but
 *                not android-arm64, and npm's platform filter skips them, so
 *                `require("sharp")` throws at plugin load. Used only by
 *                dsh-attachment-local for image decode/thumbnail.
 *
 *   sherpa-onnx  Speech-to-text models ship glibc-linked .so files. Only
 *                reached by the experimental voice-input plugin.
 *
 * node-pty is NOT stubbed: Termux ships pty.h and libutil, so it is compiled
 * from source against Bionic by the installer and keeps real PTY fidelity.
 */
import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2];
if (!root) {
  console.error('usage: node dsh-termux-stubs.mjs <node_modules-root>');
  process.exit(2);
}

const STAMP = '/* dsh-termux-stub:1 */';
const report = [];

function manifestOf(pkgDir) {
  return JSON.parse(readFileSync(join(pkgDir, 'package.json'), 'utf8'));
}

// Every runtime entry point, not just `main`: koffi and sharp are dual
// published, so an ESM `import('koffi')` reaches `exports['.'].import` and
// would bypass a `main`-only stub. Walk the conditions and skip `types`.
function collectStrings(node, out = []) {
  if (typeof node === 'string') out.push(node);
  else if (node && typeof node === 'object') {
    for (const [key, value] of Object.entries(node)) {
      if (key === 'types') continue;
      collectStrings(value, out);
    }
  }
  return out;
}

function entryFilesOf(pkgDir, manifest) {
  const candidates = [];
  if (typeof manifest.main === 'string') candidates.push(manifest.main);
  collectStrings(manifest.exports?.['.'], candidates);
  const seen = new Set();
  const found = [];
  for (const rel of candidates) {
    if (seen.has(rel)) continue;
    seen.add(rel);
    if (existsSync(join(pkgDir, rel))) found.push(rel);
  }
  return found;
}

// The abbreviated npm packument omits `type`/`exports`, and sharp is dual
// published, so sniff the real entry file we are about to replace instead of
// trusting metadata. Only top-level import/export count: a `module.exports`
// mention inside a comment or string does not make a file ESM.
function looksEsm(source) {
  const code = source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/(['"`])(?:\\.|(?!\1)[^\\])*\1/g, '""');
  return /^\s*(?:import\s|export\s|import\{|export\{)/m.test(code);
}

function stub(pkgName, { reason, cjs, esm }) {
  const pkgDir = join(root, ...pkgName.split('/'));
  if (!existsSync(join(pkgDir, 'package.json'))) {
    report.push({ pkg: pkgName, action: 'absent — upstream dropped it, nothing to do' });
    return;
  }
  const manifest = manifestOf(pkgDir);
  const entries = entryFilesOf(pkgDir, manifest);
  if (entries.length === 0) {
    report.push({ pkg: pkgName, action: 'SKIPPED — could not locate an entry file' });
    return;
  }
  const done = [];
  let fresh = 0;
  for (const rel of entries) {
    const target = join(pkgDir, rel);
    const original = readFileSync(target, 'utf8');
    if (original.startsWith(STAMP)) {
      done.push(`${rel} (already)`);
      continue;
    }
    try {
      renameSync(target, `${target}.termux-orig`);
    } catch {}
    const isModule = looksEsm(original);
    const body = isModule ? esm : cjs;
    writeFileSync(target, `${STAMP}\n/* Replaces ${rel} on Termux: ${reason} */\n${body}\n`);
    done.push(`${rel} (${isModule ? 'esm' : 'cjs'})`);
    fresh++;
  }
  report.push({ pkg: pkgName, fresh, action: `stubbed ${done.join(', ')} — ${reason}` });
}

// Emitted as source text into the stub, so the hint is interpolated here rather
// than captured from this module's scope.
const unavailable = (what, hint) => `
function unavailable(what) {
  const err = new Error(
    'dsh-termux: ' + what + ' is unavailable on Android/Bionic. ${hint}',
  );
  err.code = 'DSH_TERMUX_UNSUPPORTED';
  return err;
}`;

// ── koffi ────────────────────────────────────────────────────────────────────
// Reached only from win32 branches. Keep the shape (a default export exposing
// .load) so `await import('koffi')` and `.default` both keep working.
stub('koffi', {
  reason: 'Win32-only FFI bindings, never loaded on Linux',
  cjs: `${unavailable('the koffi FFI bindings', 'Only Windows code paths use them.')}
module.exports = new Proxy(
  { load: () => { throw unavailable('koffi.load()'); } },
  {
    get(target, prop) {
      if (prop in target) return target[prop];
      throw unavailable('koffi.' + String(prop));
    },
  },
);`,
  esm: `${unavailable('the koffi FFI bindings', 'Only Windows code paths use them.')}
const bindings = new Proxy(
  { load: () => { throw unavailable('koffi.load()'); } },
  {
    get(target, prop) {
      if (prop in target) return target[prop];
      throw unavailable('koffi.' + String(prop));
    },
  },
);
export default bindings;`,
});

// ── sharp ───────────────────────────────────────────────────────────────────
// dsh-attachment-local does `sharp(buf, opts)` then one of
// `.metadata()` / `.resize().raw().toBuffer()`. Return a chainable object whose
// terminal calls reject with the real reason, so the session log names the
// cause instead of a dlopen stack trace.
const SHARP_HINT =
  'Re-run the installer with DSH_TERMUX_SHARP=1 (needs `pkg install libvips`) to build it against Termux libvips, or drop image attachments.';

const sharpBody = (unavailable) => `${unavailable(
  'sharp (libvips image decoding)',
  SHARP_HINT,
)}
function sharp() {
  const chain = {
    metadata: () => Promise.reject(unavailable('image metadata')),
    stats: () => Promise.reject(unavailable('image stats')),
    resize: () => chain,
    rotate: () => chain,
    raw: () => chain,
    jpeg: () => chain,
    png: () => chain,
    webp: () => chain,
    toBuffer: () => Promise.reject(unavailable('image encoding')),
    toFile: () => Promise.reject(unavailable('image encoding')),
    clone: () => chain,
  };
  return chain;
}
sharp.cache = () => {};
sharp.concurrency = () => 1;
sharp.simd = () => false;
sharp.format = {};`;

stub('sharp', {
  reason: 'no android-arm64 libvips prebuild is published',
  cjs: `${sharpBody(unavailable)}
module.exports = sharp;
module.exports.default = sharp;`,
  esm: `${sharpBody(unavailable)}
export default sharp;`,
});

// ── sherpa-onnx ─────────────────────────────────────────────────────────────
// Loaded only by the experimental voice-input plugin; a throwing default keeps
// that plugin from taking down the whole boot.
const STT_HINT = 'Voice input needs a desktop build; every other DSH feature works without it.';

stub('sherpa-onnx', {
  reason: 'speech-to-text models are glibc-linked',
  cjs: `${unavailable('sherpa-onnx speech-to-text', STT_HINT)}
function unsupported() { throw unavailable('speech-to-text'); }
module.exports = unsupported;
module.exports.default = unsupported;`,
  esm: `${unavailable('sherpa-onnx speech-to-text', STT_HINT)}
function unsupported() { throw unavailable('speech-to-text'); }
export default unsupported;`,
});

for (const line of report) console.log(`  ${line.pkg}: ${line.action}`);
const fresh = report.reduce((n, r) => n + (r.fresh ?? 0), 0);
console.log(`dsh-termux: ${fresh} native module entr${fresh === 1 ? 'y' : 'ies'} stubbed for Bionic`);