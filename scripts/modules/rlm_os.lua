-- OS helpers for launching the native LTC helper without blocking REAPER.
-- UI stays in Reaper gfx/ReaImGui (cross-platform). Only process spawn differs.
local M = {}

function M.is_windows()
  return reaper.GetOS():find("Win") ~= nil
end

function M.is_osx()
  local osn = reaper.GetOS()
  return osn:find("OSX") ~= nil or osn:find("macOS") ~= nil
end

function M.helper_basename()
  return M.is_windows() and "ltc_scan.exe" or "ltc_scan"
end

local function win_quote(s)
  return '"' .. tostring(s):gsub('"', "") .. '"'
end

local function vbs_str(s)
  return '"' .. tostring(s):gsub('"', '""') .. '"'
end

local function sh_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Ensure the helper is executable on macOS/Linux.
--- USB/Windows copies often lose the Unix +x bit; Finder has no simple toggle.
function M.ensure_executable(helper_path)
  if M.is_windows() then
    return true
  end
  if not helper_path or helper_path == "" then
    return false
  end
  -- chmod +x; ignore failure (Gatekeeper is a separate issue)
  reaper.ExecProcess("/bin/chmod +x " .. sh_quote(helper_path), 3000)
  return true
end

--- Build a shell-safe command line from helper path + arg list
function M.build_cmdline(helper, args)
  if M.is_windows() then
    local parts = { win_quote(helper) }
    for _, a in ipairs(args) do
      if type(a) == "string" and a:sub(1, 2) == "--" and not a:find(" ", 1, true) then
        parts[#parts + 1] = a
      else
        parts[#parts + 1] = win_quote(a)
      end
    end
    return table.concat(parts, " ")
  end

  local parts = { sh_quote(helper) }
  for _, a in ipairs(args) do
    parts[#parts + 1] = sh_quote(a)
  end
  return table.concat(parts, " ")
end

local function write_file(path, body)
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(body)
  f:close()
  return true
end

--- Detach-launch cmdline so REAPER's UI thread is not blocked.
--- paths: { vbs=, log= } used on Windows; ignored elsewhere.
function M.spawn_detached(cmdline, paths)
  paths = paths or {}

  if M.is_windows() then
    -- WScript.Shell.Run(..., 0, False) — hidden, don't wait.
    -- (PowerShell is intentionally NOT used.)
    if not paths.vbs then
      return nil, "Missing VBS path for Windows launcher"
    end
    local vbs = table.concat({
      'Set sh = CreateObject("WScript.Shell")',
      "sh.Run " .. vbs_str(cmdline) .. ", 0, False",
    }, "\r\n")
    if not write_file(paths.vbs, vbs) then
      return nil, "Could not write " .. paths.vbs
    end
    local launch = "wscript.exe //B //Nologo " .. win_quote(paths.vbs)
    local result = reaper.ExecProcess(launch, 10000)
    return result, nil
  end

  -- macOS / Linux: background with shell. ExecProcess returns when the shell exits.
  local inner = cmdline .. " >/dev/null 2>&1 &"
  local launch = "/bin/sh -c " .. sh_quote(inner)
  local result = reaper.ExecProcess(launch, 5000)
  return result, nil
end

return M
