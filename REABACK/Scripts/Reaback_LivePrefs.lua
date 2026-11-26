-- @noindex
-- Reaback - Live preferences (library used by "Reaback Set up.lua")
-- Applies the REAPER preferences needed on stage, from a profile captured on a REAPER that is already set up.
--
-- How it works
--   * Every setting of the list is made of one or more REAPER config variables.
--   * "Capture my current settings" reads their current values and saves them in the profile
--     (file <REAPER resource path>/Data/REABACK/live_prefs.txt, can be copied to another computer).
--   * "Apply" writes the checked settings with SWS (SNM_Set...ConfigVar). The old values are saved first
--     (live_prefs_backup.txt) so "Restore" can put them back.
--   * When a setting is not found automatically, "Learn" finds its variable(s): start Learn, change the
--     setting in the Preferences window, click Apply there, put it back to the live value, Apply again, Done.
-- The ReaImGui page cannot be written (the settings belong to the extension): its button opens the page.

local M = {}

local DIR        = reaper.GetResourcePath() .. "/Data/REABACK"
local PROFILE    = DIR .. "/live_prefs.txt"
local BACKUP     = DIR .. "/live_prefs_backup.txt"
local WIN_TITLE  = "Reaback - Live preferences"
local SCAN_EVERY = 0.3                          -- seconds between two scans while learning

M.open = false

------------------------------------------------------------------------
-- The list of settings (candidate variable names: the first one that exists is used)
------------------------------------------------------------------------
local ITEMS = {
  { key = "startup",  group = "Project", label = "Open project(s) on startup: last active project",
    where = "General", slots = { { "loadlastproj" } } },
  { key = "template", group = "Project", label = "New project: use the ReaBack template",
    where = "Project", slots = { { "newprojtmpl" } }, template = true },
  { key = "newproj",  group = "Project", label = "New project: prompt to save + open project settings",
    where = "Project", slots = { { "newprojdo" } } },
  { key = "seek",     group = "Playback", label = "Seeking: top ruler only, smooth seek to next marker / region",
    where = "Audio > Seeking", slots = { { "seekmodes" }, { "smoothseek" }, { "smoothseekmeas" } } },
  { key = "device",   group = "Playback", label = "Audio device stays open when stopped",
    where = "Audio > Device", slots = { { "audiocloseinactive" } } },
  { key = "fades",    group = "Playback", label = "Tiny fade in on playback start: off (fade out stays on)",
    where = "Audio > Playback", slots = {} },
  { key = "buttons",  group = "Display", label = "Media item buttons (as on your capture)",
    where = "Appearance > Media Item Buttons", slots = { { "itemicons" } } },
  { key = "video",    group = "Display", label = "Video (output, decoder priority, delay, options)",
    where = "Media > Video", slots = {} },
}

------------------------------------------------------------------------
-- Config variables
------------------------------------------------------------------------
local function get_var(name)
  if not reaper.get_config_var_string then return nil end
  local ok, v = reaper.get_config_var_string(name)
  if ok then return v end
  return nil
end

local function has_sws() return reaper.SNM_SetIntConfigVar ~= nil end

-- returns true if the value could be written and reads back the same
local function set_var(name, val)
  if not has_sws() then return false end
  local cur = get_var(name)
  if cur == nil then return false end
  if cur == val then return true end
  local n = tonumber(val)
  local tried = {}
  if n and val:match("^%-?%d+$") then
    tried = { function() return reaper.SNM_SetIntConfigVar(name, math.floor(n)) end,
              function() return reaper.SNM_SetDoubleConfigVar(name, n) end }
  elseif n then
    tried = { function() return reaper.SNM_SetDoubleConfigVar(name, n) end,
              function() return reaper.SNM_SetIntConfigVar(name, math.floor(n)) end }
  end
  if reaper.SNM_SetStringConfigVar then
    tried[#tried + 1] = function() return reaper.SNM_SetStringConfigVar(name, val) end
  end
  for _, f in ipairs(tried) do
    local ok, res = pcall(f)
    if ok and res and get_var(name) == val then return true end
  end
  return get_var(name) == val
end

-- names of every variable of reaper.ini ([REAPER] section), used by Learn
local function ini_names()
  local list, seen = {}, {}
  local fh = io.open(reaper.get_ini_file(), "r")
  if not fh then return list end
  local inSec = false
  for line in fh:lines() do
    local sec = line:match("^%[(.-)%]")
    if sec then inSec = (sec:lower() == "reaper")
    elseif inSec then
      local k = line:match("^([%w_%.]+)=")
      if k and not seen[k] then seen[k] = true; list[#list + 1] = k end
    end
  end
  fh:close()
  return list
end

local function template_path()
  return reaper.GetResourcePath() .. "/ProjectTemplates/ReaBack.rpp"
end

------------------------------------------------------------------------
-- Profile (key -> list of { var, val })
------------------------------------------------------------------------
local profile, checked = {}, {}
local function esc(s) return (s:gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n")) end
local function unesc(s) return (s:gsub("\\(.)", { t = "\t", n = "\n", ["\\"] = "\\" })) end

local function save_file(path, data)
  reaper.RecursiveCreateDirectory(DIR, 0)
  local fh = io.open(path, "w")
  if not fh then return false end
  fh:write("# REABACK live preferences: key<TAB>variable<TAB>value\n")
  for _, it in ipairs(ITEMS) do
    for _, e in ipairs(data[it.key] or {}) do
      fh:write(it.key, "\t", e.var, "\t", esc(e.val), "\n")
    end
  end
  fh:close()
  return true
end

local function load_file(path)
  local data = {}
  local fh = io.open(path, "r")
  if not fh then return nil end
  for line in fh:lines() do
    if line:sub(1, 1) ~= "#" then
      local k, v, val = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
      if k then
        data[k] = data[k] or {}
        data[k][#data[k] + 1] = { var = v, val = unesc(val) }
      end
    end
  end
  fh:close()
  return data
end

local function find_entry(list, var)
  for _, e in ipairs(list) do if e.var == var then return e end end
end

-- capture: values of the candidate variables found + the variables already in the profile
local function capture()
  local found, missing = 0, 0
  for _, it in ipairs(ITEMS) do
    local list = profile[it.key] or {}
    for _, cands in ipairs(it.slots) do
      local got
      for _, name in ipairs(cands) do
        if get_var(name) ~= nil then got = name; break end
      end
      if got and not find_entry(list, got) then list[#list + 1] = { var = got, val = "" } end
    end
    for _, e in ipairs(list) do
      local v = get_var(e.var)
      if v ~= nil then e.val = v end
    end
    profile[it.key] = list
    if #list > 0 then found = found + 1 else missing = missing + 1 end
  end
  save_file(PROFILE, profile)
  return found, missing
end

-- value that "Apply" writes for an entry (the template path is the one of this computer)
local function live_value(it, e)
  if it.template then return template_path() end
  return e.val
end

local function item_state(it)
  local list = profile[it.key]
  if not list or #list == 0 then return "missing" end
  for _, e in ipairs(list) do
    local cur = get_var(e.var)
    if cur == nil then return "unknown" end
    if cur ~= live_value(it, e) then return "different" end
  end
  return "ok"
end

------------------------------------------------------------------------
-- Learn
------------------------------------------------------------------------
local learn = nil          -- { key, names, snap, changed = {name = true}, order = {}, last }

local function learn_start(it)
  local names = ini_names()
  local seen = {}
  for _, n in ipairs(names) do seen[n] = true end
  for _, cands in ipairs(it.slots) do
    for _, n in ipairs(cands) do if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  end
  local snap = {}
  local kept = {}
  for _, n in ipairs(names) do
    local v = get_var(n)
    if v ~= nil then snap[n] = v; kept[#kept + 1] = n end
  end
  learn = { key = it.key, label = it.label, names = kept, snap = snap, changed = {}, order = {},
            last = reaper.time_precise() }
  reaper.Main_OnCommand(40016, 0)                      -- Options: Preferences...
end

local function learn_scan()
  if not learn then return end
  local now = reaper.time_precise()
  if now - learn.last < SCAN_EVERY then return end
  learn.last = now
  for _, n in ipairs(learn.names) do
    if not learn.changed[n] then
      local v = get_var(n)
      if v ~= nil and v ~= learn.snap[n] then
        learn.changed[n] = true
        learn.order[#learn.order + 1] = n
      end
    end
  end
end

local function learn_done()
  if not learn then return 0 end
  local list = profile[learn.key] or {}
  local n = 0
  for _, name in ipairs(learn.order) do
    local e = find_entry(list, name)
    if not e then e = { var = name, val = "" }; list[#list + 1] = e end
    e.val = get_var(name) or e.val
    n = n + 1
  end
  profile[learn.key] = list
  save_file(PROFILE, profile)
  learn = nil
  return n
end

------------------------------------------------------------------------
-- Apply / Restore
------------------------------------------------------------------------
local function apply()
  local backup = load_file(BACKUP) or {}
  local okN, failN, failed = 0, 0, {}
  for _, it in ipairs(ITEMS) do
    if checked[it.key] and profile[it.key] then
      local bl = {}
      for _, e in ipairs(profile[it.key]) do
        local cur = get_var(e.var)
        if cur ~= nil then bl[#bl + 1] = { var = e.var, val = cur } end
      end
      if #bl > 0 then backup[it.key] = bl end
    end
  end
  save_file(BACKUP, backup)
  for _, it in ipairs(ITEMS) do
    if checked[it.key] and profile[it.key] then
      for _, e in ipairs(profile[it.key]) do
        if set_var(e.var, live_value(it, e)) then okN = okN + 1
        else failN = failN + 1; failed[#failed + 1] = e.var end
      end
    end
  end
  return okN, failN, failed
end

local function restore()
  local backup = load_file(BACKUP)
  if not backup then return nil end
  local okN, failN = 0, 0
  for _, it in ipairs(ITEMS) do
    for _, e in ipairs(backup[it.key] or {}) do
      if set_var(e.var, e.val) then okN = okN + 1 else failN = failN + 1 end
    end
  end
  return okN, failN
end

------------------------------------------------------------------------
-- Extensions / ReaImGui page
------------------------------------------------------------------------
local EXTS = {
  { name = "ReaImGui",         ok = function() return reaper.ImGui_GetBuiltinPath ~= nil end,
    how = "ReaPack > Browse packages > search \"ReaImGui\" (ReaTeam Extensions)" },
  { name = "js_ReaScriptAPI",  ok = function() return reaper.JS_ReaScriptAPI_Version ~= nil end,
    how = "ReaPack > Browse packages > search \"js_ReaScriptAPI\" (ReaTeam Extensions)" },
  { name = "ReaPack",          ok = function() return reaper.ReaPack_BrowsePackages ~= nil end,
    how = "Download from reapack.com, put the file in REAPER's UserPlugins folder" },
  { name = "SWS",              ok = function() return reaper.SNM_SetIntConfigVar ~= nil end,
    how = "Download from sws-extension.org (or ReaPack > Browse packages > search \"SWS\")" },
}

local IMGUI_CHECKLIST = {
  "Restore window position, size, dock state and table settings: ON",
  "Enable docking by default: ON  (Dock only when holding Shift: ON, window splitting: ON, transparent: OFF)",
  "Enable keyboard navigation by default: ON  (capture global shortcuts: ON, show cursor: OFF, teleport mouse: OFF)",
  "Graphics renderer: Direct3D 10, hardware acceleration enabled",
}

local function open_imgui_page()
  if reaper.ViewPrefs then
    for _, n in ipairs({ "ReaImGui", "reaimgui", "ReaImGui settings" }) do
      if pcall(reaper.ViewPrefs, 0, n) then return end
    end
  end
  reaper.Main_OnCommand(40016, 0)
end

local function open_folder()
  reaper.RecursiveCreateDirectory(DIR, 0)
  if reaper.CF_ShellExecute then reaper.CF_ShellExecute(DIR); return true end
  return false
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local loaded = false
local function init()
  if loaded then return end
  loaded = true
  profile = load_file(PROFILE) or {}
  for _, it in ipairs(ITEMS) do checked[it.key] = true end
end

local COL = { ok = 0x6FD08CFF, different = 0xF0B44CFF, missing = 0xFF6B5AFF, unknown = 0xFF6B5AFF, dim = 0xA0A0A0FF }
local STATE_TXT = { ok = "Live value", different = "Different", missing = "Not found: use Learn", unknown = "Variable unknown" }

local function colored(ctx, ImGui, col, txt)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, col)
  ImGui.Text(ctx, txt)
  ImGui.PopStyleColor(ctx)
end

local function draw_contents(ctx, ImGui, say)
  -- extensions
  ImGui.SeparatorText(ctx, "Extensions")
  for _, x in ipairs(EXTS) do
    local ok = x.ok()
    colored(ctx, ImGui, ok and COL.ok or COL.missing, (ok and "[OK]  " or "[MISSING]  ") .. x.name)
    if not ok then
      ImGui.SameLine(ctx)
      ImGui.TextWrapped(ctx, "- " .. x.how .. ", then restart REAPER.")
    end
  end
  if not reaper.get_config_var_string then
    colored(ctx, ImGui, COL.missing, "This REAPER is too old to read preferences: update REAPER.")
    return
  end

  -- settings
  ImGui.SeparatorText(ctx, "Settings")
  local flags = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerH | ImGui.TableFlags_SizingStretchProp
  if ImGui.BeginTable(ctx, "lp_items", 4, flags) then
    ImGui.TableSetupColumn(ctx, "Apply", ImGui.TableColumnFlags_WidthFixed, 44)
    ImGui.TableSetupColumn(ctx, "Setting", ImGui.TableColumnFlags_WidthStretch, 3)
    ImGui.TableSetupColumn(ctx, "State", ImGui.TableColumnFlags_WidthStretch, 1.4)
    ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed, 64)
    ImGui.TableHeadersRow(ctx)
    for _, it in ipairs(ITEMS) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, it.key)
      ImGui.TableNextColumn(ctx)
      local _, v = ImGui.Checkbox(ctx, "##chk", checked[it.key])
      checked[it.key] = v
      ImGui.TableNextColumn(ctx)
      ImGui.TextWrapped(ctx, it.label)
      if ImGui.IsItemHovered(ctx) then
        local t = "Preferences > " .. it.where
        for _, e in ipairs(profile[it.key] or {}) do
          local cur = get_var(e.var) or "?"
          t = t .. "\n" .. e.var .. ":  now " .. cur .. "  ->  live " .. live_value(it, e)
        end
        ImGui.SetTooltip(ctx, t)
      end
      ImGui.TableNextColumn(ctx)
      local st = item_state(it)
      colored(ctx, ImGui, COL[st], STATE_TXT[st])
      ImGui.TableNextColumn(ctx)
      ImGui.BeginDisabled(ctx, learn ~= nil)
      if ImGui.Button(ctx, "Learn", 58, 0) then
        learn_start(it)
        say("Learn: change \"" .. it.label .. "\" in Preferences, Apply, put it back, Apply, then click Done.")
      end
      ImGui.EndDisabled(ctx)
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Find the REAPER variable(s) of this setting:\nchange it in Preferences > " ..
                              it.where .. ", click Apply,\nput it back to the live value, click Apply, then Done.")
      end
      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end

  -- learning panel
  if learn then
    learn_scan()
    ImGui.Spacing(ctx)
    ImGui.SeparatorText(ctx, "Learning: " .. learn.label)
    ImGui.TextWrapped(ctx, "1. In the Preferences window, change this setting and click Apply.\n" ..
                           "2. Put it back to the value you want on stage and click Apply again.\n" ..
                           "3. Click Done.")
    if #learn.order == 0 then
      colored(ctx, ImGui, COL.dim, "No change detected yet...")
    else
      colored(ctx, ImGui, COL.ok, "Detected: " .. table.concat(learn.order, ", "))
    end
    if ImGui.Button(ctx, "Done", 100, 26) then
      local n = learn_done()
      say(n > 0 and string.format("Learn: %d variable(s) added to the profile.", n)
                 or "Learn: no change detected, nothing added.", n == 0)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100, 26) then learn = nil; say("Learn cancelled.") end
  end

  -- actions
  ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "Profile")
  local w = (ImGui.GetContentRegionAvail(ctx) - 8) / 2
  ImGui.BeginDisabled(ctx, learn ~= nil)
  if ImGui.Button(ctx, "Capture my current settings", w, 30) then
    local found, missing = capture()
    say(string.format("Captured %d setting(s)%s. Profile saved in Data/REABACK/live_prefs.txt.", found,
        missing > 0 and (", " .. missing .. " not found (use Learn)") or ""), missing > 0)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Use it on a REAPER that is already set up for the stage:\nthe current values become the live profile.")
  end
  ImGui.SameLine(ctx)
  ImGui.BeginDisabled(ctx, not has_sws())
  if ImGui.Button(ctx, "Apply checked settings", w, 30) then
    local okN, failN, failed = apply()
    if failN > 0 then
      say(string.format("Applied %d value(s), %d failed: %s. Old values saved (Restore).", okN, failN,
          table.concat(failed, ", ")), true)
    else
      say(string.format("Applied %d value(s). Old values saved: Restore puts them back.", okN))
    end
  end
  ImGui.EndDisabled(ctx)
  if not has_sws() and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
    ImGui.SetTooltip(ctx, "SWS is required to write preferences.")
  end
  ImGui.BeginDisabled(ctx, not has_sws())
  if ImGui.Button(ctx, "Restore previous values", w, 26) then
    local okN, failN = restore()
    if not okN then say("Nothing to restore yet.", true)
    else say(string.format("Restored %d value(s)%s.", okN, failN > 0 and (", " .. failN .. " failed") or ""), failN > 0) end
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Open profile folder", w, 26) then
    if not open_folder() then say("Profile folder: " .. DIR) end
  end
  ImGui.EndDisabled(ctx)
  colored(ctx, ImGui, COL.dim, "REAPER saves preferences to reaper.ini when it closes.")

  -- ReaImGui
  ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "ReaImGui settings (set by hand)")
  for _, l in ipairs(IMGUI_CHECKLIST) do ImGui.BulletText(ctx, l) end
  if ImGui.Button(ctx, "Open Preferences > ReaImGui", -1, 26) then open_imgui_page() end
end

function M.toggle() M.open = not M.open end

function M.draw_window(ctx, ImGui, say)
  init()
  if not M.open then return end
  ImGui.SetNextWindowSize(ctx, 640, 720, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, WIN_TITLE, true)
  if visible then
    draw_contents(ctx, ImGui, say)
    ImGui.End(ctx)
  end
  if not open then M.open = false; learn = nil end
end

M.ITEMS = ITEMS
return M
