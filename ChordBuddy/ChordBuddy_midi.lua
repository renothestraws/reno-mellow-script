-- @noindex
-- ReNo Mellow - Chord Buddy : MIDI helpers
-- (target take, chord insertion, reading chords from a take)

local M = {}
local r = reaper

---------------------------------------------------------------------------
-- Target
---------------------------------------------------------------------------

-- Take of the last focused MIDI editor
function M.GetEditorTake()
  local hwnd = r.MIDIEditor_GetActive()
  if not hwnd then return nil, nil, "Open a MIDI item in the MIDI editor first." end
  local take = r.MIDIEditor_GetTake(hwnd)
  if not take or not r.ValidatePtr2(0, take, "MediaItem_Take*") or not r.TakeIsMIDI(take) then
    return nil, hwnd, "The MIDI editor has no MIDI take."
  end
  return take, hwnd
end

-- Take used by the Display: MIDI editor take, otherwise the selected MIDI
-- item under the given time position in the arrangement.
function M.GetReadTake(time)
  local take = M.GetEditorTake()
  if take then return take end
  for i = 0, r.CountSelectedMediaItems(0) - 1 do
    local item = r.GetSelectedMediaItem(0, i)
    local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
    if time >= pos and time < pos + len then
      local tk = r.GetActiveTake(item)
      if tk and r.TakeIsMIDI(tk) then return tk end
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Octave naming (REAPER preference "MIDI octave name display offset")
---------------------------------------------------------------------------

-- Returns the offset read from REAPER (0 = note 60 is C4), or nil.
-- TO CHECK IN REAPER: storage format of the "midioctoffs" config variable.
function M.ReaperOctaveOffset()
  if not r.get_config_var_string then return nil end
  local ok, s = r.get_config_var_string("midioctoffs")
  local v = ok and tonumber(s)
  if not v then return nil end
  return v - 1
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Notes of a take as a list of tables
function M.GetNotes(take)
  local notes = {}
  local _, cnt = r.MIDI_CountEvts(take)
  for i = 0, cnt - 1 do
    local ok, sel, muted, s, e, chan, pitch, vel = r.MIDI_GetNote(take, i)
    if ok then
      notes[#notes + 1] = { idx = i, sel = sel, muted = muted, s = s, e = e,
                            chan = chan, pitch = pitch, vel = vel }
    end
  end
  return notes
end

-- Pitches sounding at a ppq position (muted notes ignored)
function M.PitchesAt(take, ppq)
  local out = {}
  for _, n in ipairs(M.GetNotes(take)) do
    if not n.muted and n.s <= ppq and n.e > ppq then out[#out + 1] = n.pitch end
  end
  table.sort(out)
  return out
end

-- Group notes into chords.
-- A note joins the current chord when it starts while the chord's notes are
-- still sounding, and either in the first half of their length or ending
-- with them (strummed chords stay together, back-to-back or slightly
-- overlapping chords stay apart).
-- Returns a list sorted by time: { s = ppq, e = ppq, pitches = {...} }
local function group_chords(notes)
  table.sort(notes, function(a, b) return a.s < b.s end)
  local chords = {}
  local cur = nil
  for _, n in ipairs(notes) do
    local same_end = cur and math.abs(n.e - cur.e) <= 0.1 * (cur.e - cur.s) + 1
    if cur and n.s < cur.min_e - 1 and
       ((n.s - cur.s) <= 0.5 * (cur.min_e - cur.s) or same_end) then
      cur.pitches[#cur.pitches + 1] = n.pitch
      if n.e > cur.e then cur.e = n.e end
      if n.e < cur.min_e then cur.min_e = n.e end
    else
      cur = { s = n.s, e = n.e, min_e = n.e, pitches = { n.pitch } }
      chords[#chords + 1] = cur
    end
  end
  for _, c in ipairs(chords) do table.sort(c.pitches) end
  return chords
end

-- Selected notes grouped into chords
function M.SelectedChords(take)
  local sel = {}
  for _, n in ipairs(M.GetNotes(take)) do
    if n.sel and not n.muted then sel[#sel + 1] = n end
  end
  return group_chords(sel)
end

-- Chord just before a ppq position (used by Auto inversion): the last chord
-- (same grouping as the export) among the notes starting before the position.
function M.PreviousChord(take, ppq)
  local before = {}
  for _, n in ipairs(M.GetNotes(take)) do
    if not n.muted and n.s < ppq - 1 then before[#before + 1] = n end
  end
  if #before == 0 then return nil end
  local chords = group_chords(before)
  return chords[#chords].pitches
end

---------------------------------------------------------------------------
-- Insertion
---------------------------------------------------------------------------

-- Length of the chord in QN at a time position.
--   mult : 1, 2, 4 (grid multiples) or "bar"
function M.ChordLengthQN(take, time, mult)
  if mult == "bar" then
    local num, denom = r.TimeMap_GetTimeSigAtTime(0, time)
    return num * 4 / denom
  end
  local grid = r.MIDI_GetGrid(take)
  if not grid or grid <= 0 then grid = 1 end
  return grid * (tonumber(mult) or 1)
end

-- Insert a chord at the edit cursor.
--   pitches : list of MIDI pitches
--   o = { vel, mult, replace, advance, strum_ms, human_vel, name }
-- Returns true, or false + message
function M.InsertChord(pitches, o)
  if not pitches or #pitches == 0 then return false, "Nothing to insert." end
  local take, hwnd, err = M.GetEditorTake()
  if not take then return false, err end
  o = o or {}

  local item = r.GetMediaItemTake_Item(take)
  local cur = r.GetCursorPositionEx(0)
  local start_qn = r.TimeMap2_timeToQN(0, cur)
  local end_qn = start_qn + M.ChordLengthQN(take, cur, o.mult)
  local end_time = r.TimeMap2_QNToTime(0, end_qn)

  local chan = r.MIDIEditor_GetSetting_int(hwnd, "default_note_chan")
  if not chan or chan < 0 or chan > 15 then chan = 0 end

  r.Undo_BeginBlock2(0)
  r.PreventUIRefresh(1)

  -- Extend the item when the chord goes past its edges
  local ipos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local ilen = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local istart_qn = r.TimeMap2_timeToQN(0, ipos)
  local iend_qn = r.TimeMap2_timeToQN(0, ipos + ilen)
  if start_qn < istart_qn or end_qn > iend_qn then
    r.MIDI_SetItemExtents(item, math.min(start_qn, istart_qn), math.max(end_qn, iend_qn))
  end

  local s_ppq = r.MIDI_GetPPQPosFromProjQN(take, start_qn)
  local e_ppq = r.MIDI_GetPPQPosFromProjQN(take, end_qn)

  -- Replace notes starting inside the chord's span
  if o.replace then
    local _, cnt = r.MIDI_CountEvts(take)
    for i = cnt - 1, 0, -1 do
      local ok, _, _, s = r.MIDI_GetNote(take, i)
      if ok and s >= s_ppq - 0.5 and s < e_ppq - 0.5 then r.MIDI_DeleteNote(take, i) end
    end
  end

  -- Deselect existing notes so the new chord is the selection
  r.MIDI_SelectAll(take, false)

  local sorted = {}
  for i = 1, #pitches do sorted[i] = pitches[i] end
  table.sort(sorted)

  local base_vel = o.vel or 100
  local strum = (o.strum_ms or 0) / 1000
  for i, pitch in ipairs(sorted) do
    local ns = s_ppq
    if strum > 0 then
      ns = r.MIDI_GetPPQPosFromProjTime(take, cur + strum * (i - 1))
      if ns > e_ppq - 1 then ns = e_ppq - 1 end
    end
    local vel = base_vel
    local h = o.human_vel or 0
    if h > 0 then vel = vel + math.random(-h, h) end
    vel = math.max(1, math.min(127, math.floor(vel + 0.5)))
    r.MIDI_InsertNote(take, true, false, ns, e_ppq, chan, pitch, vel, true)
  end
  r.MIDI_Sort(take)

  if o.advance ~= false then r.SetEditCurPos2(0, end_time, false, false) end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock2(0, "Chord Buddy: insert " .. (o.name or "chord"), -1)
  return true
end

return M
