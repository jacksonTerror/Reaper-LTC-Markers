# Reaper LTC Markers

Scan a selected LTC / SMPTE media item inside [REAPER](https://www.reaper.fm/), match codes from a CSV mapping, and insert project markers — no separate desktop app, no marker CSV import step.

Cross-platform ReaScript workflow (Windows + macOS). Same mapping format as [REAtcMARK](https://github.com/jacksonTerror/REAtcMARK).

## Features

- Select an LTC/SMPTE media item (or auto-suggest a track named SMPTE/LTC)
- CSV mapping: `SMPTE Code,Marker Name` (built-in gfx editor, or edit in Excel / Google Docs)
- Auto gain (default) + manual boost for quiet timecode stripes
- **Replace** or **Append** markers
- Live progress UI with a running list of found markers
- Report written next to the project: `{ProjectName}_Markers_Report.txt`

## Architecture

| Layer | What | Cross-platform? |
|---|---|---|
| UI, settings, CSV editor, markers | REAPER Lua (`gfx`, Actions) — **no ReaImGui / ReaPack** | Yes |
| LTC decode | Small native CLI `ltc_scan` ([libltc](https://github.com/x42/libltc)) | One binary per OS |

Lua scripts are identical on every machine. Only `native/bin/ltc_scan` (macOS) / `ltc_scan.exe` (Windows) differs. Download both from **GitHub Actions → Artifacts** after a build.

## Quick install

Works the same on Windows and Mac: drop the folder in Scripts, load the action.

1. Get the `Reaper-LTC-Markers` folder (USB copy, clone, or download).
2. Ensure the helper for your OS is in `native/bin/` ([CI artifacts](#native-helper-binaries-ci)):
   - Windows: `ltc_scan.exe`
   - macOS: `ltc_scan` (then `chmod +x` — see [INSTALL.md](INSTALL.md))
3. Copy the whole folder into your REAPER Scripts directory.
4. In REAPER: **Actions → Show action list → Load ReaScript…**  
   → `scripts/Reaper LTC Markers - Process.lua`

Full steps (including Mac Terminal `chmod +x` and Gatekeeper): **[INSTALL.md](INSTALL.md)**

## Workflow

1. Save the REAPER project.
2. Select the LTC item (or name the track `SMPTE` / `LTC`).
3. Run **Reaper LTC Markers - Process**.
4. Choose mapping CSV, FPS, gain, replace/append.
5. Watch the progress window; markers appear when the scan finishes.

## CSV format

```csv
SMPTE Code,Marker Name
01:00:00:00,Song One
01:04:00:00,Song Two
```

Template: [`templates/smpte_mapping_template.csv`](templates/smpte_mapping_template.csv)

## Native helper binaries (CI)

This repo includes a GitHub Action that builds Windows + macOS helpers **without a local Mac**.

1. Open the repo on GitHub → **Actions** → **Build native helpers**
2. Run workflow (**Run workflow**), or push a change under `native/`
3. Download artifacts:
   - `ltc_scan-windows` → place as `native/bin/ltc_scan.exe`
   - `ltc_scan-macos` → place as `native/bin/ltc_scan` and/or `native/bin/macos/ltc_scan`

On macOS, make it executable once (`chmod +x`) and approve Gatekeeper if prompted — step-by-step in [INSTALL.md](INSTALL.md#macos-make-the-helper-executable-chmod-x).

### Local build (optional)

```bash
git submodule update --init --recursive
# Windows (MSYS2 gcc):
native/build_win.bat
# macOS:
native/build_mac.sh
```

`libltc` is included as a **git submodule** (`libltc/` → [x42/libltc](https://github.com/x42/libltc)).

## Developer layout

```
Reaper-LTC-Markers/
  scripts/                 # ReaScripts + Lua modules
  native/                  # ltc_scan C sources + build scripts
  libltc/                  # submodule
  templates/               # CSV template
  .github/workflows/       # CI builds
```

## License / credits

- Script project: use and adapt for your sessions.
- LTC decode: [libltc](https://github.com/x42/libltc) (see that project for its license).
