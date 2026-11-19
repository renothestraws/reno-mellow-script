-- @description ReNo Mellow - Grid Buddy
-- @author ReNo Mellow
-- @version 1.0
-- @about Grille de l'arrangement et de l'éditeur MIDI dans une fenêtre à 2 onglets : type (straight, triplet, quintolet, septolet, pointé, swing), tailles fixes, grille adaptative au zoom (5 tailles + taille perso, service de fond), limites et diviseur, snap, mini Display et actions isolées (molette, plus large / plus étroite, modes adaptatifs). D'après Adaptive Grid et Gridbox de FeedTheCat. Nécessite ReaImGui.
-- @changelog Première version
-- @provides
--   GB_lib.lua
--   GB_startup.lua
--   [main] ReNo Mellow - Grid Buddy - Display.lua
--   [main] ReNo Mellow - Grid Buddy - Service.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive off (fixed).lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive narrowest.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive narrow.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive medium.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive wide.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive widest.lua
--   [main] ReNo Mellow - Grid Buddy - Adaptive custom.lua
--   [main] ReNo Mellow - Grid Buddy - Adjust grid (mousewheel).lua
--   [main] ReNo Mellow - Grid Buddy - Adjust fixed grid (mousewheel).lua
--   [main] ReNo Mellow - Grid Buddy - Wider grid.lua
--   [main] ReNo Mellow - Grid Buddy - Narrower grid.lua
--   [main] ReNo Mellow - Grid Buddy - Adapt grid to zoom.lua
--   [main] ReNo Mellow - Grid Buddy - Toggle swing.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive off (fixed).lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive off (fixed).lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive narrowest.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive narrowest.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive narrow.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive narrow.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive medium.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive medium.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive wide.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive wide.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive widest.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive widest.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive custom.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adaptive custom.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adjust grid (mousewheel).lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adjust grid (mousewheel).lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adjust fixed grid (mousewheel).lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adjust fixed grid (mousewheel).lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Wider grid.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Wider grid.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Narrower grid.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Narrower grid.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Adapt grid to zoom.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Adapt grid to zoom.lua
--   [midi_editor] MIDI/ReNo Mellow - Grid Buddy MIDI - Toggle swing.lua > MIDI/ReNo Mellow - Grid Buddy MIDI - Toggle swing.lua
--   [data] Data/toolbar_icons/ReNo_GridBuddy.png > toolbar_icons/ReNo_GridBuddy.png
--   [data] Data/toolbar_icons/150/ReNo_GridBuddy.png > toolbar_icons/150/ReNo_GridBuddy.png
--   [data] Data/toolbar_icons/200/ReNo_GridBuddy.png > toolbar_icons/200/ReNo_GridBuddy.png

local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "GB_lib.lua")

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.",
    "Grid Buddy", 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

-- toolbar toggle on while open, launching it again closes the window
if reaper.set_action_options then reaper.set_action_options(1 | 4) end
local _, _, self_sec, self_cmd = reaper.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    reaper.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    reaper.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)
GB.register_self("cmd_main")

-- first launch (manual install or .ReaperPkg): adds the other actions to the action list
if reaper.GetExtState(GB.S, "reg_v") ~= GB.VERSION then
  local todo = {}
  for _, n in ipairs({ "Display", "Service" }) do
    todo[#todo + 1] = { 0, dir .. "ReNo Mellow - Grid Buddy - " .. n .. ".lua" }
  end
  for _, n in ipairs(GB.ACTIONS) do
    todo[#todo + 1] = { 0, dir .. "ReNo Mellow - Grid Buddy - " .. n .. ".lua" }
    todo[#todo + 1] = { 32060, dir .. "MIDI/ReNo Mellow - Grid Buddy MIDI - " .. n .. ".lua" }
  end
  for i, t in ipairs(todo) do
    if reaper.file_exists(t[2]) then reaper.AddRemoveReaScript(true, t[1], t[2], i == #todo) end
  end
  GB.set("reg_v", GB.VERSION)
end

---------------------------------------------------------------- colours (RRGGBBAA)
local COL_ON    = 0x3F7FC9FF
local COL_ADAPT = 0x7CF0A6FF
local COL_GREY  = 0x9A9A9AFF
local COL_WARN  = 0xF0A040FF
local COL_ERR   = 0xE05555FF
local COL_TEXT  = 0xE8E8E8FF

local function lighten(c, a)
  local rr = math.min(255, ((c >> 24) & 255) + a)
  local g = math.min(255, ((c >> 16) & 255) + a)
  local b = math.min(255, ((c >> 8) & 255) + a)
  return (rr << 24) | (g << 16) | (b << 8) | (c & 255)
end

---------------------------------------------------------------- state
local ctx -- created just before the first frame
local FONT_MIN, FONT_MAX = 10, 28
local BIG_SIZES = { 16, 20, 24, 28, 32, 40, 48 }
local fonts, big = {}, {}
local post = nil -- modal dialogs / launches run after ImGui.End
local function later(fn) post = fn end
local last_svc_check = 0

local function opt(k, d) return tonumber(GB.get(k, d)) or d end
local function text_size() return math.floor(GB.clamp(opt("font", 14), FONT_MIN, FONT_MAX)) end

local function big_font(px)
  local best = BIG_SIZES[1]
  for _, s in ipairs(BIG_SIZES) do if s <= px then best = s end end
  return big[best]
end

local function sel_button(label, on, w)
  if on then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, COL_ON)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, lighten(COL_ON, 18))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, lighten(COL_ON, 30))
  end
  local clicked = ImGui.Button(ctx, label, w or 0, 0)
  if on then ImGui.PopStyleColor(ctx, 3) end
  return clicked
end

local function row_label(txt)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.TextColored(ctx, COL_GREY, txt)
  ImGui.SameLine(ctx, text_size() * 6)
end

local function tip(txt)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then ImGui.SetTooltip(ctx, txt) end
end

local function visible_types()
  local list = { "straight", "triplet" }
  if GB.flag("show_quint", false) then list[#list + 1] = "quintuplet" end
  if GB.flag("show_sept", false) then list[#list + 1] = "septuplet" end
  list[#list + 1] = "dotted"
  return list
end

---------------------------------------------------------------- tab 1 : Grid
local function section(c)
  local is_midi = c == "midi"
  ImGui.SeparatorText(ctx, is_midi and "MIDI editor" or "Arrange view")

  local d, sw, amt = GB.current(c)
  local m = GB.mult(c)
  local txt
  if not is_midi and GB.is_frame() then txt = "Frame"
  elseif not is_midi and GB.is_measure() then txt = "Measure"
  elseif d then txt = GB.grid_text(d)
  else txt = "No MIDI editor open" end

  ImGui.PushFont(ctx, big_font(text_size() * 2))
  ImGui.TextColored(ctx, d and COL_TEXT or COL_GREY, txt)
  ImGui.PopFont(ctx)
  if m ~= 0 then
    ImGui.SameLine(ctx, 0, 16)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL_ADAPT, "ADAPTIVE  " .. GB.MODE_NAME[m])
  end
  if d and sw == 1 then
    ImGui.SameLine(ctx, 0, 16)
    if is_midi then ImGui.TextColored(ctx, COL_GREY, "Swing")
    else ImGui.TextColored(ctx, COL_GREY, string.format("Swing %d %%", math.floor(amt * 100 + 0.5))) end
  end
  if is_midi and GB.synced() then
    ImGui.TextColored(ctx, COL_WARN, "\"Use the same grid division in arrange view and MIDI editor\" is on.")
  end

  ImGui.BeginDisabled(ctx, d == nil)
  -- type
  row_label("Type")
  for _, t in ipairs(visible_types()) do
    if sel_button(GB.TYPE_LABEL[t] .. "##t" .. c, GB.is_type(c, t)) then
      later(function() GB.set_type(c, t) end)
    end
    ImGui.SameLine(ctx)
  end
  if sel_button("Swing##t" .. c, GB.is_type(c, "swing")) then later(function() GB.set_type(c, "swing") end) end
  if is_midi then tip("Swing amount: use the MIDI editor grid settings.") end

  if not is_midi and sw == 1 then
    row_label("Swing")
    ImGui.SetNextItemWidth(ctx, text_size() * 16)
    local ch, v = ImGui.SliderInt(ctx, "##swing", math.floor((amt or 0) * 100 + 0.5), -100, 100, "%d %%")
    if ch then GB.set_swing(v / 100) end
  end

  -- fixed sizes
  row_label("Fixed")
  if not is_midi then
    if GB.flag("show_frame", false) then
      if sel_button("Frame", GB.is_frame()) then later(GB.set_frame) end
      ImGui.SameLine(ctx)
    end
    if GB.flag("show_measure", false) then
      if sel_button("Measure", GB.is_measure()) then later(GB.set_measure) end
      ImGui.SameLine(ctx)
    end
  end
  for _, s in ipairs(GB.SIZES) do
    if sel_button(s[1] .. "##f" .. c, GB.is_fixed(c, s[2])) then later(function() GB.set_fixed(c, s[2]) end) end
    ImGui.SameLine(ctx)
  end
  ImGui.Dummy(ctx, 8, 0) ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "-##n" .. c) then
    later(function() if GB.is_adaptive(c) then GB.step_adaptive(c, -1) else GB.step_fixed(c, -1) end end)
  end
  tip("Narrower grid (divided by the grid divisor, or the next adaptive size)")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "+##w" .. c) then
    later(function() if GB.is_adaptive(c) then GB.step_adaptive(c, 1) else GB.step_fixed(c, 1) end end)
  end
  tip("Wider grid (multiplied by the grid divisor, or the next adaptive size)")
  ImGui.EndDisabled(ctx)

  -- adaptive modes (can be set without an open MIDI editor)
  row_label("Adaptive")
  if sel_button("Off##a" .. c, m == 0) then later(function() GB.apply_mult(c, 0) end) end
  tip("Fixed grid: the grid does not follow the zoom")
  for _, md in ipairs(GB.MODES) do
    ImGui.SameLine(ctx)
    if sel_button(md[1] .. "##a" .. c, m == md[2]) then later(function() GB.toggle_mult(c, md[2]) end) end
    if md[2] == -1 then
      local sp = GB.custom_spacing(c)
      tip(sp and string.format("Custom: grid lines at least %s px apart (Set up tab)", sp)
        or "Custom: you will be asked for the spacing in pixels")
    end
  end

  -- snap
  row_label("Snap")
  if is_midi then
    ImGui.BeginDisabled(ctx, GB.midi_editor() == nil)
    if sel_button("Snap##s" .. c, GB.midi_snap_on()) then later(GB.midi_toggle_snap) end
    ImGui.EndDisabled(ctx)
  else
    if sel_button("Snap##s" .. c, GB.snap_on()) then later(GB.toggle_snap) end
    ImGui.SameLine(ctx)
    if sel_button("Relative##s" .. c, GB.rel_snap_on()) then later(GB.toggle_rel_snap) end
    tip("Relative grid snap")
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Snap/grid settings...") then later(GB.snap_settings) end
  end
  ImGui.Dummy(ctx, 0, 4)
end

local function tab_grid()
  section("arrange")
  section("midi")
end

---------------------------------------------------------------- tab 2 : Set up
local buf = {}
local note = {}

local function init_buf(c)
  if buf[c] then return end
  local sp = GB.custom_spacing(c)
  buf[c] = {
    sp = sp and tostring(sp) or "",
    div = tostring(GB.divisor(c)),
    mn = tostring(GB.cget(c, "min_limit_str", "")),
    mx = tostring(GB.cget(c, "max_limit_str", "")),
  }
end

local function input(label, c, k, w, hint)
  ImGui.SetNextItemWidth(ctx, w)
  local ch, v = ImGui.InputTextWithHint(ctx, label .. "##" .. k .. c, hint or "", buf[c][k])
  if ch then buf[c][k] = v end
  return ImGui.IsItemDeactivatedAfterEdit(ctx)
end

local function setup_ctx(c)
  init_buf(c)
  ImGui.SeparatorText(ctx, c == "midi" and "MIDI editor" or "Arrange view")
  local w = text_size() * 6

  if input("Custom size (px)", c, "sp", w, "e.g. 30") then
    local ok, msg = GB.set_custom_spacing(c, buf[c].sp)
    note[c] = msg and { msg, ok and COL_WARN or COL_ERR } or nil
    if ok and GB.mult(c) == -1 then GB.adapt(c) end
  end
  tip("Adaptive Custom mode: smallest distance between two grid lines, in pixels")
  ImGui.SameLine(ctx, 0, 20)
  if input("Grid divisor", c, "div", w, "2") then
    local f = tonumber(buf[c].div)
    if buf[c].div == "" then f = 2 end
    if not f or f <= 1 then note[c] = { "The grid divisor must be greater than 1.", COL_ERR }
    else GB.cset(c, "zoom_div", string.format("%.32f", f)) note[c] = nil buf[c].div = tostring(f) end
  end
  tip("Each step multiplies / divides the grid by this value (2 = 1/8 -> 1/16)")

  local a = input("Min size", c, "mn", w, "e.g. 1/128")
  ImGui.SameLine(ctx, 0, 20)
  local b = input("Max size", c, "mx", w, "e.g. 1")
  tip("Limits for the adaptive grid and the mouse wheel: 1/128, 1/8T, 1D, 2... Empty = no limit")
  if a or b then
    local ok, err = GB.set_limits(c, buf[c].mn, buf[c].mx)
    note[c] = (not ok) and { err, COL_ERR } or nil
  end
  if note[c] then ImGui.TextColored(ctx, note[c][2], note[c][1]) end
end

local function checkbox(label, key, default, help)
  local ch, v = ImGui.Checkbox(ctx, label, GB.flag(key, default))
  if ch then GB.set_flag(key, v) end
  if help then tip(help) end
  return ch, v
end

local function tab_setup()
  setup_ctx("arrange")
  ImGui.Dummy(ctx, 0, 4)
  setup_ctx("midi")
  ImGui.Dummy(ctx, 0, 4)

  ImGui.SeparatorText(ctx, "Grid")
  checkbox("Preserve grid type per size", "preserve_grid_type", false,
    "The project remembers the type (triplet, swing...) used for every size")
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.TextColored(ctx, COL_GREY, "Show:")
  ImGui.SameLine(ctx) checkbox("Quintuplet", "show_quint", false)
  ImGui.SameLine(ctx) checkbox("Septuplet", "show_sept", false)
  ImGui.SameLine(ctx) checkbox("Frame", "show_frame", false)
  ImGui.SameLine(ctx) checkbox("Measure", "show_measure", false)
  checkbox("Reverse mouse wheel", "wheel_rev", false, "For the Display and the mousewheel actions")

  ImGui.SeparatorText(ctx, "Adaptive service")
  local alive = GB.service_alive()
  ImGui.TextColored(ctx, alive and COL_ADAPT or COL_GREY,
    alive and "Running (follows the zoom)" or "Stopped (starts when an adaptive mode is chosen)")
  local ch = checkbox("Keep the adaptive mode when REAPER restarts", "svc_startup", false,
    "Starts the service with REAPER. Off: the grids are set back to fixed at start-up")
  if ch then GB.ensure_startup_hook() end

  ImGui.SeparatorText(ctx, "Display")
  if ImGui.Button(ctx, GB.alive("display") and "Hide Display" or "Show Display") then
    later(function() GB.launch("display") end)
  end
  ImGui.SameLine(ctx, 0, 20)
  ImGui.SetNextItemWidth(ctx, 160)
  local c2, val = ImGui.SliderInt(ctx, "Display text size", math.floor(GB.clamp(opt("disp_font", 16), FONT_MIN, FONT_MAX)),
    FONT_MIN, FONT_MAX)
  if c2 then GB.set("disp_font", val) end
  checkbox("Snap button", "disp_snap", true)
  ImGui.SameLine(ctx) checkbox("Swing bar", "disp_swing", true)
  ImGui.SameLine(ctx) checkbox("MIDI editor grid", "disp_midi", true, "Second line when a MIDI editor is open")
  ImGui.SameLine(ctx) checkbox("Visible grid", "disp_visible", false,
    "Shows the grid REAPER really draws at this zoom (straight sizes only)")

  ImGui.SeparatorText(ctx, "Window")
  ImGui.SetNextItemWidth(ctx, 160)
  local c3, val3 = ImGui.SliderInt(ctx, "Text size", text_size(), FONT_MIN, FONT_MAX)
  if c3 then GB.set("font", val3) end
  ImGui.Dummy(ctx, 0, 4)
  ImGui.TextColored(ctx, COL_GREY, "Based on Adaptive Grid and Gridbox by FeedTheCat. Do not run both at the same time.")
end

---------------------------------------------------------------- main loop
local function loop()
  reaper.SetExtState(GB.RT, "alive_main", tostring(reaper.time_precise()), false)
  local now = reaper.time_precise()
  if now - last_svc_check > 1 then last_svc_check = now GB.start_service() end

  local want = reaper.GetExtState(GB.RT, "want_tab")
  local goto_tab = nil
  if want ~= "" then
    reaper.DeleteExtState(GB.RT, "want_tab", false)
    goto_tab = tonumber(want)
    ImGui.SetNextWindowFocus(ctx)
  end

  ImGui.PushFont(ctx, fonts[text_size()])
  ImGui.SetNextWindowSize(ctx, 860, 600, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, "ReNo Mellow - Grid Buddy " .. GB.VERSION, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Grid", nil, goto_tab == 1 and ImGui.TabItemFlags_SetSelected or 0) then
        tab_grid()
        ImGui.EndTabItem(ctx)
      end
      if ImGui.BeginTabItem(ctx, "Set up", nil, goto_tab == 2 and ImGui.TabItemFlags_SetSelected or 0) then
        tab_setup()
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if post then local f = post post = nil f() end
  if open then reaper.defer(loop) end
end

reaper.atexit(function()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  reaper.DeleteExtState(GB.RT, "alive_main", false)
end)

GB.refresh_toggles("arrange")
GB.refresh_toggles("midi")

reaper.defer(function()
  ctx = ImGui.CreateContext("ReNo Mellow - Grid Buddy")
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  for _, sz in ipairs(BIG_SIZES) do
    big[sz] = ImGui.CreateFont("sans-serif", sz, ImGui.FontFlags_Bold)
    ImGui.Attach(ctx, big[sz])
  end
  loop()
end)
