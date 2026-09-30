# OpenClaw Task: Build OmniRoute 3.8.51 standalone dist/ bundle

## Context
OmniRoute 3.8.51 is running on a Galaxy S23 (Termux, aarch64, Bionic, no proot).
All phone-side files and patches are ALREADY done (Bionic better-sqlite3, loader patches, post-install integration script).
The ONE missing piece is `dist/server.js` (Next.js standalone backend bundle).
The phone CANNOT build it (Turbopack has no android-arm64 binding; webpack OOMs at any heap size).

`dist/` is pure JavaScript (Next.js standalone output). The build on the VPS needs NO Termux patches, NO NDK, and NO cross-compilers. Do NOT apply any .patch files.

---

## What to download & run (One-liner on VPS)

Run this on your Linux VPS:

```bash
git clone --depth 1 https://github.com/therealfreddied/termux-harness-tui.git /tmp/harness && bash /tmp/harness/recipes/vps/build-omniroute.sh
```

---

## Manual step-by-step commands (if not using the script)

```bash
# 1. Clone source
git clone --depth 1 -b release/v3.8.51 https://github.com/diegosouzapw/OmniRoute.git ~/omniroute-build
cd ~/omniroute-build

# 2. Install full dependencies (dev included — build requires them)
npm ci --no-audit --no-fund

# 3. Clean & build backend-only (DO NOT run build:release / full dashboard — it OOMs)
rm -rf .build dist
export NODE_OPTIONS="--max-old-space-size=6144"
OMNIROUTE_BUILD_BACKEND_ONLY=1 npm run build:backend

# 4. Fallback colocation (if build output went to .build/next/standalone)
if [ ! -f dist/server.js ] && [ -d .build/next/standalone ]; then
  mkdir -p dist
  cp -a .build/next/standalone/. dist/
fi

# 5. Verify the bundle
test -f dist/server.js || { echo "ERROR: dist/server.js not found"; exit 1; }
node --check dist/server.js

# 6. Package tarball (archive root MUST be dist/)
tar -czf omniroute-dist-3.8.51-backend.tar.gz dist/
sha256sum omniroute-dist-3.8.51-backend.tar.gz > omniroute-dist-3.8.51-backend.tar.gz.sha256

# 7. Upload to GitHub Releases (EXACT tag and filename required)
gh release create omniroute-3.8.51-termux \
  omniroute-dist-3.8.51-backend.tar.gz \
  omniroute-dist-3.8.51-backend.tar.gz.sha256 \
  -R therealfreddied/termux-harness-tui \
  --title "omniroute 3.8.51 dist (backend-only)" \
  --notes "Built on VPS for Termux aarch64. Phone integrates via recipes/omniroute-post-install.sh"
```

---

## How to verify it works (VPS-side checks)
1. `test -f dist/server.js` (must exist)
2. `node --check dist/server.js` (must return 0 / no syntax errors)
3. `tar -tzf omniroute-dist-3.8.51-backend.tar.gz | head -5` (must show `dist/` and `dist/server.js` at root)

---

## What to report back
- The GitHub release URL: `https://github.com/therealfreddied/termux-harness-tui/releases/tag/omniroute-3.8.51-termux`
- The `sha256sum` of `omniroute-dist-3.8.51-backend.tar.gz`
- Confirmation that `node --check dist/server.js` passed
