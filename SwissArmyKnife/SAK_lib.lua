-- @noindex
-- ReNo Mellow - Swiss Army Knife : shared library
-- Not an action: loaded by the other Swiss Army Knife scripts (keep it in the same folder).

SAK = {}

local S = "ReNoMellow_SAK"
SAK.NSLOTS = 24
SAK.KEYS   = { "main", "alt", "alt2" }
SAK.LABELS = { main = "Main", alt = "Alt", alt2 = "Alt 2" }

local function gets(k) return reaper.GetExtState(S, k) end
local function sets(k, v) reaper.SetExtState(S, k, tostring(v), true) end
SAK.gets, SAK.sets = gets, sets

---------------------------------------------------------------- context
-- "main" = arrange view (Main section), "midi" = MIDI editor (section 32060)
-- Each context has its own 24 tools and its own current tool.
SAK.CONTEXTS = {
  main = { prefix = "",    section = 0,     arm = "",            label = "Arrange" },
  midi = { prefix = "me_", section = 32060, arm = "MIDI Editor", label = "MIDI Editor" },
}
SAK.context = "main"
local P = ""

function SAK.set_context(c)
  if not SAK.CONTEXTS[c] then c = "main" end
  SAK.context = c
  P = SAK.CONTEXTS[c].prefix
  SAK.section = SAK.CONTEXTS[c].section
  SAK.arm_section = SAK.CONTEXTS[c].arm
end
SAK.set_context("main")

-- context-dependent keys
local function cgets(k) return gets(P .. k) end
local function csets(k, v) sets(P .. k, v) end
SAK.cgets, SAK.csets = cgets, csets

-- Default tools : { name, main, alt, alt2 }
SAK.DEFAULTS = {
  main = { { "Split", "40012", "40061", "40932" } },  -- edit cursor / time selection / grid
  midi = { { "Split", "40046", "40052", "40641" } },  -- edit cursor / mouse cursor / grid
}

---------------------------------------------------------------- settings
function SAK.setting(k, default)
  local v = gets("opt_" .. k)
  if v == "" then return default end
  if type(default) == "boolean" then return v == "1" end
  if type(default) == "number" then return tonumber(v) or default end
  return v
end

function SAK.set_setting(k, v)
  if type(v) == "boolean" then v = v and "1" or "0" end
  sets("opt_" .. k, v)
end

---------------------------------------------------------------- tools
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end
SAK.trim = trim

function SAK.get_tool(i)
  return {
    name = cgets("name_" .. i),
    main = cgets("main_" .. i),
    alt  = cgets("alt_" .. i),
    alt2 = cgets("alt2_" .. i),
  }
end

function SAK.set_tool(i, t)
  csets("name_" .. i, ((t.name or ""):gsub("[\t\r\n]", " ")))
  for _, k in ipairs(SAK.KEYS) do csets(k .. "_" .. i, trim(t[k])) end
end

function SAK.is_empty(i, t)
  t = t or SAK.get_tool(i)
  return t.name == "" and t.main == "" and t.alt == "" and t.alt2 == ""
end

function SAK.display_name(i, t)
  t = t or SAK.get_tool(i)
  if t.name ~= "" then return t.name end
  return "Tool " .. i
end

function SAK.load_defaults()
  for i = 1, SAK.NSLOTS do
    local d = SAK.DEFAULTS[SAK.context][i] or {}
    SAK.set_tool(i, { name = d[1] or "", main = d[2] or "", alt = d[3] or "", alt2 = d[4] or "" })
  end
  csets("current", 1)
end

function SAK.ensure_init()
  if cgets("initialized") == "1" then return end
  SAK.load_defaults()
  csets("initialized", "1")
end

---------------------------------------------------------------- action IDs
-- Accepts "40012", "_SWS_ABOUT", "SWS_ABOUT", "_RS...", custom action hash...
function SAK.normalize_id(s)
  s = trim(s)
  if s == "" then return "" end
  if s:match("^%d+$") then return s end
  if s:sub(1, 1) ~= "_" then s = "_" .. s end
  return s
end

function SAK.resolve(id)
  id = trim(id)
  if id == "" then return 0 end
  local n = tonumber(id)
  if n then return math.floor(n) end
  if id:sub(1, 1) ~= "_" then id = "_" .. id end
  return reaper.NamedCommandLookup(id) or 0
end

function SAK.id_from_cmd(cmd)
  local n = reaper.ReverseNamedCommandLookup(cmd)
  if n and n ~= "" then return "_" .. n end
  return tostring(cmd)
end

function SAK.action_name(id)
  local cmd = SAK.resolve(id)
  if cmd == 0 then return nil end
  local t
  if reaper.CF_GetCommandText then
    t = reaper.CF_GetCommandText(SAK.section, cmd)
  else
    t = reaper.kbd_getTextFromCmd(cmd, reaper.SectionFromUniqueID(SAK.section))
  end
  if not t or t == "" then return nil end
  return t
end

---------------------------------------------------------------- current tool
function SAK.get_current()
  local c = tonumber(cgets("current")) or 1
  if c < 1 or c > SAK.NSLOTS then c = 1 end
  return c
end

function SAK.set_current(i)
  csets("current", i)
end

-- Remember the command ID of the running script (used for toolbar toggle states)
function SAK.register_self(key)
  local _, _, _, cmd = reaper.get_action_context()
  if cmd and cmd > 0 then
    local id = SAK.id_from_cmd(cmd)
    if cgets(key) ~= id then csets(key, id) end
  end
end

---------------------------------------------------------------- tooltip
-- Needs REAPER 7.03+ (set_action_options) so the script can re-launch while
-- the tooltip is shown. On older versions no tooltip is shown.
function SAK.tooltip(txt)
  if not reaper.set_action_options then return end
  local x, y = reaper.GetMousePosition()
  reaper.TrackCtl_SetToolTip(txt, x + 18, y + 18, true)
  local t0  = reaper.time_precise()
  local dur = SAK.setting("tt_dur", 1.0)
  local function wait()
    if reaper.time_precise() - t0 < dur then
      reaper.defer(wait)
    else
      reaper.TrackCtl_SetToolTip("", 0, 0, true)
    end
  end
  reaper.defer(wait)
end

function SAK.prepare_script()
  -- 1: terminate the running instance when re-launched, 2: then re-launch
  if reaper.set_action_options then reaper.set_action_options(1 | 2) end
end

---------------------------------------------------------------- actions
-- which = "main", "alt" or "alt2"
function SAK.run(which)
  SAK.ensure_init()
  local i  = SAK.get_current()
  local t  = SAK.get_tool(i)
  local id = t[which] or ""
  if id == "" then return end -- nothing assigned: do nothing

  local label = SAK.display_name(i, t)
  if which ~= "main" then label = label .. " (" .. SAK.LABELS[which] .. ")" end

  local cmd = SAK.resolve(id)
  if cmd == 0 then
    SAK.tooltip("SAK: action not found (" .. id .. ")")
    return
  end

  if SAK.context == "midi" then
    if not reaper.MIDIEditor_GetActive() then
      SAK.tooltip("SAK: open a MIDI editor first")
      return
    end
    reaper.Undo_BeginBlock()
    reaper.MIDIEditor_LastFocused_OnCommand(cmd, false)
    reaper.Undo_EndBlock("SAK MIDI: " .. label, -1)
  else
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(cmd, 0)
    reaper.Undo_EndBlock("SAK: " .. label, -1)
  end

  if SAK.setting("tt_use", true) then SAK.tooltip("SAK: " .. label) end
end

function SAK.step(dir)
  SAK.ensure_init()
  local cur, n = SAK.get_current(), SAK.NSLOTS
  for k = 1, n do
    local i = ((cur - 1 + dir * k) % n) + 1
    if not SAK.is_empty(i) then
      SAK.set_current(i)
      if SAK.setting("tt_change", true) then SAK.tooltip("SAK tool: " .. SAK.display_name(i)) end
      return
    end
  end
end
