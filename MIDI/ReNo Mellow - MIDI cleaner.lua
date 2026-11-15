-- @description ReNo Mellow - MIDI cleaner
-- @author ReNo Mellow
-- @version 1.0
-- @about Nettoie les items MIDI sélectionnés : supprime les Program Change, le pitch bend et tous les CC sauf CC4 (foot controller), CC11 (expression) et CC64 (sustain) ; passe tous les événements restants sur le canal MIDI 1 ; règle le timebase de l'item sur "Beats (position, length, rate)".
-- @changelog Première version

--[[
  ReNo Mellow - MIDI cleaner
  For every selected MIDI item (all its MIDI takes):
    - deletes Program Change messages
    - deletes Pitch Bend messages
    - deletes every CC except CC4 (foot controller), CC11 (expression) and CC64 (sustain / hold pedal)
    - moves every remaining channel event (notes, kept CCs, aftertouch) to MIDI channel 1
    - sets the item timebase to "Beats (position, length, rate)"
  SysEx, text / lyric events and notation stay untouched.
  One undo step.
--]]

-- CC123 (All notes off) is kept: REAPER stores the end of the MIDI item as a CC123 event.
local KEEP_CC = { [4] = true, [11] = true, [64] = true, [123] = true }

local function clean_take(take)
  local ok, buf = reaper.MIDI_GetAllEvts(take, "")
  if not ok then return 0, 0 end

  local out = {}
  local pos, len = 1, #buf
  local carry = 0               -- offset of deleted events, added to the next kept event
  local prev_deleted_cc = false
  local removed, moved = 0, 0

  while pos < len do
    local offset, flags, msg
    offset, flags, msg, pos = string.unpack("i4Bs4", buf, pos)
    local keep = true
    local this_is_deleted_cc = false
    local b1 = msg:byte(1)

    if b1 and #msg >= 2 and b1 >= 0x80 and b1 < 0xF0 then
      local kind = b1 & 0xF0
      if kind == 0xC0 or kind == 0xE0 then          -- program change, pitch bend
        keep = false
      elseif kind == 0xB0 and not KEEP_CC[msg:byte(2)] then
        keep = false
        this_is_deleted_cc = true
      elseif (b1 & 0x0F) ~= 0 then                  -- move to channel 1
        msg = string.char(kind) .. msg:sub(2)
        moved = moved + 1
      end
    elseif b1 == 0xFF and msg:sub(3, 6) == "CCBZ" and prev_deleted_cc then
      keep = false                                  -- curve shape of a deleted CC
    end

    if keep then
      out[#out + 1] = string.pack("i4Bs4", offset + carry, flags, msg)
      carry = 0
    else
      carry = carry + offset
      removed = removed + 1
    end
    prev_deleted_cc = this_is_deleted_cc
  end

  reaper.MIDI_SetAllEvts(take, table.concat(out))
  reaper.MIDI_Sort(take)
  return removed, moved
end

local n_items = reaper.CountSelectedMediaItems(0)
if n_items == 0 then
  reaper.MB("Select one or more MIDI items first.", "ReNo Mellow - MIDI cleaner", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local cleaned = 0
for i = 0, n_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local has_midi = false
  for t = 0, reaper.CountTakes(item) - 1 do
    local take = reaper.GetTake(item, t)
    if take and reaper.TakeIsMIDI(take) then
      clean_take(take)
      has_midi = true
    end
  end
  if has_midi then
    reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 1) -- Beats (position, length, rate)
    reaper.UpdateItemInProject(item)
    cleaned = cleaned + 1
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ReNo Mellow - MIDI cleaner", -1)

if cleaned == 0 then
  reaper.MB("No MIDI item in the selection.", "ReNo Mellow - MIDI cleaner", 0)
end
