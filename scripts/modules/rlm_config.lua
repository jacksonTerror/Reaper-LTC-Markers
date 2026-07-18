-- Persistent settings via ExtState
local M = {}

local EXT_SECTION = "ReaperLTCMarkers"

local DEFAULTS = {
  csv_path = "",
  fps = "30",
  gain_mode = "auto", -- auto | manual
  gain_db = "0",      -- used when manual, or as floor boost with auto
  mode = "replace",   -- replace | append
  tolerance_frames = "3",
  last_suggest_track = "",
}

function M.get(key)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == nil or v == "" then
    return DEFAULTS[key]
  end
  return v
end

function M.set(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value or ""), true)
end

function M.load_all()
  local t = {}
  for k, _ in pairs(DEFAULTS) do
    t[k] = M.get(k)
  end
  return t
end

function M.save_all(t)
  for k, v in pairs(t) do
    if DEFAULTS[k] ~= nil then
      M.set(k, v)
    end
  end
end

M.EXT_SECTION = EXT_SECTION

return M
