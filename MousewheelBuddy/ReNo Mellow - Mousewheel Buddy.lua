-- @description ReNo Mellow - Mousewheel Buddy
-- @author ReNo Mellow
-- @version 1.0
-- @about Molette intelligente pour l'arrangement et l'éditeur MIDI : l'action lancée dépend de la zone survolée (règle, items, enveloppes, pistes, mixer, transport, notes, lignes CC…), réglable zone par zone (molette vers le haut / vers le bas) et pour chaque combinaison de Ctrl / Shift / Alt (Cmd / Opt sur Mac) : 8 actions molette pour l'arrangement, 8 pour l'éditeur MIDI. Nécessite SWS (et ReaImGui pour la fenêtre Setup).
-- @changelog Première version : 8 actions molette (sans modificateur, Ctrl, Shift, Alt et leurs combinaisons) pour l'arrangement et pour l'éditeur MIDI, fenêtre (choix des actions par zone, Pick… dans la liste d'actions, inversion du sens, zone survolée mise en évidence, centre du zoom horizontal / vertical propre à la molette, prioritaire sur les préférences).
-- @provides
--   MWB_lib.lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel.lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Ctrl).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Shift).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Alt).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Ctrl+Shift).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Ctrl+Alt).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Shift+Alt).lua
--   [main] ReNo Mellow - Mousewheel Buddy - Wheel (Ctrl+Shift+Alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel.lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel.lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Shift).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Shift).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Alt).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Shift).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Shift).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Alt).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Shift+Alt).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Shift+Alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Shift+Alt).lua > MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel (Ctrl+Shift+Alt).lua

local r = reaper
local dir = ({ r.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "MWB_lib.lua")

local TITLE = "Mousewheel Buddy"
local VERSION = "1.0"

if not r.ImGui_GetBuiltinPath then
  r.MB("This window needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.\n\n" ..
    "The wheel actions themselves only need SWS.", TITLE, 0)
  return
end
package.path = r.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

-- toolbar toggle on while open, launching it again closes the window
if r.set_action_options then r.set_action_options(1 | 4) end
local _, _, self_sec, self_cmd = r.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    r.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    r.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)

local ctx            -- created after the start-up work (see bottom of file)
local fonts = {}
local FONT_MIN, FONT_MAX = 10, 28

-- Modal dialogs must not run inside an ImGui frame: they are queued and run after ImGui.End.
local post = nil
local function later(fn) post = fn end

---------------------------------------------------------------- colours (RRGGBBAA)
local COL_RED   = 0xE05555FF
local COL_GREY  = 0x9A9A9AFF
local COL_GREEN = 0x7CF0A6FF
local COL_HOVER = 0x2F7D4F90

---------------------------------------------------------------- MIDI action registration
-- ReaPack registers the MIDI wheel actions in the MIDI Editor section.
-- The .ReaperPkg package only registers Main actions: this window adds them the first time.
local midi_n, midi_total = 0, #MWB.MODS
local midi_ok = false

local function register_midi(force)
  local n = 0
  for i, m in ipairs(MWB.MODS) do
    local suffix = (m.file ~= "") and (" (" .. m.file .. ")") or ""
    local path = dir .. "MIDI/ReNo Mellow - Mousewheel Buddy MIDI - Wheel" .. suffix .. ".lua"
    local key = "me_self" .. (m.key ~= "" and ("_" .. m.key) or "")
    local id = MWB.gets(key)
    if not force and id ~= "" and MWB.resolve(id) ~= 0 then
      n = n + 1
    elseif r.file_exists(path) then
      local cmd = r.AddRemoveReaScript(true, 32060, path, i == #MWB.MODS)
      if cmd and cmd > 0 then
        MWB.sets(key, MWB.id_from_cmd(cmd))
        n = n + 1
      end
    end
  end
  midi_n = n
  midi_ok = (n == midi_total)
end

---------------------------------------------------------------- edit buffers
local sel_mod = { main = "", midi = "" }   -- modifier page shown in each tab
local bufs = {}
local function buf_key(c, m, z, d) return c .. ":" .. m .. ":" .. z .. ":" .. d end
local function reload(c, m)
  for _, z in ipairs(MWB.CONTEXTS[c].zones) do
    for _, d in ipairs({ "up", "down" }) do
      bufs[buf_key(c, m, z.key, d)] = MWB.get_action(c, m, z.key, d)
    end
  end
end
for _, c in ipairs({ "main", "midi" }) do
  for _, m in ipairs(MWB.MODS) do reload(c, m.key) end
end

---------------------------------------------------------------- action picker (Action List)
local picking = nil  -- { c, m, z, d, section }

local function cancel_pick()
  if picking and r.PromptForAction then r.PromptForAction(-1, 0, picking.section) end
  picking = nil
end

local function start_pick(c, m, z, d)
  if not r.PromptForAction then return end
  cancel_pick()
  local sec = MWB.CONTEXTS[c].section
  picking = { c = c, m = m, z = z, d = d, section = sec }
  r.PromptForAction(1, MWB.resolve(bufs[buf_key(c, m, z, d)]), sec)
end

local function poll_pick()
  if not picking then return end
  local res = r.PromptForAction(0, 0, picking.section)
  if res > 0 then
    local id = MWB.id_from_cmd(res)
    MWB.set_action(picking.c, picking.m, picking.z, picking.d, id)
    bufs[buf_key(picking.c, picking.m, picking.z, picking.d)] = MWB.get_action(picking.c, picking.m, picking.z, picking.d)
    cancel_pick()
  elseif res < 0 then
    cancel_pick()
  end
end

---------------------------------------------------------------- drawing
local function size_of() return math.max(FONT_MIN, math.min(FONT_MAX, MWB.setting("ui_font", 14))) end

local function action_cell(c, m, z, d)
  local k = buf_key(c, m, z.key, d)
  local sec = MWB.CONTEXTS[c].section
  ImGui.PushID(ctx, k)

  ImGui.SetNextItemWidth(ctx, size_of() * 9)
  local changed, txt = ImGui.InputText(ctx, "##id", bufs[k] or "")
  if changed then bufs[k] = txt end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    MWB.set_action(c, m, z.key, d, bufs[k])
    bufs[k] = MWB.get_action(c, m, z.key, d)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Command ID: 40138, _SWS_..., _RS... (empty = do nothing)")
  end

  ImGui.SameLine(ctx)
  local is_picking = picking and picking.c == c and picking.m == m and picking.z == z.key and picking.d == d
  ImGui.BeginDisabled(ctx, not r.PromptForAction or (picking ~= nil and not is_picking))
  if ImGui.Button(ctx, is_picking and "Cancel" or "Pick...") then
    if is_picking then cancel_pick() else start_pick(c, m, z.key, d) end
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
    ImGui.SetTooltip(ctx, r.PromptForAction and "Choose the action in the Action List, then click Select"
      or "Needs a newer REAPER version: type the command ID")
  end

  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "x") then
    MWB.set_action(c, m, z.key, d, "")
    bufs[k] = ""
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Clear (do nothing)") end

  local id = bufs[k] or ""
  if id == "" then
    ImGui.TextColored(ctx, COL_GREY, "(nothing)")
  else
    local name = MWB.action_name(id, sec)
    if name then
      ImGui.TextColored(ctx, COL_GREY, name)
    else
      ImGui.TextColored(ctx, COL_RED, "Unknown action (missing extension?)")
    end
  end
  ImGui.PopID(ctx)
end

-- the page follows the wheel: turning Ctrl+wheel shows the Ctrl+Wheel page
local last_seen = r.GetExtState("ReNoMellow_MousewheelBuddy", "last_zone")
local function follow_wheel()
  local last = r.GetExtState("ReNoMellow_MousewheelBuddy", "last_zone")
  if last == last_seen then return end
  last_seen = last
  local c, m = last:match("^(%w+):(%w*):")
  if c and sel_mod[c] then sel_mod[c] = m end
end

local COL_SEL = 0x2F7D4FFF

local function draw_mod_buttons(c)
  local tag = (c == "midi") and "MIDI Editor section" or "Main section"
  for i, m in ipairs(MWB.MODS) do
    if i > 1 then ImGui.SameLine(ctx) end
    local sel = (sel_mod[c] == m.key)
    if sel then ImGui.PushStyleColor(ctx, ImGui.Col_Button, COL_SEL) end
    if ImGui.Button(ctx, MWB.mod_label(m) .. "##mod" .. i) then sel_mod[c] = m.key end
    if sel then ImGui.PopStyleColor(ctx) end
    if ImGui.IsItemHovered(ctx) then
      local suffix = (m.file ~= "") and (" (" .. m.file .. ")") or ""
      ImGui.SetTooltip(ctx, "Bind \"ReNo Mellow - Mousewheel Buddy" .. ((c == "midi") and " MIDI" or "") ..
        " - Wheel" .. suffix .. "\"\nto " .. MWB.mod_label(m) .. " in the " .. tag .. " of the Action List.")
    end
  end
end

local function draw_context(c)
  local C = MWB.CONTEXTS[c]
  local m = sel_mod[c]

  local inv = MWB.setting("invert_" .. c, false)
  local ch, v = ImGui.Checkbox(ctx, "Invert wheel direction", inv)
  if ch then MWB.set_setting("invert_" .. c, v) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset this page") then
    local mm = m
    local lbl
    for _, x in ipairs(MWB.MODS) do if x.key == mm then lbl = MWB.mod_label(x) end end
    later(function()
      if r.MB("Restore the default actions of the " .. C.label .. " zones for " .. lbl .. "?", TITLE, 1) == 1 then
        MWB.reset(c, mm); reload(c, mm)
      end
    end)
  end

  -- zoom centers (override the Preferences while a Mousewheel Buddy action runs)
  local function zoom_combo(label, key, items, tip)
    local cur = MWB.setting(key .. "_" .. c, MWB.ZOOM_DEFAULT) + 1   -- -1 (Preferences) -> 0
    ImGui.SetNextItemWidth(ctx, size_of() * 12)
    local changed, idx = ImGui.Combo(ctx, label, cur, table.concat(items, "\0") .. "\0")
    if changed then MWB.set_setting(key .. "_" .. c, idx - 1) end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, tip) end
  end
  zoom_combo("Horizontal zoom center", "hzoom", MWB.HZOOM_ITEMS,
    "Used by the zoom actions run by the wheel, instead of\nPreferences > Zoom/Scroll/Offset (Preferences = keep it)")
  ImGui.SameLine(ctx)
  zoom_combo("Vertical zoom center", "vzoom", MWB.VZOOM_ITEMS,
    "Used by the zoom actions run by the wheel, instead of\nPreferences > Zoom/Scroll/Offset (Preferences = keep it)")

  if c == "midi" and not midi_ok then
    ImGui.TextColored(ctx, COL_RED, string.format("%d of %d MIDI wheel actions are in the MIDI Editor section.", midi_n, midi_total))
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Add them") then later(function() register_midi(true) end) end
  end

  local info = r.GetExtState("ReNoMellow_MousewheelBuddy", "last_info")
  ImGui.TextColored(ctx, COL_GREY, "Last wheel event: " .. (info ~= "" and info or "none yet"))
  ImGui.Separator(ctx)
  draw_mod_buttons(c)
  local last = r.GetExtState("ReNoMellow_MousewheelBuddy", "last_zone")
  local flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY
  if ImGui.BeginTable(ctx, "zones_" .. c .. "_" .. m, 3, flags) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "Mouse over", ImGui.TableColumnFlags_WidthFixed, size_of() * 11)
    ImGui.TableSetupColumn(ctx, "Wheel up")
    ImGui.TableSetupColumn(ctx, "Wheel down")
    ImGui.TableHeadersRow(ctx)
    for _, z in ipairs(C.zones) do
      ImGui.TableNextRow(ctx)
      local here = (last == c .. ":" .. m .. ":" .. z.key)
      if here then ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg1, COL_HOVER) end
      ImGui.TableNextColumn(ctx)
      if here then ImGui.TextColored(ctx, COL_GREEN, z.label) else ImGui.Text(ctx, z.label) end
      ImGui.TableNextColumn(ctx); action_cell(c, m, z, "up")
      ImGui.TableNextColumn(ctx); action_cell(c, m, z, "down")
    end
    ImGui.EndTable(ctx)
  end
end

local function draw_options()
  ImGui.SetNextItemWidth(ctx, 160)
  local ch, v = ImGui.SliderInt(ctx, "Text size", size_of(), FONT_MIN, FONT_MAX)
  if ch then MWB.set_setting("ui_font", v) end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "SWS extension:")
  ImGui.SameLine(ctx)
  if r.BR_GetMouseCursorContext then
    ImGui.TextColored(ctx, COL_GREEN, "found")
  else
    ImGui.TextColored(ctx, COL_RED, "missing - install it from sws-extension.org, then restart REAPER")
  end
  ImGui.Text(ctx, "MIDI wheel actions:")
  ImGui.SameLine(ctx)
  if midi_ok then ImGui.TextColored(ctx, COL_GREEN, "all 8 in the MIDI Editor section")
  else ImGui.TextColored(ctx, COL_RED, string.format("%d of %d registered", midi_n, midi_total)) end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "How to use it")
  local ctrl, alt = MWB.IS_MAC and "Cmd" or "Ctrl", MWB.IS_MAC and "Opt" or "Alt"
  ImGui.TextWrapped(ctx,
    "1. Actions > Show action list, section Main: select \"ReNo Mellow - Mousewheel Buddy - Wheel\", " ..
    "click Add..., then turn the mouse wheel. Do the same with the 7 other actions " ..
    "\"... - Wheel (" .. ctrl .. ")\", \"(Shift)\", \"(" .. alt .. ")\"..., holding the keys written in their name " ..
    "while you turn the wheel. Bind only the ones you want.")
  ImGui.TextWrapped(ctx,
    "2. Same thing in the MIDI Editor section with the \"ReNo Mellow - Mousewheel Buddy MIDI - Wheel\" actions.")
  ImGui.TextWrapped(ctx,
    "3. In the Arrange and MIDI Editor tabs, choose a page (Wheel, " .. ctrl .. "+Wheel, Shift+Wheel...) " ..
    "and the action of each zone. Turn the wheel anywhere: the page follows the keys you hold " ..
    "and the zone under the mouse is highlighted in green.")
  ImGui.TextWrapped(ctx,
    "A combination that is not bound keeps REAPER's normal behaviour (Preferences > Mouse Modifiers).")
end

---------------------------------------------------------------- main loop
local function loop()
  poll_pick()
  follow_wheel()

  ImGui.PushFont(ctx, fonts[size_of()])
  ImGui.SetNextWindowSize(ctx, 760, 460, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, TITLE .. " " .. VERSION, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Arrange") then draw_context("main"); ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, "MIDI Editor") then draw_context("midi"); ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, "Options") then draw_options(); ImGui.EndTabItem(ctx) end
      ImGui.EndTabBar(ctx)
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if post then
    local fn = post
    post = nil
    fn()
  end

  if open then r.defer(loop) end
end

r.atexit(function()
  cancel_pick()
  if r.set_action_options then r.set_action_options(8) end
  set_self_toggle(false)
end)

-- start-up: register the MIDI action first, then create the ImGui context
-- in a later cycle, right before the first frame
r.defer(function()
  register_midi(false)
  r.defer(function()
    ctx = ImGui.CreateContext("ReNo Mellow - Mousewheel Buddy")
    for sz = FONT_MIN, FONT_MAX do
      fonts[sz] = ImGui.CreateFont("sans-serif", sz)
      ImGui.Attach(ctx, fonts[sz])
    end
    loop()
  end)
end)
