-- Resolve take source + call native ltc_scan helper (detached, cross-platform)
local M = {}

local path_util = require("rlm_path")
local rlm_os = require("rlm_os")

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local body = f:read("*a")
  f:close()
  return body
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

local function safe_remove(path)
  if path and reaper.file_exists(path) then
    os.remove(path)
  end
end

local function log_launch(paths, line)
  local prev = read_file(paths.log) or ""
  write_file(paths.log, prev .. os.date("%H:%M:%S ") .. line .. "\n")
end

function M.resolve_item(item)
  if not item then
    return nil, "No media item"
  end
  local take = reaper.GetActiveTake(item)
  if not take then
    return nil, "Item has no active take"
  end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then
    return nil, "Take has no source"
  end
  local parent = reaper.GetMediaSourceParent(src)
  if parent then
    src = parent
  end
  local path = reaper.GetMediaSourceFileName(src, "")
  if not path or path == "" then
    return nil, "Could not resolve source filename (offline/MIDI?)"
  end

  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate == 0 then
    playrate = 1
  end

  return {
    path = path,
    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
    playrate = playrate,
    take = take,
    item = item,
  }
end

function M.parse_output(text)
  local matches, unmapped, logs = {}, {}, {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("\r", "")
    if line:sub(1, 6) == "MATCH\t" then
      local pos, name, tc = line:match("^MATCH\t([^\t]+)\t([^\t]+)\t(.+)$")
      if pos and name then
        matches[#matches + 1] = {
          file_pos = tonumber(pos),
          name = name,
          timecode = tc or "",
        }
      end
    elseif line:sub(1, 9) == "UNMAPPED\t" then
      local pos, tc = line:match("^UNMAPPED\t([^\t]+)\t(.+)$")
      if pos and tc then
        unmapped[#unmapped + 1] = { file_pos = tonumber(pos), timecode = tc }
      end
    elseif line:sub(1, 4) == "LOG\t" then
      logs[#logs + 1] = line:sub(5)
    end
  end
  return matches, unmapped, logs
end

function M.to_project_matches(resolved, file_matches)
  local out = {}
  for _, m in ipairs(file_matches) do
    local pos = resolved.item_pos + ((m.file_pos - resolved.take_offset) / resolved.playrate)
    if pos >= resolved.item_pos - 0.01 and pos <= resolved.item_pos + resolved.item_len + 0.01 then
      out[#out + 1] = {
        pos = pos,
        name = m.name,
        timecode = m.timecode,
        file_pos = m.file_pos,
      }
    end
  end
  return out
end

function M.to_project_unmapped(resolved, file_unmapped)
  local out = {}
  for _, u in ipairs(file_unmapped) do
    local pos = resolved.item_pos + ((u.file_pos - resolved.take_offset) / resolved.playrate)
    if pos >= resolved.item_pos - 0.01 and pos <= resolved.item_pos + resolved.item_len + 0.01 then
      out[#out + 1] = { pos = pos, timecode = u.timecode, file_pos = u.file_pos }
    end
  end
  return out
end

function M.job_paths()
  local res = reaper.GetResourcePath()
  return {
    out = path_util.join(res, "ReaperLTCMarkers_last_scan.txt"),
    progress = path_util.join(res, "ReaperLTCMarkers_progress.txt"),
    done = path_util.join(res, "ReaperLTCMarkers_done.txt"),
    vbs = path_util.join(res, "ReaperLTCMarkers_run.vbs"),
    log = path_util.join(res, "ReaperLTCMarkers_launch.log"),
  }
end

function M.read_progress(progress_path)
  local body = read_file(progress_path)
  if not body then
    return nil
  end
  local pos, total, pct, matches = body:match("PROGRESS\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([%d\r\n]+)")
  if not pos then
    return nil
  end
  return {
    pos = tonumber(pos) or 0,
    total = tonumber(total) or 1,
    pct = tonumber(pct) or 0,
    matches = tonumber(matches) or 0,
  }
end

function M.read_matches_so_far(out_path)
  local body = read_file(out_path)
  if not body then
    return {}
  end
  return M.parse_output(body)
end

function M.build_helper_args(opts, paths)
  local args = {
    "--fps", tostring(opts.fps or 30),
    "--tolerance", tostring(opts.tolerance or 3),
    "--mapping", opts.mapping_path,
    "--audio", opts.audio_path,
    "--out", paths.out,
    "--progress", paths.progress,
    "--done", paths.done,
  }
  if opts.auto_gain then
    args[#args + 1] = "--auto-gain"
  end
  if opts.gain_db and tonumber(opts.gain_db) ~= 0 then
    args[#args + 1] = "--gain-db"
    args[#args + 1] = tostring(opts.gain_db)
  end
  if opts.start_sec then
    args[#args + 1] = "--start-sec"
    args[#args + 1] = tostring(opts.start_sec)
  end
  if opts.length_sec then
    args[#args + 1] = "--length-sec"
    args[#args + 1] = tostring(opts.length_sec)
  end
  return args
end

function M.start_helper_async(opts)
  local helper = path_util.native_helper_path()
  if not reaper.file_exists(helper) then
    local name = rlm_os.helper_basename()
    return nil, "Native helper not found:\n" .. helper
      .. "\n\nExpected: native/bin/" .. name
      .. "\nWindows: build with native/build_win.bat"
      .. "\nmacOS: use a CI-built binary (see native/README.md) — .exe will not run on Mac."
  end

  local paths = M.job_paths()
  safe_remove(paths.out)
  safe_remove(paths.progress)
  safe_remove(paths.done)
  write_file(paths.log, "")

  local args = M.build_helper_args(opts, paths)
  local cmdline = rlm_os.build_cmdline(helper, args)

  log_launch(paths, "os=" .. reaper.GetOS())
  log_launch(paths, "helper=" .. helper)
  log_launch(paths, "cmdline=" .. cmdline)

  local result, err = rlm_os.spawn_detached(cmdline, paths)
  if err then
    return nil, err
  end
  log_launch(paths, "spawn returned: " .. tostring(result))

  return {
    paths = paths,
    helper = helper,
    cmdline = cmdline,
    started_at = reaper.time_precise(),
  }
end

function M.job_finished(job)
  return job and job.paths and reaper.file_exists(job.paths.done)
end

function M.helper_seems_alive(job)
  if not job or not job.paths then
    return false
  end
  return reaper.file_exists(job.paths.out)
    or reaper.file_exists(job.paths.progress)
    or reaper.file_exists(job.paths.done)
end

function M.launch_diagnostics(job)
  local lines = {
    "Helper path:",
    job and job.helper or "(unknown)",
    "",
    "Exists: " .. tostring(job and reaper.file_exists(job.helper)),
    "OS: " .. reaper.GetOS(),
  }
  if job and job.paths then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Launch log: " .. job.paths.log
    local log = read_file(job.paths.log)
    if log and log ~= "" then
      lines[#lines + 1] = ""
      lines[#lines + 1] = log
    end
  end
  return table.concat(lines, "\n")
end

function M.collect_job_results(job)
  local body = read_file(job.paths.out)
  if not body or body == "" then
    local done = read_file(job.paths.done) or ""
    return nil, nil, nil, "Helper produced no result file.\nExit marker: " .. done
      .. "\n\n" .. M.launch_diagnostics(job)
  end
  local done_body = (read_file(job.paths.done) or ""):gsub("%s+", "")
  local code = tonumber(done_body)
  if code and code ~= 0 and not body:find("MATCH\t") and not body:find("LOG\tScan complete") then
    return nil, nil, nil, "Helper failed (exit " .. tostring(code) .. "):\n" .. body
  end
  local matches, unmapped, logs = M.parse_output(body)
  return matches, unmapped, logs, nil
end

return M
