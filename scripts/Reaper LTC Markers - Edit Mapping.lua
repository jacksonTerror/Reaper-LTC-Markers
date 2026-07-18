-- @description Reaper LTC Markers - Edit Mapping
-- @version 0.1.0
-- @author Reaper LTC Markers
-- @about
--   Optional ReaImGui editor for SMPTE → marker name CSV mappings.
--   Requires ReaImGui (ReaPack). Process works without this.
-- @provides
--   [main] Reaper LTC Markers - Edit Mapping.lua
--   [nomain] modules/*.lua

local SCRIPT_PATH = ({reaper.get_action_context()})[2]
local SCRIPT_DIR = SCRIPT_PATH:match("^(.*[\\/])") or ""
package.path = SCRIPT_DIR .. "modules/?.lua;" .. package.path

local path_util = require("rlm_path")
local config = require("rlm_config")
local csv = require("rlm_csv")
local ui = require("rlm_ui")

if not ui.has_imgui() then
  reaper.ShowMessageBox(ui.imgui_missing_message(), "Reaper LTC Markers — Edit Mapping", 0)
  return
end

local ctx = reaper.ImGui_CreateContext("Reaper LTC Markers — Mapping Editor")
local rows = {}
local draft = { smpte = "", name = "" }
local path = config.get("csv_path")
local status = ""

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

load_path(path)

local function loop()
  local visible, open = reaper.ImGui_Begin(ctx, "Reaper LTC Markers — Mapping Editor", true)
  if visible then
    reaper.ImGui_Text(ctx, "CSV: " .. (path or ""))
    if reaper.ImGui_Button(ctx, "Open…") then
      local rv, p = reaper.GetUserFileNameForRead(path, "Open mapping CSV", ".csv")
      if rv and p and p ~= "" then
        load_path(p)
      end
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Save") then
      save_path(path)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Save As…") then
      local p
      if reaper.JS_Dialog_BrowseForSaveFile then
        local r, file = reaper.JS_Dialog_BrowseForSaveFile("Save mapping CSV", "", path, "CSV files (.csv)\0*.csv\0\0")
        if r == 1 and file and file ~= "" then
          p = file
        end
      else
        local rv, file = reaper.GetUserFileNameForRead(path, "Type save path / pick existing to overwrite", ".csv")
        if rv and file and file ~= "" then
          p = file
        end
      end
      if p then
        save_path(p)
      end
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Clear rows") then
      rows = {}
      status = "Cleared — Save As to write a new CSV"
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, "Add row")
    local ch1, smpte = reaper.ImGui_InputText(ctx, "SMPTE", draft.smpte)
    if ch1 then
      draft.smpte = smpte
    end
    local ch2, name = reaper.ImGui_InputText(ctx, "Marker Name", draft.name)
    if ch2 then
      draft.name = name
    end
    if reaper.ImGui_Button(ctx, "Add") then
      if draft.smpte ~= "" and draft.name ~= "" then
        rows[#rows + 1] = { smpte = draft.smpte, name = draft.name }
        draft.smpte, draft.name = "", ""
        status = "Row added (remember to Save)"
      end
    end

    reaper.ImGui_Separator(ctx)
    local table_flags = reaper.ImGui_TableFlags_Borders()
      | reaper.ImGui_TableFlags_RowBg()
      | reaper.ImGui_TableFlags_ScrollY()

    if reaper.ImGui_BeginTable(ctx, "map", 3, table_flags, 0, 360) then
      reaper.ImGui_TableSetupColumn(ctx, "SMPTE Code")
      reaper.ImGui_TableSetupColumn(ctx, "Marker Name")
      reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), 60)
      reaper.ImGui_TableHeadersRow(ctx)

      local remove_i = nil
      for i, row in ipairs(rows) do
        reaper.ImGui_PushID(ctx, i)
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableNextColumn(ctx)
        local c1, v1 = reaper.ImGui_InputText(ctx, "##s", row.smpte)
        if c1 then
          row.smpte = v1
        end
        reaper.ImGui_TableNextColumn(ctx)
        local c2, v2 = reaper.ImGui_InputText(ctx, "##n", row.name)
        if c2 then
          row.name = v2
        end
        reaper.ImGui_TableNextColumn(ctx)
        if reaper.ImGui_Button(ctx, "Del") then
          remove_i = i
        end
        reaper.ImGui_PopID(ctx)
      end
      if remove_i then
        table.remove(rows, remove_i)
        status = "Row removed (remember to Save)"
      end
      reaper.ImGui_EndTable(ctx)
    end

    if status ~= "" then
      reaper.ImGui_TextWrapped(ctx, status)
    end
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(loop)
