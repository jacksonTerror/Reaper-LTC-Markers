-- UI helpers (ReaImGui is optional; Process + mapping editor use stock gfx)
local M = {}

function M.has_imgui()
  return reaper.APIExists("ImGui_CreateContext")
end

return M
