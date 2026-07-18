-- @description Reaper LTC Markers - Process
-- @version 0.3.0
-- @author Reaper LTC Markers
-- @about
--   Scan selected LTC/SMPTE item, match CSV mapping, insert project markers.
-- @provides
--   [main] Reaper LTC Markers - Process.lua
--   [nomain] modules/*.lua

local SCRIPT_PATH = ({reaper.get_action_context()})[2]
local SCRIPT_DIR = SCRIPT_PATH:match("^(.*[\\/])") or ""
package.path = SCRIPT_DIR .. "modules/?.lua;" .. package.path

local path_util = require("rlm_path")
local config = require("rlm_config")
local csv = require("rlm_csv")
local suggest = require("rlm_track_suggest")
local scan = require("rlm_scan")
local markers = require("rlm_markers")
local report = require("rlm_report")

local state = nil

local function msg(title, text)
  reaper.ShowMessageBox(text, title, 0)
end

local function browse_csv(current)
  local start = current
  if not start or start == "" then
    start = path_util.template_csv_path()
  end
  local rv, path = reaper.GetUserFileNameForRead(start, "Select SMPTE mapping CSV", ".csv")
  if rv and path and path ~= "" then
    return path
  end
  return current
end

local function prompt_settings(cfg)
  local csv_path = cfg.csv_path or ""
  if csv_path == "" or not reaper.file_exists(csv_path) then
    csv_path = browse_csv(path_util.template_csv_path())
    if not csv_path or csv_path == "" then
      return nil
    end
  else
    local pick = reaper.ShowMessageBox(
      "Use this mapping CSV?\n\n" .. csv_path .. "\n\nYes = use it\nNo = choose another",
      "Reaper LTC Markers",
      4
    )
    if pick == 7 then
      csv_path = browse_csv(csv_path)
      if not csv_path or csv_path == "" then
        return nil
      end
    end
  end

  local captions = "FPS (24/25/29.97/30),Gain mode (auto/manual),Gain dB (0/6/12/18),Mode (replace/append)"
  local defaults = table.concat({
    cfg.fps or "30",
    cfg.gain_mode or "auto",
    cfg.gain_db or "0",
    cfg.mode or "replace",
  }, ",")

  local ok, values = reaper.GetUserInputs("Reaper LTC Markers — Settings", 4, captions, defaults)
  if not ok then
    return nil
  end

  local fps, gain_mode, gain_db, mode = values:match("([^,]*),([^,]*),([^,]*),(.*)")
  fps = (fps or "30"):gsub("%s+", "")
  gain_mode = (gain_mode or "auto"):lower():gsub("%s+", "")
  gain_db = (gain_db or "0"):gsub("%s+", "")
  mode = (mode or "replace"):lower():gsub("%s+", "")

  if gain_mode ~= "auto" and gain_mode ~= "manual" then
    gain_mode = "auto"
  end
  if mode ~= "replace" and mode ~= "append" then
    mode = "replace"
  end

  return {
    csv_path = csv_path,
    fps = fps,
    gain_mode = gain_mode,
    gain_db = gain_db,
    mode = mode,
    tolerance_frames = cfg.tolerance_frames or "3",
  }
end

local function format_min(sec)
  sec = sec or 0
  local m = math.floor(sec / 60)
  local s = sec - m * 60
  return string.format("%d:%04.1f", m, s)
end

local function finish_scan()
  local s = state
  state = nil
  gfx.quit()

  local file_matches, file_unmapped, logs, herr = scan.collect_job_results(s.job)
  if herr then
    msg("Reaper LTC Markers", herr)
    return
  end

  local matches = scan.to_project_matches(s.resolved, file_matches or {})
  local unmapped = scan.to_project_unmapped(s.resolved, file_unmapped or {})
  local auto_gain = s.settings.gain_mode == "auto"
  local gain_db = tonumber(s.settings.gain_db) or 0

  if #matches == 0 then
    local extra = ""
    if logs and #logs > 0 then
      extra = "\n\nHelper log:\n" .. table.concat(logs, "\n")
    end
    report.write({
      matches = {},
      unmapped = unmapped,
      fps = s.settings.fps,
      gain_desc = auto_gain and ("auto (+" .. gain_db .. " dB floor)") or (gain_db .. " dB"),
      csv_path = s.settings.csv_path,
      source_path = s.resolved.path,
      mode = s.settings.mode,
      suggest_note = s.note,
      stats = { added = 0, skipped = 0, removed = 0 },
    })
    msg(
      "Reaper LTC Markers",
      "No mapped markers found.\n\n"
        .. "Tips:\n"
        .. "• Try Auto gain or +6 / +12 dB\n"
        .. "• Confirm FPS matches the LTC\n"
        .. "• Confirm CSV codes match the tape"
        .. extra
    )
    return
  end

  local stats = markers.apply(matches, s.settings.mode, {
    start = s.resolved.item_pos,
    finish = s.resolved.item_pos + s.resolved.item_len,
  })
  local report_path = report.write({
    matches = matches,
    unmapped = unmapped,
    fps = s.settings.fps,
    gain_desc = auto_gain and ("auto (manual floor " .. gain_db .. " dB)") or (gain_db .. " dB manual"),
    csv_path = s.settings.csv_path,
    source_path = s.resolved.path,
    mode = s.settings.mode,
    suggest_note = s.note,
    stats = stats,
  })

  msg(
    "Reaper LTC Markers",
    ("Done.\n\nAdded: %d\nSkipped: %d\nRemoved: %d\n\n%s\n\nReport:\n%s"):format(
      stats.added,
      stats.skipped,
      stats.removed,
      s.note or "",
      report_path or "(failed to write)"
    )
  )
end

local function draw_progress()
  local prog = scan.read_progress(state.job.paths.progress)
  local found = scan.read_matches_so_far(state.job.paths.out)
  local pct = prog and prog.pct or 0
  local matches = prog and prog.matches or #found
  local pos = prog and prog.pos or 0
  local total = prog and prog.total or 0
  local elapsed = reaper.time_precise() - state.t0

  local w, h = gfx.w, gfx.h
  gfx.set(0.11, 0.12, 0.14, 1)
  gfx.rect(0, 0, w, h, 1)

  gfx.set(0.95, 0.96, 0.97, 1)
  gfx.setfont(1, "Arial", 17)
  gfx.x, gfx.y = 16, 14
  gfx.drawstr("Scanning LTC")

  gfx.set(0.55, 0.75, 0.95, 1)
  gfx.setfont(1, "Arial", 12)
  gfx.x, gfx.y = 16, 38
  local spin = ({ "•", "••", "•••", "••••" })[math.floor(elapsed * 4) % 4 + 1]
  if total > 0 then
    gfx.drawstr(string.format("%s  %.0f%%   %s / %s   •   %d found   •   %.1fs",
      spin, pct, format_min(pos), format_min(total), matches, elapsed))
  else
    gfx.drawstr(string.format("%s  Starting…   %.1fs", spin, elapsed))
  end

  -- progress bar
  local bx, by, bw, bh = 16, 62, w - 32, 16
  gfx.set(0.20, 0.22, 0.26, 1)
  gfx.rect(bx, by, bw, bh, 1)
  gfx.set(0.30, 0.78, 0.55, 1)
  local fill = math.floor(bw * math.min(math.max(pct, 0), 100) / 100.0)
  if fill < 2 and (prog or #found > 0) then
    fill = 2
  end
  gfx.rect(bx, by, fill, bh, 1)

  -- live find log (like the desktop app)
  gfx.set(0.70, 0.72, 0.76, 1)
  gfx.setfont(1, "Arial", 12)
  gfx.x, gfx.y = 16, 92
  gfx.drawstr("Found markers")

  gfx.set(0.16, 0.17, 0.20, 1)
  gfx.rect(16, 112, w - 32, h - 128, 1)

  gfx.setfont(1, "Consolas", 13)
  local max_lines = math.floor((h - 140) / 18)
  if max_lines < 3 then
    max_lines = 3
  end
  local start_i = math.max(1, #found - max_lines + 1)
  local y = 118
  if #found == 0 then
    gfx.set(0.45, 0.48, 0.52, 1)
    gfx.x, gfx.y = 24, y
    gfx.drawstr("Waiting for first match…")
  else
    for i = start_i, #found do
      local m = found[i]
      gfx.set(0.55, 0.85, 0.65, 1)
      gfx.x, gfx.y = 24, y
      gfx.drawstr(string.format("%s  →  %s  @ %s",
        m.timecode or "??:??:??:??",
        m.name or "?",
        format_min(m.file_pos or 0)))
      y = y + 18
    end
  end

  gfx.update()
end

local function poll()
  if not state then
    return
  end

  gfx.getchar() -- keep window alive / process close
  draw_progress()

  if scan.job_finished(state.job) then
    finish_scan()
    return
  end

  -- If helper never starts, offer a blocking fallback with diagnostics
  if reaper.time_precise() - state.t0 > 10 and not scan.helper_seems_alive(state.job) then
    local saved = state
    local diag = scan.launch_diagnostics(saved.job)
    state = nil
    gfx.quit()

    local choice = reaper.ShowMessageBox(
      "Scan helper did not start in the background.\n\n"
        .. "YES = run blocking scan (REAPER may freeze briefly, but markers will be placed)\n"
        .. "NO = cancel\n\n"
        .. diag,
      "Reaper LTC Markers",
      4
    )
    if choice == 6 then -- Yes
      reaper.ExecProcess(saved.job.cmdline, 0)
      state = saved
      finish_scan()
    end
    return
  end

  if reaper.time_precise() - state.t0 > 600 then
    state = nil
    gfx.quit()
    msg("Reaper LTC Markers", "Scan timed out after 10 minutes.")
    return
  end

  reaper.defer(poll)
end

local function run()
  local cfg = config.load_all()
  local track, item, note = suggest.suggest()
  if not item then
    msg("Reaper LTC Markers", note or "Select an LTC/SMPTE media item first.")
    return
  end

  local settings = prompt_settings(cfg)
  if not settings then
    return
  end
  config.save_all(settings)

  local rows = csv.load(settings.csv_path)
  if not rows then
    msg("Reaper LTC Markers", "Failed to load CSV:\n" .. settings.csv_path)
    return
  end
  if #rows == 0 then
    msg("Reaper LTC Markers", "CSV has no mappings:\n" .. settings.csv_path)
    return
  end

  local resolved, err = scan.resolve_item(item)
  if not resolved then
    msg("Reaper LTC Markers", err or "Could not resolve item source")
    return
  end

  local fps_num = tonumber(settings.fps) or 30
  if settings.fps == "29.97" then
    fps_num = 30
  else
    fps_num = math.floor(fps_num + 0.5)
  end

  -- Open status window FIRST so something visible is up before launch
  gfx.init("Reaper LTC Markers — Scanning", 520, 320, 0, 180, 160)
  gfx.setfont(1, "Arial", 14)
  gfx.set(0.11, 0.12, 0.14, 1)
  gfx.rect(0, 0, gfx.w, gfx.h, 1)
  gfx.set(0.9, 0.9, 0.9, 1)
  gfx.x, gfx.y = 16, 16
  gfx.drawstr("Launching scanner…")
  gfx.update()

  local job, jerr = scan.start_helper_async({
    fps = fps_num,
    tolerance = tonumber(settings.tolerance_frames) or 3,
    mapping_path = settings.csv_path,
    audio_path = resolved.path,
    auto_gain = settings.gain_mode == "auto",
    gain_db = tonumber(settings.gain_db) or 0,
    start_sec = resolved.take_offset,
    length_sec = resolved.item_len * resolved.playrate,
  })
  if not job then
    gfx.quit()
    msg("Reaper LTC Markers", jerr or "Failed to start helper")
    return
  end

  state = {
    job = job,
    resolved = resolved,
    settings = settings,
    note = note,
    t0 = reaper.time_precise(),
  }

  reaper.defer(poll)
end

reaper.defer(run)
