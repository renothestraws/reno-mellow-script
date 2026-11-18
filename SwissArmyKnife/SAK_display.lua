-- @noindex
-- Shared code of the "Display" scripts: a small bubble showing the active tool.
-- Loaded by the two Display scripts, which set:
--   SAK_ROOT   = folder holding SAK_lib.lua
--   SAK_TB_CTX = "main" (arrange) or "midi" (MIDI editor)

local dir = SAK_ROOT
dofile(dir .. "SAK_lib.lua")

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.",
    "Swiss Army Knife", 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

-- toolbar toggle on while open, re-launch closes the window
if reaper.set_action_options then reaper.set_action_options(1 | 4) end
local _, _, self_sec, self_cmd = reaper.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    reaper.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    reaper.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)

SAK.set_context(SAK_TB_CTX or "main")
SAK.ensure_init()
local CTX = SAK.context
SAK.register_self("cmd_display")

local function opt(k, default) return SAK.setting("disp_" .. k .. "_" .. CTX, default) end
local function set_opt(k, v) SAK.set_setting("disp_" .. k .. "_" .. CTX, v) end

local FONT_MIN, FONT_MAX = 10, 28
local COL_BG     = 0x2B2D31FF
local COL_NAME   = 0x7CF0A6FF
local COL_SEP    = 0x55585EFF
local COL_LABEL  = 0x9A9A9AFF

local ctx
local fonts = {}
local icon = nil
local dock_request = nil -- nil, "dock" or "undock"
local close_request = false

local function text_size()
  return math.max(FONT_MIN, math.min(FONT_MAX, math.floor(opt("font", 16))))
end

local function open_toolbox()
  local id = SAK.cgets("cmd_toolbox")
  local cmd = SAK.resolve(id)
  if cmd == 0 then
    reaper.MB("Open the Toolbox once from the Action List first.", "Swiss Army Knife", 0)
    return
  end
  if CTX == "midi" then
    if reaper.MIDIEditor_GetActive() then reaper.MIDIEditor_LastFocused_OnCommand(cmd, false)
    else reaper.MB("Open a MIDI editor first.", "Swiss Army Knife", 0) end
  else
    reaper.Main_OnCommand(cmd, 0)
  end
end

local function step(dir_)
  local cur, n = SAK.get_current(), SAK.NSLOTS
  for k = 1, n do
    local i = ((cur - 1 + dir_ * k) % n) + 1
    if not SAK.is_empty(i) then SAK.set_current(i) return end
  end
end

local function draw_menu()
  if ImGui.BeginPopupContextWindow(ctx) then
    if ImGui.MenuItem(ctx, "Open Toolbox") then open_toolbox() end
    if ImGui.MenuItem(ctx, "Next tool") then step(1) end
    if ImGui.MenuItem(ctx, "Previous tool") then step(-1) end
    ImGui.Separator(ctx)
    ImGui.SetNextItemWidth(ctx, 140)
    local ch, v = ImGui.SliderInt(ctx, "Text size", text_size(), FONT_MIN, FONT_MAX)
    if ch then set_opt("font", v) end
    local ci, b = ImGui.Checkbox(ctx, "Show icon", opt("icon", true))
    if ci then set_opt("icon", b) end
    ImGui.Separator(ctx)
    if ImGui.IsWindowDocked(ctx) then
      if ImGui.MenuItem(ctx, "Undock") then dock_request = "undock" end
    else
      if ImGui.MenuItem(ctx, "Dock in a REAPER docker") then dock_request = "dock" end
    end
    if ImGui.MenuItem(ctx, "Close") then close_request = true end
    ImGui.EndPopup(ctx)
  end
end

local function loop()
  local sz = text_size()
  ImGui.PushFont(ctx, fonts[sz])
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COL_BG)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 8)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 12, 6)

  if dock_request == "dock" then ImGui.SetNextWindowDockID(ctx, -1)
  elseif dock_request == "undock" then ImGui.SetNextWindowDockID(ctx, 0) end
  dock_request = nil

  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar
    | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse
    | ImGui.WindowFlags_AlwaysAutoResize
  local title = (CTX == "midi") and "SAK MIDI - Active tool" or "SAK - Active tool"
  local visible, open = ImGui.Begin(ctx, title, true, flags)
  if visible then
    local cur = SAK.get_current()
    local name = SAK.display_name(cur)
    local h = ImGui.GetTextLineHeight(ctx)

    -- icon (first state of the toolbar icon) or a short label
    if opt("icon", true) and icon then
      ImGui.Image(ctx, icon, h * 1.4, h * 1.4, 0, 0, 1 / 3, 1)
      ImGui.SameLine(ctx)
    else
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.TextColored(ctx, COL_LABEL, (CTX == "midi") and "SAK MIDI" or "SAK")
      ImGui.SameLine(ctx)
    end

    -- separator
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddLine(dl, x + 4, y, x + 4, y + h * 1.4, COL_SEP, 1.5)
    ImGui.Dummy(ctx, 10, h * 1.4)
    ImGui.SameLine(ctx)

    -- tool name, vertically centered
    local cy = ImGui.GetCursorPosY(ctx)
    ImGui.SetCursorPosY(ctx, cy + (h * 1.4 - h) / 2)
    ImGui.TextColored(ctx, COL_NAME, name)

    if ImGui.IsWindowHovered(ctx) then
      if ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then open_toolbox() end
      local wheel = ImGui.GetMouseWheel(ctx)
      if wheel and wheel ~= 0 then step(wheel > 0 and -1 or 1) end
      ImGui.SetTooltip(ctx, "Double-click: open the Toolbox\nMouse wheel: previous / next tool\nRight-click: options")
    end

    draw_menu()
    ImGui.End(ctx)
  end

  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  if close_request then open = false end
  if open then reaper.defer(loop) end
end

reaper.atexit(function()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
end)

reaper.defer(function()
  ctx = ImGui.CreateContext((CTX == "midi") and "ReNo Mellow - SAK MIDI Display" or "ReNo Mellow - SAK Display")
  for s = FONT_MIN, FONT_MAX do
    fonts[s] = ImGui.CreateFont("sans-serif", s)
    ImGui.Attach(ctx, fonts[s])
  end
  local path = reaper.GetResourcePath() .. "/Data/toolbar_icons/toolbar_sak_swiss_army_knife.png"
  if reaper.file_exists(path) then
    local ok, img = pcall(ImGui.CreateImage, path)
    if ok and img then icon = img; ImGui.Attach(ctx, icon) end
  end
  loop()
end)
