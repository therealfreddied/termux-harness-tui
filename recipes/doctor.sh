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
echo "-- installed harnesses --"
for c in claude opencode codex openclaude agy antigravity cline grok dsh; do
  p="$PREFIX/bin/$c"
  if [ -e "$p" ]; then
    printf "%-12s %s\n" "$c" "$(command -v "$c")"
  fi
done
