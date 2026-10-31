#!/bin/sh
set -e
ROOT=${1:-.}
n=0
for l in $(find "$ROOT" -xtype l 2>/dev/null); do
  rm -f "$l"
  case "$l" in
    *.h|*.c|*.cc|*.cpp|*.S|*.inc|*.dts|*.dtsi|*.txt|*.json|*.py|*.yaml|*.mk)
      : > "$l" ;;
    *)
      mkdir -p "$l"; : > "$l/Kconfig"; : > "$l/Makefile" ;;
  esac
  n=$((n+1))
done
echo "fix-symlinks: $n"
