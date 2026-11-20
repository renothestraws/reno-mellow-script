-- @description ReNo Mellow - Chord Buddy
-- @author ReNo Mellow
-- @version 1.2
-- @about Roue des quintes pour créer des accords dans l'éditeur MIDI (inversions, voicings, auto voice leading) + Display du nom de l'accord et export
-- @changelog Inversion réglée avec des boutons - / + sur chaque case (clic sur le chiffre = 0) au lieu de la molette
-- @provides
--   [main] ReNo Mellow - Chord Buddy - Display.lua
--   ChordBuddy_theory.lua
--   ChordBuddy_midi.lua
--   ChordBuddy_export.lua

-- Requires ReaImGui (0.9 or later)

local r = reaper
local VERSION = "1.2"
local EXT = "ReNo_ChordBuddy"
local TITLE = "Chord Buddy"

---------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------

local SCRIPT_DIR = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
local T = dofile(SCRIPT_DIR .. "ChordBuddy_theory.lua")
local M = dofile(SCRIPT_DIR .. "ChordBuddy_midi.lua")
local E = dofile(SCRIPT_DIR .. "ChordBuddy_export.lua")
local DISPLAY_SCRIPT = SCRIPT_DIR .. "ReNo Mellow - Chord Buddy - Display.lua"

if not r.ImGui_GetBuiltinPath then
  r.MB("Chord Buddy needs the ReaImGui extension.\n\nInstall it with ReaPack:\nExtensions > ReaPack > Browse packages > search \"ReaImGui\", install, then restart REAPER.",
       TITLE, 0)
  return
end
package.path = r.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
local ImGui = require "imgui" "0.9"

---------------------------------------------------------------------------
-- Toolbar state
---------------------------------------------------------------------------

-- relaunching the action closes the window (no REAPER prompt), toolbar toggle on
if r.set_action_options then r.set_action_options(1 | 4) end
local _, _, SECTION_ID, CMD_ID = r.get_action_context()
local function set_toggle(on)
  if CMD_ID and CMD_ID > 0 then
    r.SetToggleCommandState(SECTION_ID, CMD_ID, on and 1 or 0)
    r.RefreshToolbar2(SECTION_ID, CMD_ID)
  end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local DEFAULTS = {
  key_pos = 0, minor = false, octave = 4, ctype = "triad", mult = "1",
  auto = false, bass = false, voicing = "close", strum = 0, human = 0,
  vel = 100, replace = false, advance = true, spell = "key",
  oct_mode = "auto", oct_manual = 0,
  opacity = 1.0, wheel_size = 440, font_scale = 1.0,
  invs = "",
  export_modes = "1000", chords_track = "Chords", color_items = true,
  disp_size = 22, disp_opacity = 0.9,
}

local S = {}

local function load_settings()
  for k, def in pairs(DEFAULTS) do
    local v = r.GetExtState(EXT, k)
    if v == "" then
      S[k] = def
    elseif type(def) == "boolean" then
      S[k] = (v == "1")
    elseif type(def) == "number" then
      S[k] = tonumber(v) or def
    else
      S[k] = v
    end
  end
end

local function save(k)
  local v = S[k]
  if type(v) == "boolean" then v = v and "1" or "0" end
  r.SetExtState(EXT, k, tostring(v), true)
end

local function set(k, v)
  if S[k] ~= v then S[k] = v; save(k) end
end

-- Inversions per cell: INV[ring][pos]
local INV = { {}, {}, {} }
local function load_invs()
  for ring = 1, 3 do for pos = 0, 11 do INV[ring][pos] = 0 end end
  local i = 0
  for v in (S.invs or ""):gmatch("(-?%d+)") do
    local ring, pos = i // 12 + 1, i % 12
    if ring <= 3 then INV[ring][pos] = tonumber(v) end
    i = i + 1
  end
end
local function save_invs()
  local t = {}
  for ring = 1, 3 do for pos = 0, 11 do t[#t + 1] = tostring(INV[ring][pos] or 0) end end
  set("invs", table.concat(t, ","))
end

load_settings()
load_invs()

local function oct_offset()
  if S.oct_mode == "auto" then return M.ReaperOctaveOffset() or 0 end
  return S.oct_manual or 0
end

local function key_pc() return T.FIFTHS[S.key_pos % 12] end
local function spelling() return T.Spelling(key_pc(), S.spell) end

---------------------------------------------------------------------------
-- Colors (0xRRGGBBAA)
---------------------------------------------------------------------------

local DEG_COLOR = {   -- by degree of the relative major (as on the reference picture)
  [1] = 0x9EE0CCFF,   -- I    (C)
  [2] = 0xF7F7C0FF,   -- ii   (Dm)
  [3] = 0xFF9F7AFF,   -- iii  (Em)
  [4] = 0xCCFFCCFF,   -- IV   (F)
  [5] = 0xAAD8E6FF,   -- V    (G)
  [6] = 0xFFD27FFF,   -- vi   (Am)
  [7] = 0xFFC0CBFF,   -- vii° (Bdim)
}
local COL_OUT    = 0xBDBDBDFF
local COL_LINE   = 0x808080FF
local COL_TXT_IN = 0x505050FF
local COL_TXT_OUT= 0x6E6E6EFF
local COL_CENTER = 0xF0F0F0FF

local function lighten(col, f)
  local rr = (col >> 24) & 0xFF
  local gg = (col >> 16) & 0xFF
  local bb = (col >> 8) & 0xFF
  local aa = col & 0xFF
  rr = math.floor(rr + (255 - rr) * f)
  gg = math.floor(gg + (255 - gg) * f)
  bb = math.floor(bb + (255 - bb) * f)
  return (rr << 24) | (gg << 16) | (bb << 8) | aa
end

---------------------------------------------------------------------------
-- ImGui context and fonts (created after startup work, see skill notes)
---------------------------------------------------------------------------

local ctx
local FONTS = {}       -- [size] = { normal, bold }
local FONT_MIN, FONT_MAX = 9, 34

local function create_context()
  ctx = ImGui.CreateContext(TITLE)
  for sz = FONT_MIN, FONT_MAX do
    local f = ImGui.CreateFont("sans-serif", sz)
    local fb = ImGui.CreateFont("sans-serif", sz, ImGui.FontFlags_Bold)
    ImGui.Attach(ctx, f)
    ImGui.Attach(ctx, fb)
    FONTS[sz] = { f, fb }
  end
end

local function font(size, bold)
  local sz = math.max(FONT_MIN, math.min(FONT_MAX, math.floor(size + 0.5)))
  return FONTS[sz][bold and 2 or 1], sz
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local status, status_t = "", 0
local function set_status(msg) status, status_t = msg or "", r.time_precise() end

local drag = nil          -- { start_angle, moved }
local rot_view = nil      -- fractional rotation while dragging
local hover = nil         -- { ring, pos, inv_zone } or { center = "up"/"down" }
local preview = nil       -- { pitches, name } shown on the mini keyboard
local preview_key = nil
local preview_t = 0

local LENGTHS = { { "1", "Grid" }, { "2", "Grid x2" }, { "4", "Grid x4" }, { "bar", "1 bar" } }

---------------------------------------------------------------------------
-- Chord of a cell with the current options
---------------------------------------------------------------------------

-- Spelling of a cell: chords of the key follow the key, the other cells
-- use the spelling of their own wheel position (G#dim under A, not Abdim)
local function cell_spell(pos, ring)
  if S.spell ~= "key" then return spelling() end
  if T.CellDegree(pos, ring, S.key_pos, S.minor) then return spelling() end
  return T.Spelling(T.FIFTHS[pos], "key")
end

local function cell_opts(ring, pos)
  local root_pc, quality = T.CellChord(pos, ring)
  local n = T.ToneCount(quality, S.ctype)
  local inv = INV[ring][pos] or 0
  if inv > n then inv = n elseif inv < -n then inv = -n end
  return {
    root_pc = root_pc, quality = quality, ctype = S.ctype,
    octave = S.octave, oct_offset = oct_offset(),
    inv = inv, voicing = S.voicing, bass = S.bass,
  }
end

local function previous_chord()
  local take = M.GetEditorTake()
  if not take then return nil end
  local ppq = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPositionEx(0))
  return M.PreviousChord(take, ppq)
end

local function chord_pitches(ring, pos, prev)
  local o = cell_opts(ring, pos)
  if S.auto then o.inv = T.BestInversion(o, prev) end
  return T.Build(o), o
end

local function insert_cell(ring, pos)
  local prev = S.auto and previous_chord() or nil
  local pitches = chord_pitches(ring, pos, prev)
  local name = T.Identify(pitches, cell_spell(pos, ring)) or "chord"
  local ok, err = M.InsertChord(pitches, {
    vel = S.vel, mult = S.mult == "bar" and "bar" or tonumber(S.mult),
    replace = S.replace, advance = S.advance,
    strum_ms = S.strum, human_vel = S.human, name = name,
  })
  if ok then set_status("Inserted " .. name) else set_status(err) end
  preview_key = nil  -- refresh the keyboard (the previous chord changed)
end

---------------------------------------------------------------------------
-- Wheel geometry
---------------------------------------------------------------------------

local R_OUT, R_MAJ, R_MIN, R_DIM = 1.00, 0.76, 0.55, 0.34  -- fractions of radius

-- Inversion buttons drawn this frame:
-- INV_RECT[ring][pos] = { minus = {x1,y1,x2,y2}, val = {...}, plus = {...} }
local INV_RECT = { {}, {}, {} }


local function ring_bounds(ring)
  if ring == 1 then return R_MAJ, R_OUT end
  if ring == 2 then return R_MIN, R_MAJ end
  return R_DIM, R_MIN
end

-- angle (radians, screen coords) of the center of a wheel position
local function pos_angle(pos, rot)
  return math.rad((pos - rot) * 30 - 90)
end

-- Fill an annulus sector with convex quads
local function fill_sector(dl, cx, cy, r1, r2, a1, a2, col)
  local steps = 8
  for i = 0, steps - 1 do
    local t1 = a1 + (a2 - a1) * i / steps
    local t2 = a1 + (a2 - a1) * (i + 1) / steps
    local c1, s1, c2, s2 = math.cos(t1), math.sin(t1), math.cos(t2), math.sin(t2)
    ImGui.DrawList_AddQuadFilled(dl,
      cx + r1 * c1, cy + r1 * s1, cx + r2 * c1, cy + r2 * s1,
      cx + r2 * c2, cy + r2 * s2, cx + r1 * c2, cy + r1 * s2, col)
  end
end

local function centered_text(dl, x, y, txt, col, size, bold)
  local f, sz = font(size, bold)
  ImGui.PushFont(ctx, f)
  local w, h = ImGui.CalcTextSize(ctx, txt)
  ImGui.PopFont(ctx)
  ImGui.DrawList_AddTextEx(dl, f, sz, x - w / 2, y - h / 2, col, txt)
end

-- Hit test: returns { ring, pos, inv_zone } or { center = part } or nil
local function hit(mx, my, cx, cy, rad, rot)
  local dx, dy = mx - cx, my - cy
  local d = math.sqrt(dx * dx + dy * dy) / rad
  if d > R_OUT then return nil end
  if d < R_DIM then
    return { center = (dy < 0) and "up" or "down" }
  end
  local ang = math.deg(math.atan(dy, dx)) + 90       -- 0 = top, clockwise
  local pos = math.floor((ang / 30) + rot + 0.5) % 12
  local ring = (d >= R_MAJ) and 1 or ((d >= R_MIN) and 2 or 3)
  local inv_zone = false
  local rc = INV_RECT[ring][pos]
  if rc and not S.auto then
    for _, part in ipairs({ "minus", "val", "plus" }) do
      local b = rc[part]
      if mx >= b[1] and mx <= b[3] and my >= b[2] and my <= b[4] then inv_zone = part end
    end
  end
  return { ring = ring, pos = pos, inv_zone = inv_zone }
end

local function inv_value_text(ring, pos)
  local v = cell_opts(ring, pos).inv
  return v > 0 and ("+" .. v) or tostring(v)
end

-- Change the inversion of a cell by one step (or reset it with step = nil)
local function step_inv(ring, pos, step)
  local o = cell_opts(ring, pos)
  local n = T.ToneCount(o.quality, S.ctype)
  INV[ring][pos] = step and math.max(-n, math.min(n, o.inv + step)) or 0
  save_invs()
  preview_key = nil
end

local function draw_wheel(size)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##wheel", size, size,
    ImGui.ButtonFlags_MouseButtonLeft | ImGui.ButtonFlags_MouseButtonRight)
  local hovered = ImGui.IsItemHovered(ctx)
  local cx, cy = x + size / 2, y + size / 2
  local rad = size / 2 - 2
  local rot = rot_view or S.key_pos
  local fs = size / 440 * S.font_scale
  local spell = spelling()
  local mx, my = ImGui.GetMousePos(ctx)

  -- Hover
  hover = hovered and hit(mx, my, cx, cy, rad, rot) or nil
  if drag and drag.moved then hover = nil end

  -- Cells
  for ring = 1, 3 do
    local r1, r2 = ring_bounds(ring)
    for pos = 0, 11 do
      local mid = pos_angle(pos, rot)
      local a1, a2 = mid - math.rad(15), mid + math.rad(15)
      local label, deg = T.CellDegree(pos, ring, S.key_pos, S.minor)
      local col = deg and DEG_COLOR[deg] or COL_OUT
      local is_hover = hover and hover.ring == ring and hover.pos == pos
      if is_hover then col = lighten(col, 0.35) end
      fill_sector(dl, cx, cy, r1 * rad, r2 * rad, a1, a2, col)

      -- texts, stacked vertically at the cell center: degree / name / inv
      local root_pc, quality = T.CellChord(pos, ring)
      local name = T.CellLabel(root_pc, quality, S.ctype, cell_spell(pos, ring))
      local tcol = deg and COL_TXT_IN or COL_TXT_OUT
      local rm = (r1 + (r2 - r1) * 0.5) * rad
      local tx, ty = cx + rm * math.cos(mid), cy + rm * math.sin(mid)
      local name_size = (ring == 1 and 24 or (ring == 2 and 18 or 13)) * fs
      if #name > 4 then name_size = name_size * 0.85 end
      if #name > 7 then name_size = name_size * 0.8 end
      local gap = name_size * 0.55 + 5 * fs
      centered_text(dl, tx, ty, name, tcol, name_size, true)

      -- inversion: [-] value [+] buttons ("inv A" when Auto is on)
      local f, isz = font(9 * fs, false)
      local iy = ty + gap
      if S.auto then
        INV_RECT[ring][pos] = nil
        centered_text(dl, tx, iy, "inv A", tcol, 9 * fs, false)
      else
        ImGui.PushFont(ctx, f)
        local vw = ImGui.CalcTextSize(ctx, "+3")
        ImGui.PopFont(ctx)
        local bw, bh, g = isz * 1.25, isz * 1.15, 2 * fs
        local x0 = tx - (2 * bw + vw + 2 * g) / 2
        local y1, y2 = iy - bh / 2, iy + bh / 2
        local rc = {
          minus = { x0, y1, x0 + bw, y2 },
          val   = { x0 + bw + g, y1, x0 + bw + g + vw, y2 },
          plus  = { x0 + bw + 2 * g + vw, y1, x0 + 2 * bw + 2 * g + vw, y2 },
        }
        INV_RECT[ring][pos] = rc
        local hz = is_hover and hover.inv_zone or nil
        for _, part in ipairs({ "minus", "plus" }) do
          local b = rc[part]
          local bg = (hz == part) and 0xFFFFFFE0 or 0xFFFFFF70
          ImGui.DrawList_AddRectFilled(dl, b[1], b[2], b[3], b[4], bg, 3)
          ImGui.DrawList_AddRect(dl, b[1], b[2], b[3], b[4], 0x00000050, 3)
          centered_text(dl, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 - 0.5,
            part == "minus" and "-" or "+", 0x202020FF, 10 * fs, true)
        end
        local vcol = (hz == "val") and 0x000000FF or tcol
        centered_text(dl, (rc.val[1] + rc.val[3]) / 2, iy, inv_value_text(ring, pos), vcol, 9 * fs, true)
      end

      -- top line: degree, and on the major ring the key signature (1#, 3b...)
      local top = label
      if ring == 1 then
        local sig = T.KeySignature(pos)
        top = label and (label .. "  " .. sig) or sig
      end
      if top then
        centered_text(dl, tx, ty - gap, top, tcol, 9 * fs, false)
      end
    end
  end

  -- Lines
  for _, f in ipairs({ R_OUT, R_MAJ, R_MIN, R_DIM }) do
    ImGui.DrawList_AddCircle(dl, cx, cy, f * rad, COL_LINE, 96, 2)
  end
  for pos = 0, 11 do
    local a = pos_angle(pos, rot) - math.rad(15)
    ImGui.DrawList_AddLine(dl, cx + R_DIM * rad * math.cos(a), cy + R_DIM * rad * math.sin(a),
      cx + R_OUT * rad * math.cos(a), cy + R_OUT * rad * math.sin(a), COL_LINE, 2)
  end

  -- Center: key and octave
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, R_DIM * rad - 1, COL_CENTER, 64)
  local key_txt
  if S.minor then
    key_txt = spell[(key_pc() + 9) % 12] .. " minor"
  else
    key_txt = spell[key_pc()] .. " major"
  end
  key_txt = key_txt .. "  " .. T.KeySignature(S.key_pos)
  centered_text(dl, cx, cy - R_DIM * rad * 0.58, key_txt, COL_TXT_IN, (#key_txt > 12 and 11 or 13) * fs, true)
  local up_col = (hover and hover.center == "up") and 0x000000FF or COL_TXT_OUT
  local dn_col = (hover and hover.center == "down") and 0x000000FF or COL_TXT_OUT
  local tr = 6 * fs
  local ty = cy - R_DIM * rad * 0.27
  ImGui.DrawList_AddTriangleFilled(dl, cx, ty - tr, cx - tr * 1.2, ty + tr * 0.6, cx + tr * 1.2, ty + tr * 0.6, up_col)
  centered_text(dl, cx, cy + R_DIM * rad * 0.05, "Oct " .. S.octave, COL_TXT_IN, 20 * fs, true)
  ty = cy + R_DIM * rad * 0.37
  ImGui.DrawList_AddTriangleFilled(dl, cx - tr * 1.2, ty - tr * 0.6, cx + tr * 1.2, ty - tr * 0.6, cx, ty + tr, dn_col)
  centered_text(dl, cx, cy + R_DIM * rad * 0.64,
    "C" .. S.octave .. " = " .. T.RootPitch(0, S.octave, oct_offset()), COL_TXT_OUT, 9 * fs, false)

  -- Mouse: left drag rotates, left click inserts
  if hovered and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) then
    local h = hit(mx, my, cx, cy, rad, S.key_pos)
    if h and not h.center then
      drag = { a0 = math.deg(math.atan(my - cy, mx - cx)), moved = false, target = h }
    elseif h and h.center then
      set("octave", math.max(-1, math.min(9, S.octave + (h.center == "up" and 1 or -1))))
    end
  end
  if drag then
    if ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) then
      local a = math.deg(math.atan(my - cy, mx - cx))
      local da = (a - drag.a0 + 540) % 360 - 180
      if math.abs(da) > 4 then drag.moved = true end
      if drag.moved then rot_view = S.key_pos - da / 30 end
    else
      if drag.moved then
        set("key_pos", math.floor((rot_view or S.key_pos) + 0.5) % 12)
        preview_key = nil
      else
        local t = drag.target
        if t.inv_zone == "minus" then step_inv(t.ring, t.pos, -1)
        elseif t.inv_zone == "plus" then step_inv(t.ring, t.pos, 1)
        elseif t.inv_zone == "val" then step_inv(t.ring, t.pos, nil)
        else insert_cell(t.ring, t.pos) end
      end
      drag, rot_view = nil, nil
    end
  end

  -- Right click on the inversion buttons = reset the inversion to 0
  if hovered and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) and hover
     and not hover.center and hover.inv_zone then
    step_inv(hover.ring, hover.pos, nil)
  end

  -- Mouse wheel: center = octave, elsewhere = rotate
  if hovered then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local step = wheel > 0 and 1 or -1
      if hover and hover.center then
        set("octave", math.max(-1, math.min(9, S.octave + step)))
      else
        set("key_pos", (S.key_pos - step) % 12)
      end
      preview_key = nil
    end
  end
end

---------------------------------------------------------------------------
-- Mini keyboard
---------------------------------------------------------------------------

local BLACK = { [1] = true, [3] = true, [6] = true, [8] = true, [10] = true }

local function update_preview()
  local key
  if hover and not hover.center then
    key = hover.ring .. ":" .. hover.pos
  else
    key = "none"
  end
  local now = r.time_precise()
  if key == preview_key and now - preview_t < 0.3 then return end
  preview_key, preview_t = key, now
  if key == "none" then return end   -- keep the last chord shown
  local pitches = chord_pitches(hover.ring, hover.pos, S.auto and previous_chord() or nil)
  preview = { pitches = pitches, name = T.Identify(pitches, cell_spell(hover.pos, hover.ring)) or "",
              spell = cell_spell(hover.pos, hover.ring) }
end

local function draw_keyboard(width)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local p = preview and preview.pitches or {}
  local lo, hi = 48, 83
  if #p > 0 then
    lo = math.min(lo, (p[1] // 12) * 12)
    hi = math.max(hi, (p[#p] // 12) * 12 + 11)
    if hi - lo > 59 then lo = (p[1] // 12) * 12; hi = lo + 59 end
  end
  local whites = 0
  for n = lo, hi do if not BLACK[n % 12] then whites = whites + 1 end end
  local ww = width / whites
  local wh = math.max(36, ww * 4.2)
  local on = {}
  for _, n in ipairs(p) do on[n] = true end

  local wx = {}
  local i = 0
  for n = lo, hi do
    if not BLACK[n % 12] then
      local x1 = x + i * ww
      wx[n] = x1
      ImGui.DrawList_AddRectFilled(dl, x1, y, x1 + ww - 1, y + wh, on[n] and 0x55B8FFFF or 0xFFFFFFFF)
      ImGui.DrawList_AddRect(dl, x1, y, x1 + ww - 1, y + wh, 0x808080FF)
      if n % 12 == 0 then
        local f, sz = font(9 * S.font_scale, false)
        ImGui.DrawList_AddTextEx(dl, f, sz, x1 + 2, y + wh - sz - 2, 0x808080FF,
          "C" .. (n // 12 - 1 + oct_offset()))
      end
      i = i + 1
    end
  end
  for n = lo, hi do
    if BLACK[n % 12] and wx[n - 1] then
      local x1 = wx[n - 1] + ww * 0.65
      ImGui.DrawList_AddRectFilled(dl, x1, y, x1 + ww * 0.7, y + wh * 0.6, on[n] and 0x2E8FE0FF or 0x202020FF)
    end
  end
  ImGui.Dummy(ctx, width, wh + 4)
  local names = {}
  local spell = (preview and preview.spell) or spelling()
  for _, n in ipairs(p) do names[#names + 1] = T.NoteName(n, spell, oct_offset()) end
  if preview then
    ImGui.Text(ctx, (preview.name or "") .. "   " .. table.concat(names, " "))
  else
    ImGui.TextDisabled(ctx, "Hover a chord to see its notes.")
  end
end

---------------------------------------------------------------------------
-- Display: open/close and reopening at REAPER startup (Scripts/__startup.lua)
---------------------------------------------------------------------------

local TAG_BEGIN = "-- >>> ReNo Mellow Chord Buddy Display (added by Chord Buddy) >>>"
local TAG_END   = "-- <<< ReNo Mellow Chord Buddy Display <<<"

local function startup_path() return r.GetResourcePath() .. "/Scripts/__startup.lua" end

local function read_file(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function startup_enabled()
  local s = read_file(startup_path()) or ""
  return s:find(TAG_BEGIN, 1, true) ~= nil
end

local function set_startup(on)
  local p = startup_path()
  local s = read_file(p) or ""
  local a = s:find(TAG_BEGIN, 1, true)
  if a then
    local _, b = s:find(TAG_END, a, true)
    if b then
      if s:sub(b + 1, b + 1) == "\n" then b = b + 1 end
      s = s:sub(1, a - 1) .. s:sub(b + 1)
    end
  end
  if on then
    local path = DISPLAY_SCRIPT:gsub("\\", "/")
    if s ~= "" and not s:match("\n$") then s = s .. "\n" end
    s = s .. TAG_BEGIN .. "\n" ..
      "do\n" ..
      "  local p = " .. string.format("%q", path) .. "\n" ..
      "  if reaper.file_exists(p) then\n" ..
      "    local id = reaper.AddRemoveReaScript(true, 0, p, true)\n" ..
      "    if id and id > 0 then reaper.Main_OnCommand(id, 0) end\n" ..
      "  end\n" ..
      "end\n" .. TAG_END .. "\n"
  end
  local f = io.open(p, "wb")
  if not f then set_status("Cannot write " .. p); return end
  f:write(s)
  f:close()
end

local startup_on = startup_enabled()

local function display_running()
  local b = tonumber(r.GetExtState(EXT, "disp_running")) or 0
  return r.time_precise() - b < 1.0
end

local function toggle_display()
  if not r.file_exists(DISPLAY_SCRIPT) then set_status("Display script not found."); return end
  local id = r.AddRemoveReaScript(true, 0, DISPLAY_SCRIPT, true)
  if id and id > 0 then r.Main_OnCommand(id, 0) end
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function combo(label, cur, items, width)
  -- items = { {value, text}, ... } ; returns new value
  local cur_text = items[1][2]
  for _, it in ipairs(items) do if it[1] == cur then cur_text = it[2] end end
  ImGui.SetNextItemWidth(ctx, width)
  local nv = cur
  if ImGui.BeginCombo(ctx, label, cur_text) then
    for _, it in ipairs(items) do
      if ImGui.Selectable(ctx, it[2], it[1] == cur) then nv = it[1] end
    end
    ImGui.EndCombo(ctx)
  end
  return nv
end

local function toggle_button(label, on, w)
  if on then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x3D85C6FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x5A9BD5FF)
  end
  local pressed = ImGui.Button(ctx, label, w or 0)
  if on then ImGui.PopStyleColor(ctx, 2) end
  return pressed
end

local function tab_main()
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Row 1: mode, length, auto, bass, voicing
  if toggle_button("Major", not S.minor) then set("minor", false) end
  ImGui.SameLine(ctx)
  if toggle_button("Minor", S.minor) then set("minor", true) end
  ImGui.SameLine(ctx, 0, 16)
  set("mult", combo("##len", S.mult, LENGTHS, 90))
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Chord length (MIDI editor grid)") end
  ImGui.SameLine(ctx, 0, 16)
  if toggle_button("Auto", S.auto) then set("auto", not S.auto); preview_key = nil end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Auto inversion: closest to the previous chord") end
  ImGui.SameLine(ctx)
  if toggle_button("Bass", S.bass) then set("bass", not S.bass); preview_key = nil end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Add the root an octave below") end
  ImGui.SameLine(ctx)
  local items = {}
  for _, v in ipairs(T.VOICINGS) do items[#items + 1] = { v, T.VOICING_LABEL[v] } end
  local nv = combo("##voicing", S.voicing, items, 80)
  if nv ~= S.voicing then set("voicing", nv); preview_key = nil end

  -- Wheel
  local size = math.max(240, math.min(S.wheel_size, avail_w))
  ImGui.Dummy(ctx, 0, 2)
  local cur_x = ImGui.GetCursorPosX(ctx)
  ImGui.SetCursorPosX(ctx, cur_x + math.max(0, (avail_w - size) / 2))
  draw_wheel(size)

  -- Chord types
  local bw = math.floor((avail_w - 6 * 4) / 7)
  for i, t in ipairs(T.TYPES) do
    if i > 1 then ImGui.SameLine(ctx, 0, 4) end
    if toggle_button(T.TYPE_LABEL[t], S.ctype == t, bw) then set("ctype", t); preview_key = nil end
  end

  -- Strum / humanize
  ImGui.SetNextItemWidth(ctx, avail_w / 2 - 50)
  local ch, v = ImGui.SliderInt(ctx, "Strum ms", S.strum, 0, 120)
  if ch then set("strum", v) end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, avail_w / 2 - 70)
  ch, v = ImGui.SliderInt(ctx, "Humanize", S.human, 0, 30)
  if ch then set("human", v) end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Random velocity variation (+/-)") end

  -- Keyboard (and tooltip of the hovered cell)
  update_preview()
  if hover and not hover.center and preview and not drag then
    local label = T.CellDegree(hover.pos, hover.ring, S.key_pos, S.minor)
    local spell = preview.spell or spelling()
    local names = {}
    for _, n in ipairs(preview.pitches) do names[#names + 1] = T.NoteName(n, spell, oct_offset()) end
    ImGui.SetTooltip(ctx, (preview.name or "") .. (label and ("   (" .. label .. ")") or "") ..
      "\n" .. table.concat(names, " "))
  end
  ImGui.Dummy(ctx, 0, 2)
  draw_keyboard(avail_w)

  -- Status
  if status ~= "" and r.time_precise() - status_t < 4 then
    ImGui.TextColored(ctx, 0xE0A040FF, status)
  else
    ImGui.TextDisabled(ctx, "Click = insert   - / + = inversion   Click on the number = 0")
  end
end

local function tab_setup()
  ImGui.SeparatorText(ctx, "Window")
  ImGui.SetNextItemWidth(ctx, 200)
  local ch, v = ImGui.SliderDouble(ctx, "Opacity", S.opacity, 0.2, 1.0, "%.2f")
  if ch then set("opacity", v) end
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = ImGui.SliderInt(ctx, "Wheel size", S.wheel_size, 240, 900)
  if ch then set("wheel_size", v) end
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = ImGui.SliderDouble(ctx, "Text size", S.font_scale, 0.6, 1.6, "%.2f")
  if ch then set("font_scale", v) end

  ImGui.SeparatorText(ctx, "Insertion")
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = ImGui.SliderInt(ctx, "Velocity", S.vel, 1, 127)
  if ch then set("vel", v) end
  ch, v = ImGui.Checkbox(ctx, "Replace existing notes", S.replace)
  if ch then set("replace", v) end
  ch, v = ImGui.Checkbox(ctx, "Move edit cursor to the end of the chord", S.advance)
  if ch then set("advance", v) end

  ImGui.SeparatorText(ctx, "Note names")
  local nsp = combo("Spelling", S.spell,
    { { "key", "Follow the key" }, { "sharps", "Always sharps" }, { "flats", "Always flats" } }, 200)
  if nsp ~= S.spell then set("spell", nsp) end

  local rop = M.ReaperOctaveOffset()
  local nm = combo("Octave naming", S.oct_mode,
    { { "auto", "Like REAPER" }, { "manual", "Manual" } }, 200)
  if nm ~= S.oct_mode then set("oct_mode", nm) end
  if S.oct_mode == "manual" then
    ImGui.SetNextItemWidth(ctx, 200)
    ch, v = ImGui.SliderInt(ctx, "Octave offset", S.oct_manual, -2, 2)
    if ch then set("oct_manual", v) end
  end
  ImGui.TextDisabled(ctx, string.format("Note 60 is named %s  (REAPER setting read: %s)",
    T.NoteName(60, spelling(), oct_offset()), rop and tostring(rop) or "not found"))

  ImGui.SeparatorText(ctx, "Export (Display)")
  local modes = E.ParseModes(S.export_modes)
  for _, m in ipairs(E.MODES) do
    local c, val = ImGui.Checkbox(ctx, m.label, modes[m.id])
    if c then modes[m.id] = val; set("export_modes", E.ModesString(modes)) end
  end
  ImGui.SetNextItemWidth(ctx, 200)
  local ct, tn = ImGui.InputText(ctx, "Chords track name", S.chords_track)
  if ct and tn ~= "" then set("chords_track", tn) end
  ch, v = ImGui.Checkbox(ctx, "Color exported items and markers by degree", S.color_items)
  if ch then set("color_items", v) end
  ImGui.TextDisabled(ctx, "Click Export = ticked modes. Right click Export = one mode.")

  ImGui.SeparatorText(ctx, "Display")
  if ImGui.Button(ctx, display_running() and "Close Display" or "Open Display") then toggle_display() end
  ch, v = ImGui.Checkbox(ctx, "Open the Display when REAPER starts", startup_on)
  if ch then set_startup(v); startup_on = startup_enabled() end
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = ImGui.SliderInt(ctx, "Display text size", S.disp_size, 12, 40)
  if ch then set("disp_size", v) end
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = ImGui.SliderDouble(ctx, "Display opacity", S.disp_opacity, 0.2, 1.0, "%.2f")
  if ch then set("disp_opacity", v) end

  ImGui.SeparatorText(ctx, "About")
  ImGui.TextDisabled(ctx, "ReNo Mellow - Chord Buddy " .. VERSION)
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------

local open_tab_setup = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 520, 760, ImGui.Cond_FirstUseEver)
  ImGui.SetNextWindowBgAlpha(ctx, S.opacity)
  local visible, open = ImGui.Begin(ctx, TITLE, true, ImGui.WindowFlags_NoScrollWithMouse)
  if visible then
    local f = font(14 * S.font_scale, false)
    ImGui.PushFont(ctx, f)
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Chord Buddy") then
        tab_main()
        ImGui.EndTabItem(ctx)
      end
      local flags = open_tab_setup and ImGui.TabItemFlags_SetSelected or 0
      open_tab_setup = false
      if ImGui.BeginTabItem(ctx, "Set up", nil, flags) then
        tab_setup()
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
  if open then
    r.defer(loop)
  end
end

r.atexit(function()
  r.SetExtState(EXT, "running", "0", false)
  set_toggle(false)
end)

-- Running the action again while the window is open closes it
local now = r.time_precise()
local beat = tonumber(r.GetExtState(EXT, "running")) or 0
if now - beat < 1.0 then
  r.SetExtState(EXT, "close_request", tostring(now), false)
  return
end

set_toggle(true)
create_context()

local base_loop = loop
loop = function()
  r.SetExtState(EXT, "running", tostring(r.time_precise()), false)
  local req = tonumber(r.GetExtState(EXT, "close_request")) or 0
  if req > 0 and r.time_precise() - req < 2 then
    r.SetExtState(EXT, "close_request", "0", false)
    return
  end
  if r.GetExtState(EXT, "open_setup") == "1" then
    r.SetExtState(EXT, "open_setup", "0", false)
    open_tab_setup = true
  end
  base_loop()
end
r.defer(loop)
