-- @noindex
-- Small window showing what the Recording Buddy is doing (place it anywhere).
-- Double-click: start | Ctrl+Alt+double-click: forced stop | Right-click: open the Set up tab.
-- Launching this script again closes the window.

local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "RecBuddy_lib.lua")

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.",
    "Recording Buddy", 0)
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
RB.register_self("cmd_display")

-- Open / close handshake (same as the Swiss Army Knife Display): the running
-- window writes a heartbeat (not saved) every frame. A launch that finds a fresh
-- heartbeat is a "close" request. "disp_wanted" (saved) lets RecBuddy_startup.lua
-- reopen the window when REAPER starts.
local HB, QUIT = "disp_hb", "disp_quit"
local hb = tonumber(reaper.GetExtState(RB.RT, HB))
if hb and reaper.time_precise() - hb < 1.0 then
  reaper.SetExtState(RB.RT, QUIT, "1", false)
  RB.set("disp_wanted", "0")
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end
reaper.DeleteExtState(RB.RT, QUIT, false)
RB.set("disp_wanted", "1")

-- adds (once) a block to Scripts/__startup.lua that reopens the Display at start-up
local function ensure_startup_hook()
  local sp = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
  local target = dir .. "RecBuddy_startup.lua"
  local block = "-- >>> ReNo Mellow Recording Buddy (reopens the Display)\n"
    .. "do local f = [[" .. target .. "]]; if reaper.file_exists(f) then dofile(f) end end\n"
    .. "-- <<< ReNo Mellow Recording Buddy\n"
  local cur = ""
  local fh = io.open(sp, "r")
  if fh then cur = fh:read("a") or "" fh:close() end
  if cur:find(block, 1, true) then return end
  local a, b = cur:find("%-%- >>> ReNo Mellow Recording Buddy.-%-%- <<< ReNo Mellow Recording Buddy\n?")
  if a then
    cur = cur:sub(1, a - 1) .. block .. cur:sub(b + 1)
  else
    if cur ~= "" and not cur:match("\n$") then cur = cur .. "\n" end
    cur = cur .. block
  end
  fh = io.open(sp, "w")
  if fh then fh:write(cur) fh:close() end
end
ensure_startup_hook()

local FONT_MIN, FONT_MAX = 10, 28
local COL_BG      = 0x2B2D31FF
local COL_IDLE    = 0x7CF0A6FF
local COL_PLAY    = 0x3FBF6FFF
local COL_REC     = 0xE04A3EFF
local COL_PAUSE   = 0xE0A030FF
local COL_PREROLL = 0x4A6FA5FF
local COL_GAUGE   = 0x1E2023FF
local COL_TEXT    = 0xE8E8E8FF
local COL_GREY    = 0x9A9A9AFF
local COL_ERR     = 0xE05555FF

local ctx
local fonts = {}
local first_frame = true
-- docking (opt-in, box "Dock the Display in a REAPER docker" in the Set up tab): the dock id
-- is kept between launches (negative = REAPER docker, 0 = floating); the window asks with a
-- one-shot request key read here
local DOCK_SEC, DOCK_KEY = "ReNo_Buddy_Dock", "RecordingBuddy"
local dock_next, is_docked = nil, false
local hover_since = nil
local post = nil

local function text_size()
  return math.floor(RB.clamp(tonumber(RB.get("disp_font", 14)) or 14, FONT_MIN, FONT_MAX))
end

local function kind_color(k)
  if k == "rec" then return COL_REC
  elseif k == "play" then return COL_PLAY
  elseif k == "pause" or k == "tpause" then return COL_PAUSE end
  return COL_IDLE
end

local function draw_icon(dl, x, y, s, kind, col)
  local cx, cy, h = x + s / 2, y + s / 2, s * 0.36
  if kind == "rec" then
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, h, col)
  elseif kind == "pause" or kind == "tpause" then
    local w = h * 0.6
    ImGui.DrawList_AddRectFilled(dl, cx - h * 0.85, cy - h, cx - h * 0.85 + w, cy + h, col, 2)
    ImGui.DrawList_AddRectFilled(dl, cx + h * 0.85 - w, cy - h, cx + h * 0.85, cy + h, col, 2)
  else
    ImGui.DrawList_AddTriangleFilled(dl, cx - h * 0.8, cy - h, cx - h * 0.8, cy + h, cx + h, cy, col)
  end
end

local function loop()
  reaper.SetExtState(RB.RT, HB, tostring(reaper.time_precise()), false)
  if reaper.GetExtState(RB.RT, QUIT) == "1" then
    reaper.DeleteExtState(RB.RT, QUIT, false)
    return -- closed by a new launch of the script
  end

  local st = RB.tick("display")
  local v = RB.view(st)

  local sz = text_size()
  ImGui.PushFont(ctx, fonts[sz])
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COL_BG)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 8)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 10, 6)
  if first_frame then
    dock_next = tonumber(reaper.GetExtState(DOCK_SEC, DOCK_KEY)) or 0
    first_frame = false
  end
  local req = reaper.GetExtState(DOCK_SEC, DOCK_KEY .. "_req")
  if req ~= "" then dock_next = tonumber(req) or 0; reaper.DeleteExtState(DOCK_SEC, DOCK_KEY .. "_req", false) end
  if dock_next then ImGui.SetNextWindowDockID(ctx, dock_next); dock_next = nil end

  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar
    | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse
  if not is_docked then flags = flags | ImGui.WindowFlags_AlwaysAutoResize end
  local visible, open = ImGui.Begin(ctx, "Recording Buddy - Display", true, flags)
  if visible then
    local d = ImGui.IsWindowDocked(ctx)
    if d ~= is_docked then
      is_docked = d
      reaper.SetExtState(DOCK_SEC, DOCK_KEY, d and tostring(ImGui.GetWindowDockID(ctx)) or "0", true)
    end
    local h = ImGui.GetTextLineHeight(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    local col = kind_color(v.kind)

    -- icon
    local s = h * 2.2
    local x, y = ImGui.GetCursorScreenPos(ctx)
    ImGui.Dummy(ctx, s, s)
    draw_icon(dl, x, y, s, v.kind, col)
    ImGui.SameLine(ctx)

    -- text + mini gauge
    ImGui.BeginGroup(ctx)
    local line
    if v.run then
      line = RB.pass_label(v.i, v.n, v.mode, v.prate, "  ")
    else
      line = "Rec Buddy  " .. RB.fmt_rate(v.rate * 100)
    end
    ImGui.TextColored(ctx, col, line)
    local gw, gh = math.floor(h * 11), math.max(4, math.floor(h * 0.45))
    local gx, gy = ImGui.GetCursorScreenPos(ctx)
    ImGui.Dummy(ctx, gw, gh)
    ImGui.DrawList_AddRectFilled(dl, gx, gy, gx + gw, gy + gh, COL_GAUGE, 3)
    if v.preroll then
      ImGui.DrawList_AddRectFilled(dl, gx, gy, gx + gw * (v.preprog or 0), gy + gh, COL_PREROLL, 3)
    elseif (v.prog or 0) > 0 then
      ImGui.DrawList_AddRectFilled(dl, gx, gy, gx + math.max(3, gw * v.prog), gy + gh, col, 3)
    end
    local m, is_err = RB.recent_message(4)
    if m and (is_err or not v.run) then
      ImGui.TextColored(ctx, is_err and COL_ERR or COL_GREY, m)
    else
      ImGui.TextColored(ctx, v.run and COL_TEXT or COL_GREY, v.phase or "")
    end
    ImGui.EndGroup(ctx)

    -- mouse
    if ImGui.IsWindowHovered(ctx) then
      if ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
        local mods = ImGui.GetKeyMods(ctx)
        if (mods & ImGui.Mod_Ctrl) ~= 0 and (mods & ImGui.Mod_Alt) ~= 0 then
          RB.force_stop()
        elseif not v.run then
          RB.start()
        end
      end
      if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) then
        post = function() RB.open_main(dir, 2) end
      end
      hover_since = hover_since or reaper.time_precise()
      if reaper.time_precise() - hover_since > 1.5 and not v.run then
        ImGui.SetTooltip(ctx, "Double-click: start\nCtrl+Alt+double-click: forced stop\nRight-click: Set up\nDrag: move")
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
  RB.leave("display")
end)

reaper.defer(function()
  ctx = ImGui.CreateContext("ReNo Mellow - Recording Buddy Display")
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  loop()
end)
