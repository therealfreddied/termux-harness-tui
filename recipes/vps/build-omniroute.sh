#!/usr/bin/env bash
# build-omniroute.sh — VPS one-shot: build OmniRoute 3.8.51 backend-only dist/
# Run on an x86_64/aarch64 Linux VPS (Node >= 20, git, npm, gh CLI).
# NOT for Termux/Android — dist/ is pure JS; the phone cannot build it.
set -euo pipefail

OMNI_VER="${OMNI_VER:-3.8.51}"
SRC_URL="${SRC_URL:-https://github.com/diegosouzapw/OmniRoute.git}"
GH_REPO="${GH_REPO:-therealfreddied/termux-harness-tui}"
WORK="${OMNI_BUILD_DIR:-$HOME/omniroute-build}"
TARBALL="omniroute-dist-${OMNI_VER}-backend.tar.gz"

log() { printf '\033[38;5;161m==>\033[0m %s\n' "$*"; }

log "1/6 clone release/v${OMNI_VER} (shallow)"
rm -rf "$WORK"
mkdir -p "$(dirname "$WORK")"
git clone --depth 1 -b "release/v${OMNI_VER}" "$SRC_URL" "$WORK"
cd "$WORK"

log "2/6 npm ci (full deps incl. dev; 2-5 min)"
npm ci --no-audit --no-fund

log "3/6 backend-only build (OMNIROUTE_BUILD_BACKEND_ONLY=1)"
rm -rf .build dist
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=6144}"
if ! npm run build:backend; then
  log "fallback: running build-next-isolated.mjs directly"
  OMNIROUTE_BUILD_BACKEND_ONLY=1 node scripts/build/build-next-isolated.mjs
fi

log "4/6 colocate standalone output if needed"
[ -f dist/server.js ] || { mkdir -p dist; cp -a .build/next/standalone/. dist/; }
test -f dist/server.js || { echo "FATAL: dist/server.js missing" >&2; exit 1; }

log "5/6 verify"
node --check dist/server.js
du -sh dist

# best-effort smoke test (20s loopback)
(timeout 20 node dist/server.js >smoke.log 2>&1 & echo $! >smoke.pid) || true
sleep 8
curl -s -o /dev/null -w "health: %{http_code}\n" http://127.0.0.1:20128/api/health || echo "health: WARN"
curl -s -o /dev/null -w "models: %{http_code}\n" http://127.0.0.1:20128/v1/models || echo "models: WARN"
kill "$(cat smoke.pid 2>/dev/null)" 2>/dev/null || true

log "6/6 package + publish to GitHub Releases"
tar -czf "$TARBALL" dist/
sha256sum "$TARBALL" | tee "${TARBALL}.sha256"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh release view "omniroute-${OMNI_VER}-termux" -R "$GH_REPO" >/dev/null 2>&1; then
    gh release upload "omniroute-${OMNI_VER}-termux" "$TARBALL" "${TARBALL}.sha256" -R "$GH_REPO" --clobber
  else
    gh release create "omniroute-${OMNI_VER}-termux" "$TARBALL" "${TARBALL}.sha256" \
      -R "$GH_REPO" \
      --title "omniroute ${OMNI_VER} dist (backend-only)" \
      --notes "Built on VPS for Termux aarch64. Phone integrates via recipes/omniroute-post-install.sh"
  fi
  log "SUCCESS. Download URL: https://github.com/${GH_REPO}/releases/download/omniroute-${OMNI_VER}-termux/${TARBALL}"
else
  log "gh not configured — upload $TARBALL manually to repo $GH_REPO release tag omniroute-${OMNI_VER}-termux"
fi
