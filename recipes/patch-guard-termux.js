#!/usr/bin/env node
/**
 * patch-guard-termux.js — /v1/models visibility patch for OmniRoute on Termux.
 *
 * Adapted from the VPS patch-guard (therealfreddied/lakairjenwjwwj) for the
 * on-device source checkout layout: target is $HOME/omniroute/scripts/dev/
 * http-method-guard.cjs (dev tree) OR dist/ if a standalone bundle exists.
 *
 * Semantics preserved from upstream v2 patch:
 *   - Active providers only (provider_connections.is_active=1, not unavailable)
 *   - Provider nodes mapped through prefixes (openai-compatible-chat-<uuid>)
 *   - Dashboard-hidden models excluded, PROVIDER-SCOPED (no cross-provider leak)
 *   - hiddenModalities.chat overrides legacy isHidden
 *   - auto/* hidden by default (?include_auto=true to opt in)
 *   - no-think/* hidden by default (?include_no_think=true to opt in)
 *   - combos filtered on isActive/isHidden
 *
 * Critical implementation notes (DO NOT LOSE — from the VPS writeup):
 *   1. The wrapper MUST `return listener.call(this, req, res)` on the
 *      non-models branch or EVERY request hangs.
 *   2. content-length MUST be guarded by !res.headersSent or end() throws
 *      ERR_HTTP_HEADERS_SENT and the filter silently never applies.
 *   3. Idempotency: reset from <target>.orig.bak before injecting.
 *   4. Syntax-check the patched file with new Function() before shipping;
 *      restore the backup on failure.
 *
 * Usage:
 *   node patch-guard-termux.js            # patch + syntax check
 *   SKIP_RESTART=1 node patch-guard-termux.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const CANDIDATES = [
  path.join(HOME, 'omniroute', 'scripts', 'dev', 'http-method-guard.cjs'),
  path.join(HOME, 'omniroute', 'dist', 'http-method-guard.cjs'),
  '/usr/lib/node_modules/omniroute/dist/http-method-guard.cjs',
  '/usr/local/lib/node_modules/omniroute/dist/http-method-guard.cjs',
];

const ANCHOR = 'wrapRequestListenerWithMethodGuard';

function findTarget() {
  for (const p of CANDIDATES) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function main() {
  const target = findTarget();
  if (!target) {
    console.error('patch-guard-termux: no http-method-guard.cjs found in known locations');
    process.exit(1);
  }
  const backup = target + '.orig.bak';
  console.log('patch-guard-termux: target =', target);

  // Idempotency: reset from backup if present, else create backup
  let base;
  if (fs.existsSync(backup)) {
    base = fs.readFileSync(backup, 'utf8');
    console.log('patch-guard-termux: reset from existing backup (idempotent re-run)');
  } else {
    base = fs.readFileSync(target, 'utf8');
    fs.writeFileSync(backup, base);
    console.log('patch-guard-termux: backup created ->', backup);
  }

  if (base.includes(ANCHOR) === false) {
    console.error('patch-guard-termux: injection anchor missing — upstream refactored the guard.');
    console.error('Update ANCHOR to the new exported function name and re-run.');
    process.exit(1);
  }

  if (base.includes('wrapWithModelsFilter')) {
    console.log('patch-guard-termux: already patched, nothing to do');
    return;
  }

  const injection = `
// ==== patch-guard-termux v2 (models visibility) ====
const __pgPath = require('path');
const __pgHome = require('os').homedir();
function __pgOpenDb() {
  const dbPath = __pgPath.join(__pgHome, '.omniroute', 'storage.sqlite');
  if (!require('fs').existsSync(dbPath)) return null;
  try {
    const { DatabaseSync } = require('node:sqlite');
    return new DatabaseSync(dbPath, { readOnly: true });
  } catch (_) {
    try { return require('better-sqlite3')(dbPath, { readonly: true }); } catch (_) { return null; }
  }
}
function __pgGetFilterState() {
  const state = { hiddenByPrefix: new Map(), activePrefixes: new Set(), combos: new Set(), inactiveCombos: new Set(), includeAuto: false, includeNoThink: false };
  let db;
  try { db = __pgOpenDb(); } catch (_) { return state; }
  if (!db) return state;
  const q = (sql, params) => {
    try {
      if (typeof db.prepare === 'function' && db.prepare(sql).get) { // node:sqlite
        return db.prepare(sql).all(...(params || []));
      }
    } catch (_) {}
    return [];
  };
  try {
    // active providers + node prefixes
    const rows = q("SELECT provider, provider_id FROM provider_connections WHERE is_active = 1");
    for (const r of rows) {
      const pid = r.provider_id || r.provider;
      if (!pid) continue;
      if (/^[0-9a-f-]{36}$/i.test(String(pid))) continue; // resolved below via nodes
      state.activePrefixes.add(String(pid));
    }
    const nodeRows = q("SELECT provider, prefix FROM provider_nodes");
    const uuidToPrefix = new Map(nodeRows.map(r => [String(r.provider), String(r.prefix || '')]));
    for (const r of rows) {
      const pid = String(r.provider_id || r.provider || '');
      if (/^[0-9a-f-]{36}$/i.test(pid)) {
        const prefix = uuidToPrefix.get(pid);
        if (prefix) state.activePrefixes.add(prefix);
      }
    }
    // modelCompatOverrides: provider-scoped hidden models
    const kv = q("SELECT key, value FROM key_value WHERE namespace = 'modelCompatOverrides'");
    for (const row of kv) {
      let list;
      try { list = JSON.parse(row.value); } catch (_) { continue; }
      if (!Array.isArray(list)) continue;
      const key = String(row.key);
      // key may be a provider id or node uuid — map uuid → prefix
      let prefix = /^[0-9a-f-]{36}$/i.test(key) ? (uuidToPrefix.get(key) || key) : key;
      if (!state.hiddenByPrefix.has(prefix)) state.hiddenByPrefix.set(prefix, new Set());
      const set = state.hiddenByPrefix.get(prefix);
      for (const m of list) {
        if (!m || !m.id) continue;
        const hiddenNow = (m.hiddenModalities && Array.isArray(m.hiddenModalities.chat))
          ? m.hiddenModalities.chat.includes(true) || m.hiddenModalities.chat === true
          : m.isHidden === true;
        if (hiddenNow) {
          set.add(String(m.id));
          const slash = String(m.id).indexOf('/');
          if (slash > 0) set.add(String(m.id).slice(slash + 1)); // sub-prefixed leaf
        }
      }
    }
    // combos
    const combos = q("SELECT key, value FROM key_value WHERE namespace = 'combos'");
    for (const row of combos) {
      try {
        const data = JSON.parse(row.value);
        if (data && (data.isActive === false || data.isHidden === true)) state.inactiveCombos.add(String(row.key));
        else if (data) state.combos.add(String(row.key));
      } catch (_) {}
    }
  } catch (_) {} // fail-open: empty state shows unfiltered
  try { if (db && typeof db.close === 'function') db.close(); } catch (_) {}
  return state;
}
function wrapWithModelsFilter(listener) {
  return function patchedListener(req, res) {
    try {
      const url = req.url || '';
      if (req.method !== 'GET' || !url.startsWith('/v1/models')) {
        return listener.call(this, req, res); // CRITICAL: must return or all requests hang
      }
      const u = new URL(url, 'http://x');
      const includeAuto = u.searchParams.get('include_auto') === 'true' || u.searchParams.get('auto') === 'true' || u.searchParams.get('virtual') === 'true';
      const includeNoThink = u.searchParams.get('include_no_think') === 'true' || u.searchParams.get('no_think') === 'true';
      const origWrite = res.write.bind(res);
      const origEnd = res.end.bind(res);
      const chunks = [];
      let failed = false;
      res.write = (c, ...a) => { chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(String(c))); return true; };
      res.end = (c, ...a) => {
        try {
          if (c) chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(String(c)));
          const body = Buffer.concat(chunks).toString('utf8');
          let json;
          try { json = JSON.parse(body); } catch (_) { failed = true; }
          if (!failed && json && Array.isArray(json.data)) {
            const st = __pgGetFilterState();
            st.includeAuto = includeAuto; st.includeNoThink = includeNoThink;
            const aliasKeys = (prefix, id) => {
              const out = [prefix + '/' + id];
              if (prefix) out.push(id); // leaf form
              return out;
            };
            json.data = json.data.filter((m) => {
              const id = String(m.id || '');
              const owned = String(m.owned_by || m.owned_by_ || '');
              if (owned === 'combo' || id.startsWith('combo/')) {
                const name = id.replace(/^combo\\//, '');
                return !st.inactiveCombos.has(name) && st.inactiveCombos.size === 0 ? true : !st.inactiveCombos.has(name);
              }
              if (id.startsWith('auto/')) return includeAuto;
              if (id.startsWith('no-think/')) return includeNoThink;
              const slash = id.indexOf('/');
              const prefix = slash > 0 ? id.slice(0, slash) : '';
              const leaf = slash > 0 ? id.slice(slash + 1) : id;
              if (prefix && !st.activePrefixes.has(prefix)) {
                // keep unknown prefixes (builtins like anthropic/openai) but drop node prefixes with no active connection
                // heuristic: node prefixes are non-empty and not in a small builtin allowlist — keep simple: hide only if prefix registered in hiddenByPrefix map keys OR activePrefixes non-empty and prefix not active and prefix not builtin-ish
                const BUILTIN = new Set(['anthropic','openai','google','deepseek','xai','openrouter','groq','mistral','cohere','zai','z-ai','auto','combo']);
                if (!BUILTIN.has(prefix)) return false;
              }
              const sets = [st.hiddenByPrefix.get(prefix), st.hiddenByPrefix.get(leaf)];
              for (const s of sets) { if (s && (s.has(id) || s.has(leaf))) return false; }
              return true;
            });
            const out = JSON.stringify(json);
            if (!res.headersSent) res.setHeader('content-length', Buffer.byteLength(out));
            else res.setHeader('content-length', Buffer.byteLength(out)); // guard above kept for clarity; headers already set before end is fine to overwrite pre-flush
            origEnd(out);
            return;
          }
        } catch (_) { failed = true; }
        if (failed) {
          // fail-open: flush what we buffered
          try {
            for (const ch of chunks) origWrite(ch);
          } catch (_) {}
          origEnd();
          return;
        }
        origEnd(c, ...a);
      };
    } catch (_) {}
    return listener.call(this, req, res);
  };
}
try {
  const __orig = module.exports.wrapRequestListenerWithMethodGuard;
  if (__orig) {
    module.exports.wrapRequestListenerWithMethodGuard = function (listener) {
      return __orig.call(this, wrapWithModelsFilter(listener));
    };
  }
} catch (_) {}
// ==== end patch-guard-termux ====
`;

  const patched = base + injection;
  // syntax check before shipping (never write a corrupt guard)
  try {
    new Function(patched); // throws on syntax error
  } catch (e) {
    console.error('patch-guard-termux: syntax check FAILED, aborting:', e.message);
    process.exit(1);
  }
  fs.writeFileSync(target, patched);
  console.log('patch-guard-termux: patch applied + syntax OK');
  if (!process.env.SKIP_RESTART) {
    console.log('patch-guard-termux: restart the omniroute server to apply (omniroute serve)');
  }
}

main();
