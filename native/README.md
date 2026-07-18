# Native helper: `ltc_scan`

Cross-platform C CLI that decodes LTC with [libltc](https://github.com/x42/libltc) for the Lua ReaScript.

## Binaries

| Platform | Path |
|---|---|
| Windows | `bin/ltc_scan.exe` or `bin/windows/ltc_scan.exe` |
| macOS | `bin/ltc_scan` or `bin/macos/ltc_scan` (universal: arm64 + x86_64) |

Prefer downloading **GitHub Actions** artifacts (see root README). Windows `.exe` does not run on Mac. The Mac build is a **universal** binary so Intel and Apple Silicon both work.

## Build

Requires the `libltc` git submodule at `../libltc`:

```bash
git submodule update --init --recursive
```

```bat
REM Windows (MSYS2 gcc)
build_win.bat
```

```bash
# macOS
./build_mac.sh
```

Decode runs at 48 kHz (96 kHz sources are decimated) for speed comparable to REAtcMARK.
