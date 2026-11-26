-- @noindex
-- ReNo Mellow - Chord Buddy - Display
-- Small floating bar: name of the chord under the cursor (edit cursor, play
-- cursor during playback), button to open Chord Buddy, Export button
-- (click = modes ticked in Set up, right click = choose one mode).
-- Running the action again closes the Display.

local r = reaper
local EXT = "ReNo_ChordBuddy"
local TITLE = "Chord Buddy Display"

local SCRIPT_DIR = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
local T = dofile(SCRIPT_DIR .. "ChordBuddy_theory.lua")
local M = dofile(SCRIPT_DIR .. "ChordBuddy_midi.lua")
local E = dofile(SCRIPT_DIR .. "ChordBuddy_export.lua")
local MAIN_SCRIPT = SCRIPT_DIR .. "ReNo Mellow - Chord Buddy.lua"

if not r.ImGui_GetBuiltinPath then
  r.MB("Chord Buddy needs the ReaImGui extension.\n\nInstall it with ReaPack:\nExtensions > ReaPack > Browse packages > search \"ReaImGui\", install, then restart REAPER.",
       TITLE, 0)
  return
end
package.path = r.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
local ImGui = require "imgui" "0.9"

---------------------------------------------------------------------------
-- Running the action again closes the Display
---------------------------------------------------------------------------

local now = r.time_precise()
local beat = tonumber(r.GetExtState(EXT, "disp_running")) or 0
if now - beat < 1.0 then
  r.SetExtState(EXT, "disp_close", tostring(now), false)
  return
end

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
-- Settings shared with the main window (read again regularly)
---------------------------------------------------------------------------

local cfg = {}
local cfg_t = 0
local function read_cfg()
  local function num(k, d) return tonumber(r.GetExtState(EXT, k)) or d end
  local function str(k, d) local v = r.GetExtState(EXT, k); return v ~= "" and v or d end
  cfg.key_pos = num("key_pos", 0)
  cfg.spell = str("spell", "key")
  cfg.modes = E.ParseModes(str("export_modes", "1000"))
  cfg.track_name = str("chords_track", "Chords")
  cfg.color_items = str("color_items", "1") == "1"
  cfg.size = num("disp_size", 22)
  cfg.opacity = num("disp_opacity", 0.9)
  cfg_t = r.time_precise()
end
read_cfg()

local function key_pc() return T.FIFTHS[cfg.key_pos % 12] end
local function spelling() return T.Spelling(key_pc(), cfg.spell) end

---------------------------------------------------------------------------
-- Chord under the cursor
---------------------------------------------------------------------------

local chord_name, chord_t = "", 0
local function update_chord()
  local t = r.time_precise()
  if t - chord_t < 0.05 then return end
  chord_t = t
  local playing = r.GetPlayState() & 1 == 1
  local pos = playing and r.GetPlayPosition() or r.GetCursorPositionEx(0)
  local take = M.GetReadTake(pos)
  if not take then chord_name = "—"; return end
  local ppq = r.MIDI_GetPPQPosFromProjTime(take, pos)
  local p = M.PitchesAt(take, ppq)
  chord_name = T.Identify(p, spelling()) or "—"
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local status, status_t = "", 0
local function set_status(s) status, status_t = s or "", r.time_precise() end

local function open_main()
  local beat_main = tonumber(r.GetExtState(EXT, "running")) or 0
  if r.time_precise() - beat_main < 1.0 then return end   -- already open
  if not r.file_exists(MAIN_SCRIPT) then set_status("Chord Buddy script not found."); return end
  local id = r.AddRemoveReaScript(true, 0, MAIN_SCRIPT, true)
  if id and id > 0 then r.Main_OnCommand(id, 0) end
end

local function do_export(modes)
  local n, err = E.Export({
    modes = modes, track_name = cfg.track_name, color_items = cfg.color_items,
    key_pc = key_pc(), spell = spelling(), T = T, M = M,
  })
  if n then set_status("Exported " .. n .. " chord(s)") else set_status(err) end
end

---------------------------------------------------------------------------
-- ImGui (context created after the startup work)
---------------------------------------------------------------------------

local ctx = ImGui.CreateContext(TITLE)
local FONTS = {}
for sz = 10, 40, 2 do
  FONTS[sz] = ImGui.CreateFont("sans-serif", sz, ImGui.FontFlags_Bold)
  ImGui.Attach(ctx, FONTS[sz])
end
local FONT_UI = ImGui.CreateFont("sans-serif", 13)
ImGui.Attach(ctx, FONT_UI)

local function big_font()
  local sz = math.max(10, math.min(40, math.floor(cfg.size / 2 + 0.5) * 2))
  return FONTS[sz]
end

-- docking (opt-in, right-click / menu "Dock in REAPER docker"): the dock id is kept
-- between launches (negative = REAPER docker, 0 = floating)
local DOCK_SEC, DOCK_KEY = "ReNo_Buddy_Dock", "ChordBuddy"
local function dock_saved() return tonumber(r.GetExtState(DOCK_SEC, DOCK_KEY)) or 0 end
local dock_next, is_docked = nil, false
local function dock_track()
  local d = ImGui.IsWindowDocked(ctx)
  if d ~= is_docked then
    is_docked = d
    r.SetExtState(DOCK_SEC, DOCK_KEY, d and tostring(ImGui.GetWindowDockID(ctx)) or "0", true)
  end
end
local function dock_menu_item()
  if ImGui.MenuItem(ctx, "Dock in REAPER docker", nil, is_docked) then dock_next = is_docked and 0 or -1 end
end
dock_next = dock_saved() -- applied on the first frame

local function loop()
  r.SetExtState(EXT, "disp_running", tostring(r.time_precise()), false)
  local req = tonumber(r.GetExtState(EXT, "disp_close")) or 0
  if req > 0 and r.time_precise() - req < 2 then
    r.SetExtState(EXT, "disp_close", "0", false)
    return
  end
  if r.time_precise() - cfg_t > 0.5 then read_cfg() end
  update_chord()

  ImGui.SetNextWindowBgAlpha(ctx, cfg.opacity)
  if dock_next then ImGui.SetNextWindowDockID(ctx, dock_next); dock_next = nil end
  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoCollapse
  if not is_docked then flags = flags | ImGui.WindowFlags_AlwaysAutoResize end
  local visible, open = ImGui.Begin(ctx, TITLE, true, flags)
  if visible then
    dock_track()
    ImGui.PushFont(ctx, FONT_UI)

    -- chord name
    ImGui.PushFont(ctx, big_font())
    local txt = chord_name ~= "" and chord_name or "—"
    ImGui.Text(ctx, txt)
    local name_w = ImGui.GetItemRectSize(ctx)
    ImGui.PopFont(ctx)
    -- keep a stable width so the bar does not jump
    if name_w < cfg.size * 3.2 then
      ImGui.SameLine(ctx, 0, 0)
      ImGui.Dummy(ctx, cfg.size * 3.2 - name_w, 1)
    end

    ImGui.SameLine(ctx, 0, 10)
    if ImGui.Button(ctx, "Open") then open_main() end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Open Chord Buddy") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Export") then do_export(cfg.modes) end
    if ImGui.IsItemHovered(ctx) then
      local list = {}
      for _, m in ipairs(E.MODES) do if cfg.modes[m.id] then list[#list + 1] = m.label end end
      ImGui.SetTooltip(ctx, "Export the selected chords:\n" ..
        (#list > 0 and table.concat(list, "\n") or "(no mode ticked in Set up)") ..
        "\n\nRight click: choose one mode")
    end
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then ImGui.OpenPopup(ctx, "export_menu") end
    if ImGui.BeginPopup(ctx, "export_menu") then
      for _, m in ipairs(E.MODES) do
        if ImGui.MenuItem(ctx, m.label) then do_export({ [m.id] = true }) end
      end
      ImGui.EndPopup(ctx)
    end

    if status ~= "" and r.time_precise() - status_t < 3 then
      ImGui.TextColored(ctx, 0xE0A040FF, status)
    end

    -- right-click on an empty spot of the bar
    if ImGui.BeginPopupContextWindow(ctx, "cbdmenu", ImGui.PopupFlags_MouseButtonRight | ImGui.PopupFlags_NoOpenOverItems) then
      if ImGui.MenuItem(ctx, "Open Chord Buddy") then open_main() end
      ImGui.Separator(ctx)
      dock_menu_item()
      if ImGui.MenuItem(ctx, "Close") then open = false end
      ImGui.EndPopup(ctx)
    end

    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
  if open then r.defer(loop) end
end

r.atexit(function()
  r.SetExtState(EXT, "disp_running", "0", false)
  set_toggle(false)
end)

set_toggle(true)
r.defer(loop)
