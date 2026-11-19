-- @noindex
-- ReNo Mellow - Chord Buddy : export of the selected chords
--   1 = empty item with the chord name as item notes, on a "Chords" track
--   2 = take marker at the start of the chord
--   3 = MIDI text event (type 1, "Text")
--   4 = REAPER notation event (chord symbol)

local E = {}
local r = reaper

E.MODES = {
  { id = 1, label = "Item on \"Chords\" track" },
  { id = 2, label = "Take marker" },
  { id = 3, label = "Text event" },
  { id = 4, label = "Notation event" },
}

local MAJOR = { 0, 2, 4, 5, 7, 9, 11 }

-- Degree colors (same as the wheel), as native REAPER colors
local DEG_RGB = {
  { 0x9E, 0xE0, 0xCC }, { 0xF7, 0xF7, 0xC0 }, { 0xFF, 0x9F, 0x7A }, { 0xCC, 0xFF, 0xCC },
  { 0xAA, 0xD8, 0xE6 }, { 0xFF, 0xD2, 0x7F }, { 0xFF, 0xC0, 0xCB },
}

local function degree_color(root_pc, key_pc)
  if not root_pc then return nil end
  local rel = (root_pc - key_pc) % 12
  for d = 1, 7 do
    if MAJOR[d] == rel then
      local c = DEG_RGB[d]
      return r.ColorToNative(c[1], c[2], c[3]) | 0x1000000
    end
  end
  return nil
end

-- Notation event text for a chord symbol.
-- TO CHECK IN REAPER: format taken from scripts that read these events
-- (message ending with '" chord').
local function notation_msg(name)
  return 'TRAC text "' .. name .. '" chord'
end

---------------------------------------------------------------------------
-- Takes to export from
---------------------------------------------------------------------------

-- MIDI editor take, otherwise every selected MIDI item in the arrangement
function E.SourceTakes()
  local hwnd = r.MIDIEditor_GetActive()
  local take = hwnd and r.MIDIEditor_GetTake(hwnd)
  if take and r.ValidatePtr2(0, take, "MediaItem_Take*") and r.TakeIsMIDI(take) then
    return { take }
  end
  local list = {}
  for i = 0, r.CountSelectedMediaItems(0) - 1 do
    local tk = r.GetActiveTake(r.GetSelectedMediaItem(0, i))
    if tk and r.TakeIsMIDI(tk) then list[#list + 1] = tk end
  end
  return list
end

---------------------------------------------------------------------------
-- Mode helpers
---------------------------------------------------------------------------

local function find_or_create_track(name)
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, n = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if n == name then return tr end
  end
  r.InsertTrackAtIndex(0, true)
  local tr = r.GetTrack(0, 0)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr
end

local function export_item(track, pos, len, name, color)
  -- replace an item that starts at the same position
  for i = r.CountTrackMediaItems(track) - 1, 0, -1 do
    local it = r.GetTrackMediaItem(track, i)
    if math.abs(r.GetMediaItemInfo_Value(it, "D_POSITION") - pos) < 0.001 then
      r.DeleteTrackMediaItem(track, it)
    end
  end
  local it = r.AddMediaItemToTrack(track)
  r.SetMediaItemInfo_Value(it, "D_POSITION", pos)
  r.SetMediaItemInfo_Value(it, "D_LENGTH", len)
  r.GetSetMediaItemInfo_String(it, "P_NOTES", name, true)
  if color then r.SetMediaItemInfo_Value(it, "I_CUSTOMCOLOR", color) end
end

local function export_take_marker(take, pos, name, color)
  local item = r.GetMediaItemTake_Item(take)
  local ipos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local rate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local offs = r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local srcpos = (pos - ipos) * rate + offs
  for i = r.GetNumTakeMarkers(take) - 1, 0, -1 do
    local p = r.GetTakeMarker(take, i)
    if math.abs(p - srcpos) < 0.001 then r.DeleteTakeMarker(take, i) end
  end
  r.SetTakeMarker(take, -1, name, srcpos, color or 0)
end

-- Delete text events of a type at a ppq (match = optional message test)
local function delete_text_at(take, ppq, typ, match)
  local _, _, _, cnt = r.MIDI_CountEvts(take)
  for i = cnt - 1, 0, -1 do
    local ok, _, _, p, t, msg = r.MIDI_GetTextSysexEvt(take, i)
    if ok and t == typ and math.abs(p - ppq) < 0.5 and (not match or msg:match(match)) then
      r.MIDI_DeleteTextSysexEvt(take, i)
    end
  end
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------

-- o = { modes = {[1]=true,...}, track_name, color_items, key_pc, spell (table),
--       T (theory lib), M (midi lib) }
-- Returns number of chords exported, or nil + message
function E.Export(o)
  local T, M = o.T, o.M
  local takes = E.SourceTakes()
  if #takes == 0 then return nil, "Open a MIDI item in the MIDI editor, or select MIDI items." end

  local work = {}
  for _, take in ipairs(takes) do
    for _, c in ipairs(M.SelectedChords(take)) do
      local name, root = T.Identify(c.pitches, o.spell)
      if name and name ~= "?" then
        work[#work + 1] = { take = take, c = c, name = name, root = root }
      end
    end
  end
  if #work == 0 then return nil, "Select the notes of one or more chords first." end

  local any = false
  for i = 1, 4 do if o.modes[i] then any = true end end
  if not any then return nil, "No export mode selected (see Set up)." end

  r.Undo_BeginBlock2(0)
  r.PreventUIRefresh(1)

  local chord_track = o.modes[1] and find_or_create_track(o.track_name or "Chords") or nil

  for _, w in ipairs(work) do
    local take, c = w.take, w.c
    local pos = r.MIDI_GetProjTimeFromPPQPos(take, c.s)
    local fin = r.MIDI_GetProjTimeFromPPQPos(take, c.e)
    local color = o.color_items and degree_color(w.root, o.key_pc) or nil

    if o.modes[1] then export_item(chord_track, pos, fin - pos, w.name, color) end
    if o.modes[2] then export_take_marker(take, pos, w.name, color) end
    if o.modes[3] then
      delete_text_at(take, c.s, 1)
      r.MIDI_InsertTextSysexEvt(take, false, false, c.s, 1, w.name)
    end
    if o.modes[4] then
      delete_text_at(take, c.s, 15, '" chord$')
      r.MIDI_InsertTextSysexEvt(take, false, false, c.s, 15, notation_msg(w.name))
    end
  end
  for _, take in ipairs(takes) do r.MIDI_Sort(take) end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock2(0, "Chord Buddy: export " .. #work .. " chord(s)", -1)
  return #work
end

-- "1011" <-> { [1]=true, [3]=true, [4]=true }
function E.ParseModes(s)
  local t = {}
  for i = 1, 4 do t[i] = (s or ""):sub(i, i) == "1" end
  return t
end
function E.ModesString(t)
  local s = ""
  for i = 1, 4 do s = s .. (t[i] and "1" or "0") end
  return s
end

return E
