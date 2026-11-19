-- @noindex
-- ReNo Mellow - Grid Buddy : shared engine (grid types, fixed sizes, adaptive grid,
-- background service, toolbar states). Loaded by every Grid Buddy script.
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
GB.VERSION = "1.0"
GB.S  = "ReNoMellow_GridBuddy"     -- saved settings
GB.RT = "ReNoMellow_GridBuddy_RT"  -- run state (not saved)
GB.ROOT = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""

local r = reaper

GB.FILES = {
  main    = "ReNo Mellow - Grid Buddy.lua",
  display = "ReNo Mellow - Grid Buddy - Display.lua",
  service = "ReNo Mellow - Grid Buddy - Service.lua",
}

-- isolated actions (same file names in MIDI/ with "Grid Buddy MIDI")
GB.ACTIONS = {
  "Adaptive off (fixed)", "Adaptive narrowest", "Adaptive narrow", "Adaptive medium",
  "Adaptive wide", "Adaptive widest", "Adaptive custom",
  "Adjust grid (mousewheel)", "Adjust fixed grid (mousewheel)",
  "Wider grid", "Narrower grid", "Adapt grid to zoom", "Toggle swing",
}

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
    min_limit_str = "min_limit_str", max_limit_str = "max_limit_str", custom_spacing = "custom_spacing",
    midi_zoom_div = "me_zoom_div", midi_min_limit = "me_min_limit", midi_max_limit = "me_max_limit",
    midi_min_limit_str = "me_min_limit_str", midi_max_limit_str = "me_max_limit_str",
    midi_custom_spacing = "me_custom_spacing", preserve_grid_type = "preserve_grid_type",
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
  GB.cset("arrange", "mult", 0)
  if r.GetToggleCommandState(A.FRAME) ~= 1 then r.Main_OnCommand(A.FRAME, 0) end
  GB.refresh_toggles("arrange")
end
function GB.set_measure()
  GB.cset("arrange", "mult", 0)
  if r.GetToggleCommandState(A.MEASURE) ~= 1 then r.Main_OnCommand(A.MEASURE, 0) end
  GB.refresh_toggles("arrange")
end

function GB.show_grid_lines()
  if r.GetToggleCommandState(A.GRID_LINES) ~= 1 then r.Main_OnCommand(A.GRID_LINES, 0) end
end

function GB.snap_on() return r.GetToggleCommandState(A.SNAP) == 1 end
function GB.rel_snap_on() return r.GetToggleCommandState(A.REL_SNAP) == 1 end
function GB.toggle_snap() r.Main_OnCommand(A.SNAP, 0) end
function GB.toggle_rel_snap() r.Main_OnCommand(A.REL_SNAP, 0) end
function GB.snap_settings() r.Main_OnCommand(A.SNAP_SET, 0) end
function GB.synced() return r.GetToggleCommandState(A.SYNC) == 1 end

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
function GB.midi_toggle_snap() midi_cmd(M.SNAP) end
function GB.show_midi_grid()
  if GB.midi_editor() and r.GetToggleCommandStateEx(32060, M.GRID) ~= 1 then midi_cmd(M.GRID) end
end

---------------------------------------------------------------- types and sizes (both contexts)
function GB.current(c)
  if c == "midi" then
    local d, sw = GB.midi_grid()
    return d, (sw and sw ~= 0) and 1 or 0, sw or 0
  end
  return GB.get_grid()
end

function GB.is_type(c, t)
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
  GB.cset(c, "mult", 0)
  if c == "midi" then
    local d = GB.midi_grid()
    if not d then GB.refresh_toggles(c) return GB.no_midi() end
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
  GB.refresh_toggles(c)
end

function GB.is_fixed(c, size)
  if GB.mult(c) ~= 0 then return false end
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

---------------------------------------------------------------- adaptive modes
-- multiplier: 0 = fixed, 1 narrowest, 2 narrow, 3 medium, 4 wide, 6 widest, -1 custom
GB.MODES = {
  { "Narrowest", 1 }, { "Narrow", 2 }, { "Medium", 3 }, { "Wide", 4 }, { "Widest", 6 }, { "Custom", -1 },
}
GB.MODE_NAME = { [0] = "Fixed", [1] = "Narrowest", [2] = "Narrow", [3] = "Medium", [4] = "Wide",
  [6] = "Widest", [-1] = "Custom" }

function GB.mult(c) return tonumber(GB.cget(c, "mult", 0)) or 0 end
function GB.is_adaptive(c) return GB.mult(c) ~= 0 end

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

function GB.custom_spacing(c) return tonumber(GB.cget(c, "custom_spacing", "")) end

-- returns a message for the user when the value is suspicious, or nil
function GB.set_custom_spacing(c, px)
  px = tonumber(px)
  if not px or px <= 0 then return nil, "Value not permitted" end
  GB.cset(c, "custom_spacing", px)
  local min = c == "midi" and 15 or GB.min_spacing()
  if px < min then
    return true, string.format("Smaller than the minimum grid line spacing (%d px): this might have side effects.", min)
  end
  return true
end

-- modal dialog: only call it outside an ImGui frame
function GB.ask_custom_spacing(c)
  local cur = GB.custom_spacing(c) or ""
  local ok, s = r.GetUserInputs("Grid Buddy - " .. (c == "midi" and "MIDI editor" or "Arrange view"),
    1, "Minimum grid spacing (pixels):", tostring(cur))
  if not ok then return false end
  local done, msg = GB.set_custom_spacing(c, s)
  if not done then r.MB(msg, "Grid Buddy", 0) return false end
  if msg then r.MB(msg, "Grid Buddy", 0) end
  return true
end

-- sets the mode (no toggle). m ~= 0 : adapts now and starts the service
function GB.apply_mult(c, m)
  if m == -1 and not GB.custom_spacing(c) then
    if not GB.ask_custom_spacing(c) then return false end
  end
  GB.cset(c, "mult", m)
  if m ~= 0 then
    GB.ensure_startup_hook() -- start-up: service again, or grids back to fixed
    if c == "arrange" then GB.leave_special() GB.show_grid_lines() else GB.show_midi_grid() end
    GB.adapt(c)
    GB.start_service()
  end
  GB.refresh_toggles(c)
  return true
end

-- choosing the mode that is already active switches back to fixed
function GB.toggle_mult(c, m)
  if m ~= 0 and GB.mult(c) == m then m = 0 end
  return GB.apply_mult(c, m)
end

-- dir > 0 : wider (Narrowest -> Widest)
function GB.step_adaptive(c, dir)
  local m = GB.mult(c)
  if m == -1 then m = 3 end
  if m <= 0 then return false end
  if m == 6 then m = 5 end
  m = GB.clamp(m + (dir > 0 and 1 or -1), 1, 5)
  if m == 5 then m = 6 end
  GB.apply_mult(c, m)
  return true
end

function GB.step(c, dir)
  if GB.is_adaptive(c) then return GB.step_adaptive(c, dir) end
  return GB.step_fixed(c, dir)
end

---------------------------------------------------------------- adapting the grid to the zoom
local function spacing_for(c)
  local m = GB.mult(c)
  local sp = c == "midi" and 15 or GB.min_spacing() -- MIDI editor: fixed 15 px
  if m == -1 then
    return (GB.custom_spacing(c) or sp) + 1        -- grid line of 1 px
  end
  return sp * m + m
end

local function adapt_division(c, measure_px, grid_div)
  local max_grid = measure_px / spacing_for(c)
  local grid = 1 / grid_div
  local f = GB.divisor(c)
  local exp = math.log(max_grid / grid, f)
  local new_div = 1 / (grid * f ^ math.floor(exp))
  local mn, mx = GB.limits(c)
  if new_div < mn and new_div < grid_div then return nil end
  if new_div > mx and new_div > grid_div then return nil end
  if new_div ~= new_div or new_div == math.huge or new_div <= 0 then return nil end
  return new_div
end

local function adapt_arrange()
  local zoom = r.GetHZoomLevel()
  local t0, t1 = r.GetSet_ArrangeView2(0, false, 0, 0)
  local _, _, _, b0 = r.TimeMap2_timeToBeats(0, t0)
  local _, _, _, b1 = r.TimeMap2_timeToBeats(0, t1)
  local measures = (b1 - b0) / 4
  if measures <= 0 then return end
  local measure_px = (t1 - t0) * zoom / measures
  local d, sw, amt = GB.get_grid()
  local nd = adapt_division("arrange", measure_px, d)
  if nd then GB.set_arrange_div(nd, sw, amt) end
end

local function take_chunk(take, chunk)
  if not chunk then
    local item = r.GetMediaItemTake_Item(take)
    chunk = select(2, r.GetItemStateChunk(item, "", false))
  end
  local tk = r.GetMediaItemTakeInfo_Value(take, "IP_TAKENUMBER")
  local s, e = 0, 0
  for _ = 0, tk do
    s = e
    e = chunk:find("\nTAKE[%s\n]", s + 1)
  end
  return chunk:sub(s, e)
end
GB.take_chunk = take_chunk

function GB.chunk_hzoom(chunk) return chunk:match("CFGEDITVIEW (.-) (.-) ") end

local function chunk_timebase(chunk)
  return tonumber(chunk:match("CFGEDIT " .. (".- "):rep(18) .. "(.-) "))
end

local function midi_view(hwnd)
  local take = r.MIDIEditor_GetTake(hwnd)
  if not take or not r.ValidatePtr(take, "MediaItem_Take*") then return end
  local ppq2time = r.MIDI_GetProjTimeFromPPQPos
  local chunk = take_chunk(take)
  local start_ppq, hz = GB.chunk_hzoom(chunk)
  start_ppq, hz = tonumber(start_ppq), tonumber(hz)
  if not start_ppq or not hz then return end
  local tb = chunk_timebase(chunk) or 0 -- 0 beats (proj), 1 synced, 2 time, 4 beats (source)
  local end_ppq, t0, t1

  if r.JS_Window_FindChildByID then
    local view = r.JS_Window_FindChildByID(hwnd, 0x3E9)
    local _, w = r.JS_Window_GetClientSize(view)
    if tb == 0 or tb == 4 then end_ppq = start_ppq + w / hz
    else
      t0 = ppq2time(take, start_ppq)
      t1 = t0 + w / hz
    end
  else
    -- without js_ReaScriptAPI: scroll right and back to measure the view
    r.PreventUIRefresh(1)
    if tb == 1 then r.MIDIEditor_OnCommand(hwnd, 40640) end
    r.MIDIEditor_OnCommand(hwnd, 40141)
    end_ppq = tonumber((GB.chunk_hzoom(take_chunk(take))))
    if start_ppq > 0 then
      r.MIDIEditor_OnCommand(hwnd, 40140)
    elseif end_ppq then
      local p0, p1 = ppq2time(take, start_ppq), ppq2time(take, end_ppq)
      local f = tb == 2 and 0.97087377 or 0.943396226415
      local area = (p1 - p0) * f
      local center = p0 + (p1 - p0) / 2
      local s0, s1 = r.GetSet_LoopTimeRange(false, true, 0, 0, false)
      r.GetSet_LoopTimeRange(true, true, center - area / 2, center + area / 2, false)
      r.MIDIEditor_OnCommand(hwnd, 40726)
      r.GetSet_LoopTimeRange(true, true, s0, s1, false)
    end
    if tb == 1 then r.MIDIEditor_OnCommand(hwnd, 40640) end
    r.PreventUIRefresh(-1)
    if not end_ppq then return end
  end

  t0 = t0 or ppq2time(take, start_ppq)
  t1 = t1 or ppq2time(take, end_ppq)
  if t1 <= t0 then return end
  if tb == 0 or tb == 4 then
    hz = (end_ppq - start_ppq) * hz / (t1 - t0)
  end
  return t0, t1, hz
end

local NOTE_LEN = {
  { id = 41081, div = 1 }, { id = 41079, div = 1 / 2 }, { id = 41076, div = 1 / 4 },
  { id = 41073, div = 1 / 8 }, { id = 41070, div = 1 / 16 }, { id = 41068, div = 1 / 32 },
  { id = 41064, div = 1 / 64 }, { id = 41062, div = 1 / 128 },
}

local function adapt_midi()
  local hwnd = r.MIDIEditor_GetActive()
  if not hwnd then return end
  local t0, t1, hz = midi_view(hwnd)
  if not t0 then return end
  local _, _, _, b0 = r.TimeMap2_timeToBeats(0, t0)
  local _, _, _, b1 = r.TimeMap2_timeToBeats(0, t1)
  local measures = (b1 - b0) / 4
  if measures <= 0 then return end
  local measure_px = (t1 - t0) * hz / measures
  local take = r.MIDIEditor_GetTake(hwnd)
  local qn, swing, note_len = r.MIDI_GetGrid(take)
  local nd = adapt_division("midi", measure_px, qn)
  if not nd then return end
  r.SetMIDIEditorGrid(0, nd)
  if swing ~= 0 then r.MIDIEditor_OnCommand(hwnd, M.SWING) end

  -- keep the length of the next inserted note when it follows the grid
  if note_len == 0 and nd ~= qn / 4 and r.GetToggleCommandStateEx(32060, 40479) == 1 then
    local straight = qn / 4
    local found
    for _, cmd in ipairs(NOTE_LEN) do
      if cmd.div == straight or cmd.div == straight * 3 / 2 or cmd.div == straight * 2 / 3 then found = cmd end
    end
    if not found then return end
    r.MIDIEditor_OnCommand(hwnd, found.id)
    if r.GetToggleCommandStateEx(32060, M.TRIPLET) == 1 then r.MIDIEditor_OnCommand(hwnd, 41713)
    elseif r.GetToggleCommandStateEx(32060, M.DOTTED) == 1 then r.MIDIEditor_OnCommand(hwnd, 41712)
    else r.MIDIEditor_OnCommand(hwnd, 41711) end
  end
end

-- adapts the grid of a context to its current zoom (nothing when fixed / hidden)
function GB.adapt(c)
  local m = GB.mult(c)
  if m == 0 then return end
  if c == "midi" then
    if r.GetToggleCommandStateEx(32060, M.GRID) == 0 then return end
    adapt_midi()
  else
    if GB.mult("midi") ~= 0 and GB.synced() and r.MIDIEditor_GetActive() then return end
    if r.GetToggleCommandState(A.GRID_LINES) == 0 then return end
    if GB.is_frame() or GB.is_measure() then return end
    adapt_arrange()
  end
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

---------------------------------------------------------------- background service
function GB.service_alive()
  local t = tonumber(r.GetExtState(GB.RT, "svc_hb"))
  return t ~= nil and r.time_precise() - t < 1.0
end

function GB.any_adaptive() return GB.mult("arrange") ~= 0 or GB.mult("midi") ~= 0 end

function GB.start_service()
  if not GB.any_adaptive() or GB.service_alive() then return end
  -- launched less than 2 s ago: do not launch it twice
  local t = tonumber(r.GetExtState(GB.RT, "svc_launch"))
  if t and r.time_precise() - t < 2 then return end
  r.SetExtState(GB.RT, "svc_launch", tostring(r.time_precise()), false)
  GB.launch("service")
end

-- state kept by the service between two cycles
function GB.service_new()
  local S = {}
  local is_win = r.GetOS():match("Win") ~= nil
  local has_js = r.JS_Window_FromPoint ~= nil
  local tip_delay = 0
  if is_win then
    tip_delay = select(2, r.get_config_var_string("tooltipdelay"))
    tip_delay = (tonumber(tip_delay) or 200) / 1000 * (has_js and 2 or 5)
  end

  local function arrange()
    if r.GetToggleCommandState(A.GRID_LINES) ~= 1 then return end
    if GB.is_frame() or GB.is_measure() then return end
    local z = r.GetHZoomLevel()
    if S.hz ~= z or S.force then
      S.hz = z
      GB.adapt("arrange")
    end
  end

  local function midi()
    local now = r.time_precise()
    local hwnd = S.hwnd
    if not S.hwnd_t or now > S.hwnd_t + 0.2 then
      S.hwnd_t = now
      hwnd = r.MIDIEditor_GetActive()
    elseif hwnd and not r.ValidatePtr(hwnd, "HWND*") then
      hwnd = r.MIDIEditor_GetActive()
    end
    if not hwnd then S.hwnd = nil return end
    S.hwnd = hwnd

    local take = S.take
    if not take or now > (S.take_t or 0) + 0.2 or not r.ValidatePtr(take, "MediaItem_Take*") then
      S.take_t = now
      take = r.MIDIEditor_GetTake(hwnd)
      if take and not r.ValidatePtr(take, "MediaItem_Take*") then take = nil end
    end
    if not take then S.take = nil return end
    S.take = take
    local item = r.GetMediaItemTake_Item(take)
    if not item then return end

    -- Windows: reading the item chunk too often blocks the channel combobox and tooltips
    if is_win then
      local x, y = r.GetMousePosition()
      local combo, hover_hwnd, hover_id = false, nil, nil
      if has_js then
        hover_hwnd = r.JS_Window_FromPoint(x, y)
        hover_id = r.ValidatePtr(hover_hwnd, "HWND*") and r.JS_Window_GetLong(hover_hwnd, "ID")
        if hover_id == 1000 then
          local fh = r.JS_Window_GetFocus()
          local fid = r.ValidatePtr(fh, "HWND*") and r.JS_Window_GetLong(fh, "ID")
          if fid == 1006 and r.JS_Window_IsChild(hwnd, fh) then combo = true end
        end
      end
      if combo then
        S.t = now - 0.05
      elseif x ~= S.mx or y ~= S.my then
        S.mx, S.my, S.t = x, y, nil
      elseif has_js then
        local tip = r.JS_Window_GetTitle(r.GetTooltipWindow())
        if tip ~= "" then S.t = now - 0.05
        elseif hover_id == 1001 and r.JS_Window_IsChild(hwnd, hover_hwnd) then S.t = nil end
      end
    end
    if S.t and now < S.t + tip_delay then return end
    S.t = now

    local _, chunk = r.GetItemStateChunk(item, "", false)
    if chunk == S.chunk and not S.force then return end
    S.chunk = chunk
    local _, mhz = GB.chunk_hzoom(take_chunk(take, chunk))
    if S.mhz ~= mhz or S.force then
      S.mhz = mhz
      GB.adapt("midi")
    end
  end

  -- returns false when the service is not needed any more
  return function()
    local ma, mm = GB.mult("arrange"), GB.mult("midi")
    if ma == 0 and mm == 0 then return false end
    -- a mode change made elsewhere forces a new adaptation
    local key = ma .. "|" .. mm
    S.force = S.key ~= key
    S.key = key
    if ma ~= 0 then arrange() end
    if mm ~= 0 then midi() end
    return true
  end
end

---------------------------------------------------------------- toolbar states of the adaptive actions
GB.ACTION_MULT = {
  ["Adaptive off (fixed)"] = 0, ["Adaptive narrowest"] = 1, ["Adaptive narrow"] = 2,
  ["Adaptive medium"] = 3, ["Adaptive wide"] = 4, ["Adaptive widest"] = 6, ["Adaptive custom"] = -1,
}

function GB.register_toggle(c, m)
  local _, _, _, cmd = r.get_action_context()
  if not cmd or cmd <= 0 then return end
  local n = r.ReverseNamedCommandLookup(cmd)
  local id = (n and n ~= "") and ("_" .. n) or tostring(cmd)
  local k = "tb_" .. c .. "_" .. m
  if r.GetExtState(GB.S, k) ~= id then GB.set(k, id) end
end

function GB.refresh_toggles(c)
  local m = GB.mult(c)
  local sec = c == "midi" and 32060 or 0
  for _, v in pairs(GB.ACTION_MULT) do
    local id = r.GetExtState(GB.S, "tb_" .. c .. "_" .. v)
    if id ~= "" then
      local cmd = tonumber(id) or r.NamedCommandLookup(id)
      if cmd and cmd > 0 then
        r.SetToggleCommandState(sec, cmd, v == m and 1 or 0)
        r.RefreshToolbar2(sec, cmd)
      end
    end
  end
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

function GB.launch(which)
  local path = GB.ROOT .. GB.FILES[which]
  local id = r.GetExtState(GB.S, "cmd_" .. which)
  local cmd = 0
  if id ~= "" then cmd = tonumber(id) or r.NamedCommandLookup(id) or 0 end
  if cmd == 0 and r.file_exists(path) then cmd = r.AddRemoveReaScript(true, 0, path, true) or 0 end
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
  local block = "-- >>> ReNo Mellow Grid Buddy (adaptive service and Display)\n"
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

  local m = GB.ACTION_MULT[name]
  if m ~= nil then
    GB.register_toggle(c, m)
    if c == "midi" and not GB.midi_editor() then GB.refresh_toggles(c) return GB.no_midi() end
    GB.toggle_mult(c, m)
    return
  end

  -- one-shot actions: toolbar icon always off
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0) r.RefreshToolbar2(sec, cmd) end
  if c == "midi" and not GB.midi_editor() then return GB.no_midi() end
  local rev = GB.flag("wheel_rev", false) and -1 or 1
  local wider = (val or 0) * rev < 0
  if name == "Adjust grid (mousewheel)" then GB.step(c, wider and 1 or -1)
  elseif name == "Adjust fixed grid (mousewheel)" then
    if GB.is_adaptive(c) then GB.cset(c, "mult", 0) GB.refresh_toggles(c) end
    GB.step_fixed(c, wider and 1 or -1)
  elseif name == "Wider grid" then
    if GB.is_adaptive(c) then GB.step_adaptive(c, 1) else GB.step_fixed(c, 1) end
  elseif name == "Narrower grid" then
    if GB.is_adaptive(c) then GB.step_adaptive(c, -1) else GB.step_fixed(c, -1) end
  elseif name == "Adapt grid to zoom" then
    if GB.is_adaptive(c) then GB.adapt(c)
    else
      -- one-shot: adapts with the medium size and stays fixed
      GB.cset(c, "mult", 3) GB.adapt(c) GB.cset(c, "mult", 0)
    end
  elseif name == "Toggle swing" then GB.set_type(c, "swing")
  end
end

return GB
