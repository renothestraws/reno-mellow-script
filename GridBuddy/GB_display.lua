-- @noindex
-- ReNo Mellow - Grid Buddy : Display window, shared by the two Display actions.
--   GB_DISP = "arrange" (Main section) or "midi" (MIDI editor section, own window and settings)
-- Wheel: grid size (past the finest: 1/8T 1/16T 1/32T, past the widest: 1/2D ... 1/32D) | Click: grid menu
-- Alt+click: swing on/off | Alt+wheel: swing amount (arrange)
-- Snap icon: click = snap (Alt+click = relative snap, arrange), right-click = snap/grid settings
-- Right-click on the grid: Grid Buddy window. Launching the action again closes the window.
-- The MIDI Display is hidden while no MIDI editor is open.

local C = GB_DISP == "midi" and "midi" or "arrange"
local IS_MIDI = C == "midi"
local P = IS_MIDI and "me_" or ""               -- prefix of this Display's settings
local KEY = IS_MIDI and "display_midi" or "display"

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
GB.register_self("cmd_" .. KEY)

-- Open / close handshake (same as the other Buddy Displays): the running window
-- writes a heartbeat (not saved) every frame. A launch that finds a fresh heartbeat
-- is a "close" request. "<p>disp_wanted" (saved) lets GB_startup.lua reopen the window.
local HB, QUIT = "alive_" .. KEY, "quit_" .. KEY
local hb = tonumber(reaper.GetExtState(GB.RT, HB))
if hb and reaper.time_precise() - hb < 1.0 then
  reaper.SetExtState(GB.RT, QUIT, "1", false)
  GB.set(P .. "disp_wanted", "0")
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end
reaper.DeleteExtState(GB.RT, QUIT, false)
GB.set(P .. "disp_wanted", "1")
GB.ensure_startup_hook()

local FONT_MIN, FONT_MAX = 10, 28
local COL_BG       = 0x2B2D31FF
local COL_TEXT     = 0xE8E8E8FF
local COL_GREY     = 0x9A9A9AFF
local COL_LINK     = 0x7CF0A6FF
local COL_SWING    = 0x4FA3E8FF
local COL_SNAP_ON  = 0x4FA3E8FF
local COL_SNAP_OFF = 0x787878FF
local COL_SEP      = 0x45474CFF

local SWING_AMOUNTS = { 53, 55, 57, 59, 61, 64, 67, 70, 73, 75 }

local ctx
local fonts = {}
local first_frame = true
local hover_since = nil
local editor_since = nil
local post = nil
local function later(fn) post = fn end

local function lighten(c, a)
  local rr = math.min(255, ((c >> 24) & 255) + a)
  local g = math.min(255, ((c >> 16) & 255) + a)
  local b = math.min(255, ((c >> 8) & 255) + a)
  return (rr << 24) | (g << 16) | (b << 8) | (c & 255)
end

local function text_size()
  return math.floor(GB.clamp(tonumber(GB.get(P .. "disp_font", 16)) or 16, FONT_MIN, FONT_MAX))
end
local function opt(k, d) return GB.flag(P .. k, d) end

-- Modifier keys: ImGui only sees them when the Display has the keyboard focus, which is
-- rarely the case (the focus stays in the arrange view). js_ReaScriptAPI reads the real
-- keyboard state (4 = Ctrl, 8 = Shift, 16 = Alt), whatever window has the focus.
local function mod_down(imgui_mod, js_bit)
  if (ImGui.GetKeyMods(ctx) & imgui_mod) ~= 0 then return true end
  if reaper.JS_Mouse_GetState then return reaper.JS_Mouse_GetState(js_bit) & js_bit ~= 0 end
  return false
end
local function alt_down() return mod_down(ImGui.Mod_Alt, 16) end
local function ctrl_down() return mod_down(ImGui.Mod_Ctrl, 4) end


-- a click is a release without drag (dragging moves the window)
local function clicked(btn)
  if not ImGui.IsItemHovered(ctx) or not ImGui.IsMouseReleased(ctx, btn) then return false end
  local dx, dy = ImGui.GetMouseDragDelta(ctx, btn)
  return math.abs(dx) < 3 and math.abs(dy) < 3
end

---------------------------------------------------------------- grid menu
-- grid types, special sizes (Frame, Measure, Hide grid) and the MIDI editor options
local function menu()
  if not ImGui.BeginPopup(ctx, "gbmenu") then return end
  local linked = IS_MIDI and GB.synced()
  local hidden = GB.grid_hidden(C)

  ImGui.BeginDisabled(ctx, linked)
  local types = { "straight", "triplet" }
  if GB.flag("show_quint", false) then types[#types + 1] = "quintuplet" end
  if GB.flag("show_sept", false) then types[#types + 1] = "septuplet" end
  types[#types + 1] = "dotted"
  for _, t in ipairs(types) do
    if ImGui.MenuItem(ctx, GB.TYPE_LABEL[t], nil, not hidden and GB.is_type(C, t)) then
      later(function() if hidden then GB.toggle_grid_lines(C) end GB.set_type(C, t) end)
    end
  end
  if IS_MIDI then
    if ImGui.MenuItem(ctx, "Swing", nil, GB.is_type(C, "swing")) then later(function() GB.set_type(C, "swing") end) end
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
  if not IS_MIDI then
    if ImGui.MenuItem(ctx, "Frame", nil, not hidden and GB.is_frame()) then
      later(function() if hidden then GB.toggle_grid_lines(C) end GB.set_frame() end)
    end
    if ImGui.MenuItem(ctx, "Measure", nil, not hidden and GB.is_measure()) then
      later(function() if hidden then GB.toggle_grid_lines(C) end GB.set_measure() end)
    end
  end
  ImGui.EndDisabled(ctx)
  if ImGui.MenuItem(ctx, "Hide grid", nil, hidden) then later(function() GB.toggle_grid_lines(C) end) end

  ImGui.Separator(ctx)
  if ImGui.MenuItem(ctx, "Link MIDI editor", nil, GB.synced()) then later(GB.toggle_link) end
  if IS_MIDI and ImGui.MenuItem(ctx, "Sync to arrange view", nil, GB.midi_sync_on()) then
    later(GB.toggle_midi_sync)
  end
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

-- the grid text; returns true when hovered
local function grid_line()
  local dl = ImGui.GetWindowDrawList(ctx)
  local d, sw, amt = GB.current(C)
  local txt
  if GB.grid_hidden(C) then txt = "Hidden"
  elseif not IS_MIDI and GB.is_frame() then txt = "Frame"
  elseif not IS_MIDI and GB.is_measure() then txt = "Measure"
  elseif d then
    local shown = d
    if not IS_MIDI and opt("disp_visible", false) then shown = GB.visible_div(d) end
    txt = GB.grid_text(shown)
  else txt = "-" end

  -- Alt over the arrange grid: swing state
  if not IS_MIDI and ImGui.IsWindowHovered(ctx) and alt_down() and d then
    txt = sw == 1 and string.format("Swing %d%%", math.floor(amt * 100 + 0.5)) or "Swing off"
  end

  local prefix = IS_MIDI and (GB.synced() and "MIDI = " or "MIDI ") or ""
  local pw = ImGui.CalcTextSize(ctx, prefix)
  local tw, th = ImGui.CalcTextSize(ctx, txt)
  local h = ImGui.GetTextLineHeight(ctx)
  local w = math.max(pw + tw, h * 4.2)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local bar = not IS_MIDI and opt("disp_swing", true) and sw == 1 and (amt or 0) ~= 0
  ImGui.Dummy(ctx, w, h + 4)
  local tx = x + (w - (pw + tw)) / 2
  local ty = y + (h - th) / 2
  if prefix ~= "" then
    ImGui.DrawList_AddText(dl, tx, ty, GB.synced() and COL_LINK or COL_GREY, prefix)
    tx = tx + pw
  end
  ImGui.DrawList_AddText(dl, tx, ty, COL_TEXT, txt)
  if bar then
    local len = math.ceil(math.abs(amt) * w / 2)
    local bx = amt > 0 and x + w / 2 or x + w / 2 - len
    ImGui.DrawList_AddRectFilled(dl, bx, y + h + 1, bx + len, y + h + 4, COL_SWING, 1)
  end
  return ImGui.IsItemHovered(ctx)
end

local function handle_grid(hovered)
  if not hovered then return end
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel ~= 0 then
    if not IS_MIDI and alt_down() then
      local _, _, amt = GB.get_grid()
      local step = (ctrl_down() and 0.01 or 0.03) * (wheel > 0 and 1 or -1)
      later(function() GB.set_swing((amt or 0) + step) end)
    else
      local dir = wheel > 0 and -1 or 1 -- wheel up = finer grid
      if GB.flag("wheel_rev", false) then dir = -dir end
      later(function()
        if GB.grid_hidden(C) then GB.toggle_grid_lines(C) end
        GB.step_ladder(C, dir)
      end)
    end
  end
  if clicked(ImGui.MouseButton_Left) then
    if not IS_MIDI and alt_down() then later(function() GB.set_type("arrange", "swing") end)
    else ImGui.OpenPopup(ctx, "gbmenu") end
  end
  if clicked(ImGui.MouseButton_Right) then later(function() GB.open_main(1) end) end
end

---------------------------------------------------------------- main loop
local function create_context()
  ctx = ImGui.CreateContext(IS_MIDI and "ReNo Mellow - Grid Buddy MIDI Display" or "ReNo Mellow - Grid Buddy Display")
  fonts = {}
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  first_frame = true
end

local function loop()
  reaper.SetExtState(GB.RT, HB, tostring(reaper.time_precise()), false)
  if reaper.GetExtState(GB.RT, QUIT) == "1" then
    reaper.DeleteExtState(GB.RT, QUIT, false)
    return -- closed by a new launch of the script
  end

  -- MIDI Display: while no MIDI editor is open, the ImGui context is dropped entirely
  -- (no hidden window left behind), then created again at the same place.
  if IS_MIDI then
    if not GB.midi_editor() then
      ctx = nil
      editor_since = nil
      reaper.defer(loop)
      return
    end
    if not ctx then
      editor_since = editor_since or reaper.time_precise()
      if reaper.time_precise() - editor_since < 0.4 then reaper.defer(loop) return end
      create_context()
    end
  end

  ImGui.PushFont(ctx, fonts[text_size()])
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COL_BG)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 4)
  if first_frame then ImGui.SetNextWindowDockID(ctx, 0) first_frame = false end

  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar
    | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse
    | ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoDocking
  local title = IS_MIDI and "Grid Buddy MIDI - Display" or "Grid Buddy - Display"
  local visible, open = ImGui.Begin(ctx, title, true, flags)
  if visible then
    local h = ImGui.GetTextLineHeight(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    if opt("disp_snap", true) then
      local s = h + 4
      local x, y = ImGui.GetCursorScreenPos(ctx)
      ImGui.Dummy(ctx, s, s)
      local hov = ImGui.IsItemHovered(ctx)
      if IS_MIDI then
        draw_snap(dl, x, y, s, GB.midi_snap_on(), hov, false)
        if clicked(ImGui.MouseButton_Left) then later(GB.midi_toggle_snap) end
      else
        draw_snap(dl, x, y, s, GB.snap_on(), hov, GB.rel_snap_on())
        if clicked(ImGui.MouseButton_Left) then
          if alt_down() then later(GB.toggle_rel_snap) else later(GB.toggle_snap) end
        end
      end
      if clicked(ImGui.MouseButton_Right) then later(GB.snap_settings) end
      ImGui.SameLine(ctx, 0, 6)
      local sx, sy = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddLine(dl, sx, sy + 3, sx, sy + s - 3, COL_SEP, 1)
      ImGui.Dummy(ctx, 1, s)
      ImGui.SameLine(ctx, 0, 6)
    end

    handle_grid(grid_line())
    menu()

    if ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows)
      and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId) then
      hover_since = hover_since or reaper.time_precise()
      if reaper.time_precise() - hover_since > 1.5 then
        if IS_MIDI then
          ImGui.SetTooltip(ctx, "MIDI editor grid\nWheel: grid size\n(past the ends: triplets / dotted sizes)\nClick: grid menu (type, hide, link, sync)\n"
            .. "Snap icon: click = snap, right-click = snap/grid settings\nRight-click: Grid Buddy window\nDrag: move")
        else
          ImGui.SetTooltip(ctx, "Wheel: grid size\n(past the ends: triplets / dotted sizes)\nClick: grid menu (type, frame, measure, hide, link)\n"
            .. "Alt+click: swing on/off\nAlt+wheel: swing amount (Ctrl: finer)\n"
            .. "Snap icon: click = snap, Alt+click = relative,\n  right-click = snap/grid settings\n"
            .. "Right-click: Grid Buddy window\nDrag: move")
        end
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
  if not IS_MIDI then create_context() end -- the MIDI Display waits for a MIDI editor
  loop()
end)
