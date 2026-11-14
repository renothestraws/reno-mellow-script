-- Reaback-prompter
-- Background script (no window) that feeds Reaback-prompter.html, the tablet/phone teleprompter.
-- REAPER's web interface cannot read item notes by itself, so this script reads them and publishes
-- the text that is current at the play position (or at the edit cursor when stopped).
--
--   track whose name contains "lyrics"  -> notes of its items, shown in yellow
--   track whose name contains "chords"  -> notes of its items, shown in red
--   track whose name contains "comment" -> notes of its items, shown in white italic
--
-- Run it once from the Action list (it stays active; run it again to stop it).
-- It is independent from REABACK.lua.

local SEC = "REABACK_PROMPTER"
local LANES = {
  { key = "l", word = "lyrics" },
  { key = "c", word = "chords" },
  { key = "m", word = "comment" },
}

------------------------------------------------------------------------
-- Toggle / single-instance handling
------------------------------------------------------------------------
local _, _, sectionID, cmdID = reaper.get_action_context()
local running = reaper.GetExtState(SEC, "running")
if running == "1" and (reaper.time_precise() - (tonumber(reaper.GetExtState(SEC, "hbt")) or 0)) < 3 then
  -- already running: ask the running instance to quit
  reaper.SetExtState(SEC, "quit", "1", false)
  return
end
reaper.SetExtState(SEC, "quit", "", false)
reaper.SetExtState(SEC, "running", "1", false)
if cmdID and cmdID ~= 0 then
  reaper.SetToggleCommandState(sectionID, cmdID, 1)
  reaper.RefreshToolbar2(sectionID, cmdID)
end

reaper.atexit(function()
  reaper.SetExtState(SEC, "hb", "", false)
  reaper.SetExtState(SEC, "running", "", false)
  if cmdID and cmdID ~= 0 then
    reaper.SetToggleCommandState(sectionID, cmdID, 0)
    reaper.RefreshToolbar2(sectionID, cmdID)
  end
end)

------------------------------------------------------------------------
-- Collecting the items of the lyrics / chords / comment tracks
------------------------------------------------------------------------
local lanes = {}          -- lanes[key] = sorted array of { pos, rend, text }

local function item_note(item)
  local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  return (notes or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function rebuild_lanes()
  for _, l in ipairs(LANES) do lanes[l.key] = {} end
  for t = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, t)
    local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    name = name:lower()
    for _, l in ipairs(LANES) do
      if name:find(l.word, 1, true) then
        for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
          local it = reaper.GetTrackMediaItem(tr, i)
          local text = item_note(it)
          if text ~= "" then
            local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
            local arr = lanes[l.key]
            arr[#arr + 1] = { pos = pos, rend = pos + len, text = text }
          end
        end
      end
    end
  end
  for _, l in ipairs(LANES) do
    table.sort(lanes[l.key], function(a, b) return a.pos < b.pos end)
  end
end

-- Regions (enabled ones: REABACK marks disabled regions with an ID >= 10000)
local regions = {}
local EPS = 1e-6
local function rebuild_regions()
  regions = {}
  for i = 0, reaper.CountProjectMarkers(0) - 1 do
    local _, isrgn, pos, rend, name, id = reaper.EnumProjectMarkers3(0, i)
    if isrgn and id < 10000 then regions[#regions + 1] = { pos = pos, rend = rend, name = name or "" } end
  end
  local function contains(a, b)               -- a strictly contains b
    if a.pos <= b.pos + EPS and b.rend <= a.rend + EPS then
      return (b.pos - a.pos > EPS) or (a.rend - b.rend > EPS)
    end
    return false
  end
  for _, r in ipairs(regions) do
    r.nested = false
    for _, a in ipairs(regions) do
      if a ~= r and contains(a, r) then r.nested = true; break end
    end
  end
end

-- name of the parent region and of the (smallest) nested region at time t
local function regions_at(t)
  local mother, child = "", nil
  local mpos
  for _, r in ipairs(regions) do
    if t >= r.pos and t < r.rend then
      if r.nested then
        if not child or (r.rend - r.pos) < (child.rend - child.pos) then child = r end
      elseif not mpos or r.pos < mpos then
        mother, mpos = r.name, r.pos
      end
    end
  end
  return mother, child and child.name or ""
end

-- current text (latest item that has started and not ended) and next text (first item starting later)
local function lane_at(arr, t)
  local cur, nxt = "", ""
  for _, it in ipairs(arr) do
    if it.pos <= t then
      if t < it.rend then cur = it.text end
    else
      nxt = it.text
      break
    end
  end
  return cur, nxt
end

------------------------------------------------------------------------
-- JSON
------------------------------------------------------------------------
-- Texts are percent-encoded (no backslash, quote or control character left), because REAPER's web
-- interface does not hand back backslash escapes unchanged. The page decodes them.
local function jstr(s)
  local enc = s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end)
  return '"' .. enc .. '"'
end

------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------
local lastCount, lastRebuild = -1, 0
local lastPayload, ver = "", 0
local lastHb = 0

local function loop()
  local now = reaper.time_precise()

  if reaper.GetExtState(SEC, "quit") == "1" then
    reaper.SetExtState(SEC, "quit", "", false)
    return                                   -- atexit cleans up
  end

  local count = reaper.GetProjectStateChangeCount(0)
  if count ~= lastCount or now - lastRebuild > 5 then
    lastCount, lastRebuild = count, now
    rebuild_lanes()
    rebuild_regions()
  end

  local state = reaper.GetPlayState()
  local t = (state & 3) ~= 0 and reaper.GetPlayPosition() or reaper.GetCursorPosition()

  local parts = {}
  for _, l in ipairs(LANES) do
    local cur, nxt = lane_at(lanes[l.key], t)
    parts[#parts + 1] = string.format('"%s":[%s,%s]', l.key, jstr(cur), jstr(nxt))
  end
  local rm, rc = regions_at(t)
  parts[#parts + 1] = string.format('"r":[%s,%s]', jstr(rm), jstr(rc))
  local payload = "{" .. table.concat(parts, ",") .. "}"
  if payload ~= lastPayload then
    lastPayload = payload
    ver = ver + 1
    reaper.SetExtState(SEC, "d", payload, false)
    reaper.SetExtState(SEC, "ver", tostring(ver), false)
  end

  if now - lastHb > 1 then
    lastHb = now
    reaper.SetExtState(SEC, "hb", tostring(math.floor(now * 1000)), false)
    reaper.SetExtState(SEC, "hbt", tostring(now), false)
  end

  reaper.defer(loop)
end

rebuild_lanes()
rebuild_regions()
loop()
