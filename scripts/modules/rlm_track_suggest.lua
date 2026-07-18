-- Suggest LTC/SMPTE track / item when nothing is selected
local M = {}

local function track_name(track)
  local _, name = reaper.GetTrackName(track)
  return name or ""
end

local function name_looks_like_tc(name)
  local lower = name:lower()
  return lower:find("smpte", 1, true) or lower:find("ltc", 1, true) or lower:find("timecode", 1, true)
end

--- Returns track, item, reason_string (or nils)
function M.suggest()
  local item = reaper.GetSelectedMediaItem(0, 0)
  if item then
    return reaper.GetMediaItem_Track(item), item, "Using selected media item"
  end

  local proj = 0
  local track_count = reaper.CountTracks(proj)
  local candidates = {}
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(proj, i)
    local name = track_name(track)
    if name_looks_like_tc(name) then
      candidates[#candidates + 1] = { track = track, name = name }
    end
  end

  if #candidates == 0 then
    return nil, nil, "No item selected and no track name contains SMPTE/LTC/Timecode"
  end

  -- Prefer a track that has at least one item
  for _, c in ipairs(candidates) do
    local n = reaper.CountTrackMediaItems(c.track)
    if n > 0 then
      local it = reaper.GetTrackMediaItem(c.track, 0)
      return c.track, it, ("Suggested track '%s' (first item)"):format(c.name)
    end
  end

  return candidates[1].track, nil, ("Suggested track '%s' but it has no items"):format(candidates[1].name)
end

return M
