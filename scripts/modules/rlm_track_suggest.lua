-- Suggest LTC/SMPTE track / item when nothing suitable is selected
local M = {}

local function track_name(track)
  if not track then
    return ""
  end
  -- Second arg required on some REAPER/Lua builds; ignore boolean retval.
  local _, name = reaper.GetTrackName(track, "")
  return name or ""
end

local function name_looks_like_tc(name)
  local lower = (name or ""):lower()
  return lower:find("smpte", 1, true)
    or lower:find("ltc", 1, true)
    or lower:find("timecode", 1, true)
end

local function first_item_on_track(track)
  if not track or reaper.CountTrackMediaItems(track) <= 0 then
    return nil
  end
  return reaper.GetTrackMediaItem(track, 0)
end

--- Prefer a selected item that already lives on this track; else first item.
local function item_for_track(track)
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it and reaper.GetMediaItem_Track(it) == track then
      return it
    end
  end
  return first_item_on_track(track)
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
  local selected_item = reaper.GetSelectedMediaItem(0, 0)
  local selected_track = reaper.GetSelectedTrack(0, 0)
  local candidates = find_tc_candidates()
  local tc, tc_item = first_tc_with_item(candidates)

  -- 1) Selected TRACK is SMPTE/LTC — honor that even if another track's item is selected.
  --    (Track selected ≠ item selected; leftover item selection was stealing the scan.)
  if selected_track and name_looks_like_tc(track_name(selected_track)) then
    local name = track_name(selected_track)
    local it = item_for_track(selected_track)
    if it then
      return selected_track, it, ("Using selected track '%s'"):format(name)
    end
    return selected_track, nil, ("Selected track '%s' but it has no items"):format(name)
  end

  -- 2) Selected ITEM is on an SMPTE/LTC track
  if selected_item then
    local sel_track = reaper.GetMediaItem_Track(selected_item)
    local sel_name = track_name(sel_track)
    if name_looks_like_tc(sel_name) then
      return sel_track, selected_item, ("Using selected item on '%s'"):format(sel_name)
    end
  end

  -- 3) Named LTC track exists — prefer it over an unrelated selected item
  if tc and tc_item then
    if selected_item then
      local other = track_name(reaper.GetMediaItem_Track(selected_item))
      return tc.track, tc_item,
        ("Selected item is on '%s'; using LTC track '%s' instead"):format(other, tc.name)
    end
    return tc.track, tc_item, ("Suggested track '%s' (first item)"):format(tc.name)
  end

  -- 4) Fall back to whatever item is selected
  if selected_item then
    local sel_track = reaper.GetMediaItem_Track(selected_item)
    return sel_track, selected_item,
      ("Using selected media item on '%s'"):format(track_name(sel_track))
  end

  if #candidates > 0 then
    return candidates[1].track, nil,
      ("Suggested track '%s' but it has no items"):format(candidates[1].name)
  end

  return nil, nil, "No item selected and no track name contains SMPTE/LTC/Timecode"
end

return M
