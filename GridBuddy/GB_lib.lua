-- @noindex
-- ReNo Mellow - Grid Buddy : shared engine (grid types, sizes, swing, snap, link with the
-- MIDI editor). Loaded by every Grid Buddy script.
-- Adapted from "Adaptive Grid" and "Gridbox" by Ilias-Timon Poulakis (FeedTheCat).
-- Portions Copyright (c) Ilias-Timon Poulakis, MIT License:
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this
-- software and associated documentation files (the "Software"), to deal in the Software
-- without restriction, including without limitation the rights to use, copy, modify, merge,
-- publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
-- to whom the Software is furnished to do so, subject to the following conditions: the above
-- copyright notice and this permission notice shall be included in all copies or substantial
-- portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

GB = {}
GB.VERSION = "1.5"
GB.S  = "ReNoMellow_GridBuddy"     -- saved settings
GB.RT = "ReNoMellow_GridBuddy_RT"  -- run state (not saved)
GB.ROOT = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""

local r = reaper

GB.FILES = {
  main    = "ReNo Mellow - Grid Buddy.lua",
  display = "ReNo Mellow - Grid Buddy - Display.lua",
  display_midi = "MIDI/ReNo Mellow - Grid Buddy MIDI - Display.lua",
}

-- isolated actions (same file names in MIDI/ with "Grid Buddy MIDI")
GB.ACTIONS = { "Adjust grid (mousewheel)", "Wider grid", "Narrower grid", "Toggle swing" }

---------------------------------------------------------------- settings
function GB.get(key, default)
  local v = r.GetExtState(GB.S, key)
  if v == "" then return default end
  return tonumber(v) or v
end
function GB.set(key, v) r.SetExtState(GB.S, key, tostring(v), true) end
function GB.del(key) r.DeleteExtState(GB.S, key, true) end

function GB.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- per context settings: "arrange" (no prefix) or "midi" ("me_")
local function ck(c, k) return (c == "midi" and "me_" or "") .. k end
function GB.cget(c, k, d) return GB.get(ck(c, k), d) end
function GB.cset(c, k, v) GB.set(ck(c, k), v) end
function GB.cdel(c, k) GB.del(ck(c, k)) end

function GB.flag(k, d) return tonumber(GB.get(k, d and 1 or 0)) == 1 end
function GB.set_flag(k, on) GB.set(k, on and 1 or 0) end

-- one-time import of the settings of FeedTheCat's Adaptive Grid (if installed)
if GB.get("imported", "") == "" then
  local F = "FTC.AdaptiveGrid"
  local map = {
    zoom_div = "zoom_div", min_limit = "min_limit", max_limit = "max_limit",
    min_limit_str = "min_limit_str", max_limit_str = "max_limit_str",
    midi_zoom_div = "me_zoom_div", midi_min_limit = "me_min_limit", midi_max_limit = "me_max_limit",
    midi_min_limit_str = "me_min_limit_str", midi_max_limit_str = "me_max_limit_str",
preserve_grid_type = "preserve_grid_type",
    show_quintuplets = "show_quint", show_septuplets = "show_sept",
    show_frame = "show_frame", show_measure = "show_measure",
  }
  for from, to in pairs(map) do
    local v = r.GetExtState(F, from)
    if v ~= "" and r.GetExtState(GB.S, to) == "" then r.SetExtState(GB.S, to, v, true) end
  end
  GB.set("imported", "1")
end

---------------------------------------------------------------- grid maths
GB.TO_STRAIGHT = { straight = 1, triplet = 3 / 2, quintuplet = 5 / 4, septuplet = 7 / 4, dotted = 2 / 3 }
GB.TYPES = { "straight", "triplet", "quintuplet", "septuplet", "dotted" }
GB.TYPE_LABEL = { straight = "Straight", triplet = "Triplet", quintuplet = "Quintuplet",
  septuplet = "Septuplet", dotted = "Dotted", swing = "Swing" }

local function valid(d) return d and d == d and d > 0 and d < math.huge end

function GB.grid_type(d)
  if not valid(d) then return nil end
  if math.log(d, 2) % 1 == 0 then return "straight" end
  if d > 1 then
    if 2 * d % (2 / 3) == 0 then return "triplet" end
    if 4 * d % (4 / 5) == 0 then return "quintuplet" end
    if 4 * d % (4 / 7) == 0 then return "septuplet" end
    if 2 * d % 3 == 0 then return "dotted" end
  else
    if 2 / d % 3 == 0 then return "triplet" end
    if 4 / d % 5 == 0 then return "quintuplet" end
    if 4 / d % 7 == 0 then return "septuplet" end
    if 2 / d % (2 / 3) == 0 then return "dotted" end
  end
  return nil
end

function GB.straight_of(d)
  local t = GB.grid_type(d)
  if not t then return nil end
  return d * GB.TO_STRAIGHT[t]
end

function GB.closest_straight(d) return 2 ^ math.floor(math.log(d, 2) + 0.5) end

-- same size, other type (keeps the "straight" value)
function GB.convert(d, t)
  local s = valid(d) and (GB.straight_of(d) or GB.closest_straight(d)) or 0.25
  return s / GB.TO_STRAIGHT[t]
end

local function to_fraction(x)
  local err = 0.0000000001
  local n = math.floor(x)
  x = x - n
  if x < err then return n, 1 elseif 1 - err < x then return n + 1, 1 end
  local ln, ld, un, ud = 0, 1, 1, 1
  while true do
    local mn, md = ln + un, ld + ud
    if md * (x + err) < mn then un, ud = mn, md
    elseif mn < (x - err) * md then ln, ld = mn, md
    else return n * md + mn, md end
  end
end

-- "1/16", "1/8T", "1/4D", "2"
function GB.grid_text(d)
  if not valid(d) then return "-" end
  local num, den = to_fraction(d)
  local t = GB.grid_type(d)
  local suf = ""
  if t == "triplet" then suf = "T" den = den * 2 / 3
  elseif t == "quintuplet" then suf = "Q" den = den * 4 / 5
  elseif t == "septuplet" then suf = "S" den = den * 4 / 7
  elseif t == "dotted" then suf = "D" den = den / 2 num = num / 3 end
  if num > 1 and den % num == 0 then den = den / num num = 1 end
  if num >= den and num % den == 0 then return string.format("%.0f%s", num / den, suf) end
  return string.format("%.0f/%.0f%s", num, den, suf)
end

---------------------------------------------------------------- arrange grid
local A = {
  GRID_LINES  = 40145, -- Options: Toggle grid lines
  FRAME       = 41885, -- Grid: Set framerate grid (toggle)
  FRAME_STATE = 40904,
  MEASURE     = 40725, -- Grid: Set measure grid (toggle)
  MEASURE_ST2 = 40923,
  SNAP        = 1157,  -- Options: Toggle snapping
  REL_SNAP    = 41054, -- Item edit: Toggle relative grid snap
  SNAP_SET    = 40071, -- Options: Show snap/grid settings
  SYNC        = 42010, -- Grid: Use the same grid division in arrange view and MIDI editor
}
GB.A = A

function GB.get_grid()
  local _, d, sw, amt = r.GetSetProjectGrid(0, false)
  if d ~= d then d = 1 end
  return d, sw, amt
end

function GB.is_frame()
  return r.GetToggleCommandState(A.FRAME) == 1 or r.GetToggleCommandState(A.FRAME_STATE) == 1
end
function GB.is_measure()
  local _, _, sw = r.GetSetProjectGrid(0, false)
  return r.GetToggleCommandState(A.MEASURE) == 1 or sw == 3
end
function GB.leave_special()
  if r.GetToggleCommandState(A.FRAME) == 1 then r.Main_OnCommand(A.FRAME, 0) end
  if r.GetToggleCommandState(A.MEASURE) == 1 then r.Main_OnCommand(A.MEASURE, 0) end
end
function GB.set_frame()
  if r.GetToggleCommandState(A.FRAME) ~= 1 then r.Main_OnCommand(A.FRAME, 0) end
end
function GB.set_measure()
  if r.GetToggleCommandState(A.MEASURE) ~= 1 then r.Main_OnCommand(A.MEASURE, 0) end
end

-- "Hide grid" = grid lines off (arrange: Options: Toggle grid lines, MIDI editor: View: Toggle grid)
function GB.grid_hidden(c)
  if c == "midi" then return r.GetToggleCommandStateEx(32060, 1017) == 0 end
  return r.GetToggleCommandState(A.GRID_LINES) == 0
end
function GB.toggle_grid_lines(c)
  if c == "midi" then
    local h = r.MIDIEditor_GetActive()
    if h then r.MIDIEditor_OnCommand(h, 1017) end -- View: Toggle grid
  else
    r.Main_OnCommand(A.GRID_LINES, 0)
  end
end
function GB.show_grid_lines()
  if r.GetToggleCommandState(A.GRID_LINES) ~= 1 then r.Main_OnCommand(A.GRID_LINES, 0) end
end

function GB.snap_on() return r.GetToggleCommandState(A.SNAP) == 1 end
function GB.rel_snap_on() return r.GetToggleCommandState(A.REL_SNAP) == 1 end
function GB.toggle_snap() r.Main_OnCommand(A.SNAP, 0) end
function GB.toggle_rel_snap() r.Main_OnCommand(A.REL_SNAP, 0) end
function GB.snap_settings() r.Main_OnCommand(A.SNAP_SET, 0) end
-- "Link MIDI editor" = REAPER's option "Use the same grid division in arrange view and MIDI editor"
function GB.synced() return r.GetToggleCommandState(A.SYNC) == 1 end
function GB.toggle_link() r.Main_OnCommand(A.SYNC, 0) end
-- linked: the MIDI editor uses the arrange grid, so its context is "arrange"
function GB.eff(c) if c == "midi" and GB.synced() then return "arrange" end return c end

-- "Preserve grid type per size": the project remembers the type / swing used for
-- every straight size (project ExtState)
function GB.preserve() return GB.flag("preserve_grid_type", false) end

function GB.load_project_grid(d)
  if not GB.preserve() then return false end
  local s = GB.straight_of(d)
  if not s then return false end
  local _, state = r.GetProjExtState(0, GB.S, tostring(s))
  local swing, amt = 0, nil
  local nd = s
  if state ~= "" then
    if state:sub(1, 1) == "s" then swing, amt = 1, tonumber(state:sub(2))
    else nd = tonumber(state) or s end
  end
  r.GetSetProjectGrid(0, true, nd, swing, amt)
  return true
end

function GB.save_project_grid(d, swing, amt)
  if not GB.preserve() then return end
  local s = GB.straight_of(d)
  if not s then return end
  local state = ""
  if swing == 1 and amt then state = "s" .. amt
  elseif s ~= d then state = string.format("%.32f", d) end
  r.SetProjExtState(0, GB.S, tostring(s), state)
end

function GB.set_arrange_div(d, sw, amt)
  if not GB.load_project_grid(d) then r.GetSetProjectGrid(0, true, d, sw, amt) end
end

function GB.swing_on()
  local _, sw, amt = GB.get_grid()
  return sw == 1 and amt ~= 0
end

-- amt: -1 .. 1
function GB.set_swing(amt)
  GB.leave_special()
  local d, _, old = GB.get_grid()
  local s = GB.convert(d, "straight")
  amt = GB.clamp(math.floor((amt or old or 0) * 100 + 0.5) / 100, -1, 1)
  r.GetSetProjectGrid(0, true, s, 1, amt)
  GB.save_project_grid(s, 1, amt)
end

function GB.swing_off()
  local d, _, amt = GB.get_grid()
  r.GetSetProjectGrid(0, true, d, 0, amt)
  GB.save_project_grid(d, 0, amt)
end

---------------------------------------------------------------- MIDI editor grid
local M = { STRAIGHT = 41003, TRIPLET = 41004, DOTTED = 41005, SWING = 41006,
  GRID = 1017, SNAP = 1014 }
GB.M = M

function GB.midi_editor() return r.MIDIEditor_GetActive() end

function GB.midi_take()
  local h = r.MIDIEditor_GetActive()
  if not h then return nil, nil end
  local tk = r.MIDIEditor_GetTake(h)
  if tk and r.ValidatePtr(tk, "MediaItem_Take*") then return tk, h end
  return nil, h
end

-- division in whole notes (like the project grid), swing, note length
function GB.midi_grid()
  local tk = GB.midi_take()
  if not tk then return nil end
  local qn, sw, nl = r.MIDI_GetGrid(tk)
  return qn / 4, sw, nl
end

local function midi_cmd(id)
  local h = r.MIDIEditor_GetActive()
  if h then r.MIDIEditor_OnCommand(h, id) end
end

function GB.midi_snap_on() return r.GetToggleCommandStateEx(32060, M.SNAP) == 1 end
-- MIDI editor: "Timebase: Toggle sync to arrange view" (40640)
function GB.midi_sync_on() return r.GetToggleCommandStateEx(32060, 40640) == 1 end
function GB.toggle_midi_sync() midi_cmd(40640) end
function GB.midi_toggle_snap() midi_cmd(M.SNAP) end
function GB.show_midi_grid()
  if GB.midi_editor() and r.GetToggleCommandStateEx(32060, M.GRID) ~= 1 then midi_cmd(M.GRID) end
end

---------------------------------------------------------------- types and sizes (both contexts)
function GB.current(c)
  c = GB.eff(c)
  if c == "midi" then
    local d, sw = GB.midi_grid()
    return d, (sw and sw ~= 0) and 1 or 0, sw or 0
  end
  return GB.get_grid()
end

function GB.is_type(c, t)
  c = GB.eff(c)
  if c == "arrange" and (GB.is_frame() or GB.is_measure()) then return false end
  local d, sw = GB.current(c)
  if not d then return false end
  if t == "swing" then
    if c == "midi" then return sw == 1 end
    return GB.swing_on()
  end
  if t == "straight" and sw == 1 then return false end
  return GB.grid_type(d) == t
end

function GB.set_type(c, t)
  c = GB.eff(c)
  if c == "midi" then
    local d, sw = GB.midi_grid()
    if not d then return GB.no_midi() end
    if t == "swing" then
      midi_cmd(sw == 1 and M.STRAIGHT or M.SWING)
      return
    end
    local nd = GB.convert(d, t)
    if t == "straight" or t == "triplet" or t == "dotted" then
      midi_cmd(t == "triplet" and M.TRIPLET or t == "dotted" and M.DOTTED or M.STRAIGHT)
    elseif sw == 1 then
      midi_cmd(M.STRAIGHT)
    end
    r.SetMIDIEditorGrid(0, nd)
    return
  end
  GB.leave_special()
  if t == "swing" then
    if GB.swing_on() then GB.swing_off() else GB.set_swing(nil) end
    return
  end
  local d, _, amt = GB.get_grid()
  local nd = GB.convert(d, t)
  r.GetSetProjectGrid(0, true, nd, 0, amt)
  GB.save_project_grid(nd, 0, amt)
end

GB.SIZES = {
  { "1/128", 1 / 128 }, { "1/64", 1 / 64 }, { "1/32", 1 / 32 }, { "1/16", 1 / 16 }, { "1/8", 1 / 8 },
  { "1/4", 1 / 4 }, { "1/2", 1 / 2 }, { "1", 1 }, { "2", 2 }, { "4", 4 },
}

-- size: straight value (1/16 = 0.0625); the current type is kept
function GB.set_fixed(c, size)
  c = GB.eff(c)
  if c == "midi" then
    local d = GB.midi_grid()
    if not d then return GB.no_midi() end
    local t = GB.grid_type(d) or "straight"
    r.SetMIDIEditorGrid(0, size / GB.TO_STRAIGHT[t])
  else
    GB.leave_special()
    GB.show_grid_lines()
    if not GB.load_project_grid(size) then
      local d, sw, amt = GB.get_grid()
      local t = GB.grid_type(d) or "straight"
      r.GetSetProjectGrid(0, true, size / GB.TO_STRAIGHT[t], sw, amt)
    end
  end
end

function GB.is_fixed(c, size)
  c = GB.eff(c)
  if c == "arrange" and (GB.is_frame() or GB.is_measure()) then return false end
  local d = GB.current(c)
  if not d then return false end
  local s = GB.straight_of(d)
  return s ~= nil and math.abs(s - size) < 1e-12
end

---------------------------------------------------------------- limits and divisor
function GB.divisor(c)
  local f = tonumber(GB.cget(c, "zoom_div", 2)) or 2
  if f <= 1 then f = 2 end
  return f
end

function GB.limits(c)
  local mn = tonumber(GB.cget(c, "min_limit", 0)) or 0
  local mx = tonumber(GB.cget(c, "max_limit", 0)) or 0
  if mn == 0 then mn = 1 / 4096 * 2 / 3 end
  if mx == 0 then mx = 4096 * 3 / 2 end
  return mn, mx
end

-- "1/128", "1/8T", "1D", "0.25", "" -> value (0 = no limit) or nil, error
function GB.parse_limit(s)
  s = (s or ""):gsub("%s", "")
  if s == "" then return 0 end
  local nom, den, suf = s:match("^(%d+)/(%d+)([TtDd]?)$")
  if not nom then
    nom, suf = s:match("^(%d+)([TtDd]?)$")
    den = 1
  end
  local v
  if nom then
    local f = 1
    if suf == "T" or suf == "t" then f = 2 / 3 end
    if suf == "D" or suf == "d" then f = 3 / 2 end
    v = tonumber(nom) / tonumber(den) * f
  else
    v = tonumber(s)
  end
  if not v or v < 0 or v ~= v or v == math.huge then return nil, "Value '" .. s .. "' not permitted" end
  return v
end

-- returns true or nil, error
function GB.set_limits(c, min_s, max_s)
  local mn, e1 = GB.parse_limit(min_s)
  if not mn then return nil, e1 end
  local mx, e2 = GB.parse_limit(max_s)
  if not mx then return nil, e2 end
  if mx ~= 0 and mn > mx then return nil, "Max can't be smaller than min" end
  GB.cset(c, "min_limit_str", min_s or "")
  GB.cset(c, "max_limit_str", max_s or "")
  GB.cset(c, "min_limit", string.format("%.32f", mn))
  GB.cset(c, "max_limit", string.format("%.32f", mx))
  return true
end

-- dir > 0 : wider grid (multiply), dir < 0 : narrower grid (divide)
function GB.step_fixed(c, dir)
  c = GB.eff(c)
  local f = GB.divisor(c)
  local d, sw, amt = GB.current(c)
  if not d then if c == "midi" then GB.no_midi() end return false end
  local nd = dir > 0 and d * f or d / f
  local mn, mx = GB.limits(c)
  if nd < mn and dir < 0 then return false end
  if nd > mx and dir > 0 then return false end
  if c == "midi" then r.SetMIDIEditorGrid(0, nd)
  else GB.set_arrange_div(nd, sw, amt) end
  return true
end

---------------------------------------------------------------- wheel ladder
-- The mouse wheel walks one ladder (dir > 0 = wider):
--   1/32T 1/16T 1/8T | straight sizes, finest -> widest | 1/2D 1/4D 1/8D 1/16D 1/32D
-- Past the finest straight size come the triplets, past the widest the dotted sizes.
-- The straight part goes from Min size to Max size (Set up), 1/128 to 4 when empty.
GB.LADDER_T = { 1 / 32, 1 / 16, 1 / 8 }              -- shown as 1/32T 1/16T 1/8T
GB.LADDER_D = { 1 / 2, 1 / 4, 1 / 8, 1 / 16, 1 / 32 } -- shown as 1/2D ... 1/32D

function GB.ladder(c)
  c = GB.eff(c)
  local mn = tonumber(GB.cget(c, "min_limit", 0)) or 0
  local mx = tonumber(GB.cget(c, "max_limit", 0)) or 0
  if mn <= 0 then mn = 1 / 128 end
  if mx <= 0 then mx = 4 end
  local L = {}
  for _, v in ipairs(GB.LADDER_T) do L[#L + 1] = { div = v * 2 / 3, t = "triplet" } end
  for k = -12, 12 do
    local v = 2 ^ k
    if v >= mn - 1e-12 and v <= mx + 1e-12 then L[#L + 1] = { div = v, t = "straight" } end
  end
  for _, v in ipairs(GB.LADDER_D) do L[#L + 1] = { div = v * 3 / 2, t = "dotted" } end
  return L
end

local function ladder_index(L, d)
  if not d then return nil end
  for i, e in ipairs(L) do
    if math.abs(e.div - d) < 1e-9 then return i end
  end
  -- not on the ladder (1/4T, 1/64D, quintuplet...): start from its straight size
  local s = GB.straight_of(d) or GB.closest_straight(d)
  local best, best_i = math.huge, nil
  for i, e in ipairs(L) do
    if e.t == "straight" then
      local dist = math.abs(math.log(e.div / s, 2))
      if dist < best then best, best_i = dist, i end
    end
  end
  return best_i
end

-- sets a division with its type (straight keeps the swing of the arrange view)
function GB.set_div_typed(c, v, t)
  c = GB.eff(c)
  if c == "midi" then
    local h = r.MIDIEditor_GetActive()
    if not h then return GB.no_midi() end
    local id = t == "triplet" and 41004 or t == "dotted" and 41005 or 41003
    if r.GetToggleCommandStateEx(32060, id) ~= 1 then r.MIDIEditor_OnCommand(h, id) end
    r.SetMIDIEditorGrid(0, v)
    return true
  end
  GB.leave_special()
  local _, sw, amt = GB.get_grid()
  if t ~= "straight" then sw = 0 end
  r.GetSetProjectGrid(0, true, v, sw, amt)
  return true
end

function GB.step_ladder(c, dir)
  local d = GB.current(c)
  if not d then if GB.eff(c) == "midi" then GB.no_midi() end return false end
  local L = GB.ladder(c)
  local i = ladder_index(L, d)
  if not i then return false end
  -- on the ladder: next rung; off the ladder (1/4T, 1/64D...): first its straight size
  local j = math.abs(L[i].div - d) < 1e-9 and i + dir or i
  if j < 1 or j > #L then return false end
  return GB.set_div_typed(c, L[j].div, L[j].t)
end

---------------------------------------------------------------- spacing (visible grid)
function GB.min_spacing()
  local ok, v = r.get_config_var_string("projgridmin")
  if ok then return tonumber(v) or 8 end
  if r.SNM_GetIntConfigVar then return r.SNM_GetIntConfigVar("projgridmin", 8) end
  local cached = tonumber(GB.get("projgridmin", ""))
  if cached then return cached end
  local val = 8
  local fh = io.open(r.get_ini_file(), "r")
  if fh then
    for line in fh:lines() do
      local m = line:match("^projgridmin=(.+)")
      if m then val = tonumber(m) or val end
    end
    fh:close()
  end
  GB.set("projgridmin", val)
  return val
end

---------------------------------------------------------------- visible grid (Display option)
-- the grid REAPER really draws when the straight grid is too dense for the zoom
function GB.visible_div(d)
  if not valid(d) or math.log(d, 2) % 1 ~= 0 then return d end
  local zoom = r.GetHZoomLevel()
  local t0, t1 = r.GetSet_ArrangeView2(0, false, 0, 0)
  local _, _, _, b0 = r.TimeMap2_timeToBeats(0, t0)
  local _, _, _, b1 = r.TimeMap2_timeToBeats(0, t1)
  local measures = (b1 - b0) / 4
  if measures <= 0 then return d end
  local measure_px = (t1 - t0) * zoom / measures
  local maxd = GB.min_spacing() / measure_px
  if d < maxd then return d * 2 ^ math.ceil(math.log(maxd / d, 2)) end
  return d
end

---------------------------------------------------------------- launching the other scripts
function GB.register_self(key)
  local _, _, sec, cmd = r.get_action_context()
  if sec == 0 and cmd and cmd > 0 then
    local n = r.ReverseNamedCommandLookup(cmd)
    local id = (n and n ~= "") and ("_" .. n) or tostring(cmd)
    if r.GetExtState(GB.S, key) ~= id then r.SetExtState(GB.S, key, id, true) end
  end
end

-- launches a Grid Buddy script from anywhere (a Main-section command; the MIDI Display
-- gets a Main-section copy for that, like the Tool Buddy MIDI Display)
function GB.launch(which)
  local path = GB.ROOT .. GB.FILES[which]
  local id = r.GetExtState(GB.S, "cmd_" .. which)
  local cmd = 0
  if id ~= "" then cmd = tonumber(id) or r.NamedCommandLookup(id) or 0 end
  if cmd == 0 and r.file_exists(path) then
    cmd = r.AddRemoveReaScript(true, 0, path, true) or 0
    if cmd > 0 then
      local n = r.ReverseNamedCommandLookup(cmd)
      GB.set("cmd_" .. which, (n and n ~= "") and ("_" .. n) or tostring(cmd))
    end
  end
  if cmd > 0 then r.Main_OnCommand(cmd, 0)
  else r.MB("Could not find:\n" .. path, "Grid Buddy", 0) end
end

function GB.alive(role)
  local t = tonumber(r.GetExtState(GB.RT, "alive_" .. role))
  return t ~= nil and r.time_precise() - t < 1.0
end

-- tab: 1 = Grid, 2 = Set up
function GB.open_main(tab)
  r.SetExtState(GB.RT, "want_tab", tostring(tab or 1), false)
  if GB.alive("main") then return end
  GB.launch("main")
end

function GB.no_midi()
  r.MB("Open a MIDI editor first.", "Grid Buddy", 0)
  return false
end

-- adds (once) a block to Scripts/__startup.lua that runs GB_startup.lua
function GB.ensure_startup_hook()
  local sp = r.GetResourcePath() .. "/Scripts/__startup.lua"
  local target = GB.ROOT .. "GB_startup.lua"
  local block = "-- >>> ReNo Mellow Grid Buddy (reopens the Displays)\n"
    .. "do local f = [[" .. target .. "]]; if reaper.file_exists(f) then dofile(f) end end\n"
    .. "-- <<< ReNo Mellow Grid Buddy\n"
  local cur = ""
  local fh = io.open(sp, "r")
  if fh then cur = fh:read("a") or "" fh:close() end
  if cur:find(block, 1, true) then return end
  local a, b = cur:find("%-%- >>> ReNo Mellow Grid Buddy.-%-%- <<< ReNo Mellow Grid Buddy\n?")
  if a then
    cur = cur:sub(1, a - 1) .. block .. cur:sub(b + 1)
  else
    if cur ~= "" and not cur:match("\n$") then cur = cur .. "\n" end
    cur = cur .. block
  end
  fh = io.open(sp, "w")
  if fh then fh:write(cur) fh:close() end
end

---------------------------------------------------------------- isolated actions
-- every action file only calls GB.run_action(): the action comes from its file name
function GB.run_action(path)
  local _, _, sec, cmd, _, _, val = r.get_action_context()
  local c = sec == 32060 and "midi" or "arrange"
  local name = (path:match("([^/\\]+)%.lua$") or ""):match("Grid Buddy[^%-]*%- (.+)$")
  if not name then return end
  r.defer(function() end) -- no undo point
  -- one-shot actions: toolbar icon always off
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0) r.RefreshToolbar2(sec, cmd) end
  if c == "midi" and not GB.midi_editor() then return GB.no_midi() end
  if name == "Adjust grid (mousewheel)" then
    local rev = GB.flag("wheel_rev", false) and -1 or 1
    GB.step_ladder(c, (val or 0) * rev < 0 and 1 or -1)
  elseif name == "Wider grid" then GB.step_fixed(c, 1)
  elseif name == "Narrower grid" then GB.step_fixed(c, -1)
  elseif name == "Toggle swing" then GB.set_type(c, "swing")
  end
end

-- version 1.1: the adaptive grid is gone; switch off a mode left by 1.0 (its service stops itself)
if (tonumber(GB.get("mult", 0)) or 0) ~= 0 or (tonumber(GB.get("me_mult", 0)) or 0) ~= 0 then
  GB.set("mult", 0) GB.set("me_mult", 0)
end

return GB
