-- Settings dialog using stock REAPER gfx (no ReaImGui / ReaPack required).
local M = {}

local path_util = require("rlm_path")
local config = require("rlm_config")
local mapping_editor = require("rlm_mapping_editor")

local FPS_OPTIONS = { "24", "25", "29.97", "30" }
local GAIN_DB_OPTIONS = { "0", "6", "12", "18" }

local function browse_csv(current)
  local start = current
  if not start or start == "" or not reaper.file_exists(start) then
    start = path_util.template_csv_path()
  end
  local rv, path = reaper.GetUserFileNameForRead(start, "Select SMPTE mapping CSV", ".csv")
  if rv and path and path ~= "" then
    return path
  end
  return current
end

local function index_of(list, value, default_index)
  for i, v in ipairs(list) do
    if v == value then
      return i
    end
  end
  return default_index or 1
end

local function normalize(settings)
  local fps = settings.fps or "30"
  local gain_mode = (settings.gain_mode or "auto"):lower()
  local gain_db = tostring(settings.gain_db or "0")
  local mode = (settings.mode or "replace"):lower()

  if gain_mode ~= "auto" and gain_mode ~= "manual" then
    gain_mode = "auto"
  end
  if mode ~= "replace" and mode ~= "append" then
    mode = "replace"
  end

  return {
    csv_path = settings.csv_path or "",
    fps = FPS_OPTIONS[index_of(FPS_OPTIONS, fps, 4)],
    gain_mode = gain_mode,
    gain_db = GAIN_DB_OPTIONS[index_of(GAIN_DB_OPTIONS, gain_db, 1)],
    mode = mode,
    tolerance_frames = settings.tolerance_frames or "3",
  }
end

local function hit(mx, my, x, y, w, h)
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function draw_chip(label, x, y, w, h, selected, hover)
  if selected then
    gfx.set(0.28, 0.55, 0.40, 1)
  elseif hover then
    gfx.set(0.28, 0.30, 0.34, 1)
  else
    gfx.set(0.18, 0.20, 0.24, 1)
  end
  gfx.rect(x, y, w, h, 1)
  gfx.set(selected and 0.95 or 0.82, selected and 0.97 or 0.84, selected and 0.95 or 0.88, 1)
  gfx.setfont(1, "Arial", 13)
  local tw, th = gfx.measurestr(label)
  gfx.x = x + (w - tw) / 2
  gfx.y = y + (h - th) / 2
  gfx.drawstr(label)
end

local function draw_button(label, x, y, w, h, primary, hover)
  if primary then
    gfx.set(hover and 0.34 or 0.28, hover and 0.72 or 0.62, hover and 0.48 or 0.40, 1)
  else
    gfx.set(hover and 0.30 or 0.22, hover and 0.32 or 0.24, hover and 0.36 or 0.28, 1)
  end
  gfx.rect(x, y, w, h, 1)
  gfx.set(0.95, 0.96, 0.97, 1)
  gfx.setfont(1, "Arial", 14)
  local tw, th = gfx.measurestr(label)
  gfx.x = x + (w - tw) / 2
  gfx.y = y + (h - th) / 2
  gfx.drawstr(label)
end

--- gfx chooser. Calls on_done(settings_or_nil).
function M.prompt_gfx(cfg, on_done)
  local draft = normalize(cfg)
  if draft.csv_path == "" or not reaper.file_exists(draft.csv_path) then
    draft.csv_path = path_util.template_csv_path()
  end

  local fps_idx = index_of(FPS_OPTIONS, draft.fps, 4)
  local gain_idx = index_of(GAIN_DB_OPTIONS, draft.gain_db, 1)
  local prev_mb = 0
  local finished = false

  gfx.init("Reaper LTC Markers — Settings", 520, 490, 0, 160, 120)

  local function finish(result)
    if finished then
      return
    end
    finished = true
    gfx.quit()
    on_done(result)
  end

  local function open_mapping_editor()
    -- gfx is single-window: close settings, open editor, then reopen settings
    draft.fps = FPS_OPTIONS[fps_idx]
    draft.gain_db = GAIN_DB_OPTIONS[gain_idx]
    config.set("csv_path", draft.csv_path or "")
    finished = true
    gfx.quit()
    mapping_editor.open({
      path = draft.csv_path,
      on_close = function(edited_path)
        local cfg = normalize(draft)
        if edited_path and edited_path ~= "" then
          cfg.csv_path = edited_path
        end
        -- Continue the Process settings flow after editing
        M.prompt_gfx(cfg, on_done)
      end,
    })
  end

  local function loop()
    if finished then
      return
    end

    local c = gfx.getchar()
    if c == -1 then
      finish(nil)
      return
    end
    if c == 27 then -- Esc
      finish(nil)
      return
    end
    if c == 13 then -- Enter
      if draft.csv_path ~= "" and reaper.file_exists(draft.csv_path) then
        draft.fps = FPS_OPTIONS[fps_idx]
        draft.gain_db = GAIN_DB_OPTIONS[gain_idx]
        finish(normalize(draft))
        return
      end
    end

    local w, h = gfx.w, gfx.h
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mb = gfx.mouse_cap
    local click = (mb & 1) == 1 and (prev_mb & 1) == 0
    prev_mb = mb

    -- background
    gfx.set(0.11, 0.12, 0.14, 1)
    gfx.rect(0, 0, w, h, 1)

    gfx.set(0.95, 0.96, 0.97, 1)
    gfx.setfont(1, "Arial", 18)
    gfx.x, gfx.y = 20, 16
    gfx.drawstr("Scan settings")

    -- CSV
    gfx.set(0.70, 0.72, 0.76, 1)
    gfx.setfont(1, "Arial", 12)
    gfx.x, gfx.y = 20, 52
    gfx.drawstr("Mapping CSV")

    gfx.set(0.16, 0.17, 0.20, 1)
    gfx.rect(20, 72, w - 140, 28, 1)
    gfx.set(0.85, 0.87, 0.90, 1)
    gfx.setfont(1, "Arial", 12)
    local csv_show = draft.csv_path or ""
    if #csv_show > 62 then
      csv_show = "…" .. csv_show:sub(-60)
    end
    gfx.x, gfx.y = 28, 78
    gfx.drawstr(csv_show)

    local browse_x, browse_y, browse_w, browse_h = w - 110, 72, 90, 28
    local browse_hover = hit(mx, my, browse_x, browse_y, browse_w, browse_h)
    draw_button("Browse…", browse_x, browse_y, browse_w, browse_h, false, browse_hover)
    if click and browse_hover then
      local picked = browse_csv(draft.csv_path)
      if picked and picked ~= "" then
        draft.csv_path = picked
      end
    end

    local edit_x, edit_y, edit_w, edit_h = 20, 106, 140, 26
    local edit_hover = hit(mx, my, edit_x, edit_y, edit_w, edit_h)
    draw_button("Edit mapping…", edit_x, edit_y, edit_w, edit_h, false, edit_hover)
    if click and edit_hover then
      open_mapping_editor()
      return
    end

    -- FPS chips
    gfx.set(0.70, 0.72, 0.76, 1)
    gfx.setfont(1, "Arial", 12)
    gfx.x, gfx.y = 20, 148
    gfx.drawstr("Frame rate")
    local chip_y = 170
    local chip_w, chip_h, gap = 70, 28, 8
    for i, label in ipairs(FPS_OPTIONS) do
      local x = 20 + (i - 1) * (chip_w + gap)
      local hover = hit(mx, my, x, chip_y, chip_w, chip_h)
      draw_chip(label, x, chip_y, chip_w, chip_h, i == fps_idx, hover)
      if click and hover then
        fps_idx = i
        draft.fps = label
      end
    end

    -- Gain mode
    gfx.set(0.70, 0.72, 0.76, 1)
    gfx.x, gfx.y = 20, 216
    gfx.drawstr("Decode gain")
    local mode_y = 238
    local auto_w, man_w = 200, 110
    local auto_hover = hit(mx, my, 20, mode_y, auto_w, chip_h)
    local man_hover = hit(mx, my, 20 + auto_w + gap, mode_y, man_w, chip_h)
    draw_chip("Auto (recommended)", 20, mode_y, auto_w, chip_h, draft.gain_mode == "auto", auto_hover)
    draw_chip("Manual", 20 + auto_w + gap, mode_y, man_w, chip_h, draft.gain_mode == "manual", man_hover)
    if click and auto_hover then
      draft.gain_mode = "auto"
    end
    if click and man_hover then
      draft.gain_mode = "manual"
    end

    gfx.set(0.70, 0.72, 0.76, 1)
    gfx.x, gfx.y = 20, 280
    gfx.drawstr(draft.gain_mode == "auto" and "Boost floor" or "Gain amount")
    local db_y = 302
    for i, label in ipairs(GAIN_DB_OPTIONS) do
      local x = 20 + (i - 1) * (chip_w + gap)
      local hover = hit(mx, my, x, db_y, chip_w, chip_h)
      draw_chip("+" .. label .. " dB", x, db_y, chip_w, chip_h, i == gain_idx, hover)
      if click and hover then
        gain_idx = i
        draft.gain_db = label
      end
    end

    -- Replace / Append
    gfx.set(0.70, 0.72, 0.76, 1)
    gfx.x, gfx.y = 20, 348
    gfx.drawstr("Markers")
    local mark_y = 370
    local rep_w, app_w = 140, 140
    local rep_hover = hit(mx, my, 20, mark_y, rep_w, chip_h)
    local app_hover = hit(mx, my, 20 + rep_w + gap, mark_y, app_w, chip_h)
    draw_chip("Replace", 20, mark_y, rep_w, chip_h, draft.mode == "replace", rep_hover)
    draw_chip("Append", 20 + rep_w + gap, mark_y, app_w, chip_h, draft.mode == "append", app_hover)
    if click and rep_hover then
      draft.mode = "replace"
    end
    if click and app_hover then
      draft.mode = "append"
    end

    -- Gap + rule between options and actions
    local sep_y = mark_y + chip_h + 18
    gfx.set(0.24, 0.26, 0.30, 1)
    gfx.rect(20, sep_y, w - 40, 1, 1)

    -- Process / Cancel
    local btn_y = sep_y + 16
    local btn_w = 140
    local proc_x, cancel_x = 20, 20 + btn_w + gap
    local proc_hover = hit(mx, my, proc_x, btn_y, btn_w, 34)
    local cancel_hover = hit(mx, my, cancel_x, btn_y, btn_w, 34)
    draw_button("Process", proc_x, btn_y, btn_w, 34, true, proc_hover)
    draw_button("Cancel", cancel_x, btn_y, btn_w, 34, false, cancel_hover)

    if click and proc_hover then
      if not draft.csv_path or draft.csv_path == "" or not reaper.file_exists(draft.csv_path) then
        reaper.ShowMessageBox("Please choose a valid mapping CSV.", "Reaper LTC Markers", 0)
      else
        draft.fps = FPS_OPTIONS[fps_idx]
        draft.gain_db = GAIN_DB_OPTIONS[gain_idx]
        finish(normalize(draft))
        return
      end
    end
    if click and cancel_hover then
      finish(nil)
      return
    end

    gfx.update()
    reaper.defer(loop)
  end

  reaper.defer(loop)
end

--- Entry point used by Process.lua
function M.prompt(cfg, on_done)
  M.prompt_gfx(cfg, on_done)
end

return M
