-- Optional ReaImGui UI helpers
local M = {}

function M.has_imgui()
  return reaper.APIExists("ImGui_CreateContext")
end

function M.imgui_missing_message()
  return table.concat({
    "ReaImGui is not installed.",
    "",
    "The mapping editor needs ReaImGui (via ReaPack):",
    "  https://reapack.com/",
    "  https://github.com/cfillion/reaimgui",
    "",
    "You can still run Process with any CSV edited elsewhere",
    "(see templates/smpte_mapping_template.csv).",
  }, "\n")
end

return M
