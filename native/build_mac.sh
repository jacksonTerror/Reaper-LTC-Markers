#!/usr/bin/env bash
# Build ltc_scan for macOS as a universal binary (arm64 + x86_64).
# Run on a Mac or in GitHub Actions (macos-latest).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin/macos

LIBLTC_SRC="../libltc/src"
if [[ ! -f "$LIBLTC_SRC/ltc.c" ]]; then
  echo "libltc sources not found at $LIBLTC_SRC"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

OUT="bin/macos/ltc_scan"
# Universal so Intel and Apple Silicon Macs both run the same helper.
ARCHS=(-arch arm64 -arch x86_64)

echo "Building macOS ltc_scan (universal: arm64 + x86_64)…"
clang -O2 -std=c11 "${ARCHS[@]}" \
  -Iinclude -I"$LIBLTC_SRC" \
  src/ltc_scan_lib.c src/ltc_scan_cli.c \
  "$LIBLTC_SRC/ltc.c" \
  "$LIBLTC_SRC/decoder.c" \
  "$LIBLTC_SRC/encoder.c" \
  "$LIBLTC_SRC/timecode.c" \
  -lm -o "$OUT"

chmod +x "$OUT"
cp -f "$OUT" bin/ltc_scan

echo "OK: $(pwd)/$OUT"
if command -v lipo >/dev/null 2>&1; then
  echo "Architectures: $(lipo -archs "$OUT")"
fi
file "$OUT"
