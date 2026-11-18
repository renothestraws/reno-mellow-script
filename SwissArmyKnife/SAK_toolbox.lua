-- @noindex
-- Shared toolbox code. Loaded by the two toolbox scripts, which set:
--   SAK_ROOT    = folder holding SAK_lib.lua
--   SAK_TB_CTX  = "main" (arrange) or "midi" (MIDI editor)
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

-- both contexts get their defaults, then the last used one is restored
SAK.set_context("midi"); SAK.ensure_init()
SAK.set_context("main"); SAK.ensure_init()
SAK.set_context(SAK_TB_CTX or "main")
local TB_CTX = SAK.context

local N = SAK.NSLOTS
local ctx -- created after the start-up work (see bottom of file)

-- Modal dialogs (MB, file dialogs) must not run inside an ImGui frame:
-- they are queued and run after ImGui.End.
local post = nil
local function later(fn) post = fn end

---------------------------------------------------------------- colours (RRGGBBAA)
local COL_TOOL     = 0x3C4148FF
local COL_SELECTED = 0x2F7D4FFF
local COL_ARM = { main = 0xB03A2EFF, alt = 0xC2671FFF, alt2 = 0x8E44ADFF }
local COL_RED      = 0xE05555FF
local COL_GREY     = 0x9A9A9AFF
local COL_BORDER   = 0x7CF0A6FF

local function lighten(c, a)
  local r = math.min(255, ((c >> 24) & 255) + a)
  local g = math.min(255, ((c >> 16) & 255) + a)
  local b = math.min(255, ((c >> 8) & 255) + a)
  return (r << 24) | (g << 16) | (b << 8) | (c & 255)
end

---------------------------------------------------------------- state
local tools = {}
local function reload_tools()
  for i = 1, N do tools[i] = SAK.get_tool(i) end
end
reload_tools()

local sel_slot = SAK.get_current()
local edit = {}
local function load_edit(i)
  local t = tools[i]
  edit = { slot = i, name = t.name, main = t.main, alt = t.alt, alt2 = t.alt2 }
end
load_edit(sel_slot)

local function save_edit()
  SAK.set_tool(edit.slot, edit)
  tools[edit.slot] = SAK.get_tool(edit.slot)
end

local picking = nil -- { slot = i, key = "main"/"alt"/"alt2" }

---------------------------------------------------------------- companion scripts
local function companions_for(c)
  -- MIDI editor scripts live in the MIDI/ subfolder
  local base = (c == "midi") and "MIDI/ReNo Mellow - Swiss Army Knife MIDI" or "ReNo Mellow - Swiss Army Knife"
  local list = {
    { key = "cmd_main", file = base .. ".lua" },
    { key = "cmd_alt",  file = base .. " (alt).lua" },
    { key = "cmd_alt2", file = base .. " (alt2).lua" },
    { key = "cmd_next", file = base .. " - Next tool.lua" },
    { key = "cmd_prev", file = base .. " - Previous tool.lua" },
    { key = "cmd_toolbox", file = base .. " - Toolbox.lua" },
  }
  for i = 1, N do
    list[#list + 1] = { key = "selcmd_" .. i, file = string.format("%s - Select tool %02d.lua", base, i) }
  end
  return list
end

-- runs fn(c) in each context, then restores the current one
local function for_each_context(fn)
  local keep = SAK.context
  for _, c in ipairs({ "main", "midi" }) do
    SAK.set_context(c)
    fn(c)
  end
  SAK.set_context(keep)
end

local function count_registered()
  local n, total = 0, 0
  for_each_context(function(c)
    for _, comp in ipairs(companions_for(c)) do
      total = total + 1
      local id = SAK.cgets(comp.key)
      if id ~= "" and SAK.resolve(id) ~= 0 then n = n + 1 end
    end
  end)
  return n, total
end

-- Adds the scripts to the Action List (Main and MIDI Editor sections) if they are not there yet
local function register_companions(force)
  local todo = {}
  for_each_context(function(c)
    for _, comp in ipairs(companions_for(c)) do
      local path = dir .. comp.file
      local id = SAK.cgets(comp.key)
      if reaper.file_exists(path) and (force or id == "" or SAK.resolve(id) == 0) then
        todo[#todo + 1] = { ctx = c, key = comp.key, path = path }
      end
    end
  end)
  local keep = SAK.context
  for k, t in ipairs(todo) do
    SAK.set_context(t.ctx)
    local cmd = reaper.AddRemoveReaScript(true, SAK.section, t.path, k == #todo)
    if cmd and cmd > 0 then SAK.csets(t.key, SAK.id_from_cmd(cmd)) end
  end
  SAK.set_context(keep)
end

local function sync_all_toggles()
  for_each_context(function() SAK.sync_toggles() end)
end
local n_registered, n_total = 0, 0

---------------------------------------------------------------- action picker (Action List)
local function start_pick(key)
  if not reaper.PromptForAction then return end
  picking = { slot = edit.slot, key = key, section = SAK.section }
  reaper.PromptForAction(1, SAK.resolve(edit[key]), SAK.section)
end

local function poll_pick()
  if not picking then return end
  local r = reaper.PromptForAction(0, 0, picking.section)
  if r > 0 then
    local id = SAK.id_from_cmd(r)
    local t = tools[picking.slot]
    t[picking.key] = id
    SAK.set_tool(picking.slot, t)
    tools[picking.slot] = SAK.get_tool(picking.slot)
    if edit.slot == picking.slot then edit[picking.key] = id end
    reaper.PromptForAction(-1, 0, picking.section)
    picking = nil
  elseif r < 0 then
    reaper.PromptForAction(-1, 0, picking.section)
    picking = nil
  end
end

local function cancel_pick()
  if picking then reaper.PromptForAction(-1, 0, picking.section) end
  picking = nil
end

---------------------------------------------------------------- arm
-- returns slot, key of the armed tool action (or nil), and the armed command
local function same_section(sec)
  sec = (sec or ""):lower()
  if SAK.context == "midi" then return sec:find("midi") ~= nil end
  return sec == "" or sec == "main"
end

local function armed_info()
  local cmd, sec = reaper.GetArmedCommand()
  if not cmd or cmd == 0 then return nil, nil, 0, sec end
  if not same_section(sec) then return nil, nil, cmd, sec end
  for i = 1, N do
    for _, k in ipairs(SAK.KEYS) do
      if tools[i][k] ~= "" and SAK.resolve(tools[i][k]) == cmd then return i, k, cmd, sec end
    end
  end
  return nil, nil, cmd, sec
end

---------------------------------------------------------------- slot operations
local function swap_slots(a, b)
  if b < 1 or b > N then return end
  tools[a], tools[b] = tools[b], tools[a]
  SAK.set_tool(a, tools[a]); SAK.set_tool(b, tools[b])
  local cur = SAK.get_current()
  if cur == a then SAK.set_current(b) elseif cur == b then SAK.set_current(a) end
  sel_slot = b
  load_edit(b)
end

local function duplicate_slot(a)
  for i = 1, N do
    if SAK.is_empty(i, tools[i]) then
      local t = tools[a]
      SAK.set_tool(i, { name = (t.name ~= "" and t.name or ("Tool " .. a)) .. " copy",
        main = t.main, alt = t.alt, alt2 = t.alt2 })
      tools[i] = SAK.get_tool(i)
      sel_slot = i
      load_edit(i)
      return
    end
  end
  reaper.MB("No empty slot left.", "Swiss Army Knife", 0)
end

local function clear_slot(a)
  if reaper.MB("Clear slot " .. a .. " (" .. SAK.display_name(a, tools[a]) .. ")?",
      "Swiss Army Knife", 4) ~= 6 then return end
  SAK.set_tool(a, { name = "", main = "", alt = "", alt2 = "" })
  tools[a] = SAK.get_tool(a)
  load_edit(a)
end

---------------------------------------------------------------- presets
local function export_preset()
  local path
  if reaper.JS_Dialog_BrowseForSaveFile then
    local rv, p = reaper.JS_Dialog_BrowseForSaveFile("Export Swiss Army Knife preset",
      reaper.GetResourcePath(), (SAK.context == "midi" and "Swiss Army Knife MIDI preset.txt" or "Swiss Army Knife preset.txt"), "Text files (*.txt)\0*.txt\0\0")
    if rv ~= 1 or p == "" then return end
    path = p
    if not path:lower():match("%.txt$") then path = path .. ".txt" end
  else
    local d = reaper.GetResourcePath() .. "/Data"
    reaper.RecursiveCreateDirectory(d, 0)
    path = d .. (SAK.context == "midi" and "/ReNoMellow_SAK_MIDI_preset.txt" or "/ReNoMellow_SAK_preset.txt")
  end
  local f = io.open(path, "w")
  if not f then reaper.MB("Could not write:\n" .. path, "Swiss Army Knife", 0) return end
  f:write("ReNoMellow_SAK_preset\t2\n")
  for i = 1, N do
    local t = tools[i]
    f:write(table.concat({ i, t.name, t.main, t.alt, t.alt2 }, "\t"), "\n")
  end
  f:close()
  reaper.MB("Preset exported to:\n" .. path, "Swiss Army Knife", 0)
end

local function import_preset()
  local rv, path = reaper.GetUserFileNameForRead(reaper.GetResourcePath() .. "/", "Import Swiss Army Knife preset", "txt")
  if not rv then return end
  local f = io.open(path, "r")
  if not f then return end
  local data, ok = {}, false
  for line in f:lines() do
    line = line:gsub("\r$", "")
    if line:match("^ReNoMellow_SAK_preset") then ok = true
    else
      local fields = {}
      for v in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = v end
      local i = tonumber(fields[1])
      if i and i >= 1 and i <= N then
        data[i] = { name = fields[2] or "", main = fields[3] or "", alt = fields[4] or "", alt2 = fields[5] or "" }
      end
    end
  end
  f:close()
  if not ok then reaper.MB("This is not a Swiss Army Knife preset.", "Swiss Army Knife", 0) return end
  for i = 1, N do SAK.set_tool(i, data[i] or { name = "", main = "", alt = "", alt2 = "" }) end
  reload_tools()
  load_edit(sel_slot)
  SAK.sync_toggles()
end

local function reset_defaults()
  if reaper.MB("Replace all " .. SAK.CONTEXTS[SAK.context].label .. " tools with the default set?",
    "Swiss Army Knife", 4) ~= 6 then return end
  SAK.load_defaults()
  reload_tools()
  sel_slot = 1
  load_edit(1)
  SAK.sync_toggles()
end

---------------------------------------------------------------- sizes, fonts, auto-close
-- Per toolbox (Arrange / MIDI) settings
local function tb_setting(k, default) return SAK.setting(k .. "_" .. TB_CTX, default) end
local function tb_set(k, v) SAK.set_setting(k .. "_" .. TB_CTX, v) end

-- Sizes chosen by the user (Setup > Settings), one set per toolbox.
-- ReaImGui fonts have a fixed size, so one font per size is created at start-up.
local FONT_MIN, FONT_MAX = 10, 28
local SIZE_DEFAULTS = { ui_font = 13, tool_font = 15, tool_h = 44, tool_w = 110 }
local fonts = {}
local close_request = false

local function size_of(k)
  local v = math.floor(tb_setting(k, SIZE_DEFAULTS[k]))
  if k == "ui_font" or k == "tool_font" then v = math.max(FONT_MIN, math.min(FONT_MAX, v)) end
  return v
end

---------------------------------------------------------------- tab 1 : tools
local function action_desc(id)
  if id == "" then return "(none)" end
  return SAK.action_name(id) or ("not found: " .. id)
end

local function draw_tools()
  local cur = SAK.get_current()
  local armed_slot, armed_key, armed_cmd, armed_sec = armed_info()

  local list = {}
  for i = 1, N do if not SAK.is_empty(i, tools[i]) then list[#list + 1] = i end end
  if #list == 0 then
    ImGui.TextDisabled(ctx, "No tool defined. Create your tools in the Setup tab.")
    return
  end

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local sp = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
  local min_w = size_of("tool_w")
  local cols = math.max(1, math.floor((avail_w + sp) / (min_w + sp)))
  local bw = (avail_w - sp * (cols - 1)) / cols

  local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
  local ctrl  = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)

  ImGui.PushFont(ctx, fonts[size_of("tool_font")])
  for k, i in ipairs(list) do
    local t = tools[i]
    if (k - 1) % cols ~= 0 then ImGui.SameLine(ctx) end

    local col = (i == cur) and COL_SELECTED or COL_TOOL
    if armed_slot == i then col = COL_ARM[armed_key] end
    local border = (i == cur and armed_slot == i)

    ImGui.PushStyleColor(ctx, ImGui.Col_Button, col)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, lighten(col, 25))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, lighten(col, 45))
    if border then
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 3)
      ImGui.PushStyleColor(ctx, ImGui.Col_Border, COL_BORDER)
    end

    if ImGui.Button(ctx, SAK.display_name(i, t) .. "##tool" .. i, bw, size_of("tool_h")) then
      SAK.set_current(i)
      if tb_setting("autoclose", false) then close_request = true end
    end

    if border then
      ImGui.PopStyleColor(ctx)
      ImGui.PopStyleVar(ctx)
    end
    ImGui.PopStyleColor(ctx, 3)

    -- right-click : arm / disarm
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
      if armed_slot == i then
        reaper.ArmCommand(0, armed_sec or "")
      else
        local key = ctrl and "alt2" or (shift and "alt" or "main")
        local cmd = SAK.resolve(t[key])
        if cmd ~= 0 then reaper.ArmCommand(cmd, SAK.arm_section) end
      end
    end

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, string.format(
        "Slot %d\nMain:  %s\nAlt:   %s\nAlt 2: %s\n\nClick: select tool\nRight-click: arm main  (again: disarm)\nShift+right-click: arm alt\nCtrl+right-click: arm alt 2",
        i, action_desc(t.main), action_desc(t.alt), action_desc(t.alt2)))
    end
  end

  ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  local t = tools[cur]
  ImGui.Text(ctx, "Current tool: " .. SAK.display_name(cur, t))
  ImGui.TextColored(ctx, COL_GREY, "Main:  " .. action_desc(t.main))
  ImGui.TextColored(ctx, COL_GREY, "Alt:   " .. action_desc(t.alt))
  ImGui.TextColored(ctx, COL_GREY, "Alt 2: " .. action_desc(t.alt2))

  if armed_cmd ~= 0 then
    ImGui.Spacing(ctx)
    local what
    if armed_slot then
      what = SAK.display_name(armed_slot, tools[armed_slot]) .. " (" .. SAK.LABELS[armed_key] .. ")"
    else
      what = SAK.action_name(tostring(armed_cmd)) or tostring(armed_cmd)
    end
    ImGui.TextColored(ctx, COL_RED, "ARMED: " .. what)
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Disarm") then reaper.ArmCommand(0, armed_sec or "") end
  end
end

---------------------------------------------------------------- tab 2 : setup
local function action_row(key)
  ImGui.PushID(ctx, key)
  ImGui.Text(ctx, SAK.LABELS[key] .. " action")
  ImGui.SetNextItemWidth(ctx, -150)
  local rv, v = ImGui.InputText(ctx, "##id", edit[key])
  if rv then edit[key] = v; save_edit() end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    edit[key] = SAK.normalize_id(edit[key]); save_edit()
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Command ID: native (40012), SWS (_SWS_...), script (_RS...) or custom action (_hash)")
  end
  ImGui.SameLine(ctx)
  ImGui.BeginDisabled(ctx, picking ~= nil or not reaper.PromptForAction)
  if ImGui.Button(ctx, "Pick...") then start_pick(key) end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear") then edit[key] = ""; save_edit() end

  if edit[key] == "" then
    ImGui.TextDisabled(ctx, "(none)")
  else
    local nm = SAK.action_name(edit[key])
    if nm then ImGui.TextColored(ctx, COL_GREY, nm)
    else ImGui.TextColored(ctx, COL_RED, "Action not found in the Main section") end
  end
  ImGui.Spacing(ctx)
  ImGui.PopID(ctx)
end

local function draw_setup()
  -- slot list
  if ImGui.BeginChild(ctx, "slots", 190, 0, ImGui.ChildFlags_Border) then
    local cur = SAK.get_current()
    for i = 1, N do
      local t = tools[i]
      local label = string.format("%02d  %s", i, SAK.is_empty(i, t) and "-" or SAK.display_name(i, t))
      if i == cur then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x7CF0A6FF) end
      if ImGui.Selectable(ctx, label .. "##slot" .. i, sel_slot == i) then
        sel_slot = i
        load_edit(i)
      end
      if i == cur then ImGui.PopStyleColor(ctx) end
    end
    ImGui.EndChild(ctx)
  end

  ImGui.SameLine(ctx)

  if ImGui.BeginChild(ctx, "editor", 0, 0, ImGui.ChildFlags_Border) then
    if edit.slot ~= sel_slot then load_edit(sel_slot) end

    ImGui.Text(ctx, string.format("Slot %02d", edit.slot))
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(script \"Select tool " .. string.format("%02d", edit.slot) .. "\")")
    ImGui.SetNextItemWidth(ctx, -1)
    local rv, v = ImGui.InputTextWithHint(ctx, "##name", "Tool name", edit.name)
    if rv then edit.name = v; save_edit() end
    ImGui.Spacing(ctx)

    for _, k in ipairs(SAK.KEYS) do action_row(k) end

    if picking then
      ImGui.TextColored(ctx, COL_RED, "Choose an action in the Action List...")
      ImGui.SameLine(ctx)
      if ImGui.SmallButton(ctx, "Cancel") then cancel_pick() end
    elseif not reaper.PromptForAction then
      ImGui.TextDisabled(ctx, "\"Pick...\" needs a more recent REAPER: type the command ID instead.")
    end

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Move up") then swap_slots(edit.slot, edit.slot - 1) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Move down") then swap_slots(edit.slot, edit.slot + 1) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Duplicate") then local s = edit.slot; later(function() duplicate_slot(s) end) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear slot") then local s = edit.slot; later(function() clear_slot(s) end) end

    ImGui.Spacing(ctx)
    if ImGui.CollapsingHeader(ctx, "Settings") then
      local c, b
      c, b = ImGui.Checkbox(ctx, "Tooltip when the tool changes", SAK.setting("tt_change", true))
      if c then SAK.set_setting("tt_change", b) end
      c, b = ImGui.Checkbox(ctx, "Tooltip when a tool action is run", SAK.setting("tt_use", true))
      if c then SAK.set_setting("tt_use", b) end
      ImGui.SetNextItemWidth(ctx, 200)
      local cd, d = ImGui.SliderDouble(ctx, "Tooltip duration", SAK.setting("tt_dur", 1.0), 0.3, 3.0, "%.1f s")
      if cd then SAK.set_setting("tt_dur", string.format("%.2f", d)) end
      if not reaper.set_action_options then
        ImGui.TextColored(ctx, COL_RED, "Tooltips need REAPER 7.03 or newer.")
      end
      ImGui.Spacing(ctx)
      ImGui.Text(ctx, "Sizes")
      local function size_slider(label, k, lo, hi)
        ImGui.SetNextItemWidth(ctx, 200)
        local ch, v = ImGui.SliderInt(ctx, label, size_of(k), lo, hi)
        if ch then tb_set(k, v) end
      end
      size_slider("Window text size", "ui_font", FONT_MIN, 20)
      size_slider("Tool text size", "tool_font", FONT_MIN, FONT_MAX)
      size_slider("Tool button height", "tool_h", 20, 120)
      size_slider("Tool button min. width", "tool_w", 50, 300)
      if ImGui.SmallButton(ctx, "Default sizes") then
        for k, v in pairs(SIZE_DEFAULTS) do tb_set(k, v) end
      end
      c, b = ImGui.Checkbox(ctx, "Close the window after choosing a tool (Tools tab)", tb_setting("autoclose", false))
      if c then tb_set("autoclose", b) end
    end

    if ImGui.CollapsingHeader(ctx, "Presets") then
      if ImGui.Button(ctx, "Export...") then later(export_preset) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Import...") then later(import_preset) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Reset to defaults") then later(reset_defaults) end
    end

    if ImGui.CollapsingHeader(ctx, "Scripts") then
      ImGui.Text(ctx, string.format("Scripts in the Action List: %d / %d", n_registered, n_total))
      if ImGui.Button(ctx, "Register scripts again") then
        later(function()
          register_companions(true)
          sync_all_toggles()
          n_registered, n_total = count_registered()
        end)
      end
      ImGui.TextDisabled(ctx, "Assign shortcuts in the Action List to:")
      ImGui.TextDisabled(ctx, "  Main section: ReNo Mellow - Swiss Army Knife  /  (alt)  /  (alt2)")
      ImGui.TextDisabled(ctx, "  MIDI Editor section: ReNo Mellow - Swiss Army Knife MIDI  /  (alt)  /  (alt2)")
      ImGui.TextDisabled(ctx, "  ... - Next tool / Previous tool / Select tool 01-24 (both sections)")
    end

    ImGui.EndChild(ctx)
  end
end

---------------------------------------------------------------- main loop
local function loop()
  poll_pick()

  ImGui.PushFont(ctx, fonts[size_of("ui_font")])
  ImGui.SetNextWindowSize(ctx, 600, 420, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, TB_CTX == "midi" and "Swiss Army Knife MIDI" or "Swiss Army Knife", true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Tools") then
        draw_tools()
        ImGui.EndTabItem(ctx)
      end
      if ImGui.BeginTabItem(ctx, "Setup") then
        draw_setup()
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if close_request then open = false end

  if post then
    local fn = post
    post = nil
    fn()
  end

  if open then reaper.defer(loop) end
end

reaper.atexit(function()
  cancel_pick()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
end)

-- start-up: register the companion scripts first, then create the
-- ImGui context in a later cycle, right before the first frame
reaper.defer(function()
  register_companions(false)
  sync_all_toggles()
  n_registered, n_total = count_registered()
  reaper.defer(function()
    ctx = ImGui.CreateContext(TB_CTX == "midi" and "ReNo Mellow - Swiss Army Knife MIDI" or "ReNo Mellow - Swiss Army Knife")
    for sz = FONT_MIN, FONT_MAX do
      fonts[sz] = ImGui.CreateFont("sans-serif", sz)
      ImGui.Attach(ctx, fonts[sz])
    end
    loop()
  end)
end)
