-- REABACK: Next region
-- Standalone action: bind it to a keyboard shortcut or MIDI in REAPER's Action list.

local DISABLED_BASE = 10000      -- same value as in REABACK.lua: IDs >= this are disabled regions
local EPS = 1e-6

-- Enabled regions sorted by ID
local function get_regions()
  local out = {}
  local total = reaper.CountProjectMarkers(0)
  for i = 0, total - 1 do
    local _, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers3(0, i)
    if isrgn and id < DISABLED_BASE then out[#out + 1] = { id = id, pos = pos, rgnend = rgnend } end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

-- Go to the next region (by ID, wraps around) and time-select it.
-- If the edit cursor is not inside a region, runs the SWS "select next marker or region" action.
local dir = 1
local regions = get_regions()
local cursor_pos = reaper.GetCursorPosition()

local current
for _, r in ipairs(regions) do
  if cursor_pos >= r.pos and cursor_pos <= r.rgnend then current = r; break end
end

if current then
  local target
  if dir > 0 then
    for _, r in ipairs(regions) do
      if r.id > current.id then target = r; break end
    end
    target = target or regions[1]
  else
    for i = #regions, 1, -1 do
      if regions[i].id < current.id then target = regions[i]; break end
    end
    target = target or regions[#regions]
  end
  reaper.SetEditCurPos(target.pos, true, true)
  reaper.GetSet_LoopTimeRange(true, false, target.pos, target.rgnend, false)
else
  local cmd = reaper.NamedCommandLookup("_SWS_SELNEXTMORR")
  if cmd ~= 0 then reaper.Main_OnCommand(cmd, 0) end
end
