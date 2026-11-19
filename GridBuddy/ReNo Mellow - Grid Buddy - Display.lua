-- @noindex
-- Small floating window showing the grid (place it anywhere, e.g. next to the transport).
-- Click: grid menu | Wheel: grid size | Alt+click: swing on/off | Alt+wheel: swing amount
-- Snap icon: click = snap, Alt+click = relative snap, right-click = snap/grid settings
-- Right-click on the grid: Grid Buddy window. Launching this script again closes the window.

local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "GB_lib.lua")

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.",
    "Grid Buddy", 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

if reaper.set_action_options then reaper.set_action_options(1 | 2 | 4) end
local _, _, self_sec, self_cmd = reaper.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    reaper.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    reaper.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)
GB.register_self("cmd_display")

-- Open / close handshake (same as the other Buddy Displays): the running window
-- writes a heartbeat (not saved) every frame. A launch that finds a fresh heartbeat
-- is a "close" request. "disp_wanted" (saved) lets GB_startup.lua reopen the window.
local HB, QUIT = "alive_display", "disp_quit"
local hb = tonumber(reaper.GetExtState(GB.RT, HB))
if hb and reaper.time_precise() - hb < 1.0 then
  reaper.SetExtState(GB.RT, QUIT, "1", false)
  GB.set("disp_wanted", "0")
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end
reaper.DeleteExtState(GB.RT, QUIT, false)
GB.set("disp_wanted", "1")
GB.ensure_startup_hook()

local FONT_MIN, FONT_MAX = 10, 28
local COL_BG       = 0x2B2D31FF
local COL_TEXT     = 0xE8E8E8FF
local COL_GREY     = 0x9A9A9AFF
local COL_ADAPT    = 0x7CF0A6FF
local COL_SWING    = 0x4FA3E8FF
local COL_SNAP_ON  = 0x4FA3E8FF
local COL_SNAP_OFF = 0x787878FF
local COL_SEP      = 0x45474CFF

local SWING_AMOUNTS = { 53, 55, 57, 59, 61, 64, 67, 70, 73, 75 }

local ctx
local fonts = {}
local first_frame = true
local hover_since = nil
local post = nil
local function later(fn) post = fn end
local last_svc_check = 0

local function lighten(c, a)
  local rr = math.min(255, ((c >> 24) & 255) + a)
  local g = math.min(255, ((c >> 16) & 255) + a)
  local b = math.min(255, ((c >> 8) & 255) + a)
  return (rr << 24) | (g << 16) | (b << 8) | (c & 255)
end

local function text_size()
  return math.floor(GB.clamp(tonumber(GB.get("disp_font", 16)) or 16, FONT_MIN, FONT_MAX))
end

local function alt_down() return (ImGui.GetKeyMods(ctx) & ImGui.Mod_Alt) ~= 0 end
local function ctrl_down() return (ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl) ~= 0 end

-- a click is a release without drag (dragging moves the window)
local function clicked(btn)
  if not ImGui.IsItemHovered(ctx) or not ImGui.IsMouseReleased(ctx, btn) then return false end
  local dx, dy = ImGui.GetMouseDragDelta(ctx, btn)
  return math.abs(dx) < 3 and math.abs(dy) < 3
end

---------------------------------------------------------------- grid menu
local function menu(c)
  if not ImGui.BeginPopup(ctx, "gbmenu_" .. c) then return end
  local is_midi = c == "midi"
  ImGui.TextDisabled(ctx, is_midi and "MIDI editor" or "Arrange view")
  ImGui.Separator(ctx)
  local types = { "straight", "triplet" }
  if GB.flag("show_quint", false) then types[#types + 1] = "quintuplet" end
  if GB.flag("show_sept", false) then types[#types + 1] = "septuplet" end
  types[#types + 1] = "dotted"
  for _, t in ipairs(types) do
    if ImGui.MenuItem(ctx, GB.TYPE_LABEL[t], nil, GB.is_type(c, t)) then later(function() GB.set_type(c, t) end) end
  end
  if is_midi then
    if ImGui.MenuItem(ctx, "Swing", nil, GB.is_type(c, "swing")) then later(function() GB.set_type(c, "swing") end) end
  elseif ImGui.BeginMenu(ctx, "Swing") then
    local _, sw, amt = GB.get_grid()
    local on = sw == 1
    if ImGui.MenuItem(ctx, "Off", nil, not on) then later(GB.swing_off) end
    for _, v in ipairs(SWING_AMOUNTS) do
      local cur = on and math.floor(amt * 100 + 0.5) == v
      if ImGui.MenuItem(ctx, v .. " %", nil, cur) then later(function() GB.set_swing(v / 100) end) end
    end
    ImGui.EndMenu(ctx)
  end

  ImGui.Separator(ctx)
  ImGui.TextDisabled(ctx, "Fixed")
  if not is_midi then
    if GB.flag("show_frame", false) and ImGui.MenuItem(ctx, "Frame", nil, GB.is_frame()) then later(GB.set_frame) end
    if GB.flag("show_measure", false) and ImGui.MenuItem(ctx, "Measure", nil, GB.is_measure()) then later(GB.set_measure) end
  end
  for _, s in ipairs(GB.SIZES) do
    if ImGui.MenuItem(ctx, s[1], nil, GB.is_fixed(c, s[2])) then later(function() GB.set_fixed(c, s[2]) end) end
  end

  ImGui.Separator(ctx)
  ImGui.TextDisabled(ctx, "Adaptive")
  local m = GB.mult(c)
  for _, md in ipairs(GB.MODES) do
    if ImGui.MenuItem(ctx, md[1], nil, m == md[2]) then later(function() GB.toggle_mult(c, md[2]) end) end
  end

  ImGui.Separator(ctx)
  if not is_midi and ImGui.BeginMenu(ctx, "MIDI editor") then
    local mm = GB.mult("midi")
    if ImGui.MenuItem(ctx, "Fixed", nil, mm == 0) then later(function() GB.apply_mult("midi", 0) end) end
    for _, md in ipairs(GB.MODES) do
      if ImGui.MenuItem(ctx, md[1], nil, mm == md[2]) then later(function() GB.toggle_mult("midi", md[2]) end) end
    end
    ImGui.EndMenu(ctx)
  end
  if ImGui.MenuItem(ctx, "Open Grid Buddy...") then later(function() GB.open_main(1) end) end
  if ImGui.MenuItem(ctx, "Set up...") then later(function() GB.open_main(2) end) end
  ImGui.EndPopup(ctx)
end

---------------------------------------------------------------- drawing
local function draw_snap(dl, x, y, s, on, hovered, rel)
  local col = on and COL_SNAP_ON or COL_SNAP_OFF
  if hovered then col = lighten(col, 30) end
  local cx, cy = x + s * 0.45, y + s / 2
  local rr, th = s * 0.26, math.max(2, s * 0.13)
  ImGui.DrawList_PathArcTo(dl, cx, cy, rr, math.pi * 0.5, math.pi * 1.5)
  ImGui.DrawList_PathStroke(dl, col, 0, th)
  local arm = s * 0.38
  ImGui.DrawList_AddLine(dl, cx, cy - rr, cx + arm, cy - rr, col, th)
  ImGui.DrawList_AddLine(dl, cx, cy + rr, cx + arm, cy + rr, col, th)
  local tipc = lighten(col, 60)
  ImGui.DrawList_AddRectFilled(dl, cx + arm * 0.6, cy - rr - th / 2, cx + arm, cy - rr + th / 2, tipc)
  ImGui.DrawList_AddRectFilled(dl, cx + arm * 0.6, cy + rr - th / 2, cx + arm, cy + rr + th / 2, tipc)
  if rel then ImGui.DrawList_AddCircleFilled(dl, x + s * 0.12, cy, th * 0.6, col) end
end

-- one line of grid text; returns true when hovered
local function grid_line(c, main_line)
  local dl = ImGui.GetWindowDrawList(ctx)
  local is_midi = c == "midi"
  local d, sw, amt = GB.current(c)
  local adaptive = GB.is_adaptive(c)
  local txt
  if not is_midi and GB.is_frame() then txt = "Frame" adaptive = false
  elseif not is_midi and GB.is_measure() then txt = "Measure" adaptive = false
  elseif d then
    local shown = d
    if not is_midi and not adaptive and GB.flag("disp_visible", false) then shown = GB.visible_div(d) end
    txt = GB.grid_text(shown)
  else txt = "-" end

  -- Alt over the arrange grid: swing state
  local hovering = ImGui.IsWindowHovered(ctx)
  if not is_midi and hovering and alt_down() and d then
    txt = sw == 1 and string.format("Swing %d%%", math.floor(amt * 100 + 0.5)) or "Swing off"
    adaptive = false
  end

  local prefix = is_midi and "MIDI " or ""
  local a_txt = adaptive and "A " or ""
  local pw = ImGui.CalcTextSize(ctx, prefix)
  local aw = ImGui.CalcTextSize(ctx, a_txt)
  local tw, th = ImGui.CalcTextSize(ctx, txt)
  local h = ImGui.GetTextLineHeight(ctx)
  local w = math.max(pw + aw + tw, h * 4.2)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local bar = main_line and GB.flag("disp_swing", true) and sw == 1 and (amt or 0) ~= 0 and not is_midi
  ImGui.Dummy(ctx, w, h + 4)
  local tx = x + (w - (pw + aw + tw)) / 2
  local ty = y + (h - th) / 2
  if prefix ~= "" then ImGui.DrawList_AddText(dl, tx, ty, COL_GREY, prefix) tx = tx + pw end
  if a_txt ~= "" then ImGui.DrawList_AddText(dl, tx, ty, COL_ADAPT, a_txt) tx = tx + aw end
  ImGui.DrawList_AddText(dl, tx, ty, is_midi and COL_GREY or COL_TEXT, txt)
  if bar then
    local len = math.ceil(math.abs(amt) * w / 2)
    local bx = amt > 0 and x + w / 2 or x + w / 2 - len
    ImGui.DrawList_AddRectFilled(dl, bx, y + h + 1, bx + len, y + h + 4, COL_SWING, 1)
  end
  return ImGui.IsItemHovered(ctx)
end

local function handle_grid(c, hovered)
  if not hovered then return end
  local is_midi = c == "midi"
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel ~= 0 then
    if not is_midi and alt_down() then
      local _, _, amt = GB.get_grid()
      local step = (ctrl_down() and 0.01 or 0.03) * (wheel > 0 and 1 or -1)
      later(function() GB.set_swing((amt or 0) + step) end)
    else
      local dir = wheel > 0 and -1 or 1 -- wheel up = finer grid
      if GB.flag("wheel_rev", false) then dir = -dir end
      later(function() GB.step(c, dir) end)
    end
  end
  if clicked(ImGui.MouseButton_Left) then
    if not is_midi and alt_down() then later(function() GB.set_type("arrange", "swing") end)
    else ImGui.OpenPopup(ctx, "gbmenu_" .. c) end
  end
  if clicked(ImGui.MouseButton_Right) then later(function() GB.open_main(1) end) end
end

---------------------------------------------------------------- main loop
local function loop()
  reaper.SetExtState(GB.RT, HB, tostring(reaper.time_precise()), false)
  if reaper.GetExtState(GB.RT, QUIT) == "1" then
    reaper.DeleteExtState(GB.RT, QUIT, false)
    return -- closed by a new launch of the script
  end
  local now = reaper.time_precise()
  if now - last_svc_check > 1 then last_svc_check = now GB.start_service() end

  ImGui.PushFont(ctx, fonts[text_size()])
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COL_BG)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 4)
  if first_frame then ImGui.SetNextWindowDockID(ctx, 0) first_frame = false end

  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar
    | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse
    | ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoDocking
  local visible, open = ImGui.Begin(ctx, "Grid Buddy - Display", true, flags)
  if visible then
    local h = ImGui.GetTextLineHeight(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    local show_midi = GB.flag("disp_midi", true) and GB.midi_editor() ~= nil

    if GB.flag("disp_snap", true) then
      local s = show_midi and h * 2 + 4 or h + 4
      local x, y = ImGui.GetCursorScreenPos(ctx)
      ImGui.Dummy(ctx, s, s)
      local hov = ImGui.IsItemHovered(ctx)
      draw_snap(dl, x, y, s, GB.snap_on(), hov, GB.rel_snap_on())
      if clicked(ImGui.MouseButton_Left) then
        if alt_down() then later(GB.toggle_rel_snap) else later(GB.toggle_snap) end
      end
      if clicked(ImGui.MouseButton_Right) then later(GB.snap_settings) end
      ImGui.SameLine(ctx, 0, 6)
      local sx, sy = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddLine(dl, sx, sy + 3, sx, sy + s - 3, COL_SEP, 1)
      ImGui.Dummy(ctx, 1, s)
      ImGui.SameLine(ctx, 0, 6)
    end

    ImGui.BeginGroup(ctx)
    handle_grid("arrange", grid_line("arrange", true))
    if show_midi then handle_grid("midi", grid_line("midi", false)) end
    ImGui.EndGroup(ctx)

    menu("arrange")
    menu("midi")

    if ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows) and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId) then
      hover_since = hover_since or reaper.time_precise()
      if reaper.time_precise() - hover_since > 1.5 then
        ImGui.SetTooltip(ctx, "Click: grid menu\nWheel: grid size\nAlt+click: swing on/off\n"
          .. "Alt+wheel: swing amount (Ctrl: finer)\nSnap icon: click = snap, Alt+click = relative,\n"
          .. "  right-click = snap/grid settings\nRight-click: Grid Buddy window\nDrag: move")
      end
    else
      hover_since = nil
    end
    ImGui.End(ctx)
  end
  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  if post then local f = post post = nil f() end
  if open then reaper.defer(loop) end
end

reaper.atexit(function()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
end)

reaper.defer(function()
  ctx = ImGui.CreateContext("ReNo Mellow - Grid Buddy Display")
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  loop()
end)
