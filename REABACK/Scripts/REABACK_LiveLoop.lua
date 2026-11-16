-- REABACK: Live loop
-- Standalone action: bind it to a keyboard shortcut or MIDI in REAPER's Action list.
--   loop off -> loop on, time selection on the nested (child) region at the current position
--               (play position while playing, else edit cursor); the parent region if there is no child
--   loop on  -> loop off, time selection back on the parent region

-- Toolbar toggle state (lit / unlit icon). The command ID is also stored so that the REABACK
-- window, while open, keeps this icon in sync with the transport.
local function rb_toggle(key, state)
  local _, _, sec, cmd = reaper.get_action_context()
  if not cmd or cmd <= 0 then return end
  local named = reaper.ReverseNamedCommandLookup(cmd)
  if named and named ~= "" then reaper.SetExtState("REABACK_toggles", key, sec .. "|" .. named, true) end
  reaper.SetToggleCommandState(sec, cmd, state)
  reaper.RefreshToolbar2(sec, cmd)
end


local DISABLED_BASE = 10000      -- same value as in REABACK.lua: IDs >= this are disabled regions
local EPS = 1e-6

-- Enabled regions
local function get_regions()
  local out = {}
  local total = reaper.CountProjectMarkers(0)
  for i = 0, total - 1 do
    local _, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers3(0, i)
    if isrgn and id < DISABLED_BASE then out[#out + 1] = { id = id, pos = pos, rgnend = rgnend } end
  end
  return out
end

-- a strictly contains b
local function contains(a, b)
  if a == b then return false end
  if a.pos <= b.pos + EPS and b.rgnend <= a.rgnend + EPS then
    return (b.pos - a.pos > EPS) or (a.rgnend - b.rgnend > EPS)
  end
  return false
end

local playing = (reaper.GetPlayState() & 1) == 1
local pos = playing and reaper.GetPlayPosition() or reaper.GetCursorPosition()
local regions = get_regions()

local mother, child
for _, r in ipairs(regions) do
  if pos >= r.pos and pos < r.rgnend then
    local hasParent = false
    for _, a in ipairs(regions) do
      if contains(a, r) then hasParent = true; break end
    end
    if hasParent then
      if not child or (r.rgnend - r.pos) < (child.rgnend - child.pos) then child = r end
    elseif not mother or r.pos < mother.pos then
      mother = r
    end
  end
end

if mother then
  if reaper.GetSetRepeat(-1) == 1 then
    reaper.GetSetRepeat(0)
    reaper.GetSet_LoopTimeRange(true, false, mother.pos, mother.rgnend, false)
  else
    local t = child or mother
    reaper.GetSet_LoopTimeRange(true, false, t.pos, t.rgnend, false)
    reaper.GetSetRepeat(1)
  end
end

-- lit while the loop (repeat) is on
rb_toggle("LiveLoop", reaper.GetSetRepeat(-1) == 1 and 1 or 0)
