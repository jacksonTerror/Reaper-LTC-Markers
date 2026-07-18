#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin/windows

LIBLTC_SRC="../libltc/src"
if [[ ! -f "$LIBLTC_SRC/ltc.c" ]]; then
  echo "libltc sources not found at $LIBLTC_SRC"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

echo "Building ltc_scan.exe…"
gcc -O2 -std=c11 -mwindows \
  -Iinclude -I"$LIBLTC_SRC" \
  src/ltc_scan_lib.c src/ltc_scan_cli.c \
  "$LIBLTC_SRC/ltc.c" \
  "$LIBLTC_SRC/decoder.c" \
  "$LIBLTC_SRC/encoder.c" \
  "$LIBLTC_SRC/timecode.c" \
  -o bin/ltc_scan.exe

cp -f bin/ltc_scan.exe bin/windows/ltc_scan.exe
echo "OK: $(pwd)/bin/ltc_scan.exe"
