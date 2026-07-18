-- CSV load/save for SMPTE Code, Marker Name mappings
local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_line(line)
  -- minimal CSV: split on commas not inside quotes
  local fields = {}
  local field, in_quotes = "", false
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == '"' then
      if in_quotes and line:sub(i + 1, i + 1) == '"' then
        field = field .. '"'
        i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif c == "," and not in_quotes then
      fields[#fields + 1] = trim(field)
      field = ""
    else
      field = field .. c
    end
    i = i + 1
  end
  fields[#fields + 1] = trim(field)
  return fields
end

--- Load mappings → list of { smpte=, name= }
function M.load(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "Could not open CSV: " .. tostring(path)
  end
  local rows = {}
  local first = true
  for line in f:lines() do
    line = line:gsub("\r", "")
    if line:match("%S") then
      local fields = parse_line(line)
      if first then
        first = false
        local h1 = (fields[1] or ""):lower()
        local h2 = (fields[2] or ""):lower()
        if h1:find("smpte") or h1:find("timecode") or h2:find("marker") or h2:find("name") then
          -- skip header
        else
          if fields[1] and fields[2] and fields[1] ~= "" and fields[2] ~= "" then
            rows[#rows + 1] = { smpte = fields[1], name = fields[2] }
          end
        end
      else
        if fields[1] and fields[2] and fields[1] ~= "" and fields[2] ~= "" then
          rows[#rows + 1] = { smpte = fields[1], name = fields[2] }
        end
      end
    end
  end
  f:close()
  return rows
end

function M.save(path, rows)
  local f = io.open(path, "w")
  if not f then
    return nil, "Could not write CSV: " .. tostring(path)
  end
  f:write("SMPTE Code,Marker Name\n")
  for _, row in ipairs(rows) do
    local smpte = tostring(row.smpte or "")
    local name = tostring(row.name or "")
    if name:find(",") or name:find('"') then
      name = '"' .. name:gsub('"', '""') .. '"'
    end
    f:write(smpte .. "," .. name .. "\n")
  end
  f:close()
  return true
end

--- Build absolute-frame lookup table for fuzzy match (also used by helper via CSV file)
function M.code_to_abs(code, fps)
  local hh, mm, ss, ff = code:match("^(%d+):(%d+):(%d+):(%d+)$")
  if not hh then
    return nil
  end
  return (((tonumber(hh) * 60) + tonumber(mm)) * 60 + tonumber(ss)) * fps + tonumber(ff)
end

return M
