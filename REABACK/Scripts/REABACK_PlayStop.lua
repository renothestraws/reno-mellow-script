-- REABACK: Play/Stop
-- Standalone action: bind it to a keyboard shortcut or MIDI in REAPER's Action list.
--   playing + loop on  -> loop off, time selection moved to the parent (top-level) region under the play cursor
--   playing + loop off -> same as Stop
--   not playing        -> play

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

-- Stop: while playing run action 40328, otherwise move the edit cursor to the start of the time selection
local function stop_action()
  if (reaper.GetPlayState() & 1) == 1 then
    reaper.Main_OnCommand(40328, 0)
  else
    local ts_s, ts_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if ts_e > ts_s then reaper.SetEditCurPos(ts_s, true, false) end
  end
end

-- a strictly contains b
local function contains(a, b)
  if a == b then return false end
  if a.pos <= b.pos + EPS and b.rgnend <= a.rgnend + EPS then
    return (b.pos - a.pos > EPS) or (a.rgnend - b.rgnend > EPS)
  end
  return false
end

if (reaper.GetPlayState() & 1) == 0 then
  reaper.OnPlayButton()
elseif reaper.GetSetRepeat(-1) == 1 then
  reaper.GetSetRepeat(0)
  local pos = reaper.GetPlayPosition()
  local regions = get_regions()
  local best
  for _, r in ipairs(regions) do
    if pos >= r.pos and pos < r.rgnend then
      local hasParent = false
      for _, a in ipairs(regions) do
        if contains(a, r) then hasParent = true; break end
      end
      if not hasParent and (not best or r.pos < best.pos) then best = r end
    end
  end
  if best then reaper.GetSet_LoopTimeRange(true, false, best.pos, best.rgnend, false) end
else
  stop_action()
end
