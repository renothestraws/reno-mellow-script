-- @noindex
-- ReNo Mellow - Drum Buddy - Display
-- Floating bar: drummer of the project, his 16 chops (wheel, click = insert), Again, Vary, Random, open Drum Buddy.
-- Needs "ReNo Mellow - Drum Buddy.lua" in the same folder. Run the action again to close the Display.

local SCRIPT_NAME = "ReNo Mellow - Drum Buddy - Display"

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("Drum Buddy needs the ReaImGui extension.\n\nInstall it with ReaPack:\nExtensions > ReaPack > Browse packages > ReaImGui\nthen restart REAPER.", SCRIPT_NAME, 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

local _, this_file, sec, cmd = reaper.get_action_context()
local dir = this_file:match("^(.*)[/\\]") or ""
local main_file = dir .. "/ReNo Mellow - Drum Buddy.lua"
if not reaper.file_exists(main_file) then
  reaper.MB("The Display needs \"ReNo Mellow - Drum Buddy.lua\" in the same folder:\n" .. dir, SCRIPT_NAME, 0)
  return
end

DRUMBUDDY_LIB = true
local ok, DB = pcall(dofile, main_file)
DRUMBUDDY_LIB = nil
if not ok or type(DB) ~= "table" then
  reaper.MB("Cannot load Drum Buddy:\n" .. tostring(DB), SCRIPT_NAME, 0)
  return
end
local EXT = DB.EXT

-- Run again = close (REAPER 7: no "already running" question; older versions: heartbeat)
if reaper.set_action_options then reaper.set_action_options(1) end
local alive = tonumber(reaper.GetExtState(EXT, "display_alive")) or 0
if reaper.time_precise() - alive < 0.5 then
  reaper.SetExtState(EXT, "display_close", "1", false)
  return
end

---------------------------------------------------------------------------
-- Reopen at REAPER startup (block added once to Scripts/__startup.lua),
-- only if "Open the Display when REAPER starts" is checked in Drum Buddy > Set up
---------------------------------------------------------------------------
local function install_startup()
  local path = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
  local f = io.open(path, "r")
  local content = f and f:read("*a") or ""
  if f then f:close() end
  if content:find("ReNo Mellow Drum Buddy Display", 1, true) then return end
  local block = "\n-- >>> ReNo Mellow Drum Buddy Display (added by the script)\n"
    .. "do\n"
    .. "  local p = " .. string.format("%q", this_file) .. "\n"
    .. "  if reaper.GetExtState(\"ReNo_DrumBuddy\", \"display_open\") == \"1\" and reaper.file_exists(p) then\n"
    .. "    local c = reaper.AddRemoveReaScript(true, 0, p, true)\n"
    .. "    if c and c ~= 0 then reaper.Main_OnCommand(c, 0) end\n"
    .. "  end\n"
    .. "end\n"
    .. "-- <<< ReNo Mellow Drum Buddy Display\n"
  local w = io.open(path, "a")
  if w then w:write(block); w:close() end
end

reaper.SetExtState(EXT, "display_close", "", false)
install_startup()

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(function()
  reaper.SetExtState(EXT, "display_alive", "", false)
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end)


---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local pad = tonumber(reaper.GetExtState(EXT, "disp_pad")) or 1
local ctx, ctx_wait = nil, 0
local pending = nil
local msg, msg_err, msg_time = "", false, 0

local COL_TEXT_DIM = 0x9A9AA4FF
local COL_WARN = 0xE8A040FF

local function note(m, e) msg, msg_err, msg_time = m or "", e and true or false, reaper.time_precise() end
local function after() local st, err = DB.get_status(); note(st, err) end

-- filled pads of the drummer, in order
local function filled()
  local t = {}
  local d = DB.drummer()
  for i = 1, 16 do if d.chops[i] then t[#t + 1] = i end end
  return t
end

local function step_pad(dir)
  local f = filled()
  if #f == 0 then return end
  local pos = 1
  for k, i in ipairs(f) do if i == pad then pos = k end end
  pos = pos + dir
  if pos < 1 then pos = #f elseif pos > #f then pos = 1 end
  pad = f[pos]
  reaper.SetExtState(EXT, "disp_pad", tostring(pad), true)
end

local function toggle_main()
  local a = tonumber(reaper.GetExtState(EXT, "main_alive")) or 0
  if reaper.time_precise() - a < 1 then
    reaper.SetExtState(EXT, "main_close", "1", false)
    return
  end
  local name = reaper.GetExtState(EXT, "main_cmd")
  local msec = tonumber(reaper.GetExtState(EXT, "main_sec")) or 0
  local c = 0
  if name ~= "" then c = reaper.NamedCommandLookup((name:sub(1, 1) == "_") and name or ("_" .. name)) end
  if c == 0 then note("Run Drum Buddy once from the action list first.", true); return end
  if msec == 32060 then reaper.MIDIEditor_LastFocused_OnCommand(c, false) else reaper.Main_OnCommand(c, 0) end
end

local function close_display()
  reaper.SetExtState(EXT, "display_close", "1", false)
end


---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local function draw()
  local d = DB.drummer()
  if not d.chops[pad] then
    local f = filled()
    pad = f[1] or 1
  end
  local c = d.chops[pad]
  local open_list, open_rand, open_menu = false, false, false

  ImGui.TextDisabled(ctx, d.name)
  ImGui.SameLine(ctx)
  if ImGui.ArrowButton(ctx, "##prev", ImGui.Dir_Left) then step_pad(-1) end
  ImGui.SameLine(ctx, 0, 2)
  local label = c and (pad .. ". " .. c.name) or "No chop yet"
  if ImGui.Button(ctx, label .. "##chop", 200, 0) and c then
    local i = pad
    pending = function() DB.insert_chop(i); after() end
  end
  if ImGui.IsItemHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel > 0 then step_pad(-1) elseif wheel < 0 then step_pad(1) end
    ImGui.SetTooltip(ctx, (c and (DB.chop_preview(c.data) .. "\n\n") or "")
      .. "Click: insert at the edit cursor (grid " .. DB.grid_name() .. ")\nWheel: choose\nRight-click: the 16 pads")
  end
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then open_list = true end
  ImGui.SameLine(ctx, 0, 2)
  if ImGui.ArrowButton(ctx, "##next", ImGui.Dir_Right) then step_pad(1) end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Again") then pending = function() DB.again(); after() end end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Insert the last fill again (new humanize)") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Vary") then pending = function() DB.vary(); after() end end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Last fill, new orchestration") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Random") then pending = function() DB.random(); after() end end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "New fill in the style of " .. d.name .. " (" .. DB.LENGTHS[DB.G.rlen][1] .. ")\nRight-click: length")
  end
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then open_rand = true end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Open") then pending = toggle_main end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Open / close Drum Buddy\nRight-click: Display menu") end
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then open_menu = true end

  if msg ~= "" and reaper.time_precise() - msg_time < 4 then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, msg_err and COL_WARN or COL_TEXT_DIM)
    ImGui.Text(ctx, msg)
    ImGui.PopStyleColor(ctx)
  end

  if open_list then ImGui.OpenPopup(ctx, "##padlist") end
  if open_rand then ImGui.OpenPopup(ctx, "##randmenu") end
  if open_menu then ImGui.OpenPopup(ctx, "##dispmenu") end

  if ImGui.BeginPopup(ctx, "##padlist") then
    ImGui.TextDisabled(ctx, d.name .. ": click = insert")
    for i = 1, 16 do
      if (i - 1) % 4 ~= 0 then ImGui.SameLine(ctx, 0, 4) end
      local ci = d.chops[i]
      local short = ci and ci.name or "-"
      if #short > 12 then short = short:sub(1, 11) .. "." end
      if ImGui.Button(ctx, i .. " " .. short .. "##p" .. i, 120, 34) and ci then
        pad = i
        reaper.SetExtState(EXT, "disp_pad", tostring(i), true)
        pending = function() DB.insert_chop(i); after() end
        ImGui.CloseCurrentPopup(ctx)
      end
      if ci and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, ci.name .. "\n" .. DB.chop_preview(ci.data)) end
    end
    ImGui.EndPopup(ctx)
  end

  if ImGui.BeginPopup(ctx, "##randmenu") then
    ImGui.TextDisabled(ctx, "Length of a Random fill")
    for i, l in ipairs(DB.LENGTHS) do
      if ImGui.MenuItem(ctx, l[1], nil, DB.G.rlen == i) then DB.set_rlen(i) end
    end
    ImGui.EndPopup(ctx)
  end

  if ImGui.BeginPopup(ctx, "##dispmenu") then
    if ImGui.MenuItem(ctx, "Open / close Drum Buddy") then pending = toggle_main end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Close the Display") then close_display() end
    ImGui.EndPopup(ctx)
  end
end

---------------------------------------------------------------------------
-- Loop: hidden while no MIDI editor is open
---------------------------------------------------------------------------
local WFLAGS = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoDocking | ImGui.WindowFlags_AlwaysAutoResize
  | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse | ImGui.WindowFlags_NoCollapse

local function frame()
  local now = reaper.time_precise()
  reaper.SetExtState(EXT, "display_alive", tostring(now), false)
  if reaper.GetExtState(EXT, "display_close") == "1" then
    reaper.SetExtState(EXT, "display_close", "", false)
    return
  end

  if not reaper.MIDIEditor_GetActive() then
    -- no MIDI editor: let the context go (no ImGui call at all), recreate it later
    ctx = nil
    ctx_wait = now + 0.4
    reaper.defer(frame)
    return
  end
  if not ctx then
    if now < ctx_wait then reaper.defer(frame); return end
    ctx = ImGui.CreateContext(SCRIPT_NAME)   -- same name: ReaImGui keeps the position
  end

  DB.sync()

  local visible = ImGui.Begin(ctx, "Drum Buddy Display###ReNoDrumBuddyDisplay", nil, WFLAGS)
  if visible then
    draw()
    ImGui.End(ctx)
  end
  if pending then
    local f = pending; pending = nil
    f()
  end
  reaper.defer(frame)
end

reaper.defer(frame)
