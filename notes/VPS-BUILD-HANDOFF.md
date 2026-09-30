# OmniRoute 3.8.51 — VPS build handoff (dist/ only)

**The one goal:** build `dist/` (backend-only standalone server bundle) for
OmniRoute 3.8.51 on the VPS and ship the tarball back to the phone.

Why this is easy on the VPS:
- `dist/` is **pure JavaScript** (Next.js standalone output) — platform-
  independent. No NDK, no cross-compile, **no Termux patches needed**.
- The only native dependency (better-sqlite3) is already compiled on the
  phone against Bionic; the phone swaps it in after extraction.
- The phone CANNOT build it: Turbopack has no android-arm64 binding, and
  webpack OOMs/cache-snapshot-fails on-device (tried 1.5GB + 3GB heaps,
  12GB swap — dead end, do not retry).

## Build (copy-paste on the VPS)

```bash
git clone --depth 1 -b release/v3.8.51 https://github.com/diegosouzapw/OmniRoute.git omniroute
cd omniroute
npm ci --no-audit --no-fund        # full deps (dev included) — build needs them

rm -rf .build dist
npm run build:backend              # = OMNIROUTE_BUILD_BACKEND_ONLY=1 node scripts/build/build-next-isolated.mjs

# fallback if the standalone wasn't colocated into dist/:
test -f dist/server.js || cp -a .build/next/standalone/. dist/

# verify, then package
test -f dist/server.js && tar -czf omniroute-dist-3.8.51-backend.tar.gz dist/
```

RAM notes: backend-only build peaked >3GB on the phone; give it 4-6GB
(headroom: `NODE_OPTIONS=--max-old-space-size=6144` if it OOMs). The FULL
dashboard build (`npm run build:release`) OOM'd on this VPS before — skip
unless you've got headroom; the phone only needs the API plane.

## Ship back (GitHub release, preferred over the HTTP server)

```bash
gh release create omniroute-3.8.51-termux omniroute-dist-3.8.51-backend.tar.gz \
  -R therealfreddied/termux-harness-tui \
  --title "omniroute 3.8.51 dist (backend-only)" \
  --notes "Built on VPS for Termux aarch64. Phone integrates via recipes/omniroute-post-install.sh"
```

## Phone-side (already scripted — one command)

```bash
curl -fsSLO "https://github.com/therealfreddied/termux-harness-tui/releases/download/omniroute-3.8.51-termux/omniroute-dist-3.8.51-backend.tar.gz"
bash ~/LLM/termux-harness-tui/recipes/omniroute-post-install.sh omniroute-dist-3.8.51-backend.tar.gz
```

The script: extracts `dist/` into `~/omniroute/`, swaps the glibc
better-sqlite3 addon for the phone-built Bionic one, applies the android
loader patches inside `dist/node_modules/`, applies the `/v1/models`
visibility patch, then prints the start command (`omniroute serve --no-open`).

## Security

- Rotate the API key that leaked into chat/logs earlier this session.
- Keep the server on loopback (`OMNIROUTE_SERVER_HOST=127.0.0.1`) — the
  inference plane without an API key must not be LAN-reachable.
