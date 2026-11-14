-- REABACK_Install
-- One-click installer. Load it ONCE from REAPER: Actions > Show action list > New action > Load ReaScript...,
-- then run it. It must stay next to the folders "Scripts", "reaper_www_root" and "ProjectTemplates".
--
--   Scripts/*.lua            -> <REAPER resource path>/Scripts/REABACK/   (and added to the Action list)
--   reaper_www_root/*.html   -> <REAPER resource path>/reaper_www_root/
--   ProjectTemplates/*.rpp   -> <REAPER resource path>/ProjectTemplates/
--   Data/toolbar_icons/**    -> <REAPER resource path>/Data/toolbar_icons/  (100%, 150% and 200% icons)

local TITLE = "REABACK installer"
local SEP = package.config:sub(1, 1)
local res = reaper.GetResourcePath()

local _, me = reaper.get_action_context()
local src = me:match("^(.*)[/\\][^/\\]*$")
if not src then reaper.MB("Cannot locate the installer folder.", TITLE, 0); return end

local PLAN = {
  { from = "Scripts",          to = res .. SEP .. "Scripts" .. SEP .. "REABACK", ext = "%.lua$", register = true },
  { from = "reaper_www_root",  to = res .. SEP .. "reaper_www_root",             ext = "%.html$" },
  { from = "ProjectTemplates", to = res .. SEP .. "ProjectTemplates",            ext = "%.rpp$" },
  { from = "Data" .. SEP .. "toolbar_icons",               to = res .. SEP .. "Data" .. SEP .. "toolbar_icons",               ext = "%.png$" },
  { from = "Data" .. SEP .. "toolbar_icons" .. SEP .. "150", to = res .. SEP .. "Data" .. SEP .. "toolbar_icons" .. SEP .. "150", ext = "%.png$" },
  { from = "Data" .. SEP .. "toolbar_icons" .. SEP .. "200", to = res .. SEP .. "Data" .. SEP .. "toolbar_icons" .. SEP .. "200", ext = "%.png$" },
}

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function list_files(dir, ext)
  local out, i = {}, 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    if f:lower():match(ext) then out[#out + 1] = f end
    i = i + 1
  end
  return out
end

-- 1. collect what has to be copied
local jobs, missing, conflicts = {}, {}, 0
for _, p in ipairs(PLAN) do
  local sdir = src .. SEP .. p.from
  local files = list_files(sdir, p.ext)
  if #files == 0 then missing[#missing + 1] = p.from end
  for _, name in ipairs(files) do
    local s, d = sdir .. SEP .. name, p.to .. SEP .. name
    local sdata, ddata = read_all(s), read_all(d)
    local job = { from = s, to = d, dir = p.to, name = name, data = sdata, register = p.register, exists = ddata ~= nil }
    if ddata ~= nil and ddata ~= sdata then conflicts = conflicts + 1; job.differs = true end
    jobs[#jobs + 1] = job
  end
end

if #missing > 0 then
  reaper.MB("These folders are missing or empty next to the installer:\n\n  " .. table.concat(missing, "\n  ") ..
            "\n\nUnzip the whole archive first, then run the installer from the unzipped folder.", TITLE, 0)
  return
end

-- 2. ask before overwriting different files
local overwrite = true
if conflicts > 0 then
  local r = reaper.MB(conflicts .. " file(s) already exist with different content (older or modified version).\n\n" ..
                      "Overwrite them?", TITLE, 4)
  overwrite = (r == 6)
end

-- 3. copy
local copied, skipped, failed, registered = 0, 0, {}, 0
for _, j in ipairs(jobs) do
  if j.differs and not overwrite then
    skipped = skipped + 1
  else
    reaper.RecursiveCreateDirectory(j.dir, 0)
    local f = io.open(j.to, "wb")
    if f then
      f:write(j.data)
      f:close()
      copied = copied + 1
    else
      failed[#failed + 1] = j.name
    end
  end
end

-- 4. add the scripts to the Action list
local lastScript
for _, j in ipairs(jobs) do if j.register then lastScript = j end end
for _, j in ipairs(jobs) do
  if j.register and reaper.file_exists(j.to) then
    local cmd = reaper.AddRemoveReaScript(true, 0, j.to, j == lastScript)   -- commit on the last one
    if cmd and cmd ~= 0 then registered = registered + 1 end
  end
end

-- 5. requirements
local function has(fn) return reaper[fn] ~= nil end
local lines = {}
lines[#lines + 1] = string.format("%d file(s) copied, %d skipped, %d script(s) added to the Action list.", copied, skipped, registered)
if #failed > 0 then lines[#lines + 1] = "NOT copied (check write permissions): " .. table.concat(failed, ", ") end
lines[#lines + 1] = ""
lines[#lines + 1] = "Requirements:"
lines[#lines + 1] = (has("ImGui_GetBuiltinPath") and "  OK       " or "  MISSING  ") .. "ReaImGui (needed for REABACK and Reaback Set up)  - install via ReaPack"
lines[#lines + 1] = (has("BR_GetMediaItemImageResource") and "  OK       " or "  optional ") .. "SWS extension (count-in, region navigation fallback)"
lines[#lines + 1] = (has("JS_Dialog_BrowseForSaveFile") and "  OK       " or "  optional ") .. "js_ReaScriptAPI (Save as dialog for the .txt export)"
lines[#lines + 1] = ""
lines[#lines + 1] = "Next steps:"
lines[#lines + 1] = "  - Actions > Show action list, search \"REABACK\": run \"REABACK.lua\" for the main window,"
lines[#lines + 1] = "    \"Reaback Set up.lua\" for the session set-up window."
lines[#lines + 1] = "  - File > Project templates > ReaBack to start a new session."
lines[#lines + 1] = "  - Toolbar icons: right-click a toolbar > Customize toolbar > Choose icon... (names start with REABACK / Reaback)."
lines[#lines + 1] = "  - Phone / tablet: Preferences > Control/OSC/web > Add > Web browser interface, then open"
lines[#lines + 1] = "    http://<computer IP>:<port>/REABACK.html  or  /Reaback-prompter.html"
reaper.MB(table.concat(lines, "\n"), TITLE, 0)
