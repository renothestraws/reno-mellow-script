-- @noindex
-- ReNo Mellow - Tool Buddy : shared library
-- Not an action: loaded by the other Tool Buddy scripts (keep it in the same folder).

TB = {}

local S = "ReNoMellow_ToolBuddy"
TB.NSLOTS = 24
TB.KEYS   = { "main", "alt", "alt2" }
TB.LABELS = { main = "Main", alt = "Alt", alt2 = "Alt 2" }

local function gets(k) return reaper.GetExtState(S, k) end
local function sets(k, v) reaper.SetExtState(S, k, tostring(v), true) end
TB.gets, TB.sets = gets, sets

---------------------------------------------------------------- migration
-- Tool Buddy was called "Swiss Army Knife" (ExtState section ReNoMellow_SAK) until 1.9.
-- The tools, current tools and settings are copied once from the old section.
-- Action IDs are not copied: the scripts have new names, they are registered again.
local OLD = "ReNoMellow_SAK"
if gets("migrated") == "" then
  if reaper.GetExtState(OLD, "initialized") ~= "" or reaper.GetExtState(OLD, "me_initialized") ~= "" then
    local function copy(k)
      local v = reaper.GetExtState(OLD, k)
      if v ~= "" then sets(k, v) end
    end
    for _, p in ipairs({ "", "me_" }) do
      copy(p .. "current"); copy(p .. "initialized"); copy(p .. "disp_wanted")
      for i = 1, 24 do
        for _, k in ipairs({ "name_", "main_", "alt_", "alt2_" }) do copy(p .. k .. i) end
      end
    end
    for _, k in ipairs({ "tt_change", "tt_use", "tt_dur" }) do copy("opt_" .. k) end
    for _, c in ipairs({ "main", "midi" }) do
      for _, k in ipairs({ "ui_font", "tool_font", "tool_h", "tool_w", "autoclose", "disp_font" }) do
        copy("opt_" .. k .. "_" .. c)
      end
    end
  end
  sets("migrated", "1")
end

---------------------------------------------------------------- context
-- "main" = arrange view (Main section), "midi" = MIDI editor (section 32060)
-- Each context has its own 24 tools and its own current tool.
TB.CONTEXTS = {
  main = { prefix = "",    section = 0,     arm = "",            label = "Arrange" },
  midi = { prefix = "me_", section = 32060, arm = "MIDI Editor", label = "MIDI Editor" },
}
TB.context = "main"
local P = ""

function TB.set_context(c)
  if not TB.CONTEXTS[c] then c = "main" end
  TB.context = c
  P = TB.CONTEXTS[c].prefix
  TB.section = TB.CONTEXTS[c].section
  TB.arm_section = TB.CONTEXTS[c].arm
end
TB.set_context("main")

-- context-dependent keys
local function cgets(k) return gets(P .. k) end
local function csets(k, v) sets(P .. k, v) end
TB.cgets, TB.csets = cgets, csets

-- Default tools : { name, main, alt, alt2 }
TB.DEFAULTS = {
  main = { { "Split", "40012", "40061", "40932" } },  -- edit cursor / time selection / grid
  midi = { { "Split", "40046", "40052", "40641" } },  -- edit cursor / mouse cursor / grid
}

---------------------------------------------------------------- settings
function TB.setting(k, default)
  local v = gets("opt_" .. k)
  if v == "" then return default end
  if type(default) == "boolean" then return v == "1" end
  if type(default) == "number" then return tonumber(v) or default end
  return v
end

function TB.set_setting(k, v)
  if type(v) == "boolean" then v = v and "1" or "0" end
  sets("opt_" .. k, v)
end

---------------------------------------------------------------- tools
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end
TB.trim = trim

function TB.get_tool(i)
  return {
    name = cgets("name_" .. i),
    main = cgets("main_" .. i),
    alt  = cgets("alt_" .. i),
    alt2 = cgets("alt2_" .. i),
  }
end

function TB.set_tool(i, t)
  csets("name_" .. i, ((t.name or ""):gsub("[\t\r\n]", " ")))
  for _, k in ipairs(TB.KEYS) do csets(k .. "_" .. i, trim(t[k])) end
end

function TB.is_empty(i, t)
  t = t or TB.get_tool(i)
  return t.name == "" and t.main == "" and t.alt == "" and t.alt2 == ""
end

function TB.display_name(i, t)
  t = t or TB.get_tool(i)
  if t.name ~= "" then return t.name end
  return "Tool " .. i
end

function TB.load_defaults()
  for i = 1, TB.NSLOTS do
    local d = TB.DEFAULTS[TB.context][i] or {}
    TB.set_tool(i, { name = d[1] or "", main = d[2] or "", alt = d[3] or "", alt2 = d[4] or "" })
  end
  csets("current", 1)
end

function TB.ensure_init()
  if cgets("initialized") == "1" then return end
  TB.load_defaults()
  csets("initialized", "1")
end

---------------------------------------------------------------- action IDs
-- Accepts "40012", "_SWS_ABOUT", "SWS_ABOUT", "_RS...", custom action hash...
function TB.normalize_id(s)
  s = trim(s)
  if s == "" then return "" end
  if s:match("^%d+$") then return s end
  if s:sub(1, 1) ~= "_" then s = "_" .. s end
  return s
end

function TB.resolve(id)
  id = trim(id)
  if id == "" then return 0 end
  local n = tonumber(id)
  if n then return math.floor(n) end
  if id:sub(1, 1) ~= "_" then id = "_" .. id end
  return reaper.NamedCommandLookup(id) or 0
end

function TB.id_from_cmd(cmd)
  local n = reaper.ReverseNamedCommandLookup(cmd)
  if n and n ~= "" then return "_" .. n end
  return tostring(cmd)
end

function TB.action_name(id)
  local cmd = TB.resolve(id)
  if cmd == 0 then return nil end
  local t
  if reaper.CF_GetCommandText then
    t = reaper.CF_GetCommandText(TB.section, cmd)
  else
    t = reaper.kbd_getTextFromCmd(cmd, reaper.SectionFromUniqueID(TB.section))
  end
  if not t or t == "" then return nil end
  return t
end

---------------------------------------------------------------- current tool
function TB.get_current()
  local c = tonumber(cgets("current")) or 1
  if c < 1 or c > TB.NSLOTS then c = 1 end
  return c
end

function TB.set_current(i)
  csets("current", i)
end

-- Remember the command ID of the running script (used for toolbar toggle states)
function TB.register_self(key)
  local _, _, _, cmd = reaper.get_action_context()
  if cmd and cmd > 0 then
    local id = TB.id_from_cmd(cmd)
    if cgets(key) ~= id then csets(key, id) end
  end
end

---------------------------------------------------------------- tooltip
-- Needs REAPER 7.03+ (set_action_options) so the script can re-launch while
-- the tooltip is shown. On older versions no tooltip is shown.
function TB.tooltip(txt)
  if not reaper.set_action_options then return end
  local x, y = reaper.GetMousePosition()
  reaper.TrackCtl_SetToolTip(txt, x + 18, y + 18, true)
  local t0  = reaper.time_precise()
  local dur = TB.setting("tt_dur", 1.0)
  local function wait()
    if reaper.time_precise() - t0 < dur then
      reaper.defer(wait)
    else
      reaper.TrackCtl_SetToolTip("", 0, 0, true)
    end
  end
  reaper.defer(wait)
end

function TB.prepare_script()
  -- 1: terminate the running instance when re-launched, 2: then re-launch
  if reaper.set_action_options then reaper.set_action_options(1 | 2) end
end

---------------------------------------------------------------- actions
-- which = "main", "alt" or "alt2"
function TB.run(which)
  TB.ensure_init()
  local i  = TB.get_current()
  local t  = TB.get_tool(i)
  local id = t[which] or ""
  if id == "" then return end -- nothing assigned: do nothing

  local label = TB.display_name(i, t)
  if which ~= "main" then label = label .. " (" .. TB.LABELS[which] .. ")" end

  local cmd = TB.resolve(id)
  if cmd == 0 then
    TB.tooltip("Tool Buddy: action not found (" .. id .. ")")
    return
  end

  if TB.context == "midi" then
    if not reaper.MIDIEditor_GetActive() then
      TB.tooltip("Tool Buddy: open a MIDI editor first")
      return
    end
    reaper.Undo_BeginBlock()
    reaper.MIDIEditor_LastFocused_OnCommand(cmd, false)
    reaper.Undo_EndBlock("Tool Buddy MIDI: " .. label, -1)
  else
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(cmd, 0)
    reaper.Undo_EndBlock("Tool Buddy: " .. label, -1)
  end

  if TB.setting("tt_use", true) then TB.tooltip("Tool Buddy: " .. label) end
end

function TB.step(dir)
  TB.ensure_init()
  local cur, n = TB.get_current(), TB.NSLOTS
  for k = 1, n do
    local i = ((cur - 1 + dir * k) % n) + 1
    if not TB.is_empty(i) then
      TB.set_current(i)
      if TB.setting("tt_change", true) then TB.tooltip("Tool Buddy: " .. TB.display_name(i)) end
      return
    end
  end
end
