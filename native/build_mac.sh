#!/usr/bin/env bash
# Build ltc_scan for macOS. Run on a Mac or in GitHub Actions (macos-latest).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin/macos

LIBLTC_SRC="../libltc/src"
if [[ ! -f "$LIBLTC_SRC/ltc.c" ]]; then
  echo "libltc sources not found at $LIBLTC_SRC"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

echo "Building macOS ltc_scan…"
clang -O2 -std=c11 \
  -Iinclude -I"$LIBLTC_SRC" \
  src/ltc_scan_lib.c src/ltc_scan_cli.c \
  "$LIBLTC_SRC/ltc.c" \
  "$LIBLTC_SRC/decoder.c" \
  "$LIBLTC_SRC/encoder.c" \
  "$LIBLTC_SRC/timecode.c" \
  -lm -o bin/macos/ltc_scan

chmod +x bin/macos/ltc_scan
cp -f bin/macos/ltc_scan bin/ltc_scan
echo "OK: $(pwd)/bin/macos/ltc_scan"
