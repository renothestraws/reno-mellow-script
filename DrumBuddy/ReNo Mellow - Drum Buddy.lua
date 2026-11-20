-- @description ReNo Mellow - Drum Buddy
-- @author ReNo Mellow
-- @version 1.3
-- @about Fills de batterie par profils de batteurs : 16 chops par batteur (sticking par groupes), insertion à la grille de l'éditeur MIDI
-- @changelog « Kick + crash » après le fill désactivé par défaut chez Charlie, Mike et Buddie (et les nouveaux batteurs) : Again et Vary ne sont plus perturbés
-- @provides
--   [main] ReNo Mellow - Drum Buddy - Display.lua

-- Requires ReaImGui (0.9 or later)

local SCRIPT_NAME = "ReNo Mellow - Drum Buddy"
local VERSION = "1.3"
local EXT = "ReNo_DrumBuddy"

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("Drum Buddy needs the ReaImGui extension.\n\nInstall it with ReaPack:\nExtensions > ReaPack > Browse packages > ReaImGui\nthen restart REAPER.", SCRIPT_NAME, 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'
local ctx

---------------------------------------------------------------------------
-- Drum pieces (logical), short names and General MIDI defaults
-- The order is the order of the mouse wheel in the orchestration row
---------------------------------------------------------------------------
local PIECES = {
  { key = "snare",      ab = "S",  grp = "Snare",  name = "Snare center",       gm = 38 },
  { key = "rimshot",    ab = "RS", grp = "Snare",  name = "Snare rimshot",      gm = 40 },
  { key = "sidestick",  ab = "SS", grp = "Snare",  name = "Side stick",         gm = 37 },
  { key = "snare_edge", ab = "SE", grp = "Snare",  name = "Snare edge",         gm = -1 },
  { key = "tom1",       ab = "T1", grp = "Toms",   name = "Tom 1",              gm = 50 },
  { key = "tom2",       ab = "T2", grp = "Toms",   name = "Tom 2",              gm = 48 },
  { key = "tom3",       ab = "T3", grp = "Toms",   name = "Tom 3",              gm = 47 },
  { key = "tom4",       ab = "T4", grp = "Toms",   name = "Tom 4",              gm = 45 },
  { key = "tom5",       ab = "T5", grp = "Toms",   name = "Tom 5",              gm = 43 },
  { key = "tom6",       ab = "T6", grp = "Toms",   name = "Tom 6",              gm = 41 },
  { key = "hh_closed",  ab = "H",  grp = "Hi-hat", name = "Hi-hat closed",      gm = 42 },
  { key = "hh_shank",   ab = "HS", grp = "Hi-hat", name = "Hi-hat closed edge", gm = -1 },
  { key = "hh_half",    ab = "HM", grp = "Hi-hat", name = "Hi-hat half open",   gm = -1 },
  { key = "hh_open",    ab = "HO", grp = "Hi-hat", name = "Hi-hat open",        gm = 46 },
  { key = "hh_pedal",   ab = "HP", grp = "Hi-hat", name = "Hi-hat pedal",       gm = 44 },
  { key = "hh_splash",  ab = "HF", grp = "Hi-hat", name = "Hi-hat foot splash", gm = -1 },
  { key = "ride",       ab = "R",  grp = "Ride",   name = "Ride bow",           gm = 51 },
  { key = "ride_bell",  ab = "RB", grp = "Ride",   name = "Ride bell",          gm = 53 },
  { key = "ride_edge",  ab = "RE", grp = "Ride",   name = "Ride edge",          gm = 59 },
  { key = "crash1",     ab = "C1", grp = "Crash",  name = "Crash 1",            gm = 49 },
  { key = "crash2",     ab = "C2", grp = "Crash",  name = "Crash 2",            gm = 57 },
  { key = "crash3",     ab = "C3", grp = "Crash",  name = "Crash 3",            gm = -1 },
  { key = "china",      ab = "CH", grp = "Crash",  name = "China",              gm = 52 },
  { key = "splash",     ab = "SP", grp = "Crash",  name = "Splash",             gm = 55 },
  { key = "stack",      ab = "ST", grp = "Crash",  name = "Stack",              gm = -1 },
  { key = "cowbell",    ab = "CB", grp = "Perc",   name = "Cowbell",            gm = 56 },
  { key = "tambourine", ab = "TB", grp = "Perc",   name = "Tambourine",         gm = 54 },
  { key = "clap",       ab = "CL", grp = "Perc",   name = "Clap",               gm = 39 },
  { key = "kick",       ab = "K",  grp = "Kick",   name = "Kick",               gm = 36 },
  { key = "kick2",      ab = "K2", grp = "Kick",   name = "Kick 2",             gm = 35 },
}
local PIECE_INDEX = {}
for i, p in ipairs(PIECES) do PIECE_INDEX[p.key] = i end
local GROUPS = { "Snare", "Toms", "Hi-hat", "Ride", "Crash", "Perc" }
local REST = "rest"   -- silent stroke: no note is inserted
local TOMS = { "tom1", "tom2", "tom3", "tom4", "tom5", "tom6" }
local CYMBALS = { "hh_closed", "ride", "crash1", "crash2" }

---------------------------------------------------------------------------
-- Presets (rudiments and groupings)
-- Token syntax: R / L = hands, K = kick, ">" = accent, "-" = ghost,
-- prefix f = flam, d = drag, "|" = new group
---------------------------------------------------------------------------
local FAMILIES = {
  { name = "Rolls", list = {
    { "Single stroke roll", "R> L R L" },
    { "Double stroke roll", "R R L L" },
    { "Triple stroke roll", "R R R L L L" },
    { "Five stroke roll",   "R R L L R> | L L R R L>" },
    { "Six stroke roll",    "R> L L R R L>" },
    { "Seven stroke roll",  "R R L L R R L>" },
  } },
  { name = "Diddles", list = {
    { "Paradiddle",          "R> L R R | L> R L L" },
    { "Double paradiddle",   "R> L R L R R | L> R L R L L" },
    { "Triple paradiddle",   "R> L R L R L R R | L> R L R L R L L" },
    { "Paradiddle-diddle",   "R> L R R L L" },
    { "Inverted paradiddle", "R> L L R | L> R R L" },
  } },
  { name = "Flams", list = {
    { "Flam",               "fR | fL" },
    { "Flam accent",        "fR> L R | fL> R L" },
    { "Flam tap",           "fR R | fL L" },
    { "Flam paradiddle",    "fR L R R | fL R L L" },
    { "Swiss army triplet", "fR R L | fR R L" },
    { "Pataflafla",         "fR L R fL" },
  } },
  { name = "Drags", list = {
    { "Single drag tap",  "dR L> | dL R>" },
    { "Double drag tap",  "dR dR L> | dL dL R>" },
    { "Lesson 25",        "dR L R> | dL R L>" },
    { "Single ratamacue", "dR L R L> | dL R L R>" },
    { "Drag paradiddle",  "R> dR L R R | L> dL R L L" },
  } },
  { name = "Groupings", list = {
    { "4+4+4+4",       sizes = { 4 } },
    { "3+3+2",         sizes = { 3, 3, 2 } },
    { "3+3+3+3+4",     sizes = { 3, 3, 3, 3, 4 } },
    { "5+5+6",         sizes = { 5, 5, 6 } },
    { "6+6+4",         sizes = { 6, 6, 4 } },
    { "2+2+3",         sizes = { 2, 2, 3 } },
    { "Custom",        custom = true },
  } },
}

-- Length of a Random fill (the strokes follow the grid of the MIDI editor)
local LENGTHS = {
  { "1 beat", 1, "beat" }, { "2 beats", 2, "beat" }, { "1 bar", 1, "bar" }, { "2 bars", 2, "bar" },
}

---------------------------------------------------------------------------
-- Drummer profile (S = how he plays) and global settings (G)
---------------------------------------------------------------------------
local PROFILE_DEFAULT = {
  vacc = 120, vnorm = 90, vghost = 40, flam_ms = 25, drag_ms = 30,
  hum_vel = 8, hum_time = 6, feel = 0, density = 40,
  crash = false, crash_piece = "crash1", rand_cym = false,
}
local P_NUM = { "vacc", "vnorm", "vghost", "flam_ms", "drag_ms", "hum_vel", "hum_time", "feel", "density" }
local P_BOOL = { "crash", "rand_cym" }
local S = {}
for k, v in pairs(PROFILE_DEFAULT) do S[k] = v end

local G = { fam = 2, rud = 1, rlen = 3, replace = false }

local function load_global()
  local v = tonumber(reaper.GetExtState(EXT, "fam")); if v then G.fam = math.floor(v) end
  v = tonumber(reaper.GetExtState(EXT, "rud")); if v then G.rud = math.floor(v) end
  v = tonumber(reaper.GetExtState(EXT, "rlen")); if v then G.rlen = math.floor(v) end
  G.replace = reaper.GetExtState(EXT, "replace") == "1"
  if not FAMILIES[G.fam] then G.fam = 1 end
  if not FAMILIES[G.fam].list[G.rud] then G.rud = 1 end
  if not LENGTHS[G.rlen] then G.rlen = 3 end
end

local function save_global()
  reaper.SetExtState(EXT, "fam", tostring(G.fam), true)
  reaper.SetExtState(EXT, "rud", tostring(G.rud), true)
  reaper.SetExtState(EXT, "rlen", tostring(G.rlen), true)
  reaper.SetExtState(EXT, "replace", G.replace and "1" or "0", true)
end

---------------------------------------------------------------------------
-- Drum maps
---------------------------------------------------------------------------
local function gm_map()
  local m = {}
  for _, p in ipairs(PIECES) do m[p.key] = p.gm end
  return m
end

local function map_to_string(m)
  local t = {}
  for _, p in ipairs(PIECES) do t[#t + 1] = p.key .. "=" .. tostring(m[p.key] or -1) end
  return table.concat(t, ";")
end

local function map_from_string(s)
  if not s or s == "" then return nil end
  local m, found = {}, false
  for _, p in ipairs(PIECES) do m[p.key] = -1 end
  for k, v in s:gmatch("([%w_]+)=(%-?%d+)") do
    if PIECE_INDEX[k] then m[k] = tonumber(v); found = true end
  end
  if found then return m end
  return nil
end

local function has(n, s) return n:find(s, 1, true) ~= nil end
local function word(n, w) return n:find("%f[%w]" .. w .. "%f[%W]") ~= nil end

local function classify(n)
  if has(n, "choke") or has(n, "grab") or has(n, "stop") or has(n, "mute") then return nil end
  local hat = has(n, "hat") or word(n, "hh") or has(n, "charley") or has(n, "charleston")
  if hat then
    if has(n, "pedal") or has(n, "foot") or has(n, "pied") or has(n, "chick") or has(n, "splash") then
      if has(n, "splash") then return "hh_splash" end
      return "hh_pedal"
    end
    if has(n, "open") or has(n, "ouvert") then
      if has(n, "half") or has(n, "1/2") or has(n, "semi") or has(n, "mid") or has(n, "loose") then return "hh_half" end
      return "hh_open"
    end
    if has(n, "shank") or has(n, "edge") then return "hh_shank" end
    return "hh_closed"
  end
  if has(n, "ride") then
    if has(n, "bell") or has(n, "cloche") or has(n, "cup") then return "ride_bell" end
    if has(n, "edge") or has(n, "crash") then return "ride_edge" end
    return "ride"
  end
  if has(n, "stack") then return "stack" end
  if has(n, "crash") then return "crash" end
  if has(n, "china") then return "china" end
  if has(n, "splash") then return "splash" end
  if has(n, "cowbell") then return "cowbell" end
  if has(n, "tamb") then return "tambourine" end
  if has(n, "clap") then return "clap" end
  if has(n, "side") or has(n, "cross") or has(n, "rim click") or has(n, "rimclick") then return "sidestick" end
  if has(n, "kick") or has(n, "bass drum") or has(n, "bassdrum") or has(n, "grosse caisse")
    or word(n, "bd") or word(n, "kd") or word(n, "gc") then return "kick" end
  if has(n, "tom") or has(n, "floor") then
    if has(n, "rim") then return nil end
    return "tom"
  end
  local snare = has(n, "snare") or has(n, "caisse claire") or word(n, "sd") or word(n, "cc")
  if snare then
    if has(n, "rim") then return "rimshot" end
    if has(n, "edge") then return "snare_edge" end
    if has(n, "flam") or has(n, "roll") or has(n, "ghost") or has(n, "drag") or has(n, "buzz")
      or has(n, "off") or has(n, "brush") or has(n, "wire") then return nil end
    return "snare"
  end
  if has(n, "rimshot") then return "rimshot" end
  return nil
end

local function order_key(n, pitch, is_tom)
  local k = 50
  local d = n:match("(%d+)")
  if d then
    k = tonumber(d)
  elseif is_tom then
    if has(n, "high") or word(n, "hi") then k = 1
    elseif has(n, "mid") then k = 2
    elseif has(n, "low") then k = 3 end
  end
  if is_tom and (has(n, "floor") or has(n, "basse")) then k = k + 100 end
  return k * 1000 + (127 - pitch)
end

local function note_name(track, pitch, chan)
  if not track or not reaper.GetTrackMIDINoteNameEx then return nil end
  local name = reaper.GetTrackMIDINoteNameEx(0, track, pitch, chan or 0)
  if (not name or name == "") and chan and chan ~= 0 then
    name = reaper.GetTrackMIDINoteNameEx(0, track, pitch, 0)
  end
  if name == "" then return nil end
  return name
end

-- base: the current map; a piece keeps its note when no note name matches it
local function detect_map(track, chan, base)
  local m = {}
  for _, p in ipairs(PIECES) do m[p.key] = base and base[p.key] or -1 end
  local best, toms, crashes, kicks, named = {}, {}, {}, {}, 0
  for pitch = 0, 127 do
    local name = note_name(track, pitch, chan)
    if name then
      named = named + 1
      local n = name:lower()
      local c = classify(n)
      if c == "tom" then
        toms[#toms + 1] = { p = pitch, k = order_key(n, pitch, true) }
      elseif c == "crash" then
        crashes[#crashes + 1] = { p = pitch, k = order_key(n, pitch, false) + #n }
      elseif c == "kick" then
        kicks[#kicks + 1] = { p = pitch, k = #n * 1000 + order_key(n, pitch, false) % 1000 }
      elseif c then
        if not best[c] or #n < best[c].len then best[c] = { p = pitch, len = #n } end
      end
    end
  end
  for k, v in pairs(best) do m[k] = v.p end
  table.sort(toms, function(a, b) return a.k < b.k end)
  for i = 1, math.min(#TOMS, #toms) do m[TOMS[i]] = toms[i].p end
  table.sort(crashes, function(a, b) return a.k < b.k end)
  if crashes[1] then m.crash1 = crashes[1].p end
  if crashes[2] then m.crash2 = crashes[2].p end
  if crashes[3] then m.crash3 = crashes[3].p end
  table.sort(kicks, function(a, b) return a.k < b.k end)
  if kicks[1] then m.kick = kicks[1].p end
  if kicks[2] then m.kick2 = kicks[2].p end
  local found = 0
  for _ in pairs(best) do found = found + 1 end
  found = found + math.min(#TOMS, #toms) + math.min(3, #crashes) + math.min(2, #kicks)
  return m, found, named
end


---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local map = gm_map()        -- drum map of the current drummer
local editor, take, chan = nil, nil, 0
local cur_track = nil
-- A fill is a list of groups:
-- { strokes = { { h = "R"/"L"/"K", g = nil/"f"/"d", dyn = "norm"/"acc"/"ghost", piece = key,
--                  hand = hand of a kick stroke before it became K } },
--   mi = motif index in the library (0 = from a preset), piece = piece of the group }
local groups = {}           -- fill of the Editor
local fill_name = nil       -- its name
local status, status_err = "", false
local learn_key, learn_seq = nil, 0
local learn_row, learn_sel = -1, ""   -- MIDI editor state when Learn started
local pending = nil
local menu_g, menu_s = nil, nil
local select_tab = nil      -- tab to show on the next frame
local custom_buf = reaper.GetExtState(EXT, "custom")
if custom_buf == "" then custom_buf = "3+3+2" end

-- current drummer: chops[1..16] = { name = , data = serialized groups } or nil
local drummer = { name = "", file = "", chops = {} }
local drummers = {}         -- { name = , file = } found in the drummers folder
local profile_dirty, dirty_time = false, 0

math.randomseed(os.time())

local function set_status(msg, err) status = msg; status_err = err and true or false end
local function is_mapped(key) return (map[key] or -1) >= 0 end

local function parse(s)
  local t = {}
  for tok in s:gmatch("%S+") do
    local g = nil
    local c = tok:sub(1, 1)
    if c == "f" or c == "d" then g = c; tok = tok:sub(2) end
    local h = tok:sub(1, 1):upper()
    if h == "R" or h == "L" or h == "K" then
      local dyn = "norm"
      if tok:find(">", 1, true) then dyn = "acc" elseif tok:find("-", 1, true) then dyn = "ghost" end
      if h == "K" then g = nil end
      t[#t + 1] = { h = h, g = g, dyn = dyn, piece = (h == "K") and "kick" or "snare" }
    end
  end
  return t
end

-- Motif library: stickings offered for a group of n strokes (click on the group header)
local LIB = {
  [1] = { "R>", "L>", "K", "fR>", "dR>" },
  [2] = { "R> L", "R R", "R> K", "K R>", "fR> L", "dR> L" },
  [3] = { "R> L L", "R> L R", "R> L K", "R> R L", "R> K K", "fR> L R" },
  [4] = { "R> L R L", "R> L R R", "R> R L L", "R> L L K", "R> L R K", "R> K R K" },
  [5] = { "R> L R L K", "R> L R R L", "R> L L R K", "R> R L L K", "R> L R L R" },
  [6] = { "R> L R L R L", "R> L R R L L", "R> L L R R L>", "R> L R L K K", "R> L K R L K", "R> L R L R R" },
  [7] = { "R> L R L R R L", "R> L R L R L K", "R> L L R L L K" },
  [8] = { "R> L R R L> R L L", "R> L R L R L R L", "R> L R L R L K K", "R> L L R R L L K" },
}

local function motifs_for(n)
  if LIB[n] then return LIB[n] end
  local t = {}
  for i = 1, n do t[i] = (i % 2 == 1) and "R" or "L" end
  t[1] = "R>"
  local a = table.concat(t, " ")
  t[n] = "K"
  return { a, table.concat(t, " ") }
end

local function parse_sizes(str)
  local t = {}
  for d in str:gmatch("%d+") do
    local n = tonumber(d)
    if n and n >= 1 and n <= 16 then t[#t + 1] = n end
  end
  if #t == 0 then t = { 4 } end
  return t
end

---------------------------------------------------------------------------
-- Grid of the MIDI editor: one stroke = one grid step
---------------------------------------------------------------------------
local function grid_qn()
  local g = take and reaper.MIDI_GetGrid(take) or 0
  if not g or g <= 0 then g = 0.25 end
  return g
end

-- steps per quarter note (0 if the grid does not divide the quarter note)
local function grid_spb()
  local s = 1 / grid_qn()
  local r = math.floor(s + 0.5)
  if r >= 1 and math.abs(s - r) < 0.01 then return r end
  return 0
end

local function grid_name()
  local d = 4 / grid_qn()                  -- 1/16 -> 16
  local r = math.floor(d + 0.5)
  if math.abs(d - r) < 0.01 then
    local t = d * 2 / 3                    -- triplets: 1/16T -> 24 * 2/3 = 16
    local rt = math.floor(t + 0.5)
    if r % 3 == 0 and math.abs(t - rt) < 0.01 then return "1/" .. rt .. "T" end
    return "1/" .. r
  end
  return string.format("%.3f QN", grid_qn())
end

local function fmt_beats(q)
  if math.abs(q - math.floor(q + 0.5)) < 0.01 then
    local n = math.floor(q + 0.5)
    return n .. (n == 1 and " beat" or " beats")
  end
  return string.format("%.2f beats", q)
end

-- Length of a Random fill in quarter notes, at the edit cursor
local function length_qn(li)
  local cursor = reaper.GetCursorPosition()
  local num, denom = reaper.TimeMap_GetTimeSigAtTime(0, cursor)
  local beat_qn = 4 / denom
  local L = LENGTHS[li] or LENGTHS[3]
  return L[2] * ((L[3] == "bar") and (num * beat_qn) or beat_qn)
end

---------------------------------------------------------------------------
-- Presets -> groups
---------------------------------------------------------------------------
local function preset_templates(fam, rud)
  local f = FAMILIES[fam]
  local pr = f and f.list[rud]
  local t = {}
  if not pr then return t end
  if pr.sizes or pr.custom then
    local sizes = pr.custom and parse_sizes(custom_buf) or pr.sizes
    for _, n in ipairs(sizes) do t[#t + 1] = { s = motifs_for(n)[1], mi = 1 } end
  else
    for part in (pr[2] .. "|"):gmatch("([^|]*)|") do
      if part:find("%S") then t[#t + 1] = { s = part, mi = 0 } end
    end
  end
  return t
end

local function new_group(str, mi)
  return { strokes = parse(str), mi = mi, piece = "snare" }
end

local function count_strokes(list)
  local n = 0
  for _, g in ipairs(list) do n = n + #g.strokes end
  return n
end
local function total_strokes() return count_strokes(groups) end

-- n = nil: one pass of the preset; n = number of strokes: repeated, last group cut
local function groups_from_preset(fam, rud, n)
  local tpl = preset_templates(fam, rud)
  local out = {}
  if #tpl == 0 then return out end
  local target = n
  if not target then
    target = 0
    for _, t in ipairs(tpl) do target = target + #parse(t.s) end
  end
  local total, k = 0, 0
  while total < target do
    k = k + 1
    local t = tpl[((k - 1) % #tpl) + 1]
    local g = new_group(t.s, t.mi)
    if #g.strokes == 0 then break end
    if total + #g.strokes > target then
      for i = #g.strokes, target - total + 1, -1 do table.remove(g.strokes, i) end
      g.mi = 0
    end
    total = total + #g.strokes
    out[#out + 1] = g
  end
  return out
end

-- Editor: load the selected preset
local function build_groups()
  groups = groups_from_preset(G.fam, G.rud)
  local pr = FAMILIES[G.fam] and FAMILIES[G.fam].list[G.rud]
  fill_name = pr and pr[1] or nil
end


local deserialize_groups
local function serialize_groups(src)
  local gs = {}
  for _, g in ipairs(src or groups) do
    local ss = {}
    for _, st in ipairs(g.strokes) do
      ss[#ss + 1] = table.concat({ st.h, st.g or "", st.dyn, st.piece, st.hand or "" }, ".")
    end
    gs[#gs + 1] = g.piece .. ":" .. table.concat(ss, ",")
  end
  return table.concat(gs, ";")
end

local function valid_piece(k) return k == REST or PIECE_INDEX[k] ~= nil end

deserialize_groups = function(str)
  local out = {}
  for gstr in str:gmatch("[^;]+") do
    local gp, body = gstr:match("^([%w_]+):(.*)$")
    if gp then
      local g = { strokes = {}, mi = 0, piece = valid_piece(gp) and gp or "snare" }
      for sstr in body:gmatch("[^,]+") do
        local h, gr, dyn, piece, hand = sstr:match("^(%a)%.(%a?)%.(%a+)%.([%w_]+)%.(%a?)$")
        if h then
          if not valid_piece(piece) then piece = (h == "K") and "kick" or "snare" end
          g.strokes[#g.strokes + 1] = { h = h, g = (gr ~= "") and gr or nil, dyn = dyn, piece = piece,
            hand = (hand ~= "") and hand or nil }
        end
      end
      if #g.strokes > 0 then out[#out + 1] = g end
    end
  end
  return out
end

local function clean_name(n)
  n = (n or ""):gsub("[\t\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return n
end

---------------------------------------------------------------------------
-- Group operations
---------------------------------------------------------------------------
local function opposite(h) return (h == "R") and "L" or (h == "L") and "R" or h end
local function copy_stroke(st) return { h = st.h, g = st.g, dyn = st.dyn, piece = st.piece, hand = st.hand } end

-- keep_rest = true: silent strokes stay silent
local function set_group_piece(g, key, keep_rest)
  g.piece = key
  for _, st in ipairs(g.strokes) do
    if st.h ~= "K" and not (keep_rest and st.piece == REST) then st.piece = key end
  end
end

local function set_motif(g, mi)
  local lib = motifs_for(#g.strokes)
  if mi > #lib then mi = 1 elseif mi < 1 then mi = #lib end
  g.mi = mi
  g.strokes = parse(lib[mi])
  for _, st in ipairs(g.strokes) do if st.h ~= "K" then st.piece = g.piece end end
end

local function resize_group(gi, delta)
  local g = groups[gi]
  if delta > 0 then
    local last = g.strokes[#g.strokes]
    local h = last and opposite((last.h == "K") and (last.hand or "L") or last.h) or "R"
    g.strokes[#g.strokes + 1] = { h = h, dyn = "norm", piece = g.piece }
  elseif #g.strokes > 1 then
    table.remove(g.strokes)
  end
  g.mi = 0
end

local function split_group(gi)
  local g = groups[gi]
  local n = #g.strokes
  if n < 2 then return end
  local a = math.ceil(n / 2)
  local g2 = { strokes = {}, mi = 0, piece = g.piece }
  for i = a + 1, n do g2.strokes[#g2.strokes + 1] = g.strokes[i] end
  for i = n, a + 1, -1 do table.remove(g.strokes, i) end
  g.mi = 0
  table.insert(groups, gi + 1, g2)
end

local function merge_next(gi)
  local g, nx = groups[gi], groups[gi + 1]
  if not nx then return end
  for _, st in ipairs(nx.strokes) do g.strokes[#g.strokes + 1] = st end
  g.mi = 0
  table.remove(groups, gi + 1)
end

local function copy_to_next(gi)
  local g = groups[gi]
  local c = { strokes = {}, mi = g.mi, piece = g.piece }
  for _, st in ipairs(g.strokes) do c.strokes[#c.strokes + 1] = copy_stroke(st) end
  groups[gi + 1] = c
end

local function invert_group(gi)
  for _, st in ipairs(groups[gi].strokes) do
    st.h = opposite(st.h)
    if st.hand then st.hand = opposite(st.hand) end
  end
end


---------------------------------------------------------------------------
-- Tools (all groups)
---------------------------------------------------------------------------
local function accent_first()
  for _, g in ipairs(groups) do
    for i, st in ipairs(g.strokes) do
      if st.h ~= "K" and not st.g then
        if i == 1 then st.dyn = "acc" elseif st.dyn == "acc" then st.dyn = "norm" end
      end
    end
  end
end

local function ghost_others()
  for _, g in ipairs(groups) do
    for i, st in ipairs(g.strokes) do
      if i > 1 and st.h ~= "K" and not st.g then st.dyn = "ghost" end
    end
  end
end

local function toms_by_group(up)
  local toms = {}
  for _, k in ipairs(TOMS) do if is_mapped(k) then toms[#toms + 1] = k end end
  if #toms == 0 then set_status("No tom in the drum map (Set up).", true); return end
  local ng = #groups
  for i, g in ipairs(groups) do
    local k = math.floor((i - 1) * #toms / ng) + 1
    if k > #toms then k = #toms end
    if up then k = #toms - k + 1 end
    set_group_piece(g, toms[k], true)
  end
end

local function random_by_group()
  local pool = {}
  if is_mapped("snare") then pool[#pool + 1] = "snare" end
  for _, k in ipairs(TOMS) do if is_mapped(k) then pool[#pool + 1] = k end end
  if S.rand_cym then
    for _, k in ipairs(CYMBALS) do if is_mapped(k) then pool[#pool + 1] = k end end
  end
  if #pool == 0 then set_status("Nothing to randomize: map the snare and toms first (Set up).", true); return end
  local prev, piece = nil, nil
  for _, g in ipairs(groups) do
    repeat piece = pool[math.random(#pool)] until #pool == 1 or piece ~= prev
    prev = piece
    set_group_piece(g, piece, true)
  end
end

local function all_snare()
  for _, g in ipairs(groups) do set_group_piece(g, "snare", false) end
end

---------------------------------------------------------------------------
-- Drummers: one file per drummer in Data/ReNo_DrumBuddy/drummers
-- (name, drum map, how he plays, 16 chops). One drummer per project.
---------------------------------------------------------------------------
local DATA_DIR = reaper.GetResourcePath() .. "/Data/ReNo_DrumBuddy"
local DRUM_DIR = DATA_DIR .. "/drummers"
local drum_rev_seen = ""

local function file_safe(name)
  local s = name:gsub('[\\/:%*%?"<>|%c]', "_")
  return s
end

local function unique_file(name)
  local base = file_safe(name)
  local f, i = base .. ".txt", 2
  while reaper.file_exists(DRUM_DIR .. "/" .. f) do f = base .. " " .. i .. ".txt"; i = i + 1 end
  return f
end

local function scan_drummers()
  drummers = {}
  reaper.EnumerateFiles(DRUM_DIR, -1)   -- refresh the cached folder listing
  local i = 0
  while true do
    local f = reaper.EnumerateFiles(DRUM_DIR, i)
    if not f then break end
    if f:lower():match("%.txt$") then
      local name = f:sub(1, -5)
      local h = io.open(DRUM_DIR .. "/" .. f, "r")
      if h then
        for line in h:lines() do
          local v = line:match("^name=(.*)$")
          if v then name = v; break end
        end
        h:close()
      end
      drummers[#drummers + 1] = { name = name, file = f }
    end
    i = i + 1
  end
  table.sort(drummers, function(a, b) return a.name:lower() < b.name:lower() end)
end

local function save_drummer()
  profile_dirty = false
  if drummer.file == "" then return end
  reaper.RecursiveCreateDirectory(DRUM_DIR, 0)
  local h = io.open(DRUM_DIR .. "/" .. drummer.file, "w")
  if not h then set_status("Cannot write the drummer file.", true); return end
  h:write("name=", drummer.name, "\n")
  h:write("map=", map_to_string(map), "\n")
  for _, k in ipairs(P_NUM) do h:write(k, "=", tostring(S[k]), "\n") end
  for _, k in ipairs(P_BOOL) do h:write(k, "=", S[k] and "1" or "0", "\n") end
  h:write("crash_piece=", S.crash_piece, "\n")
  for i = 1, 16 do
    local c = drummer.chops[i]
    if c then h:write("chop", i, "=", c.name, "\t", c.data, "\n") end
  end
  h:close()
  -- tell the other window (main / Display) to read the drummer again
  drum_rev_seen = tostring(reaper.time_precise())
  reaper.SetExtState(EXT, "drum_rev", drum_rev_seen, false)
end

local function touch_profile() profile_dirty = true; dirty_time = reaper.time_precise() end
local function save_map() save_drummer() end

local function load_drummer(file)
  local h = io.open(DRUM_DIR .. "/" .. file, "r")
  if not h then return false end
  for k, v in pairs(PROFILE_DEFAULT) do S[k] = v end
  map = gm_map()
  drummer = { name = file:sub(1, -5), file = file, chops = {} }
  for line in h:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "name" then
      drummer.name = v
    elseif k == "map" then
      map = map_from_string(v) or gm_map()
    elseif k == "crash_piece" then
      if PIECE_INDEX[v] then S.crash_piece = v end
    elseif k and k:match("^chop%d+$") then
      local i = tonumber(k:sub(5))
      local nm, data = v:match("^([^\t]*)\t(.*)$")
      if i and i >= 1 and i <= 16 and nm then drummer.chops[i] = { name = nm, data = data } end
    elseif k and PROFILE_DEFAULT[k] ~= nil then
      if type(PROFILE_DEFAULT[k]) == "boolean" then S[k] = (v == "1") else S[k] = tonumber(v) or S[k] end
    end
  end
  h:close()
  return true
end

local function project_drummer()
  local _, f = reaper.GetProjExtState(0, EXT, "drummer")
  return f or ""
end

local function link_project(file)
  reaper.SetProjExtState(0, EXT, "drummer", file)
  reaper.SetExtState(EXT, "last_drummer", file, true)
end

-- Every frame: follow the project (each project remembers its drummer)
-- and the changes saved by the other window
local function sync_drummer()
  local want = project_drummer()
  if want == "" or not reaper.file_exists(DRUM_DIR .. "/" .. want) then
    want = reaper.GetExtState(EXT, "last_drummer")
    if want == "" or not reaper.file_exists(DRUM_DIR .. "/" .. want) then
      if drummer.file ~= "" and reaper.file_exists(DRUM_DIR .. "/" .. drummer.file) then
        want = drummer.file
      else
        scan_drummers()
        want = drummers[1] and drummers[1].file or ""
      end
    end
  end
  local rev = reaper.GetExtState(EXT, "drum_rev")
  if want ~= "" and (want ~= drummer.file or (rev ~= drum_rev_seen and not profile_dirty)) then
    if profile_dirty and want ~= drummer.file then save_drummer() end
    drum_rev_seen = rev
    load_drummer(want)
  end
end

---------------------------------------------------------------------------
-- Factory drummers (created once; a deleted one does not come back)
-- chop = { name, { { sticking, piece of the group, pieces per stroke (optional) }, ... } }
-- pieces per stroke use the short names (S, T1, H, HO, R, RB, C1, CH...), K / K2 for kick strokes
---------------------------------------------------------------------------
local create_factory_drummer, FACTORY
do
FACTORY = {
  { name = "Charlie", style = "rock-pop",
    profile = { vacc = 115, vnorm = 90, vghost = 40, flam_ms = 25, drag_ms = 30, hum_vel = 8, hum_time = 5,
                feel = 0, density = 30, crash = false, crash_piece = "crash1", rand_cym = false },
    chops = {
      { "Snare 8",          { { "R> L R L R> L R L", "snare" } } },
      { "Snare to toms",    { { "R> L R L", "snare" }, { "R> L R L", "tom1" }, { "R> L R L", "tom2" }, { "R> L R L", "tom3" } } },
      { "Full HH accents",  { { "R> L- R L- R> L- R L-", "hh_closed", "HO H H H HO H H H" } } },
      { "Full HH kick",     { { "R L K L R L K L", "hh_closed", "H H K H H H K H" } } },
      { "Fours down",       { { "R> L R L", "tom1" }, { "R> L R L", "tom3" } } },
      { "Triplets around",  { { "R> L L", "snare" }, { "R> L L", "tom1" }, { "R> L L", "tom2" }, { "R> L L", "tom3" } } },
      { "Flam fill",        { { "fR L R L", "snare" }, { "fR L R L", "tom3" } } },
      { "RLRLKK",           { { "R> L R L K K", "snare" }, { "R> L R L K K", "tom3" } } },
      { "Snare build",      { { "R> L R L R> L R L", "snare" }, { "R> L R L R> L R L", "snare" } } },
      { "Paradiddle toms",  { { "R> L R R", "tom1" }, { "L> R L L", "tom3" } } },
      { "Doubles",          { { "R R L L", "snare" }, { "R R L L", "tom1" } } },
      { "Ride bell lift",   { { "R> L R> L R> L R> L", "snare", "RB S RB S RB S RB S" } } },
      { "3+3+2 toms",       { { "R> L L", "snare" }, { "R> L L", "tom1" }, { "R> L", "tom3" } } },
      { "HH open lift",     { { "R L R L R L R> L", "hh_closed", "H H H H H H HO H" } } },
      { "RLKK",             { { "R> L K K", "snare" }, { "R> L K K", "tom3" } } },
      { "Big ending",       { { "R> L R L", "tom1" }, { "R> L R L", "tom2" }, { "R> L R L", "tom3" }, { "R> L R L", "snare" } } },
    } },
  { name = "Mike", style = "metal",
    profile = { vacc = 127, vnorm = 110, vghost = 55, flam_ms = 15, drag_ms = 20, hum_vel = 4, hum_time = 2,
                feel = 0, density = 60, crash = false, crash_piece = "china", rand_cym = false },
    chops = {
      { "SSKK x4",          { { "R L K K", "snare" }, { "R L K K", "snare" }, { "R L K K", "snare" }, { "R L K K", "snare" } } },
      { "SSSSKK",           { { "R L R L K K", "snare" }, { "R L R L K K", "snare" }, { "R L R L", "snare" } } },
      { "Blast",            { { "R K L K R K L K", "snare", "S K S K S K S K" } } },
      { "Double kick run",  { { "K K K K K K K K", "snare", "K K2 K K2 K K2 K K2" } } },
      { "RLK toms",         { { "R> L K", "tom1" }, { "R> L K", "tom2" }, { "R> L K", "tom3" }, { "R> L K", "tom4" } } },
      { "Six stroke toms",  { { "R> L L R R L>", "tom1" }, { "R> L L R R L>", "tom3" } } },
      { "Linear RLKK",      { { "R> L K K", "snare" }, { "R> L K K", "tom1" }, { "R> L K K", "tom2" }, { "R> L K K", "tom3" } } },
      { "China accents",    { { "R> L R L", "snare", "CH S S S" }, { "R> L R L", "snare", "CH S S S" } } },
      { "Sextuplets down",  { { "R> L R L R L", "snare" }, { "R> L R L R L", "tom1" }, { "R> L R L R L", "tom3" } } },
      { "5+5+6 kicks",      { { "R> L R L K", "snare" }, { "R> L R L K", "tom1" }, { "R> L R L K K", "tom3" } } },
      { "Paradiddle kicks", { { "R> L R K", "snare" }, { "L> R L K", "tom1" } } },
      { "Doubles toms",     { { "R R L L", "tom1" }, { "R R L L", "tom2" }, { "R R L L", "tom3" }, { "R R L L", "tom4" } } },
      { "Cymbal kicks",     { { "R K L K", "snare", "C1 K CH K" }, { "R K L K", "snare", "C1 K CH K" } } },
      { "Gallop",           { { "R K K", "snare" }, { "R K K", "snare" }, { "R K K", "tom1" }, { "R K K", "tom3" } } },
      { "Swiss toms",       { { "fR R L", "tom1" }, { "fR R L", "tom3" } } },
      { "Stop ending",      { { "R> L> R> L>", "snare", "S S T1 T1" }, { "K K K K", "snare", "K K2 K K2" } } },
    } },
  { name = "Buddie", style = "jazz-gospel",
    profile = { vacc = 105, vnorm = 75, vghost = 30, flam_ms = 30, drag_ms = 35, hum_vel = 15, hum_time = 10,
                feel = 6, density = 70, crash = false, crash_piece = "crash2", rand_cym = true },
    chops = {
      { "Swing triplets",   { { "R- L- R>", "snare" }, { "R- L- R>", "snare" }, { "R- L- R>", "snare" }, { "R- L- R>", "snare" } } },
      { "Comping ghosts",   { { "R- L- R- L> R- L-", "snare" } } },
      { "Ride and snare",   { { "R L- R", "ride", "R S R" }, { "R L- R", "ride", "R S R" }, { "R L> R", "ride", "R S R" } } },
      { "Gospel RLLK",      { { "R> L L K", "snare" }, { "R> L L K", "tom1" }, { "R> L L K", "tom2" }, { "R> L L K", "tom3" } } },
      { "Gospel RLK",       { { "R> L K R L K", "snare" }, { "R> L K R L K", "tom1" } } },
      { "Paradiddle-diddle", { { "R> L R R L L", "snare" }, { "R> L R R L L", "tom1" } } },
      { "Ratamacue",        { { "dR L R L>", "snare" }, { "dL R L R>", "tom1" } } },
      { "Flam drags",       { { "fR L L", "snare" }, { "fR L L", "tom3" } } },
      { "Pataflafla",       { { "fR L R fL", "snare" }, { "fR L R fL", "tom1" } } },
      { "Swiss triplets",   { { "fR R L", "snare" }, { "fR R L", "tom1" } } },
      { "Single drag tap",  { { "dR L>", "snare" }, { "dL R>", "snare" } } },
      { "Six stroke roll",  { { "R> L L R R L>", "snare" } } },
      { "Soft doubles",     { { "R- R- L- L-", "snare" }, { "R- R- L> L-", "snare" } } },
      { "Gospel run",       { { "R L K K", "snare" }, { "R L K K", "tom1" }, { "R L K K", "tom2" }, { "R> L K K", "tom3" } } },
      { "Bebop kicks",      { { "R- L- K", "snare", "R S K" }, { "R- L- K", "snare", "R S K" }, { "R L> K", "snare", "R S K" } } },
      { "Ride bell gospel", { { "R> L K", "snare", "RB S K" }, { "R> L K", "snare", "RB S K" }, { "R> L K", "snare", "RB S K" } } },
    } },
}

local AB_KEY = { ["-"] = REST }
for _, p in ipairs(PIECES) do AB_KEY[p.ab] = p.key end

local function factory_groups(spec)
  local list = {}
  for _, gspec in ipairs(spec) do
    local g = new_group(gspec[1], 0)
    set_group_piece(g, gspec[2], true)
    if gspec[3] then
      local codes = {}
      for c in gspec[3]:gmatch("%S+") do codes[#codes + 1] = c end
      for i, st in ipairs(g.strokes) do
        local key = AB_KEY[codes[i] or ""]
        if key then
          if st.h == "K" then
            st.piece = (key == "kick2") and "kick2" or "kick"
          elseif key ~= "kick" and key ~= "kick2" then
            st.piece = key
          end
        end
      end
    end
    list[#list + 1] = g
  end
  return list
end

function create_factory_drummer(f)
  reaper.RecursiveCreateDirectory(DRUM_DIR, 0)
  for k, v in pairs(PROFILE_DEFAULT) do S[k] = v end
  for k, v in pairs(f.profile) do S[k] = v end
  map = gm_map()
  drummer = { name = f.name, file = unique_file(f.name), chops = {} }
  for i, c in ipairs(f.chops) do
    drummer.chops[i] = { name = c[1], data = serialize_groups(factory_groups(c[2])) }
  end
  save_drummer()
end

end

-- The "Demo drummer" of 1.0-1.1 is replaced by the factory drummers: removed once
-- 1.3: "Kick + crash" is off by default for the factory drummers (it broke Again and Vary)
local function remove_demo()
  if reaper.GetExtState(EXT, "kick_crash_off") ~= "1" then
    scan_drummers()
    for _, d in ipairs(drummers) do
      if d.name == "Charlie" or d.name == "Mike" or d.name == "Buddie" then
        local path = DRUM_DIR .. "/" .. d.file
        local h = io.open(path, "r")
        local txt = h and h:read("a")
        if h then h:close() end
        if txt then
          local fixed = ("\n" .. txt):gsub("\ncrash=1\n", "\ncrash=0\n"):sub(2)
          if fixed ~= txt then
            h = io.open(path, "w")
            if h then h:write(fixed); h:close() end
          end
        end
      end
    end
    reaper.SetExtState(EXT, "kick_crash_off", "1", true)
  end
  if reaper.GetExtState(EXT, "demo_removed") == "1" then return end
  scan_drummers()
  local last = reaper.GetExtState(EXT, "last_drummer")
  for _, d in ipairs(drummers) do
    if d.name == "Demo drummer" then
      os.remove(DRUM_DIR .. "/" .. d.file)
      if last == d.file then reaper.SetExtState(EXT, "last_drummer", "", true) end
    end
  end
  reaper.SetExtState(EXT, "demo_removed", "1", true)
  scan_drummers()
end

-- force = true: create them even if they were created before (no drummer left)
local function create_factory(force)
  if not force and reaper.GetExtState(EXT, "factory") == "1" then return end
  scan_drummers()
  local have = {}
  for _, d in ipairs(drummers) do have[d.name] = true end
  for _, f in ipairs(FACTORY) do
    if not have[f.name] then create_factory_drummer(f) end
  end
  reaper.SetExtState(EXT, "factory", "1", true)
  scan_drummers()
  if reaper.GetExtState(EXT, "last_drummer") == "" or force then
    for _, d in ipairs(drummers) do
      if d.name == "Charlie" then reaper.SetExtState(EXT, "last_drummer", d.file, true) end
    end
  end
end

---------------------------------------------------------------------------
-- Export / import a drummer (one text file: name, drum map, profile, 16 chops)
---------------------------------------------------------------------------
local EXPORT_DIR = DATA_DIR .. "/exports"

local function export_drummer()
  if profile_dirty then save_drummer() end
  local src = DRUM_DIR .. "/" .. drummer.file
  local fn = file_safe(drummer.name) .. ".txt"
  local dest
  if reaper.JS_Dialog_BrowseForSaveFile then
    local ok, path = reaper.JS_Dialog_BrowseForSaveFile("Export drummer", EXPORT_DIR, fn, "Drummer (*.txt)\0*.txt\0\0")
    if ok ~= 1 or not path or path == "" then return end
    if not path:lower():match("%.txt$") then path = path .. ".txt" end
    dest = path
  else
    reaper.RecursiveCreateDirectory(EXPORT_DIR, 0)
    dest = EXPORT_DIR .. "/" .. fn
  end
  local i, o = io.open(src, "rb"), io.open(dest, "wb")
  if not i or not o then
    if i then i:close() end
    if o then o:close() end
    set_status("Cannot export to " .. dest, true); return
  end
  o:write(i:read("*a")); i:close(); o:close()
  set_status("Drummer exported: " .. dest)
  if not reaper.JS_Dialog_BrowseForSaveFile and reaper.CF_LocateInExplorer then reaper.CF_LocateInExplorer(dest) end
end

local function import_drummer()
  local ok, path = reaper.GetUserFileNameForRead(EXPORT_DIR .. "/", "Import drummer", "txt")
  if not ok or not path or path == "" then return end
  local h = io.open(path, "rb")
  if not h then set_status("Cannot read " .. path, true); return end
  local data = h:read("*a"); h:close()
  local name = data:match("^name=([^\r\n]*)") or data:match("\nname=([^\r\n]*)")
  if not name or not data:find("\nmap=", 1, true) then
    set_status("This file is not a Drum Buddy drummer.", true); return
  end
  scan_drummers()
  local base, n = name, 2
  local taken = {}
  for _, d in ipairs(drummers) do taken[d.name] = true end
  while taken[name] do name = base .. " " .. n; n = n + 1 end
  if name ~= base then data = data:gsub("name=[^\r\n]*", "name=" .. name:gsub("%%", "%%%%"), 1) end
  local file = unique_file(name)
  reaper.RecursiveCreateDirectory(DRUM_DIR, 0)
  local o = io.open(DRUM_DIR .. "/" .. file, "wb")
  if not o then set_status("Cannot write the drummer file.", true); return end
  o:write(data); o:close()
  scan_drummers()
  if profile_dirty then save_drummer() end
  if load_drummer(file) then
    link_project(file)
    set_status("Drummer imported: " .. name .. " (saved in this project)")
  end
end

local function new_drummer(name, copy)
  name = clean_name(name)
  if name == "" then set_status("Type a name first.", true); return false end
  if profile_dirty then save_drummer() end
  if not copy then
    for k, v in pairs(PROFILE_DEFAULT) do S[k] = v end
    map = gm_map()
    drummer.chops = {}
  end
  local chops = {}
  for i = 1, 16 do
    local c = drummer.chops[i]
    if c then chops[i] = { name = c.name, data = c.data } end
  end
  drummer = { name = name, file = unique_file(name), chops = chops }
  save_drummer()
  link_project(drummer.file)
  scan_drummers()
  set_status("Drummer created: " .. name)
  return true
end

local function select_drummer(file)
  if profile_dirty then save_drummer() end
  if load_drummer(file) then
    link_project(file)
    set_status("Drummer: " .. drummer.name .. " (saved in this project)")
  end
end

local function delete_drummer()
  local gone = drummer.name
  os.remove(DRUM_DIR .. "/" .. drummer.file)
  profile_dirty = false
  scan_drummers()
  if #drummers == 0 then create_factory(true) end
  select_drummer(drummers[1].file)
  set_status("Drummer deleted: " .. gone)
end

---------------------------------------------------------------------------
-- Style of the drummer, Random and Vary
---------------------------------------------------------------------------
local function with_groups(list, fn)
  local keep = groups
  groups = list
  fn()
  groups = keep
end

-- Density: more ghost notes and more kicks at the end of the groups
local function apply_density(list)
  local d = (S.density or 40) / 100
  for _, g in ipairs(list) do
    local n = #g.strokes
    for i, st in ipairs(g.strokes) do
      if st.h ~= "K" and not st.g then
        if i == 1 then
          if math.random() < 0.85 then st.dyn = "acc" end
        elseif math.random() < d * 0.6 then
          st.dyn = "ghost"
        else
          st.dyn = "norm"
        end
      end
    end
    local last = g.strokes[n]
    if n > 2 and last and last.h ~= "K" and not last.g and math.random() < d * 0.35 then
      last.hand = last.h; last.h = "K"; last.dyn = "norm"; last.piece = "kick"
    end
  end
end

-- A new fill: random preset (not Custom) repeated over the Random length, in the style of the drummer
local function random_groups()
  local cands = {}
  for fi, f in ipairs(FAMILIES) do
    for ri, r in ipairs(f.list) do
      if not r.custom then cands[#cands + 1] = { fi, ri } end
    end
  end
  local c = cands[math.random(#cands)]
  local n = math.max(1, math.floor(length_qn(G.rlen) / grid_qn() + 0.5))
  local list = groups_from_preset(c[1], c[2], n)
  with_groups(list, function()
    for _, g in ipairs(groups) do
      if g.mi > 0 and math.random() < 0.6 then set_motif(g, math.random(#motifs_for(#g.strokes))) end
    end
    random_by_group()
  end)
  apply_density(list)
  return list, "Random " .. FAMILIES[c[1]].list[c[2]][1]
end

-- Same sticking, new orchestration
local function vary_groups(list)
  with_groups(list, function() random_by_group() end)
  return list
end

---------------------------------------------------------------------------
-- MIDI editor
---------------------------------------------------------------------------
local function update_editor()
  editor = reaper.MIDIEditor_GetActive()
  take = editor and reaper.MIDIEditor_GetTake(editor) or nil
  if take and not reaper.ValidatePtr(take, "MediaItem_Take*") then take = nil end
  cur_track = take and reaper.GetMediaItemTake_Track(take) or nil
  chan = editor and reaper.MIDIEditor_GetSetting_int(editor, "default_note_chan") or 0
  if chan < 0 then chan = 0 end
end

---------------------------------------------------------------------------
-- Insertion: one stroke = one grid step of the MIDI editor
---------------------------------------------------------------------------
local function rnd() return math.random() * 2 - 1 end

local function insert_groups(list, name)
  name = name or "fill"
  if not editor or not take then set_status("Open a MIDI editor first.", true); return end
  local strokes = {}
  for _, g in ipairs(list) do for _, st in ipairs(g.strokes) do strokes[#strokes + 1] = st end end
  local n = #strokes
  if n == 0 then set_status("The fill is empty.", true); return end
  local step_qn = grid_qn()
  local cursor = reaper.GetCursorPosition()
  local item = reaper.GetMediaItemTake_Item(take)
  local start_qn = reaper.TimeMap2_timeToQN(0, cursor)
  local end_qn = start_qn + n * step_qn

  local notes, missing = {}, {}
  local function add(key, t0, t1, vel)
    local pitch = map[key] or -1
    if pitch < 0 then missing[key] = true; return end
    notes[#notes + 1] = { p = pitch, t0 = t0, t1 = t1, v = math.max(1, math.min(127, math.floor(vel + 0.5))) }
  end
  local function hvel(v) return v * (1 + rnd() * S.hum_vel / 100) end

  local first_t = cursor
  for i = 1, n do
    local st = strokes[i]
    local key = st.piece
    if key ~= REST then
      local qn = start_qn + (i - 1) * step_qn
      local shift = (S.feel + rnd() * S.hum_time) / 1000
      if i == 1 and shift < 0 then shift = 0 end   -- never before the cursor
      local t0 = reaper.TimeMap2_QNToTime(0, qn) + shift
      local t1 = reaper.TimeMap2_QNToTime(0, qn + step_qn * 0.5) + shift
      local v = S.vnorm
      if st.h ~= "K" and not st.g then
        v = (st.dyn == "acc") and S.vacc or (st.dyn == "ghost") and S.vghost or S.vnorm
      end
      add(key, t0, t1, hvel(v))
      if st.g == "f" then
        local d = S.flam_ms / 1000
        add(key, t0 - d, t0, hvel(S.vghost))
        first_t = math.min(first_t, t0 - d)
      elseif st.g == "d" then
        local d = S.drag_ms / 1000
        add(key, t0 - 2 * d, t0 - d, hvel(S.vghost))
        add(key, t0 - d, t0, hvel(S.vghost))
        first_t = math.min(first_t, t0 - 2 * d)
      end
    end
  end
  local end_t = reaper.TimeMap2_QNToTime(0, end_qn)
  local last_t = end_t
  if S.crash then
    local c1 = reaper.TimeMap2_QNToTime(0, end_qn + step_qn)
    add(S.crash_piece, end_t, c1, S.vacc)
    add("kick", end_t, c1, S.vacc)
    last_t = c1
  end
  if #notes == 0 then set_status("No note to insert: the pieces are not in the drum map (Kit).", true); return end
  if first_t < 0 then first_t = 0 end

  reaper.Undo_BeginBlock2(0)
  reaper.PreventUIRefresh(1)

  local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local iend = ipos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if first_t < ipos or last_t > iend then
    reaper.MIDI_SetItemExtents(item,
      reaper.TimeMap2_timeToQN(0, math.min(ipos, first_t)),
      reaper.TimeMap2_timeToQN(0, math.max(iend, last_t)))
  end

  reaper.MIDI_SelectAll(take, false)

  if G.replace then
    local used = {}
    for _, nt in ipairs(notes) do used[nt.p] = true end
    local p0 = reaper.MIDI_GetPPQPosFromProjTime(take, first_t - 0.05)
    local p1 = reaper.MIDI_GetPPQPosFromProjTime(take, end_t)
    local _, cnt = reaper.MIDI_CountEvts(take)
    for idx = cnt - 1, 0, -1 do
      local ok, _, _, sp, _, ch, pitch = reaper.MIDI_GetNote(take, idx)
      if ok and used[pitch] and ch == chan and sp >= p0 and sp < p1 then
        reaper.MIDI_DeleteNote(take, idx)
      end
    end
  end

  for _, nt in ipairs(notes) do
    local p0 = reaper.MIDI_GetPPQPosFromProjTime(take, nt.t0)
    local p1 = reaper.MIDI_GetPPQPosFromProjTime(take, nt.t1)
    if p1 <= p0 then p1 = p0 + 1 end
    reaper.MIDI_InsertNote(take, true, false, p0, p1, chan, nt.p, nt.v, true)
  end
  reaper.MIDI_Sort(take)

  reaper.SetEditCurPos(end_t, false, false)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(0, "Drum Buddy: " .. name, -1)

  -- the last fill (Again, Vary)
  reaper.SetExtState(EXT, "last_fill", serialize_groups(list), true)
  reaper.SetExtState(EXT, "last_name", name, true)

  local miss = {}
  for k in pairs(missing) do miss[#miss + 1] = PIECES[PIECE_INDEX[k]].name end
  if #miss > 0 then
    set_status("Inserted. Not in the drum map (skipped): " .. table.concat(miss, ", "), true)
  else
    set_status("Inserted: " .. name .. " (" .. n .. " strokes, " .. fmt_beats(n * step_qn) .. " at " .. grid_name() .. ")")
  end
end

local function last_fill()
  local d = reaper.GetExtState(EXT, "last_fill")
  if d == "" then return nil end
  return deserialize_groups(d), reaper.GetExtState(EXT, "last_name")
end

local function again()
  local list, nm = last_fill()
  if not list then set_status("Nothing inserted yet.", true); return end
  insert_groups(list, nm)                -- humanize is drawn again
end

local function vary()
  local list, nm = last_fill()
  if not list then set_status("Nothing inserted yet.", true); return end
  vary_groups(list)
  insert_groups(list, (nm or "fill"):gsub(" %(vary%)$", "") .. " (vary)")
end

local function random_insert()
  local list, nm = random_groups()
  insert_groups(list, nm)
end

---------------------------------------------------------------------------
-- Chops (16 pads per drummer)
---------------------------------------------------------------------------
local function chop_groups(i)
  local c = drummer.chops[i]
  return c and deserialize_groups(c.data) or {}
end

local function insert_chop(i)
  local c = drummer.chops[i]
  if c then insert_groups(chop_groups(i), c.name) end
end

local function save_to_pad(i, name)
  name = clean_name(name)
  if name == "" then set_status("Type a name first.", true); return false end
  if #groups == 0 then set_status("The Editor is empty.", true); return false end
  drummer.chops[i] = { name = name, data = serialize_groups(groups) }
  fill_name = name
  save_drummer()
  set_status("Pad " .. i .. ": " .. name)
  return true
end

local function chop_preview(data)
  local parts = {}
  for _, g in ipairs(deserialize_groups(data)) do
    local t = {}
    for _, st in ipairs(g.strokes) do
      local lab
      if st.h == "K" then lab = "K"
      elseif st.g == "f" then lab = "Fl"
      elseif st.g == "d" then lab = "Dr"
      else lab = st.h .. ((st.dyn == "acc") and ">" or (st.dyn == "ghost") and "-" or "") end
      t[#t + 1] = lab
    end
    parts[#parts + 1] = table.concat(t, " ")
  end
  return table.concat(parts, " | ")
end


-- Selected note of the MIDI editor: "index:pitch" of the first one
local function sel_signature()
  if not take then return "", nil end
  local i = reaper.MIDI_EnumSelNotes(take, -1)
  if not i or i < 0 then return "", nil end
  local ok, _, _, sp, _, _, pitch = reaper.MIDI_GetNote(take, i)
  if not ok then return "", nil end
  return i .. ":" .. sp .. ":" .. pitch, pitch
end

local function active_row()
  if not editor then return -1 end
  return reaper.MIDIEditor_GetSetting_int(editor, "active_note_row") or -1
end

local function start_learn(key)
  learn_key = key
  learn_seq = reaper.MIDI_GetRecentInputEvent and (reaper.MIDI_GetRecentInputEvent(0) or 0) or 0
  learn_row = active_row()
  learn_sel = sel_signature()
end

-- Learn: a note played on a MIDI device, a click on the piano keyboard of the MIDI editor,
-- or a note selected in the MIDI editor
local function poll_learn()
  if not learn_key then return end
  local note = nil
  local row = active_row()
  if row >= 0 and row ~= learn_row then note = row end
  learn_row = row
  local sig, pitch = sel_signature()
  if not note and sig ~= "" and sig ~= learn_sel then note = pitch end
  learn_sel = sig
  if not reaper.MIDI_GetRecentInputEvent then
    if note then
      map[learn_key] = note; save_map()
      set_status(PIECES[PIECE_INDEX[learn_key]].name .. " = note " .. note)
      learn_key = nil
    end
    return
  end
  local idx, newest = 0, nil
  while idx < 64 do
    local seq, buf = reaper.MIDI_GetRecentInputEvent(idx)
    if not seq or seq == 0 or seq <= learn_seq then break end
    newest = newest or seq
    if #buf >= 3 then
      local st, vel = buf:byte(1) & 0xF0, buf:byte(3)
      if st == 0x90 and vel > 0 and not note then note = buf:byte(2) end
    end
    idx = idx + 1
  end
  if newest then learn_seq = newest end
  if note then
    map[learn_key] = note
    save_map()
    set_status(PIECES[PIECE_INDEX[learn_key]].name .. " = note " .. note)
    learn_key = nil
  end
end

---------------------------------------------------------------------------
-- Interface helpers
---------------------------------------------------------------------------
local COL_ON = 0x5A4FCFFF
local COL_ON_HOV = 0x6E64DCFF
local COL_ACC = 0xC8642DFF
local COL_CELL = 0x34343CFF
local COL_CELL_BEAT = 0x4C4C62FF
local COL_ORCH = 0x3B3560FF
local COL_KICK = 0x2A2A2EFF
local COL_REST = 0x202024FF
local COL_GHEAD = 0x2C2C34FF
local COL_GPIECE = 0x5A4FCFFF
local COL_HOVER = 0xA8A0FFFF
local COL_TEXT = 0xE8E8E8FF
local COL_DIM = 0x9A9AA4FF
local COL_WARN = 0xE8A040FF
local COL_MARK = 0xF0F0F0FF

local function colored_button(label, on, w, col)
  if on then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, col or COL_ON)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, COL_ON_HOV)
  end
  local pressed = ImGui.Button(ctx, label, w or 0, 0)
  if on then ImGui.PopStyleColor(ctx, 2) end
  return pressed
end

local function stroke_label(st)
  if st.h == "K" then return "K" end
  if st.g == "f" then return "Fl" end
  if st.g == "d" then return "Dr" end
  return st.h
end

-- One "mode" per stroke: normal, accent, ghost, kick, flam (drag from the menu)
local function stroke_mode(st)
  if st.h == "K" then return "kick" end
  if st.g == "f" then return "flam" end
  if st.g == "d" then return "drag" end
  return (st.dyn == "acc") and "acc" or (st.dyn == "ghost") and "ghost" or "norm"
end

local function set_mode(st, g, mode)
  if mode == "kick" then
    if st.h ~= "K" then st.hand = st.h end
    st.h = "K"; st.g = nil; st.dyn = "norm"
    if st.piece ~= "kick" and st.piece ~= "kick2" then st.piece = "kick" end
    return
  end
  if st.h == "K" then st.h = st.hand or "R"; st.piece = g.piece end
  st.g = nil; st.dyn = "norm"
  if mode == "acc" then st.dyn = "acc"
  elseif mode == "ghost" then st.dyn = "ghost"
  elseif mode == "flam" then st.g = "f"
  elseif mode == "drag" then st.g = "d" end
end

local NEXT_MODE = { norm = "acc", acc = "ghost", ghost = "kick", kick = "flam", flam = "norm", drag = "norm" }
local MODE_NAMES = { { "norm", "Normal" }, { "acc", "Accent" }, { "ghost", "Ghost" },
  { "kick", "Kick" }, { "flam", "Flam" }, { "drag", "Drag" } }

local function cell(dl, id, x, y, w, h, bg, text, tcol)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, id, w, h)
  local hov = ImGui.IsItemHovered(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg, 3)
  if hov then ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COL_HOVER, 3, 0, 1) end
  local tw, th = ImGui.CalcTextSize(ctx, text)
  ImGui.DrawList_AddText(dl, x + (w - tw) / 2, y + (h - th) / 2, tcol, text)
  return hov
end

-- Wheel order for R/L strokes: silent, then every piece except the kick
local WHEEL = { REST }
for _, p in ipairs(PIECES) do if p.grp ~= "Kick" then WHEEL[#WHEEL + 1] = p.key end end

local function next_piece(cur, dir, kick_stroke)
  if kick_stroke then return (cur == "kick") and "kick2" or "kick" end
  local i = 1
  for k, v in ipairs(WHEEL) do if v == cur then i = k end end
  i = i + dir
  if i < 1 then i = #WHEEL elseif i > #WHEEL then i = 1 end
  return WHEEL[i]
end

local function piece_display(key)
  if key == REST then return "-", "Silent (no note)" end
  local p = PIECES[PIECE_INDEX[key]]
  return p.ab, p.name
end

-- The mouse wheel changes pieces on the grid: the window must not scroll at the same time.
-- (Begin gets NoScrollWithMouse on the next frame while the mouse is over a wheel cell.)
local wheel_hover, wheel_hover_prev = false, false
local function grab_wheel() wheel_hover = true end

-- Menu items to pick a piece; returns the chosen key or nil
local function piece_menu_items(cur, kick_stroke)
  local sel = nil
  if kick_stroke then
    for _, k in ipairs({ "kick", "kick2" }) do
      local p = PIECES[PIECE_INDEX[k]]
      if ImGui.MenuItem(ctx, p.ab .. "   " .. p.name .. (is_mapped(k) and "" or " (not mapped)"), nil, cur == k) then sel = k end
    end
    return sel
  end
  if ImGui.MenuItem(ctx, "-   Silent (no note)", nil, cur == REST) then sel = REST end
  ImGui.Separator(ctx)
  for _, gname in ipairs(GROUPS) do
    local in_grp = false
    for _, p in ipairs(PIECES) do if p.grp == gname and p.key == cur then in_grp = true end end
    if ImGui.BeginMenu(ctx, gname .. (in_grp and "  *" or "")) then
      for _, p in ipairs(PIECES) do
        if p.grp == gname then
          local lab = p.ab .. "   " .. p.name .. (is_mapped(p.key) and "" or " (not mapped)")
          if ImGui.MenuItem(ctx, lab, nil, cur == p.key) then sel = p.key end
        end
      end
      ImGui.EndMenu(ctx)
    end
  end
  return sel
end

---------------------------------------------------------------------------
-- Grid: one block per group (header, sticking, orchestration, group piece)
---------------------------------------------------------------------------
local function draw_grid()
  local dl = ImGui.GetWindowDrawList(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  local spb = grid_spb()   -- steps per quarter note (0 = unknown)
  local w, gap, ggap, h, hh, ph = 28, 2, 10, 22, 16, 16
  local ox, oy = ImGui.GetCursorScreenPos(ctx)
  local block_h = hh + 6 + h + 6 + h + 5 + ph + 14
  local wheel = ImGui.GetMouseWheel(ctx)
  local x, row, gidx = 0, 0, 0
  local open = nil

  for gi, g in ipairs(groups) do
    local n = #g.strokes
    local gw = n * (w + gap) - gap
    if x > 0 and x + gw > avail then x = 0; row = row + 1 end
    local gx = ox + x
    local yh = oy + row * block_h
    local ys = yh + hh + 6
    local yo = ys + h + 6
    local yp = yo + h + 5

    -- group header
    local hhov = cell(dl, "##gh" .. gi, gx, yh, gw, hh, COL_GHEAD, tostring(n), COL_DIM)
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then set_motif(g, g.mi + 1) end
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then menu_g = gi; open = "##groupmenu" end
    if hhov then ImGui.SetTooltip(ctx, "Group of " .. n .. "\nClick: next sticking\nRight-click: group menu") end

    for si, st in ipairs(g.strokes) do
      gidx = gidx + 1
      local cx = gx + (si - 1) * (w + gap)
      local beat_start = spb > 0 and ((gidx - 1) % spb) == 0

      -- sticking
      local shov = cell(dl, "##s" .. gi .. "_" .. si, cx, ys, w, h, beat_start and COL_CELL_BEAT or COL_CELL, stroke_label(st), COL_TEXT)
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then set_mode(st, g, NEXT_MODE[stroke_mode(st)]) end
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then menu_g, menu_s = gi, si; open = "##stickmenu" end
      if shov then
        local hand = (st.h == "K") and (st.hand or "R") or st.h
        ImGui.SetTooltip(ctx, "Hand " .. hand .. "\nClick: normal > accent > ghost > kick > flam\nRight-click: stroke menu")
      end
      local plain = (st.h ~= "K") and not st.g
      if plain and st.dyn == "acc" then
        ImGui.DrawList_AddLine(dl, cx + 4, ys - 3, cx + w - 4, ys - 3, COL_MARK, 2)
      elseif plain and st.dyn == "ghost" then
        ImGui.DrawList_AddLine(dl, cx + 4, ys + h + 2, cx + w - 4, ys + h + 2, COL_MARK, 2)
      end

      -- orchestration
      local ab, pname = piece_display(st.piece)
      local silent = (st.piece == REST)
      local bg = silent and COL_REST or ((st.h == "K") and COL_KICK or COL_ORCH)
      local tcol = silent and COL_DIM or (is_mapped(st.piece) and COL_TEXT or COL_WARN)
      local ohov = cell(dl, "##o" .. gi .. "_" .. si, cx, yo, w, h, bg, ab, tcol)
      if ohov then
        grab_wheel()
        if wheel > 0 then st.piece = next_piece(st.piece, -1, st.h == "K")
        elseif wheel < 0 then st.piece = next_piece(st.piece, 1, st.h == "K") end
        local mapped = silent or is_mapped(st.piece)
        ImGui.SetTooltip(ctx, pname .. (mapped and "" or " (not mapped)") .. "\nWheel: change\nRight-click: menu")
      end
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then menu_g, menu_s = gi, si; open = "##orchmenu" end
    end

    -- piece of the whole group
    local gab = piece_display(g.piece)
    local gcol = (g.piece == REST or is_mapped(g.piece)) and COL_TEXT or COL_WARN
    local phov = cell(dl, "##gp" .. gi, gx, yp, gw, ph, COL_GPIECE, gab, gcol)
    if phov then
      grab_wheel()
      if wheel > 0 then set_group_piece(g, next_piece(g.piece, -1, false), false)
      elseif wheel < 0 then set_group_piece(g, next_piece(g.piece, 1, false), false) end
      ImGui.SetTooltip(ctx, "Piece of the whole group\nClick or wheel: change\nRight-click: menu")
    end
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then set_group_piece(g, next_piece(g.piece, 1, false), false) end
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then menu_g = gi; open = "##gpiecemenu" end

    x = x + gw + ggap
  end

  local rows = (#groups > 0) and (row + 1) or 0
  ImGui.SetCursorScreenPos(ctx, ox, oy + rows * block_h)
  ImGui.Dummy(ctx, 1, 1)

  if open then ImGui.OpenPopup(ctx, open) end

  -- stroke menu
  if ImGui.BeginPopup(ctx, "##stickmenu") then
    local g = groups[menu_g]
    local st = g and g.strokes[menu_s]
    if st then
      ImGui.TextDisabled(ctx, "Stroke " .. menu_s .. " of group " .. menu_g)
      local hand = (st.h == "K") and (st.hand or "R") or st.h
      for _, hnd in ipairs({ "R", "L" }) do
        if ImGui.MenuItem(ctx, "Hand " .. hnd, nil, hand == hnd) then
          if st.h == "K" then st.hand = hnd else st.h = hnd end
        end
      end
      ImGui.Separator(ctx)
      local cur = stroke_mode(st)
      for _, md in ipairs(MODE_NAMES) do
        if ImGui.MenuItem(ctx, md[2], nil, cur == md[1]) then set_mode(st, g, md[1]) end
      end
    end
    ImGui.EndPopup(ctx)
  end

  -- piece of one stroke
  if ImGui.BeginPopup(ctx, "##orchmenu") then
    local g = groups[menu_g]
    local st = g and g.strokes[menu_s]
    if st then
      local sel = piece_menu_items(st.piece, st.h == "K")
      if sel then st.piece = sel end
    end
    ImGui.EndPopup(ctx)
  end

  -- piece of a group
  if ImGui.BeginPopup(ctx, "##gpiecemenu") then
    local g = groups[menu_g]
    if g then
      ImGui.TextDisabled(ctx, "Whole group " .. menu_g)
      local sel = piece_menu_items(g.piece, false)
      if sel then set_group_piece(g, sel, false) end
    end
    ImGui.EndPopup(ctx)
  end

  -- group menu
  if ImGui.BeginPopup(ctx, "##groupmenu") then
    local g = groups[menu_g]
    if g then
      ImGui.TextDisabled(ctx, "Group " .. menu_g .. " (" .. #g.strokes .. " strokes)")
      if ImGui.BeginMenu(ctx, "Sticking") then
        for mi, m in ipairs(motifs_for(#g.strokes)) do
          if ImGui.MenuItem(ctx, m .. "##m" .. mi, nil, g.mi == mi) then set_motif(g, mi) end
        end
        ImGui.EndMenu(ctx)
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, "Add a stroke") then resize_group(menu_g, 1) end
      if ImGui.MenuItem(ctx, "Remove the last stroke", nil, false, #g.strokes > 1) then resize_group(menu_g, -1) end
      if ImGui.MenuItem(ctx, "Split in two", nil, false, #g.strokes > 1) then split_group(menu_g) end
      if ImGui.MenuItem(ctx, "Merge with next", nil, false, groups[menu_g + 1] ~= nil) then merge_next(menu_g) end
      if ImGui.MenuItem(ctx, "Copy to next") then copy_to_next(menu_g) end
      if ImGui.MenuItem(ctx, "Invert R / L") then invert_group(menu_g) end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, "Delete group", nil, false, #groups > 1) then table.remove(groups, menu_g) end
    end
    ImGui.EndPopup(ctx)
  end
end

local COL_PAD = 0x3B3560FF
local COL_PAD_EMPTY = 0x26262CFF

---------------------------------------------------------------------------
-- Drummer tab: the drummer of the project and his 16 chops
---------------------------------------------------------------------------
local pad_idx, pad_name_buf, dr_name_buf, dr_copy = nil, "", "", false

local function draw_drummer()
  local avail = ImGui.GetContentRegionAvail(ctx)

  -- drummer of the project
  ImGui.SetNextItemWidth(ctx, math.max(120, avail - 360))
  if ImGui.BeginCombo(ctx, "##drummer", drummer.name) then
    if ImGui.IsWindowAppearing(ctx) then scan_drummers() end
    for i, d in ipairs(drummers) do
      if ImGui.Selectable(ctx, d.name .. "##d" .. i, d.file == drummer.file) then select_drummer(d.file) end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  local open_new, open_del = false, false
  if ImGui.Button(ctx, "New") then dr_name_buf = ""; dr_copy = false; open_new = true end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Duplicate") then dr_name_buf = drummer.name .. " copy"; dr_copy = true; open_new = true end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Delete") then open_del = true end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Export") then pending = export_drummer end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Save this drummer in a file (drum map, profile, 16 chops)") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Import") then pending = import_drummer end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Load a drummer from a file and use it in this project") end

  if project_drummer() == drummer.file then
    ImGui.TextDisabled(ctx, "Drummer of this project")
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, COL_WARN)
    ImGui.Text(ctx, "Not saved in this project yet")
    ImGui.PopStyleColor(ctx)
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Use in this project") then link_project(drummer.file) end
  end

  if open_new then ImGui.OpenPopup(ctx, "##drnew") end
  if open_del then ImGui.OpenPopup(ctx, "##drdel") end
  if ImGui.BeginPopup(ctx, "##drnew") then
    ImGui.Text(ctx, dr_copy and "Duplicate " .. drummer.name or "New drummer (General MIDI kit, no chop)")
    if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
    ImGui.SetNextItemWidth(ctx, 220)
    local ch, v = ImGui.InputTextWithHint(ctx, "##drname", "Name of the drummer", dr_name_buf)
    if ch then dr_name_buf = v end
    if ImGui.Button(ctx, "Create") or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if new_drummer(dr_name_buf, dr_copy) then ImGui.CloseCurrentPopup(ctx) end
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel") then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
  if ImGui.BeginPopup(ctx, "##drdel") then
    ImGui.Text(ctx, "Delete " .. drummer.name .. " and his 16 chops?")
    if ImGui.Button(ctx, "Delete") then delete_drummer(); ImGui.CloseCurrentPopup(ctx) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel") then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end

  -- 16 pads
  ImGui.SeparatorText(ctx, "Chops")
  local gap = 6
  local pw = math.floor((avail - 3 * gap) / 4)
  local ph = 48
  local open_save, open_menu = false, false
  local g = grid_qn()
  for i = 1, 16 do
    if (i - 1) % 4 ~= 0 then ImGui.SameLine(ctx, 0, gap) end
    local c = drummer.chops[i]
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, c and COL_PAD or COL_PAD_EMPTY)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, COL_ON_HOV)
    local label = c and (tostring(i) .. "\n" .. c.name) or (tostring(i) .. "\n+")
    if ImGui.Button(ctx, label .. "##pad" .. i, pw, ph) then
      if c then
        local idx = i
        pending = function() insert_chop(idx) end
      else
        pad_idx = i; pad_name_buf = fill_name or ("Chop " .. i); open_save = true
      end
    end
    ImGui.PopStyleColor(ctx, 2)
    if ImGui.IsItemHovered(ctx) then
      if c then
        local n = count_strokes(deserialize_groups(c.data))
        ImGui.SetTooltip(ctx, c.name .. "\n" .. chop_preview(c.data) .. "\n" .. n .. " strokes = " .. fmt_beats(n * g)
          .. " at " .. grid_name() .. "\n\nClick: insert at the edit cursor\nRight-click: edit, replace, rename, clear")
      else
        ImGui.SetTooltip(ctx, "Empty pad\nClick: save the fill of the Editor here")
      end
    end
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
      pad_idx = i; pad_name_buf = c and c.name or (fill_name or ("Chop " .. i))
      if c then open_menu = true else open_save = true end
    end
  end

  if open_save then ImGui.OpenPopup(ctx, "##padsave") end
  if open_menu then ImGui.OpenPopup(ctx, "##padmenu") end
  if ImGui.BeginPopup(ctx, "##padsave") then
    ImGui.Text(ctx, "Save the fill of the Editor in pad " .. tostring(pad_idx))
    if #groups == 0 then
      ImGui.TextDisabled(ctx, "The Editor is empty: build a fill there first.")
    else
      ImGui.TextDisabled(ctx, chop_preview(serialize_groups(groups)))
      if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
      ImGui.SetNextItemWidth(ctx, 220)
      local ch, v = ImGui.InputText(ctx, "##padname", pad_name_buf)
      if ch then pad_name_buf = v end
      if ImGui.Button(ctx, "Save") or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
        if save_to_pad(pad_idx, pad_name_buf) then ImGui.CloseCurrentPopup(ctx) end
      end
      ImGui.SameLine(ctx)
    end
    if ImGui.Button(ctx, "Cancel") then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
  if ImGui.BeginPopup(ctx, "##padmenu") then
    local c = drummer.chops[pad_idx]
    if c then
      ImGui.TextDisabled(ctx, tostring(pad_idx) .. ". " .. c.name)
      if ImGui.MenuItem(ctx, "Edit in the Editor") then
        groups = chop_groups(pad_idx); fill_name = c.name; select_tab = "Editor"
      end
      if ImGui.MenuItem(ctx, "Replace with the fill of the Editor", nil, false, #groups > 0) then
        save_to_pad(pad_idx, c.name)
      end
      ImGui.Separator(ctx)
      ImGui.SetNextItemWidth(ctx, 180)
      local ch, v = ImGui.InputText(ctx, "##rename", pad_name_buf)
      if ch then pad_name_buf = v end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Rename") then
        local nn = clean_name(pad_name_buf)
        if nn ~= "" then c.name = nn; save_drummer(); ImGui.CloseCurrentPopup(ctx) end
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, "Clear the pad") then drummer.chops[pad_idx] = nil; save_drummer() end
    end
    ImGui.EndPopup(ctx)
  end

  -- quick actions
  ImGui.Spacing(ctx)
  local bw = math.floor((avail - 2 * gap) / 3)
  if ImGui.Button(ctx, "Again", bw, 30) then pending = again end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Insert the last fill again (new humanize)") end
  ImGui.SameLine(ctx, 0, gap)
  if ImGui.Button(ctx, "Vary", bw, 30) then pending = vary end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Insert the last fill with a new orchestration (same sticking)") end
  ImGui.SameLine(ctx, 0, gap)
  if ImGui.Button(ctx, "Random", bw, 30) then pending = random_insert end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Insert a new fill in the style of " .. drummer.name .. " (" .. LENGTHS[G.rlen][1] .. ")")
  end
  ImGui.Text(ctx, "Random length")
  for i, l in ipairs(LENGTHS) do
    ImGui.SameLine(ctx)
    if colored_button(l[1] .. "##rl" .. i, G.rlen == i) then G.rlen = i; save_global() end
  end
  ImGui.TextDisabled(ctx, "Grid of the MIDI editor: " .. grid_name() .. " (one stroke = one grid step)")
end

---------------------------------------------------------------------------
-- Editor tab: build a chop (presets, groups, sticking, orchestration)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Editor tools: sticking (dynamics) and orchestration, along the whole fill
---------------------------------------------------------------------------
-- calls fn(stroke, group, index in the fill) for every stroke
local function each_stroke(fn)
  local i = 0
  for _, g in ipairs(groups) do
    for _, st in ipairs(g.strokes) do i = i + 1; fn(st, g, i) end
  end
end

local function plain(st) return st.h ~= "K" and not st.g end

-- stroke i (1 = first of the fill) falls on a quarter note
local function on_beat(i)
  local q = (i - 1) * grid_qn()
  return math.abs(q - math.floor(q + 0.5)) < 0.001
end

local function random_sticking()
  for _, g in ipairs(groups) do set_motif(g, math.random(#motifs_for(#g.strokes))) end
end

-- accents where test(i) is true, no accent elsewhere (ghost notes kept)
local function accent_where(test)
  each_stroke(function(st, _, i)
    if plain(st) then
      if test(i) then st.dyn = "acc" elseif st.dyn == "acc" then st.dyn = "norm" end
    end
  end)
end

-- ghost notes where test(i) is true (accents kept)
local function ghost_where(test)
  each_stroke(function(st, _, i)
    if plain(st) and st.dyn ~= "acc" and test(i) then st.dyn = "ghost" end
  end)
end

local function all_hh()
  for _, g in ipairs(groups) do g.piece = "hh_closed" end
  each_stroke(function(st)
    if st.h ~= "K" then st.piece = (st.dyn == "acc") and "hh_open" or "hh_closed" end
  end)
end

local function ride_hh()
  each_stroke(function(st)
    if st.h == "R" then st.piece = "ride" elseif st.h == "L" then st.piece = "hh_closed" end
  end)
end

-- pieces in a cycle along the fill; "K" = the stroke becomes a kick
local function cycle_orch(seq)
  each_stroke(function(st, g, i)
    local k = seq[((i - 1) % #seq) + 1]
    if k == "K" then
      set_mode(st, g, "kick")
    else
      if st.h == "K" then set_mode(st, g, "norm") end
      st.piece = k
    end
  end)
end

-- buttons that wrap to the next line when the window is narrow
local flow_x, flow_avail = 0, 0
local function flow_begin() flow_x = 0; flow_avail = ImGui.GetContentRegionAvail(ctx) end
local function flow_button(label, tip)
  local w = ImGui.CalcTextSize(ctx, label) + 16
  if flow_x > 0 and flow_x + w <= flow_avail then ImGui.SameLine(ctx) else flow_x = 0 end
  local pressed = ImGui.Button(ctx, label)
  if tip and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, tip) end
  flow_x = flow_x + w + 8
  return pressed
end

local save_name_buf = ""

local function draw_editor()
  local avail = ImGui.GetContentRegionAvail(ctx)

  ImGui.SeparatorText(ctx, "Start from a preset")
  for i, f in ipairs(FAMILIES) do
    if i > 1 then ImGui.SameLine(ctx) end
    if colored_button(f.name .. "##fam" .. i, G.fam == i) then
      if G.fam ~= i then G.fam = i; G.rud = 1; build_groups(); save_global() end
    end
  end
  local list = FAMILIES[G.fam].list
  local bw = (avail - 8) / 2
  for i, r in ipairs(list) do
    if (i - 1) % 2 == 1 then ImGui.SameLine(ctx) end
    if colored_button(r[1] .. "##rud" .. i, G.rud == i and fill_name == r[1], bw) then
      G.rud = i; build_groups(); save_global()
    end
  end
  if list[G.rud] and list[G.rud].custom then
    ImGui.SetNextItemWidth(ctx, 140)
    local ch, v = ImGui.InputText(ctx, "##custom", custom_buf)
    if ch then custom_buf = v end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Apply") then build_groups() end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "ex. 3+3+2 or 5 5 6")
  end

  -- Sticking: hands and dynamics
  ImGui.SeparatorText(ctx, "Sticking")
  flow_begin()
  if flow_button("Random", "A random sticking for each group (from the motif library)") then random_sticking() end
  if flow_button("Accent first", "Accent on the first stroke of each group") then accent_first() end
  if flow_button("Accent odd", "Accents on strokes 1, 3, 5...") then accent_where(function(i) return i % 2 == 1 end) end
  if flow_button("Accent even", "Accents on strokes 2, 4, 6...") then accent_where(function(i) return i % 2 == 0 end) end
  if flow_button("Accent beat", "Accents only on the beats (quarter notes)") then accent_where(function(i) return on_beat(i) end) end
  if flow_button("Ghost odd", "Ghost notes on strokes 1, 3, 5... (accents kept)") then ghost_where(function(i) return i % 2 == 1 end) end
  if flow_button("Ghost even", "Ghost notes on strokes 2, 4, 6... (accents kept)") then ghost_where(function(i) return i % 2 == 0 end) end
  if flow_button("Ghost offbeat", "Ghost notes on every stroke that is not on a beat (accents kept)") then
    ghost_where(function(i) return not on_beat(i) end)
  end

  -- Orchestration: pieces the strokes are played on
  ImGui.SeparatorText(ctx, "Orchestration")
  flow_begin()
  if flow_button("All snare", "Every R and L stroke on the snare") then all_snare() end
  if flow_button("All HH", "Hi-hat closed, open on the accents") then all_hh() end
  if flow_button("Toms down", "One tom per group, high to low") then toms_by_group(false) end
  if flow_button("Toms up", "One tom per group, low to high") then toms_by_group(true) end
  if flow_button("R ride / L HH", "Right hand on the ride, left hand on the closed hi-hat") then ride_hh() end
  if flow_button("MP", "Snare Snare Kick Kick, all along the fill") then cycle_orch({ "snare", "snare", "K", "K" }) end
  if flow_button("Shuffle", "HH SN HH HH SN HH, all along the fill") then
    cycle_orch({ "hh_closed", "snare", "hh_closed", "hh_closed", "snare", "hh_closed" })
  end

  -- Fill
  ImGui.SeparatorText(ctx, "Fill")
  if ImGui.Button(ctx, "Repeat") then
    local nb = #groups
    for i = 1, nb do
      local g = groups[i]
      local c = { strokes = {}, mi = g.mi, piece = g.piece }
      for _, st in ipairs(g.strokes) do c.strokes[#c.strokes + 1] = copy_stroke(st) end
      groups[#groups + 1] = c
    end
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Play the whole fill twice") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset") then build_groups() end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Back to the preset as written") end
  ImGui.SameLine(ctx)

  local n = total_strokes()
  ImGui.TextDisabled(ctx, (fill_name or "Fill") .. ": " .. n .. " strokes = " .. fmt_beats(n * grid_qn())
    .. " at " .. grid_name())
  ImGui.Spacing(ctx)
  draw_grid()

  -- insert / save
  local half = (avail - 8) / 2
  if colored_button("Insert at edit cursor", true, half) then
    local list, nm = groups, fill_name
    pending = function() insert_groups(list, nm) end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Save to a pad...", half, 0) then
    save_name_buf = fill_name or "My chop"
    ImGui.OpenPopup(ctx, "##savepad")
  end
  if ImGui.BeginPopup(ctx, "##savepad") then
    ImGui.Text(ctx, "Name of the chop")
    ImGui.SetNextItemWidth(ctx, 240)
    local ch, v = ImGui.InputText(ctx, "##savename", save_name_buf)
    if ch then save_name_buf = v end
    ImGui.Text(ctx, "Pad of " .. drummer.name .. " (a used pad is replaced)")
    for i = 1, 16 do
      if (i - 1) % 4 ~= 0 then ImGui.SameLine(ctx, 0, 4) end
      local c = drummer.chops[i]
      local short = c and c.name or "-"
      if #short > 10 then short = short:sub(1, 9) .. "." end
      if colored_button(i .. " " .. short .. "##sp" .. i, c ~= nil, 110) then
        if save_to_pad(i, save_name_buf) then ImGui.CloseCurrentPopup(ctx) end
      end
    end
    ImGui.EndPopup(ctx)
  end
end

---------------------------------------------------------------------------
-- Profile tab: how the drummer plays
---------------------------------------------------------------------------
local function feel_format()
  if S.feel < 0 then return "Rush " .. (-S.feel) .. " ms" end
  if S.feel > 0 then return "Laid back " .. S.feel .. " ms" end
  return "On the beat"
end

local function slider(id, key, mn, mx, fmt, w)
  ImGui.SetNextItemWidth(ctx, w)
  local ch, v = ImGui.SliderInt(ctx, id, S[key], mn, mx, fmt)
  if ch then S[key] = v; touch_profile() end
end

local END_PIECES = { "crash1", "crash2", "crash3", "china", "splash", "stack", "ride", "ride_bell" }

local function draw_profile()
  local avail = ImGui.GetContentRegionAvail(ctx)
  local half = (avail - 8) / 2
  local third = (avail - 16) / 3

  ImGui.Text(ctx, "Name")
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, avail - 60)
  local ch, v = ImGui.InputText(ctx, "##pname", drummer.name)
  if ch and clean_name(v) ~= "" then drummer.name = clean_name(v); touch_profile() end

  ImGui.SeparatorText(ctx, "Velocity")
  slider("##vacc", "vacc", 1, 127, "Accent %d", third); ImGui.SameLine(ctx)
  slider("##vnorm", "vnorm", 1, 127, "Normal %d", third); ImGui.SameLine(ctx)
  slider("##vghost", "vghost", 1, 127, "Ghost %d", third)

  ImGui.SeparatorText(ctx, "Grace notes")
  slider("##flam", "flam_ms", 5, 80, "Flam %d ms", half); ImGui.SameLine(ctx)
  slider("##drag", "drag_ms", 5, 80, "Drag %d ms", half)

  ImGui.SeparatorText(ctx, "Feel")
  slider("##hv", "hum_vel", 0, 50, "Humanize velocity %d %%", half); ImGui.SameLine(ctx)
  slider("##ht", "hum_time", 0, 30, "Humanize timing %d ms", half)
  slider("##feel", "feel", -20, 20, (feel_format():gsub("%%", "%%%%")), avail)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Left = Rush (ahead of the beat)\nRight = Laid back (behind the beat)") end

  ImGui.SeparatorText(ctx, "Style (Random and Vary)")
  slider("##dens", "density", 0, 100, "Density %d %%", avail)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Low = clean fills; high = more ghost notes and kicks") end
  local c1, v1 = ImGui.Checkbox(ctx, "Cymbals in Random and Vary", S.rand_cym)
  if c1 then S.rand_cym = v1; touch_profile() end

  ImGui.SeparatorText(ctx, "End of the fill")
  local c2, v2 = ImGui.Checkbox(ctx, "Kick +", S.crash)
  if c2 then S.crash = v2; touch_profile() end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 160)
  if ImGui.BeginCombo(ctx, "after the fill##endp", PIECES[PIECE_INDEX[S.crash_piece]].name) then
    for _, k in ipairs(END_PIECES) do
      if ImGui.Selectable(ctx, PIECES[PIECE_INDEX[k]].name, S.crash_piece == k) then S.crash_piece = k; touch_profile() end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SeparatorText(ctx, "Options (all drummers)")
  local c3, v3 = ImGui.Checkbox(ctx, "Replace the notes under the fill", G.replace)
  if c3 then G.replace = v3; save_global() end
  local dopen = reaper.GetExtState(EXT, "display_open") == "1"
  local c4, v4 = ImGui.Checkbox(ctx, "Open the Display when REAPER starts", dopen)
  if c4 then
    reaper.SetExtState(EXT, "display_open", v4 and "1" or "0", true)
    if v4 then
      -- add the startup block once (Scripts/__startup.lua); it opens the Display only while this box is ticked
      local _, me = reaper.get_action_context()
      local disp = (me:match("^(.*)[/\\]") or "") .. "/ReNo Mellow - Drum Buddy - Display.lua"
      local path = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
      local f = io.open(path, "r")
      local content = f and f:read("*a") or ""
      if f then f:close() end
      if not content:find("ReNo Mellow Drum Buddy Display", 1, true) and reaper.file_exists(disp) then
        local w = io.open(path, "a")
        if w then
          w:write("\n-- >>> ReNo Mellow Drum Buddy Display (added by the script)\n"
            .. "do\n"
            .. "  local p = " .. string.format("%q", disp) .. "\n"
            .. "  if reaper.GetExtState(\"ReNo_DrumBuddy\", \"display_open\") == \"1\" and reaper.file_exists(p) then\n"
            .. "    local c = reaper.AddRemoveReaScript(true, 0, p, true)\n"
            .. "    if c and c ~= 0 then reaper.Main_OnCommand(c, 0) end\n"
            .. "  end\n"
            .. "end\n"
            .. "-- <<< ReNo Mellow Drum Buddy Display\n")
          w:close()
        end
      end
    end
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "The Display opens by itself each time REAPER starts") end
  local dsize = tonumber(reaper.GetExtState(EXT, "disp_size")) or 13
  local dalpha = tonumber(reaper.GetExtState(EXT, "disp_alpha")) or 90
  ImGui.SetNextItemWidth(ctx, half)
  local c5, v5 = ImGui.SliderInt(ctx, "##dsize", dsize, 10, 28, "Display text size %d")
  if c5 then reaper.SetExtState(EXT, "disp_size", tostring(v5), true) end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, half)
  local c6, v6 = ImGui.SliderInt(ctx, "##dalpha", dalpha, 15, 100, "Display opacity %d %%")
  if c6 then reaper.SetExtState(EXT, "disp_alpha", tostring(v6), true) end
end

---------------------------------------------------------------------------
-- Kit tab: drum map of the drummer
---------------------------------------------------------------------------
local function draw_kit()
  ImGui.TextWrapped(ctx, "Drum map of " .. drummer.name .. ": the notes of his instrument.")
  local can_detect = cur_track ~= nil
  if ImGui.Button(ctx, "Detect from note names") then
    if not can_detect then
      set_status("Open a MIDI editor on the drum track first.", true)
    else
      local m, found, named = detect_map(cur_track, chan, map)
      if named == 0 then
        set_status("This track has no note names. Load a note name file in the MIDI editor (File > Note names), or use Learn.", true)
      else
        map = m; save_map()
        set_status(found .. " pieces detected from " .. named .. " note names (the others keep their note). Check the list below.")
      end
    end
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Reads the note names loaded in the MIDI editor for the edited track") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Load GM") then map = gm_map(); save_map(); set_status("General MIDI map loaded.") end

  ImGui.Spacing(ctx)
  ImGui.TextDisabled(ctx, "Note -1 = not mapped. Learn: click, then a key of the MIDI editor keyboard, a note, or a pad.")
  local flags = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerH
  if ImGui.BeginTable(ctx, "map", 4, flags) then
    ImGui.TableSetupColumn(ctx, "Piece", ImGui.TableColumnFlags_WidthFixed, 150)
    ImGui.TableSetupColumn(ctx, "Note", ImGui.TableColumnFlags_WidthFixed, 90)
    ImGui.TableSetupColumn(ctx, "Name on track", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "##learn", ImGui.TableColumnFlags_WidthFixed, 80)
    ImGui.TableHeadersRow(ctx)
    local last_grp = nil
    for _, p in ipairs(PIECES) do
      if p.grp ~= last_grp then
        last_grp = p.grp
        ImGui.TableNextRow(ctx)
        ImGui.TableNextColumn(ctx)
        ImGui.TextDisabled(ctx, p.grp)
      end
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.Text(ctx, p.ab .. "  " .. p.name)
      ImGui.TableNextColumn(ctx)
      ImGui.SetNextItemWidth(ctx, 85)
      local ch, v = ImGui.InputInt(ctx, "##n" .. p.key, map[p.key] or -1, 1, 12)
      if ch then
        if v < -1 then v = -1 elseif v > 127 then v = 127 end
        map[p.key] = v; touch_profile()
      end
      ImGui.TableNextColumn(ctx)
      local nn = (cur_track and (map[p.key] or -1) >= 0) and note_name(cur_track, map[p.key], chan) or nil
      ImGui.TextDisabled(ctx, nn or "")
      ImGui.TableNextColumn(ctx)
      if learn_key == p.key then
        if colored_button("Listening##l" .. p.key, true, 75, COL_ACC) then learn_key = nil end
      else
        if ImGui.Button(ctx, "Learn##l" .. p.key, 75, 0) then
          start_learn(p.key)
          set_status("Learn " .. p.name .. ": click its key on the piano keyboard of the MIDI editor, select one of its notes, or hit the pad.")
        end
      end
    end
    ImGui.EndTable(ctx)
  end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local TABS = { { "Drummer", draw_drummer }, { "Editor", draw_editor }, { "Profile", draw_profile }, { "Kit", draw_kit } }

local function draw()
  local want = select_tab
  select_tab = nil
  ImGui.Text(ctx, drummer.name)
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, "  grid " .. grid_name())
  if ImGui.BeginTabBar(ctx, "tabs") then
    for _, t in ipairs(TABS) do
      local fl = (want == t[1]) and ImGui.TabItemFlags_SetSelected or 0
      if ImGui.BeginTabItem(ctx, t[1], nil, fl) then t[2](); ImGui.EndTabItem(ctx) end
    end
    ImGui.EndTabBar(ctx)
  end
  if status ~= "" then
    ImGui.Separator(ctx)
    if status_err then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, COL_WARN)
      ImGui.TextWrapped(ctx, status)
      ImGui.PopStyleColor(ctx)
    else
      ImGui.TextWrapped(ctx, status)
    end
  end
end


---------------------------------------------------------------------------
-- Start: factory drummers on the first run
---------------------------------------------------------------------------
load_global()
reaper.RecursiveCreateDirectory(DRUM_DIR, 0)
scan_drummers()
remove_demo()
create_factory(false)
if #drummers == 0 then create_factory(true) end
sync_drummer()
build_groups()

---------------------------------------------------------------------------
-- Used as a library by the Display (DRUMBUDDY_LIB = true before dofile)
---------------------------------------------------------------------------
if DRUMBUDDY_LIB then
  return {
    EXT = EXT, LENGTHS = LENGTHS, G = G,
    sync = function() sync_drummer(); update_editor() end,
    drummer = function() return drummer end,
    insert_chop = insert_chop,
    chop_preview = chop_preview,
    again = again, vary = vary, random = random_insert,
    grid_name = grid_name,
    set_rlen = function(i) G.rlen = i; save_global() end,
    get_status = function() return status, status_err end,
  }
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------
local _, _, sec, cmd = reaper.get_action_context()
-- the Display can open / close this window
reaper.SetExtState(EXT, "main_cmd", reaper.ReverseNamedCommandLookup(cmd) or "", true)
reaper.SetExtState(EXT, "main_sec", tostring(sec), true)
reaper.SetExtState(EXT, "main_close", "", false)
reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(function()
  reaper.SetExtState(EXT, "main_alive", "", false)
  if profile_dirty then save_drummer() end
  save_global()
  reaper.SetExtState(EXT, "custom", custom_buf, true)
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end)

ctx = ImGui.CreateContext(SCRIPT_NAME)

local function loop()
  local now = reaper.time_precise()
  reaper.SetExtState(EXT, "main_alive", tostring(now), false)
  if reaper.GetExtState(EXT, "main_close") == "1" then
    reaper.SetExtState(EXT, "main_close", "", false)
    return
  end
  sync_drummer()
  update_editor()
  poll_learn()
  if profile_dirty and now - dirty_time > 0.5 then save_drummer() end

  ImGui.SetNextWindowSize(ctx, 500, 720, ImGui.Cond_FirstUseEver)
  local wflags = wheel_hover_prev and ImGui.WindowFlags_NoScrollWithMouse or 0
  wheel_hover = false
  local visible, open = ImGui.Begin(ctx, "Drum Buddy " .. VERSION .. "###ReNoDrumBuddy", true, wflags)
  if visible then
    draw()
    ImGui.End(ctx)
  end
  wheel_hover_prev = wheel_hover
  if pending then
    local f = pending; pending = nil
    f()
  end
  if open then reaper.defer(loop) else reaper.SetExtState(EXT, "main_alive", "", false) end
end

reaper.defer(loop)
