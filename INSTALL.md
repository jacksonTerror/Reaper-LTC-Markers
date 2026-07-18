# Install — Reaper LTC Markers

Same idea on Windows and macOS: put the whole folder in REAPER’s Scripts directory, load the Process action, run it. The only OS-specific piece is the native helper binary inside `native/bin/`.

## 1. Get the project

**Option A — copy a ready folder (USB / shared drive)**  
Copy the entire `Reaper-LTC-Markers` folder. If it already contains both helpers from CI, you can skip rebuilding:

- Windows: `native/bin/ltc_scan.exe`
- macOS: `native/bin/ltc_scan` (and/or `native/bin/macos/ltc_scan`)

**Option B — clone from GitHub**

```bash
git clone --recurse-submodules https://github.com/jacksonTerror/Reaper-LTC-Markers.git
```

Then download the helper for your OS from CI (step 2), unless you build locally.

## 2. Native helper

| OS | File the script looks for |
|---|---|
| Windows | `native/bin/ltc_scan.exe` |
| macOS | `native/bin/ltc_scan` or `native/bin/macos/ltc_scan` |

**From GitHub Actions:** repo → **Actions** → **Build native helpers** → download artifact → place into `native/bin/` as above.

Windows `.exe` does **not** run on Mac. Keep the Mac binary named `ltc_scan` (no `.exe`).

CI builds a **universal** Mac helper (`arm64` + `x86_64`) so the same file works on Apple Silicon and Intel Macs. If you see **bad CPU type in executable**, you have an old Silicon-only binary — download a fresh `ltc_scan-macos` artifact from Actions (after the universal build) and replace `native/bin/ltc_scan`.

### macOS: executable bit + Gatekeeper

You are **not** missing a separate “install action” after copying the folder. When you hit **Process**, the script silently runs `chmod +x` and clears quarantine — there is no Terminal window or popup for that.

If you see **Scan helper did not start in the background**, do this **once** in Finder (most common fix):

1. Go to `…/Scripts/Reaper-LTC-Markers/native/bin/` (or `native/bin/macos/`)
2. Right-click (Control-click) `ltc_scan` → **Open** → **Open**
3. If a small Terminal window flashes usage text, that is fine — close it
4. Run **Process** again in REAPER (or choose **Yes** for the blocking scan)

**Manual `chmod` only if needed** — type the whole command on one line. Do **not** press Return until the path is there. Do **not** use `chmod +` (missing `x`).

```bash
chmod +x /full/path/to/ltc_scan
```

Or: type `chmod +x ` (space after `x`, **no** Return yet) → drag `ltc_scan` into Terminal → Return.

If you drop `ltc_scan` into Terminal alone and press Return, macOS **runs** the helper (looks like “the app opened”). That is not chmod.

## 3. Copy into REAPER

Copy the entire `Reaper-LTC-Markers` folder to:

```
<REAPER resource path>/Scripts/Reaper-LTC-Markers/
```

In REAPER: **Options → Show REAPER resource path in explorer/finder**.

Keep `native/bin/` inside that copy so the script can find the helper.

## 4. Load the action

1. REAPER → **Actions → Show action list…**
2. **New action… / Load ReaScript…**
3. Select `scripts/Reaper LTC Markers - Process.lua`
4. (Optional) Load `scripts/Reaper LTC Markers - Edit Mapping.lua`  
   (stock REAPER gfx — no ReaImGui / ReaPack)

Bind a shortcut or toolbar button if you like.

## 5. Mapping CSV

Use your existing REAtcMARK-style CSV, or start from:

`templates/smpte_mapping_template.csv`

Edit in Excel / Google Docs, or use **Edit mapping…** inside the Process settings window.

## 6. Run

1. Save the project.
2. Select the LTC/SMPTE media item (WAV take recommended).
3. Run **Reaper LTC Markers - Process**.
4. Choose CSV / FPS / gain / replace|append → **Process**.

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| Helper did not start | Wrong/missing helper for this OS; on Mac don’t use `.exe` |
| Helper did not start (Mac) | Script auto-`chmod`s on run; if needed, Terminal `chmod +x`; try right-click → **Open** once (Gatekeeper) |
| `bad CPU type in executable` | Old arm64-only helper on an Intel Mac — replace with the universal CI `ltc_scan-macos` artifact |
| No markers / few markers | Try Auto gain or +6/+12 dB; confirm FPS; confirm CSV codes |
| “Not a RIFF/WAV” | Consolidate/bounce the LTC take to WAV |

Launch diagnostics (if background start fails) are under the REAPER resource path as `ReaperLTCMarkers_launch.log`.
