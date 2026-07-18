-- Suggest LTC/SMPTE track / item when nothing suitable is selected
local M = {}

local function track_name(track)
  local _, name = reaper.GetTrackName(track)
  return name or ""
end

local function name_looks_like_tc(name)
  local lower = (name or ""):lower()
  return lower:find("smpte", 1, true)
    or lower:find("ltc", 1, true)
    or lower:find("timecode", 1, true)
end

local function first_item_on_track(track)
  if reaper.CountTrackMediaItems(track) <= 0 then
    return nil
  end
  return reaper.GetTrackMediaItem(track, 0)
end

local function find_tc_candidates()
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
  return candidates
end

local function first_tc_with_item(candidates)
  for _, c in ipairs(candidates) do
    local it = first_item_on_track(c.track)
    if it then
      return c, it
    end
  end
  return nil, nil
end

--- Returns track, item, reason_string (or nils)
function M.suggest()
  local selected = reaper.GetSelectedMediaItem(0, 0)
  local candidates = find_tc_candidates()
  local tc, tc_item = first_tc_with_item(candidates)

  -- Selected item on an SMPTE/LTC/Timecode track → use it
  if selected then
    local sel_track = reaper.GetMediaItem_Track(selected)
    local sel_name = track_name(sel_track)
    if name_looks_like_tc(sel_name) then
      return sel_track, selected, ("Using selected item on '%s'"):format(sel_name)
    end

    -- Something else is selected (e.g. first audio track). Prefer the named
    -- LTC track so a leftover selection does not steal the scan — same on Win/Mac.
    if tc and tc_item then
      return tc.track, tc_item,
        ("Selected item is on '%s'; using LTC track '%s' instead"):format(sel_name, tc.name)
    end

    -- No named LTC track; fall back to whatever is selected
    return sel_track, selected, ("Using selected media item on '%s'"):format(sel_name)
  end

  if tc and tc_item then
    return tc.track, tc_item, ("Suggested track '%s' (first item)"):format(tc.name)
  end

  if #candidates > 0 then
    return candidates[1].track, nil,
      ("Suggested track '%s' but it has no items"):format(candidates[1].name)
  end

  return nil, nil, "No item selected and no track name contains SMPTE/LTC/Timecode"
end

return M
