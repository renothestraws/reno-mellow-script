-- @noindex
-- ReNo Mellow - Mousewheel Buddy : shared library
-- Not an action: loaded by the other Mousewheel Buddy scripts (keep it in the same folder).

MWB = {}
local r = reaper

local S = "ReNoMellow_MousewheelBuddy"
local function gets(k) return r.GetExtState(S, k) end
local function sets(k, v) r.SetExtState(S, k, tostring(v), true) end
MWB.gets, MWB.sets = gets, sets

-- settings made with the test versions (named "Smart Mousewheel") are copied once
if gets("migrated") == "" then
  local OLD = "ReNoMellow_SmartMousewheel"
  local keys = { "opt_invert_main", "opt_invert_midi", "opt_hzoom_main", "opt_vzoom_main",
                 "opt_hzoom_midi", "opt_vzoom_midi", "opt_ui_font" }
  for _, z in ipairs({ "ruler", "item", "env", "track", "empty", "mcp", "transport", "other" }) do
    keys[#keys + 1] = z .. "_up"; keys[#keys + 1] = z .. "_down"
  end
  for _, z in ipairs({ "ruler", "notes", "cc", "other" }) do
    keys[#keys + 1] = "me_" .. z .. "_up"; keys[#keys + 1] = "me_" .. z .. "_down"
  end
  for _, k in ipairs(keys) do
    local v = r.GetExtState(OLD, k)
    if v ~= "" then sets(k, v) end
  end
  sets("migrated", "1")
end

---------------------------------------------------------------- zones
-- Each context has its own list of zones. A zone = where the mouse is when the wheel turns.
-- up / down = default actions (empty = do nothing).
MWB.CONTEXTS = {
  main = {
    label = "Arrange", section = 0, prefix = "",
    zones = {
      { key = "ruler",     label = "Ruler / timeline",        up = "1012",            down = "1011" },
      { key = "item",      label = "Item",                    up = "40138",           down = "40139" },
      { key = "env",       label = "Envelope lane",           up = "40138",           down = "40139" },
      { key = "track",     label = "Track lane (no item)",    up = "40138",           down = "40139" },
      { key = "empty",     label = "Empty area below tracks", up = "40138",           down = "40139" },
      { key = "mcp",       label = "Mixer (MCP)",             up = "",                down = "" },
      { key = "transport", label = "Transport",               up = "_SWS_SCROLL_L10", down = "_SWS_SCROLL_R10" },
      { key = "other",     label = "Other (scrollbars...)",   up = "40111",           down = "40112" },
    },
  },
  midi = {
    label = "MIDI Editor", section = 32060, prefix = "me_",
    zones = {
      { key = "ruler", label = "Ruler / timeline",      up = "1012",  down = "1011" },
      { key = "notes", label = "Notes area",            up = "40138", down = "40139" },
      { key = "cc",    label = "CC lanes",              up = "40140", down = "40141" },
      { key = "other", label = "Other (scrollbars...)", up = "",      down = "" },
    },
  },
}

local function zone_def(ctx, key)
  for _, z in ipairs(MWB.CONTEXTS[ctx].zones) do
    if z.key == key then return z end
  end
end

---------------------------------------------------------------- modifiers
-- One wheel action per modifier combination (8 in the Main section, 8 in the MIDI Editor section).
-- The combination comes from the action file name: "... - Wheel (Ctrl+Shift).lua".
-- On macOS REAPER shows Ctrl as Cmd and Alt as Opt (the file names stay the same).
MWB.MODS = {
  { key = "",    file = "" },
  { key = "c",   file = "Ctrl" },
  { key = "s",   file = "Shift" },
  { key = "a",   file = "Alt" },
  { key = "cs",  file = "Ctrl+Shift" },
  { key = "ca",  file = "Ctrl+Alt" },
  { key = "sa",  file = "Shift+Alt" },
  { key = "csa", file = "Ctrl+Shift+Alt" },
}
local os_name = r.GetOS() or ""
MWB.IS_MAC = (os_name:find("OSX") or os_name:find("macOS")) ~= nil

function MWB.mod_label(m)
  if m.key == "" then return "Wheel" end
  local t = m.file
  if MWB.IS_MAC then t = t:gsub("Ctrl", "Cmd"):gsub("Alt", "Opt") end
  return t .. "+Wheel"
end

function MWB.mod_from_path(path)
  local name = (path or ""):match("%(([%w%+]+)%)%.lua$")
  if not name then return "" end
  for _, m in ipairs(MWB.MODS) do
    if m.file == name then return m.key end
  end
  return ""
end

-- Default actions of the modifier combinations (like REAPER's own wheel modifiers):
-- Ctrl = zoom vertically, Alt = scroll left/right, Ctrl+Alt = scroll up/down.
local MOD_DEFAULTS = {
  c  = { up = "40111", down = "40112" },
  a  = { up = "40140", down = "40141" },
  ca = { up = "40138", down = "40139" },
}

local function default_action(ctx, mod, key, dir)
  if mod == "" then
    local z = zone_def(ctx, key)
    return z and z[dir] or ""
  end
  local d = MOD_DEFAULTS[mod]
  return d and d[dir] or ""
end

local function akey(ctx, mod, key, dir)
  local p = MWB.CONTEXTS[ctx].prefix
  if mod ~= "" then p = p .. mod .. "_" end
  return p .. key .. "_" .. dir
end

---------------------------------------------------------------- settings
-- Stored action = the text typed by the user; "-" = cleared on purpose (do nothing)
function MWB.get_action(ctx, mod, key, dir)
  local v = gets(akey(ctx, mod, key, dir))
  if v == "" then return default_action(ctx, mod, key, dir) end
  if v == "-" then return "" end
  return v
end

function MWB.set_action(ctx, mod, key, dir, id)
  id = MWB.normalize_id(id)
  sets(akey(ctx, mod, key, dir), id == "" and "-" or id)
end

function MWB.reset(ctx, mod)
  for _, z in ipairs(MWB.CONTEXTS[ctx].zones) do
    r.DeleteExtState(S, akey(ctx, mod, z.key, "up"), true)
    r.DeleteExtState(S, akey(ctx, mod, z.key, "down"), true)
  end
end

---------------------------------------------------------------- banks
-- A bank = every wheel action (both sections, 8 key combinations, all zones) + the
-- direction and zoom center settings, saved as a small text file:
--   Data/ReNo_MousewheelBuddy/Banks/<name>.mwbank
-- Lines "key=value"; an empty value = default action, "-" = do nothing.
local BANK_EXT = ".mwbank"
MWB.BANK_DIR = r.GetResourcePath() .. "/Data/ReNo_MousewheelBuddy/Banks"

local function bank_keys()
  local keys = {}
  for _, c in ipairs({ "main", "midi" }) do
    for _, m in ipairs(MWB.MODS) do
      for _, z in ipairs(MWB.CONTEXTS[c].zones) do
        keys[#keys + 1] = akey(c, m.key, z.key, "up")
        keys[#keys + 1] = akey(c, m.key, z.key, "down")
      end
    end
    for _, o in ipairs({ "invert_", "hzoom_", "vzoom_" }) do keys[#keys + 1] = "opt_" .. o .. c end
  end
  return keys
end

local function clean_name(name)
  name = (name or ""):gsub("[\\/:%*%?\"<>|]", ""):match("^%s*(.-)%s*$")
  return name
end
MWB.clean_bank_name = clean_name

function MWB.bank_path(name) return MWB.BANK_DIR .. "/" .. name .. BANK_EXT end

function MWB.list_banks()
  local t, i = {}, 0
  r.EnumerateFiles(MWB.BANK_DIR, -1)  -- refresh the file cache
  while true do
    local f = r.EnumerateFiles(MWB.BANK_DIR, i)
    if not f then break end
    local n = f:match("^(.*)%" .. BANK_EXT .. "$")
    if n then t[#t + 1] = n end
    i = i + 1
  end
  table.sort(t, function(a, b) return a:lower() < b:lower() end)
  return t
end

-- returns true, or nil + error text
function MWB.save_bank(name)
  name = clean_name(name)
  if name == "" then return nil, "Type a name for the bank first." end
  r.RecursiveCreateDirectory(MWB.BANK_DIR, 0)
  local f = io.open(MWB.bank_path(name), "w")
  if not f then return nil, "Cannot write the file:\n" .. MWB.bank_path(name) end
  f:write("# ReNo Mellow - Mousewheel Buddy bank 1\n")
  for _, k in ipairs(bank_keys()) do f:write(k, "=", gets(k), "\n") end
  f:close()
  sets("bank_current", name)
  return true
end

-- path = any .mwbank file (a bank of the list or an imported file)
function MWB.load_bank(path)
  local f = io.open(path, "r")
  if not f then return nil, "Cannot read the file:\n" .. path end
  local first = f:read("l") or ""
  if not first:find("Mousewheel Buddy bank", 1, true) then
    f:close()
    return nil, "This file is not a Mousewheel Buddy bank."
  end
  local vals = {}
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k then vals[k] = v end
  end
  f:close()
  for _, k in ipairs(bank_keys()) do  -- keys missing from the file go back to their default
    local v = vals[k] or ""
    if v == "" then r.DeleteExtState(S, k, true) else sets(k, v) end
  end
  local name = path:match("([^/\\]+)%" .. BANK_EXT .. "$") or path:match("([^/\\]+)$")
  sets("bank_current", name)
  return true
end

-- copies an outside .mwbank file into the bank folder (same name), then loads it
function MWB.import_bank(path)
  local f = io.open(path, "rb")
  if not f then return nil, "Cannot read the file:\n" .. path end
  local data = f:read("a")
  f:close()
  if not data:find("Mousewheel Buddy bank", 1, true) then return nil, "This file is not a Mousewheel Buddy bank." end
  local name = clean_name(path:match("([^/\\]+)%.%w+$") or path:match("([^/\\]+)$") or "Imported")
  r.RecursiveCreateDirectory(MWB.BANK_DIR, 0)
  local dest = MWB.bank_path(name)
  local o = io.open(dest, "wb")
  if not o then return nil, "Cannot write the file:\n" .. dest end
  o:write(data)
  o:close()
  return MWB.load_bank(dest)
end

function MWB.delete_bank(name)
  return os.remove(MWB.bank_path(name))
end

function MWB.current_bank() return gets("bank_current") end

function MWB.setting(k, default)
  local v = gets("opt_" .. k)
  if v == "" then return default end
  if type(default) == "boolean" then return v == "1" end
  if type(default) == "number" then return tonumber(v) or default end
  return v
end

function MWB.set_setting(k, v)
  if type(v) == "boolean" then v = v and "1" or "0" end
  sets("opt_" .. k, v)
end

---------------------------------------------------------------- action IDs
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

-- Accepts "40012", "_SWS_ABOUT", "SWS_ABOUT", "_RS...", custom action hash...
function MWB.normalize_id(s)
  s = trim(s)
  if s == "" or s == "-" then return "" end
  if s:match("^%d+$") then return s end
  if s:sub(1, 1) ~= "_" then s = "_" .. s end
  return s
end

function MWB.resolve(id)
  id = MWB.normalize_id(id)
  if id == "" then return 0 end
  local n = tonumber(id)
  if n then return math.floor(n) end
  return r.NamedCommandLookup(id) or 0
end

function MWB.id_from_cmd(cmd)
  local n = r.ReverseNamedCommandLookup(cmd)
  if n and n ~= "" then return "_" .. n end
  return tostring(cmd)
end

function MWB.action_name(id, section)
  local cmd = MWB.resolve(id)
  if cmd == 0 then return nil end
  local t
  if r.CF_GetCommandText then
    t = r.CF_GetCommandText(section, cmd)
  else
    t = r.kbd_getTextFromCmd(cmd, r.SectionFromUniqueID(section))
  end
  if not t or t == "" then return nil end
  return t
end

---------------------------------------------------------------- mouse zone
-- Returns context ("main" / "midi") and zone key, or nil when SWS is missing.
function MWB.mouse_zone(window, segment, details)
  if not window then
    if not r.BR_GetMouseCursorContext then return nil end
    window, segment, details = r.BR_GetMouseCursorContext()
  end
  if window == "midi_editor" then
    if segment == "ruler" then return "midi", "ruler" end
    -- the piano roll keyboard is not listed: REAPER handles the wheel there itself
    if segment == "piano" then return "midi", "none" end
    if segment == "notes" then return "midi", "notes" end
    if segment == "cc_lane" then return "midi", "cc" end
    return "midi", "other"
  end
  if window == "ruler" then return "main", "ruler" end
  if window == "transport" then return "main", "transport" end
  if window == "mcp" then return "main", "mcp" end
  -- the track panel (TCP) is not listed: REAPER scrolls it with the wheel itself
  if window == "tcp" then return "main", "none" end
  if window == "arrange" then
    if details == "item" or details == "stretch_marker" then return "main", "item" end
    if segment == "envelope" or details == "env_point" or details == "env_segment" then return "main", "env" end
    if segment == "track" then return "main", "track" end
    return "main", "empty"
  end
  return "main", "other"
end

---------------------------------------------------------------- run
-- Zoom centers: the Mousewheel Buddy choice overrides Preferences > Zoom/Scroll/Offset
-- while the action runs, then the preference is restored.
-- value -1 = keep the preference ; otherwise the REAPER value of "zoommode" / "vzoommode"
MWB.HZOOM_ITEMS = { "Preferences", "Edit or play cursor", "Edit cursor", "Center of view", "Mouse cursor" }
MWB.VZOOM_ITEMS = { "Preferences", "Track at view center", "Top visible track", "Last selected track", "Track under mouse" }
MWB.ZOOM_DEFAULT = 3  -- mouse cursor / track under mouse

local function with_zoom_center(ctx, fn)
  local h = MWB.setting("hzoom_" .. ctx, MWB.ZOOM_DEFAULT)
  local v = MWB.setting("vzoom_" .. ctx, MWB.ZOOM_DEFAULT)
  if not r.SNM_GetIntConfigVar or (h < 0 and v < 0) then fn() return end
  local h0 = r.SNM_GetIntConfigVar("zoommode", -1)
  local v0 = r.SNM_GetIntConfigVar("vzoommode", -1)
  if h >= 0 and h0 >= 0 then r.SNM_SetIntConfigVar("zoommode", h) end
  if v >= 0 and v0 >= 0 then r.SNM_SetIntConfigVar("vzoommode", v) end
  fn()
  if h >= 0 and h0 >= 0 then r.SNM_SetIntConfigVar("zoommode", h0) end
  if v >= 0 and v0 >= 0 then r.SNM_SetIntConfigVar("vzoommode", v0) end
end

local function run_cmd(ctx, cmd)
  if ctx == "midi" then
    if not r.MIDIEditor_GetActive() then return false end
    with_zoom_center(ctx, function() r.MIDIEditor_LastFocused_OnCommand(cmd, false) end)
  else
    with_zoom_center(ctx, function() r.Main_OnCommand(cmd, 0) end)
  end
  return true
end

-- Called by the two wheel actions. Never shows a dialog for a normal wheel turn
-- (one dialog per REAPER session at most, when SWS is missing).
-- ac = the result of get_action_context(), read on the first line of the action file
-- (the wheel value must be read before anything else).
function MWB.run_wheel(from_ctx, ac)
  ac = ac or { r.get_action_context() }
  local sec, cmd, mode, res, val = ac[3], ac[4], ac[5], ac[6], ac[7]
  local mod = MWB.mod_from_path(ac[2])

  -- one-shot action: toolbar button always off
  if cmd and cmd > 0 then
    r.SetToggleCommandState(sec, cmd, 0)
    r.RefreshToolbar2(sec, cmd)
    local k = ((from_ctx == "midi") and "me_self" or "self") .. (mod ~= "" and ("_" .. mod) or "")
    local id = MWB.id_from_cmd(cmd)
    if gets(k) ~= id then sets(k, id) end
  end

  if not r.BR_GetMouseCursorContext then
    if r.GetExtState(S, "sws_warned") == "" then
      r.SetExtState(S, "sws_warned", "1", false)
      r.MB("Mousewheel Buddy needs the SWS extension.\nInstall it from sws-extension.org (or with ReaPack), then restart REAPER.",
        "Mousewheel Buddy", 0)
    end
    return
  end

  local window, segment, details = r.BR_GetMouseCursorContext()
  local ctx, zone = MWB.mouse_zone(window, segment, details)
  if from_ctx == "midi" and ctx ~= "midi" then ctx, zone = "midi", "other" end  -- launched from the MIDI editor section
  -- last wheel event, shown in the Setup window (helps to set up and to find problems)
  r.SetExtState(S, "last_info", string.format("%s %s | val %s, mode %s, res %s | %s / %s / %s",
    from_ctx, mod == "" and "wheel" or mod, tostring(val), tostring(mode), tostring(res), tostring(window), tostring(segment), tostring(details))
    .. " -> " .. zone, false)

  -- launched without a wheel value (Run button, menu, key): nothing to do, no dialog
  if not val or val == 0 then return end

  r.SetExtState(S, "last_zone", ctx .. ":" .. mod .. ":" .. zone, false)  -- shown in the Setup window

  if zone == "none" then return end  -- zone left to REAPER

  -- Fast wheel turns: REAPER adds up several notches in one value, which can overflow
  -- and come back with the wrong sign (the view jumps backwards). A change of direction
  -- less than 120 ms after the previous notch is treated as an overflow: same direction
  -- as before, and the real number of notches is rebuilt.
  local now = r.time_precise()
  local unit = tonumber(gets("wheel_unit")) or 15          -- smallest value seen = one notch
  local a = math.abs(val)
  if a < unit then unit = a; sets("wheel_unit", unit) end
  local dir = (val > 0) and 1 or -1
  local last_dir = tonumber(r.GetExtState(S, "last_dir")) or 0
  local last_t = tonumber(r.GetExtState(S, "last_t")) or 0
  if last_dir ~= 0 and dir ~= last_dir and (now - last_t) < 0.12 then
    dir = last_dir
    local range = (res and res > 0) and (res + 1) or 128
    if a < range then a = range - a end
  end
  r.SetExtState(S, "last_dir", tostring(dir), false)
  r.SetExtState(S, "last_t", tostring(now), false)
  local steps = math.max(1, math.min(10, math.floor(a / unit + 0.5)))

  local up = dir > 0
  if MWB.setting("invert_" .. ctx, false) then up = not up end
  local id = MWB.get_action(ctx, mod, zone, up and "up" or "down")
  local c = MWB.resolve(id)
  if c == 0 then
    r.SetExtState(S, "last_info", r.GetExtState(S, "last_info") .. " | no action", false)
    return
  end
  for _ = 1, steps do run_cmd(ctx, c) end
  r.SetExtState(S, "last_info", r.GetExtState(S, "last_info") .. " | ran " .. id ..
    (steps > 1 and (" x" .. steps) or ""), false)
  -- no r.defer here: the script ends at once, so a fast next notch never finds it still running
end
