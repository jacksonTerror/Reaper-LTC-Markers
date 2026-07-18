-- Stock gfx CSV mapping editor (callable from Process settings or standalone action)
local M = {}

local path_util = require("rlm_path")
local config = require("rlm_config")
local csv = require("rlm_csv")

local function hit(mx, my, x, y, w, h)
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function draw_btn(label, x, y, w, h, hover, primary)
  if primary then
    gfx.set(hover and 0.34 or 0.28, hover and 0.70 or 0.60, hover and 0.48 or 0.40, 1)
  else
    gfx.set(hover and 0.30 or 0.20, hover and 0.32 or 0.22, hover and 0.36 or 0.26, 1)
  end
  gfx.rect(x, y, w, h, 1)
  gfx.set(0.95, 0.96, 0.97, 1)
  gfx.setfont(1, "Arial", 12)
  local tw, th = gfx.measurestr(label)
  gfx.x = x + (w - tw) / 2
  gfx.y = y + (h - th) / 2
  gfx.drawstr(label)
end

local function draw_field(label, value, x, y, w, h, focused, hover)
  gfx.set(0.65, 0.68, 0.72, 1)
  gfx.setfont(1, "Arial", 11)
  gfx.x, gfx.y = x, y - 16
  gfx.drawstr(label)

  if focused then
    gfx.set(0.22, 0.32, 0.28, 1)
  elseif hover then
    gfx.set(0.20, 0.22, 0.26, 1)
  else
    gfx.set(0.16, 0.17, 0.20, 1)
  end
  gfx.rect(x, y, w, h, 1)
  if focused then
    gfx.set(0.35, 0.75, 0.55, 1)
    gfx.rect(x, y, w, h, 0)
  end

  gfx.set(0.92, 0.93, 0.95, 1)
  gfx.setfont(1, "Consolas", 13)
  local show = value or ""
  if focused then
    show = show .. "|"
  end
  gfx.x, gfx.y = x + 8, y + 6
  gfx.drawstr(show)
end

--- Open editor. opts: { path?=string, on_close?=function(path) }
function M.open(opts)
  opts = opts or {}
  local rows = {}
  local path = opts.path or config.get("csv_path")
  local status = ""
  local selected = 0
  local scroll = 0
  local draft_smpte = ""
  local draft_name = ""
  local focus = "smpte"
  local prev_mb = 0
  local finished = false
  local dragging_scroll = false
  local drag_offset_y = 0

  if path == "" or not reaper.file_exists(path) then
    path = path_util.template_csv_path()
  end

  local function load_path(p)
    local loaded, err = csv.load(p)
    if not loaded then
      status = err or "Load failed"
      return
    end
    rows = loaded
    path = p
    config.set("csv_path", p)
    selected = 0
    scroll = 0
    status = ("Loaded %d rows"):format(#rows)
  end

  local function save_path(p)
    local ok, err = csv.save(p, rows)
    if not ok then
      status = err or "Save failed"
      return
    end
    path = p
    config.set("csv_path", p)
    status = "Saved: " .. p
  end

  local function browse_open()
    local start = path
    if start == "" then
      start = path_util.template_csv_path()
    end
    local rv, p = reaper.GetUserFileNameForRead(start, "Open mapping CSV", ".csv")
    if rv and p and p ~= "" then
      load_path(p)
    end
  end

  local function browse_save_as()
    local p
    if reaper.JS_Dialog_BrowseForSaveFile then
      local r, file = reaper.JS_Dialog_BrowseForSaveFile("Save mapping CSV", "", path, "CSV files (.csv)\0*.csv\0\0")
      if r == 1 and file and file ~= "" then
        p = file
      end
    else
      local rv, file = reaper.GetUserFileNameForRead(path, "Choose/overwrite CSV path to save", ".csv")
      if rv and file and file ~= "" then
        p = file
      end
    end
    if p then
      save_path(p)
    end
  end

  local function add_row()
    if draft_smpte ~= "" and draft_name ~= "" then
      rows[#rows + 1] = { smpte = draft_smpte, name = draft_name }
      draft_smpte, draft_name = "", ""
      focus = "smpte"
      selected = #rows
      if selected > scroll + 10 then
        scroll = selected - 10
      end
      status = "Row added (remember to Save)"
    else
      status = "Enter both SMPTE and Marker Name"
    end
  end

  local function close_editor()
    if finished then
      return
    end
    finished = true
    gfx.quit()
    if opts.on_close then
      reaper.defer(function()
        opts.on_close(path)
      end)
    end
  end

  load_path(path)
  gfx.init("Reaper LTC Markers — Mapping Editor", 640, 520, 0, 140, 100)

  local function loop()
    if finished then
      return
    end

    local ch = gfx.getchar()
    if ch == -1 or ch == 27 then
      close_editor()
      return
    end

    if ch == 8 or ch == 127 then
      if focus == "smpte" then
        draft_smpte = draft_smpte:sub(1, -2)
      else
        draft_name = draft_name:sub(1, -2)
      end
    elseif ch == 9 then
      focus = (focus == "smpte") and "name" or "smpte"
    elseif ch == 13 then
      add_row()
    elseif ch >= 32 and ch < 127 then
      local c = string.char(ch)
      if focus == "smpte" then
        draft_smpte = draft_smpte .. c
      else
        draft_name = draft_name .. c
      end
    end

    local w, h = gfx.w, gfx.h
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mb = gfx.mouse_cap
    local click = (mb & 1) == 1 and (prev_mb & 1) == 0
    local wheel = gfx.mouse_wheel
    gfx.mouse_wheel = 0
    prev_mb = mb

    gfx.set(0.11, 0.12, 0.14, 1)
    gfx.rect(0, 0, w, h, 1)

    gfx.set(0.95, 0.96, 0.97, 1)
    gfx.setfont(1, "Arial", 17)
    gfx.x, gfx.y = 16, 12
    gfx.drawstr("Mapping editor")

    gfx.set(0.60, 0.63, 0.68, 1)
    gfx.setfont(1, "Arial", 11)
    gfx.x, gfx.y = 16, 36
    local path_show = path or ""
    if #path_show > 78 then
      path_show = "…" .. path_show:sub(-76)
    end
    gfx.drawstr(path_show)

    local buttons = {
      { "Open…", browse_open },
      { "Save", function()
        save_path(path)
      end },
      { "Save As…", browse_save_as },
      { "Clear", function()
        rows = {}
        selected = 0
        status = "Cleared — Save As to write a new file"
      end },
    }
    local bx = 16
    for _, b in ipairs(buttons) do
      local bw = 72
      local hover = hit(mx, my, bx, 56, bw, 26)
      draw_btn(b[1], bx, 56, bw, 26, hover, false)
      if click and hover then
        b[2]()
      end
      bx = bx + bw + 8
    end

    local list_x, list_y = 16, 96
    local list_w, list_h = w - 32, h - 250
    local sb_w = 14
    local header_h = 28
    local row_h = 22
    local track_x = list_x + list_w - sb_w
    local track_y = list_y + header_h
    local track_h = list_h - header_h
    local rows_area_w = list_w - sb_w

    gfx.set(0.16, 0.17, 0.20, 1)
    gfx.rect(list_x, list_y, list_w, list_h, 1)

    gfx.set(0.55, 0.58, 0.62, 1)
    gfx.setfont(1, "Arial", 12)
    gfx.x, gfx.y = list_x + 10, list_y + 8
    gfx.drawstr("SMPTE Code")
    gfx.x, gfx.y = list_x + 160, list_y + 8
    gfx.drawstr("Marker Name")

    local visible = math.floor(track_h / row_h)
    if visible < 1 then
      visible = 1
    end
    local max_scroll = math.max(0, #rows - visible)
    if scroll > max_scroll then
      scroll = max_scroll
    end
    if scroll < 0 then
      scroll = 0
    end

    -- Mouse wheel over list
    if wheel ~= 0 and hit(mx, my, list_x, list_y, list_w, list_h) then
      local steps = math.max(1, math.floor(math.abs(wheel) / 120 + 0.5))
      if wheel > 0 then
        scroll = scroll - steps
      else
        scroll = scroll + steps
      end
      if scroll < 0 then
        scroll = 0
      end
      if scroll > max_scroll then
        scroll = max_scroll
      end
    end

    -- Scrollbar track
    gfx.set(0.12, 0.13, 0.15, 1)
    gfx.rect(track_x, track_y, sb_w, track_h, 1)

    local thumb_y, thumb_h = track_y, track_h
    if max_scroll > 0 then
      thumb_h = math.max(28, math.floor(track_h * visible / #rows))
      local travel = math.max(1, track_h - thumb_h)
      thumb_y = track_y + math.floor((scroll / max_scroll) * travel + 0.5)

      local thumb_hover = hit(mx, my, track_x, thumb_y, sb_w, thumb_h)
      local track_hover = hit(mx, my, track_x, track_y, sb_w, track_h)

      if (mb & 1) == 1 then
        if dragging_scroll then
          local travel2 = math.max(1, track_h - thumb_h)
          local rel = (my - track_y - drag_offset_y) / travel2
          if rel < 0 then
            rel = 0
          end
          if rel > 1 then
            rel = 1
          end
          scroll = math.floor(rel * max_scroll + 0.5)
        elseif click and thumb_hover then
          dragging_scroll = true
          drag_offset_y = my - thumb_y
        elseif click and track_hover then
          -- Jump so thumb centers on click
          local travel2 = math.max(1, track_h - thumb_h)
          local rel = (my - track_y - thumb_h * 0.5) / travel2
          if rel < 0 then
            rel = 0
          end
          if rel > 1 then
            rel = 1
          end
          scroll = math.floor(rel * max_scroll + 0.5)
          dragging_scroll = true
          drag_offset_y = thumb_h * 0.5
        end
      else
        dragging_scroll = false
      end

      -- Recompute thumb after possible scroll change
      travel = math.max(1, track_h - thumb_h)
      thumb_y = track_y + math.floor((scroll / max_scroll) * travel + 0.5)
      thumb_hover = hit(mx, my, track_x, thumb_y, sb_w, thumb_h)

      if dragging_scroll or thumb_hover then
        gfx.set(0.42, 0.55, 0.48, 1)
      else
        gfx.set(0.32, 0.36, 0.40, 1)
      end
      gfx.rect(track_x + 2, thumb_y, sb_w - 4, thumb_h, 1)
    else
      dragging_scroll = false
      gfx.set(0.22, 0.24, 0.28, 1)
      gfx.rect(track_x + 2, track_y + 2, sb_w - 4, track_h - 4, 1)
    end

    for i = 1, visible do
      local idx = scroll + i
      if idx > #rows then
        break
      end
      local row = rows[idx]
      local ry = track_y + (i - 1) * row_h
      local hover = (not dragging_scroll) and hit(mx, my, list_x, ry, rows_area_w, row_h)
      if idx == selected then
        gfx.set(0.22, 0.40, 0.32, 1)
        gfx.rect(list_x + 2, ry, rows_area_w - 4, row_h, 1)
      elseif hover then
        gfx.set(0.20, 0.22, 0.26, 1)
        gfx.rect(list_x + 2, ry, rows_area_w - 4, row_h, 1)
      end
      gfx.set(0.90, 0.92, 0.94, 1)
      gfx.setfont(1, "Consolas", 13)
      gfx.x, gfx.y = list_x + 10, ry + 3
      gfx.drawstr(row.smpte or "")
      gfx.x, gfx.y = list_x + 160, ry + 3
      gfx.drawstr(row.name or "")

      if click and hover then
        selected = idx
        draft_smpte = row.smpte or ""
        draft_name = row.name or ""
        focus = "name"
        status = ("Selected row %d — edit below, then Update or Add"):format(idx)
      end
    end

    if #rows == 0 then
      gfx.set(0.45, 0.48, 0.52, 1)
      gfx.setfont(1, "Arial", 13)
      gfx.x, gfx.y = list_x + 16, list_y + 48
      gfx.drawstr("No rows yet. Type a SMPTE code and name below, then Add.")
    end

    local field_y = h - 130
    local smpte_w = 160
    local name_w = w - 32 - smpte_w - 16
    local smpte_hover = hit(mx, my, 16, field_y, smpte_w, 28)
    local name_hover = hit(mx, my, 16 + smpte_w + 16, field_y, name_w, 28)
    draw_field("SMPTE", draft_smpte, 16, field_y, smpte_w, 28, focus == "smpte", smpte_hover)
    draw_field("Marker Name", draft_name, 16 + smpte_w + 16, field_y, name_w, 28, focus == "name", name_hover)
    if click and smpte_hover then
      focus = "smpte"
    end
    if click and name_hover then
      focus = "name"
    end

    local ay = h - 78
    local actions = {
      { "Add", true, add_row },
      {
        "Update",
        false,
        function()
          if selected > 0 and selected <= #rows and draft_smpte ~= "" and draft_name ~= "" then
            rows[selected] = { smpte = draft_smpte, name = draft_name }
            status = "Row updated (remember to Save)"
          else
            status = "Select a row and fill both fields to Update"
          end
        end,
      },
      {
        "Delete",
        false,
        function()
          if selected > 0 and selected <= #rows then
            table.remove(rows, selected)
            if selected > #rows then
              selected = #rows
            end
            draft_smpte, draft_name = "", ""
            status = "Row deleted (remember to Save)"
          else
            status = "Select a row to Delete"
          end
        end,
      },
      { "Close", false, close_editor },
    }
    local ax = 16
    for _, a in ipairs(actions) do
      local aw = 90
      local hover = hit(mx, my, ax, ay, aw, 30)
      draw_btn(a[1], ax, ay, aw, 30, hover, a[2])
      if click and hover then
        a[3]()
        if finished then
          return
        end
      end
      ax = ax + aw + 8
    end

    gfx.set(0.55, 0.70, 0.60, 1)
    gfx.setfont(1, "Arial", 11)
    gfx.x, gfx.y = 16, h - 36
    gfx.drawstr(status ~= "" and status or "Tip: click a row to load it · Tab switches fields · Enter adds")

    gfx.update()
    reaper.defer(loop)
  end

  reaper.defer(loop)
end

return M
