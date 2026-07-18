# Install — Reaper LTC Markers

## 1. Get the project

```bash
git clone --recurse-submodules https://github.com/jacksonTerror/Reaper-LTC-Markers.git
```

Or download the source from GitHub and then:

```bash
git submodule update --init --recursive
```

If you only copied a folder without git, you still need the `ltc_scan` binary (step 2) and the `scripts/`, `templates/`, and `native/bin/` layout.

## 2. Native helper

| OS | File |
|---|---|
| Windows | `native/bin/ltc_scan.exe` |
| macOS | `native/bin/ltc_scan` |

**Easiest:** GitHub → **Actions** → **Build native helpers** → download the artifact for your OS → copy into `native/bin/`.

On macOS after copying:

```bash
chmod +x native/bin/ltc_scan
```

## 3. Copy into REAPER

Copy the entire `Reaper-LTC-Markers` folder to:

```
<REAPER resource path>/Scripts/Reaper-LTC-Markers/
```

**Options → Show REAPER resource path in explorer/finder** shows that folder.

Keep `native/bin/` inside the copy so the script can find the helper.

## 4. Load the action

1. REAPER → **Actions → Show action list…**
2. **New action… / Load ReaScript…**
3. Select `scripts/Reaper LTC Markers - Process.lua`
4. (Optional) Load `scripts/Reaper LTC Markers - Edit Mapping.lua` — stock REAPER gfx, no extra installs

Bind a shortcut or toolbar button if you like.

## 5. Mapping CSV

Use your existing REAtcMARK CSV, or start from:

`templates/smpte_mapping_template.csv`

You can edit that file anywhere (including Google Docs → export CSV). The in-Reaper editor is optional.

## 6. Run

1. Save the project.
2. Select the LTC/SMPTE media item (WAV take recommended).
3. Run **Reaper LTC Markers - Process**.
4. Confirm CSV / FPS / gain / replace|append.

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| Helper did not start | Wrong/missing `native/bin/ltc_scan` for this OS; on Mac don’t use `.exe` |
| No markers / few markers | Try Auto gain or +6/+12 dB; confirm FPS; confirm CSV codes |
| “Not a RIFF/WAV” | Consolidate/bounce the LTC take to WAV |
| macOS blocks the binary | Right-click → Open once (Gatekeeper) |

Launch diagnostics (if background start fails) are written under the REAPER resource path as `ReaperLTCMarkers_launch.log`.
