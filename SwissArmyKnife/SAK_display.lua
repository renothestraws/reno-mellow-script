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

-- toolbar toggle on while open; launching it again closes it
if reaper.set_action_options then reaper.set_action_options(1 | 2 | 4) end
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
if self_sec == SAK.section then SAK.register_self("cmd_display") end

-- Open / close handshake. The running window writes a heartbeat (not saved) every frame.
-- A launch that finds a fresh heartbeat is a "close" request: it tells the running
-- window to close and stops. "disp_wanted" (saved) remembers whether the window is open,
-- so SAK_startup.lua can reopen it when REAPER starts.
local S = "ReNoMellow_SAK"
local HB, QUIT = "disp_hb_" .. CTX, "disp_quit_" .. CTX
local hb = tonumber(reaper.GetExtState(S, HB))
if hb and reaper.time_precise() - hb < 1.0 then
  reaper.SetExtState(S, QUIT, "1", false)
  SAK.csets("disp_wanted", "0")
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end
reaper.DeleteExtState(S, QUIT, false)
SAK.csets("disp_wanted", "1")

-- Adds (once) a small block to Scripts/__startup.lua that reopens the Display windows
-- when REAPER starts. The block only runs SAK_startup.lua if it still exists.
local function ensure_startup_hook()
  local sp = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
  local target = dir .. "SAK_startup.lua"
  local block = "-- >>> ReNo Mellow Swiss Army Knife (reopens the Display windows)\n"
    .. "do local f = [[" .. target .. "]]; if reaper.file_exists(f) then dofile(f) end end\n"
    .. "-- <<< ReNo Mellow Swiss Army Knife\n"
  local cur = ""
  local fh = io.open(sp, "r")
  if fh then cur = fh:read("a") or ""; fh:close() end
  if cur:find(block, 1, true) then return end
  local a, b = cur:find("%-%- >>> ReNo Mellow Swiss Army Knife.-%-%- <<< ReNo Mellow Swiss Army Knife\n?")
  if a then
    cur = cur:sub(1, a - 1) .. block .. cur:sub(b + 1)
  else
    if cur ~= "" and not cur:match("\n$") then cur = cur .. "\n" end
    cur = cur .. block
  end
  fh = io.open(sp, "w")
  if fh then fh:write(cur); fh:close() end
end
ensure_startup_hook()

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
local close_request = false
local first_frame = true

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
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Close") then
      SAK.csets("disp_wanted", "0")
      close_request = true
    end
    ImGui.EndPopup(ctx)
  end
end

local editor_since = nil

-- (re)creates the ImGui context with its fonts and icon
local function create_context()
  ctx = ImGui.CreateContext((CTX == "midi") and "ReNo Mellow - SAK MIDI Display" or "ReNo Mellow - SAK Display")
  fonts = {}
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  icon = nil
  local path = reaper.GetResourcePath() .. "/Data/toolbar_icons/toolbar_sak_swiss_army_knife.png"
  if reaper.file_exists(path) then
    local ok, img = pcall(ImGui.CreateImage, path)
    if ok and img then icon = img; ImGui.Attach(ctx, icon) end
  end
end

local function loop()
  reaper.SetExtState(S, HB, tostring(reaper.time_precise()), false)
  if reaper.GetExtState(S, QUIT) == "1" then
    reaper.DeleteExtState(S, QUIT, false)
    return -- closed by a new launch of the script
  end
  if close_request then return end

  -- MIDI version: while no MIDI editor is open, the ImGui context is dropped
  -- entirely (no hidden window left behind, which made REAPER crash when a
  -- window set was saved). It is created again, at the same saved place, once a
  -- MIDI editor has been open for a short moment.
  if CTX == "midi" then
    if not reaper.MIDIEditor_GetActive() then
      ctx = nil          -- unused this cycle: ReaImGui frees it
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

  local sz = text_size()
  ImGui.PushFont(ctx, fonts[sz])
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COL_BG)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 8)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 12, 6)

  -- undock a window that was docked with version 1.4
  if first_frame then ImGui.SetNextWindowDockID(ctx, 0) first_frame = false end

  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar
    | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse
    | ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoDocking
  local title = (CTX == "midi") and "SAK MIDI - Active tool" or "SAK - Active tool"
  local visible, open = ImGui.Begin(ctx, title, true, flags)
  if visible then
    local cur = SAK.get_current()
    local name = SAK.display_name(cur)
    local h = ImGui.GetTextLineHeight(ctx)

    -- Swiss Army Knife icon (first state of the toolbar icon), or a short label if it is missing
    if icon then
      ImGui.Image(ctx, icon, h * 1.4, h * 1.4, 0, 0, 1 / 3, 1)
      ImGui.SameLine(ctx)
      if CTX == "midi" then
        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + h * 0.2)
        ImGui.TextColored(ctx, COL_LABEL, "MIDI")
        ImGui.SameLine(ctx)
        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - h * 0.2)
      end
    else
      ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + h * 0.2)
      ImGui.TextColored(ctx, COL_LABEL, (CTX == "midi") and "SAK MIDI" or "SAK")
      ImGui.SameLine(ctx)
      ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - h * 0.2)
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
      ImGui.SetTooltip(ctx, "Double-click: open the Toolbox\nMouse wheel: previous / next tool\nRight-click: options\nDrag: move")
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
  if CTX ~= "midi" then create_context() end -- the MIDI version waits for a MIDI editor
  loop()
end)
