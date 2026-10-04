#!/usr/bin/env bash
# scripts/resolve-latest.sh — resolve live latest versions vs manifest versions
# Dependencies: bash, jq, curl. Compatible with standard Linux and Termux.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"

if [ ! -d "$MANIFESTS_DIR" ]; then
  echo "Error: manifests directory not found at $MANIFESTS_DIR" >&2
  exit 1
fi

printf "%-18s %-20s %-20s %-10s\n" "HARNESS" "MANIFEST-VER" "LIVE-LATEST" "STATUS"
printf "%-18s %-20s %-20s %-10s\n" "-------" "------------" "-----------" "------"

for manifest in "$MANIFESTS_DIR"/*.json; do
  [ -f "$manifest" ] || continue
  name="$(basename "$manifest" .json)"
  [ "$name" = "schema" ] && continue

  manifest_version="$(jq -r '.version // "unknown"' "$manifest")"
  source_url="$(jq -r '.source.url // empty' "$manifest")"
  source_type="$(jq -r '.source.type // empty' "$manifest")"

  live_version="-"
  status="unknown"

  if [[ "$source_url" == *"registry.npmjs.org"* ]] || [ "$source_type" = "npm" ]; then
    pkg_name="$(jq -r '.source.package // empty' "$manifest")"
    if [ -z "$pkg_name" ]; then
      if [[ "$source_url" =~ registry\.npmjs\.org/(@[^/]+/[^/]+) ]]; then
        pkg_name="${BASH_REMATCH[1]}"
      elif [[ "$source_url" =~ registry\.npmjs\.org/([^/]+) ]]; then
        pkg_name="${BASH_REMATCH[1]}"
      fi
    fi
    if [ -n "$pkg_name" ]; then
      live_version="$(curl -sSL --max-time 10 "https://registry.npmjs.org/${pkg_name}/latest" 2>/dev/null | jq -r '.version // "-"' 2>/dev/null || echo "-")"
    fi
  elif [[ "$source_url" == *"github.com"* ]] || [ "$source_type" = "github-release" ]; then
    if [[ "$source_url" =~ github\.com/([^/]+)/([^/]+) ]]; then
      owner="${BASH_REMATCH[1]}"
      repo="${BASH_REMATCH[2]%.git}"
      # Filter to avoid pointing to this repo's own releases if upstream is separate
      live_version="$(curl -sSL --max-time 10 "https://api.github.com/repos/${owner}/${repo}/releases/latest" 2>/dev/null | jq -r '.tag_name // "-"' 2>/dev/null || echo "-")"
      live_version="${live_version#v}"
    fi
  fi

  if [ "$live_version" != "-" ] && [ -n "$live_version" ] && [ "$live_version" != "null" ]; then
    if [ "$manifest_version" = "$live_version" ] || [ "$manifest_version" = "latest" ]; then
      status="resolved"
    else
      status="outdated"
    fi
  else
    live_version="-"
  fi

  printf "%-18s %-20s %-20s %-10s\n" "$name" "$manifest_version" "$live_version" "$status"
done
