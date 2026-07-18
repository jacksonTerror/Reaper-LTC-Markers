-- Write detailed detection report next to the project
local M = {}

local path_util = require("rlm_path")

function M.write(opts)
  -- opts: {
  --   matches, unmapped, fps, gain_desc, csv_path, source_path,
  --   mode, suggest_note, helper_log
  -- }
  local report_path, is_fallback = path_util.report_path()
  local f = io.open(report_path, "w")
  if not f then
    return nil, "Could not write report: " .. tostring(report_path)
  end

  local _, proj_base = path_util.project_paths()
  f:write("Reaper LTC Markers — Detection Report\n")
  f:write("=====================================\n\n")
  f:write(("Project: %s%s\n"):format(proj_base, is_fallback and " (unsaved — report in script folder)" or ""))
  f:write(("Source: %s\n"):format(opts.source_path or "(unknown)"))
  f:write(("Mapping CSV: %s\n"):format(opts.csv_path or "(unknown)"))
  f:write(("Frame rate: %s fps\n"):format(tostring(opts.fps or 30)))
  f:write(("Gain: %s\n"):format(opts.gain_desc or ""))
  f:write(("Mode: %s\n"):format(opts.mode or ""))
  if opts.suggest_note then
    f:write(("Selection: %s\n"):format(opts.suggest_note))
  end
  f:write("\nDetected Markers:\n")
  f:write("-----------------\n")

  local matches = opts.matches or {}
  table.sort(matches, function(a, b)
    return a.pos < b.pos
  end)

  if #matches == 0 then
    f:write("(none)\n")
  else
    for _, m in ipairs(matches) do
      f:write(("%s  %s  @ %.3fs\n"):format(m.timecode or "??:??:??:??", m.name, m.pos))
    end
  end

  local unmapped = opts.unmapped or {}
  if #unmapped > 0 then
    f:write("\nUnmapped timecodes (seen but not in CSV):\n")
    f:write("---------------------------------------\n")
    for _, u in ipairs(unmapped) do
      f:write(("%s  @ %.3fs\n"):format(u.timecode, u.pos))
    end
  end

  if opts.stats then
    f:write("\nSummary:\n")
    f:write(("  Added: %d\n"):format(opts.stats.added or 0))
    f:write(("  Skipped (append dupes): %d\n"):format(opts.stats.skipped or 0))
    f:write(("  Removed (replace): %d\n"):format(opts.stats.removed or 0))
  end

  f:close()
  return report_path, is_fallback
end

return M
