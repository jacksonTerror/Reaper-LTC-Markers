-- Project marker insert / replace / append (plain marker names, no prefix)
local M = {}

local DUP_WINDOW_SEC = 0.05 -- treat markers within 50ms as same position

function M.delete_in_range(range_start, range_end)
  local removed = 0
  local i = 0
  while true do
    local idx, is_region, pos, _, name = reaper.EnumProjectMarkers3(0, i)
    if idx == 0 then
      break
    end
    local plain = name or ""
    -- Also clear legacy tagged names from earlier builds
    if plain:sub(1, 6) == "[RLM] " then
      plain = plain:sub(7)
    end
    if not is_region and pos >= range_start - 0.01 and pos <= range_end + 0.01 then
      reaper.DeleteProjectMarkerByIndex(0, i)
      removed = removed + 1
    else
      i = i + 1
    end
  end
  return removed
end

local function existing_at(pos, name)
  local i = 0
  while true do
    local idx, is_region, mpos, _, mname = reaper.EnumProjectMarkers3(0, i)
    if idx == 0 then
      break
    end
    local plain = mname or ""
    if plain:sub(1, 6) == "[RLM] " then
      plain = plain:sub(7)
    end
    if not is_region and math.abs(mpos - pos) <= DUP_WINDOW_SEC and plain == name then
      return true
    end
    i = i + 1
  end
  return false
end

--- matches: list of { pos=, name=, timecode= } project positions in seconds
--- mode: "replace" | "append"
--- range: optional { start=, finish= } — on replace, clear markers in this span first
function M.apply(matches, mode, range)
  reaper.Undo_BeginBlock()
  local added, skipped, removed = 0, 0, 0

  if mode == "replace" then
    if range and range.start and range.finish then
      removed = M.delete_in_range(range.start, range.finish)
    else
      -- Fallback: clear near each new marker position
      for _, m in ipairs(matches) do
        local i = 0
        while true do
          local idx, is_region, mpos = reaper.EnumProjectMarkers3(0, i)
          if idx == 0 then
            break
          end
          if not is_region and math.abs(mpos - m.pos) <= DUP_WINDOW_SEC then
            reaper.DeleteProjectMarkerByIndex(0, i)
            removed = removed + 1
          else
            i = i + 1
          end
        end
      end
    end
  end

  for _, m in ipairs(matches) do
    if mode == "append" and existing_at(m.pos, m.name) then
      skipped = skipped + 1
    else
      reaper.AddProjectMarker2(0, false, m.pos, 0, m.name, -1, 0)
      added = added + 1
    end
  end

  reaper.Undo_EndBlock("Reaper LTC Markers", -1)
  reaper.UpdateTimeline()
  return { added = added, skipped = skipped, removed = removed }
end

return M
