#!/data/data/com.termux/files/usr/bin/bash
# doctor.sh — health check for harness-hub
echo "== Harness Doctor =="
printf "%-22s %s\n" "Termux PREFIX:" "${PREFIX:-unset}"
printf "%-22s %s\n" "Arch:" "$(uname -m)"
printf "%-22s %s\n" "glibc loader:" \
  "$([ -e "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" ] && echo OK || echo missing)"
printf "%-22s %s\n" "patchelf:" "$(command -v patchelf >/dev/null && echo OK || echo missing)"
printf "%-22s %s\n" "node:" "$(node --version 2>/dev/null || echo missing)"
printf "%-22s %s\n" "free RAM:" \
  "$(awk '/MemAvailable/{printf "%.1f MB", $2/1024}' /proc/meminfo)"
printf "%-22s %s\n" "free disk:" "$(df -h /data | awk 'NR==2{print $4}')"
echo
echo "-- dsh (DeepSeek Harness) --"
DSH_DIR="${DSH_DIR:-$PREFIX/opt/dsh}"
# The prebuilt route installs a flattened tree (dsh itself is inlined as
# lib/bin.js with 196 @deepseek-ai/* hoisted alongside); the patch route keeps
# upstream's nested node_modules/@deepseek-ai/dsh. Accept either layout.
if [ -f "$DSH_DIR/lib/bin.js" ] || [ -d "$DSH_DIR/node_modules/@deepseek-ai/dsh" ]; then
  if [ -f "$DSH_DIR/.dsh-termux-build" ]; then
    printf "%-22s %s\n" "route:" "prebuilt ($(cat "$DSH_DIR/.dsh-termux-build"))"
  else
    printf "%-22s %s\n" "route:" "patch (ours, unproven)"
  fi
  printf "%-22s %s\n" "version:" \
    "$(cat "$DSH_DIR/.dsh-termux-version" 2>/dev/null \
       || node -p "require('$DSH_DIR/package.json').version" 2>/dev/null || echo unknown)"
  # The shim only exists on the patch route; the prebuilt patches the sources
  # instead, so a missing shim is expected there and must not read as a fault.
  [ -f "$DSH_DIR/shim/dsh-termux-preload.cjs" ] \
    && printf "%-22s %s\n" "shim:" "OK" \
    || printf "%-22s %s\n" "shim:" "n/a (patches applied in-tree)"
  # The upstream linux-arm64 prebuild is glibc-linked and cannot dlopen under
  # Bionic; only an android-arm64 or from-source build is healthy.
  PTY="$DSH_DIR/node_modules/node-pty/build/Release/pty.node"
  if [ -f "$PTY" ]; then
    if strings -a "$PTY" 2>/dev/null | grep -qm1 'GLIBC_\|ld-linux-aarch64'; then
      printf "%-22s %s\n" "node-pty (bionic):" "BROKEN (glibc prebuild)"
    else
      printf "%-22s %s\n" "node-pty (bionic):" \
        "OK ($(cd "$DSH_DIR" && node -e "require('node-pty')" >/dev/null 2>&1 && echo loads || echo 'WILL NOT LOAD'))"
    fi
  else
    printf "%-22s %s\n" "node-pty (bionic):" "not built"
  fi
  if [ -d "$DSH_DIR/node_modules/koffi" ]; then
    printf "%-22s %s\n" "koffi:" \
      "$(cd "$DSH_DIR" && node -e "require('koffi')" >/dev/null 2>&1 && echo "OK (loads)" || echo "BROKEN (will not load)")"
  fi
  # @vscode/ripgrep ships no android-arm64 package; without this shim the
  # glob/grep tools fail in every fresh process.
  if [ -f "$DSH_DIR/node_modules/@vscode/ripgrep-android-arm64/package.json" ]; then
    printf "%-22s %s\n" "ripgrep shim:" "OK -> $(readlink -f "$DSH_DIR/node_modules/@vscode/ripgrep-android-arm64/bin/rg" 2>/dev/null)"
  else
    printf "%-22s %s\n" "ripgrep shim:" "MISSING (glob/grep tools will fail)"
  fi
  # On the patch route, stubs can sit one level down (sharp ships from dist/).
  for dep in node_modules/sharp node_modules/sherpa-onnx; do
    [ -d "$DSH_DIR/$dep" ] || continue
    n="${dep##*/}"
    if [ -n "$(find "$DSH_DIR/$dep" -maxdepth 2 -name '*.termux-orig' -print -quit 2>/dev/null)" ]; then
      printf "%-22s %s\n" "$n:" "stubbed (Bionic-safe)"
    fi
  done
else
  echo "  not installed (run recipes/dsh-termux.sh)"
fi

echo
echo "-- installed harnesses --"
for c in claude opencode codex openclaude agy antigravity cline grok dsh hermes bwb pentestcode cli-proxy-api 9router; do
  p="$PREFIX/bin/$c"
  if [ -e "$p" ]; then
    printf "%-12s %s\n" "$c" "$(command -v "$c")"
  fi
done
