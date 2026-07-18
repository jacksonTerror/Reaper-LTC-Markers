-- Path helpers for Reaper LTC Markers
local M = {}

local function dirname(path)
  return path:match("^(.*[\\/])") or ""
end

function M.script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  return dirname(src)
end

--- Install root = parent of scripts/ (…/Reaper-LTC-Markers/)
function M.install_root()
  local mod_dir = M.script_dir() -- …/scripts/modules/
  local scripts_dir = dirname(mod_dir:gsub("[\\/]+$", "")) -- …/scripts/
  return dirname(scripts_dir:gsub("[\\/]+$", "")) -- …/Reaper-LTC-Markers/
end

function M.join(...)
  local sep = package.config:sub(1, 1)
  local out = ""
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    if p and p ~= "" then
      if out == "" then
        out = p
      else
        if not out:match("[\\/]$") then
          out = out .. sep
        end
        out = out .. p:gsub("^[\\/]+", "")
      end
    end
  end
  return out
end

function M.native_helper_path()
  local root = M.install_root()
  local is_win = reaper.GetOS():find("Win")
  local name = is_win and "ltc_scan.exe" or "ltc_scan"
  -- Prefer OS-specific subfolders when present (CI artifacts), then flat bin/
  local candidates = {
    M.join(root, "native", "bin", is_win and "windows" or "macos", name),
    M.join(root, "native", "bin", name),
    M.join(root, "native", name),
  }
  for _, p in ipairs(candidates) do
    if reaper.file_exists(p) then
      return p
    end
  end
  return candidates[2]
end

function M.template_csv_path()
  return M.join(M.install_root(), "templates", "smpte_mapping_template.csv")
end

--- Returns project_dir, base_name (base_name never nil)
function M.project_paths()
  local _, proj_path = reaper.EnumProjects(-1, "")
  if not proj_path or proj_path == "" then
    return nil, "unsaved_project"
  end
  local dir = dirname(proj_path)
  local file = proj_path:match("([^\\/]+)$") or "project"
  local base = file:gsub("%.rpp%-?-?backup$", ""):gsub("%.[Rr][Pp][Pp]$", "")
  if base == "" then
    base = "unsaved_project"
  end
  return dir, base
end

--- Report path; second return true if fallback (unsaved / no project dir)
function M.report_path()
  local dir, base = M.project_paths()
  local name = base .. "_Markers_Report.txt"
  if not dir or dir == "" then
    return M.join(M.install_root(), name), true
  end
  return M.join(dir, name), false
end

return M
