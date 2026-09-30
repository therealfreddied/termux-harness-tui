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
if [ -d "$DSH_DIR/node_modules/@deepseek-ai/dsh" ]; then
  printf "%-22s %s\n" "version:" "$(cat "$DSH_DIR/.dsh-termux-version" 2>/dev/null || echo unknown)"
  printf "%-22s %s\n" "shim:" \
    "$([ -f "$DSH_DIR/shim/dsh-termux-preload.cjs" ] && echo OK || echo MISSING)"
  # The linux-arm64 prebuild is glibc-linked and cannot dlopen under Bionic;
  # only a from-source build counts as healthy.
  PTY="$DSH_DIR/node_modules/node-pty/build/Release/pty.node"
  if [ -f "$PTY" ]; then
    printf "%-22s %s\n" "node-pty (bionic):" \
      "$(strings -a "$PTY" 2>/dev/null | grep -qm1 'GLIBC_' && echo "BROKEN (glibc prebuild)" || echo OK)"
  else
    printf "%-22s %s\n" "node-pty (bionic):" "not built"
  fi
  for dep in node_modules/koffi node_modules/sharp node_modules/sherpa-onnx; do
    [ -d "$DSH_DIR/$dep" ] || continue
    n="${dep##*/}"
    # Stubs can sit one level down (sharp ships from dist/), so allow depth 2.
    if [ -n "$(find "$DSH_DIR/$dep" -maxdepth 2 -name '*.termux-orig' -print -quit 2>/dev/null)" ]; then
      printf "%-22s %s\n" "$n:" "stubbed (Bionic-safe)"
    else
      printf "%-22s %s\n" "$n:" "native"
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
