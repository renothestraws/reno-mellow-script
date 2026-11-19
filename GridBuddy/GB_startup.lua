-- @noindex
-- Run at REAPER start by the block that Grid Buddy adds to Scripts/__startup.lua.
-- Starts the adaptive service (option "Keep the adaptive mode when REAPER restarts")
-- or sets both grids back to fixed, then reopens the Display if it was open.
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
if not dir or not reaper.file_exists(dir .. "GB_lib.lua") then return end
dofile(dir .. "GB_lib.lua")

reaper.defer(function()
  if GB.flag("svc_startup", false) then
    GB.start_service()
  else
    GB.cset("arrange", "mult", 0)
    GB.cset("midi", "mult", 0)
  end
  GB.refresh_toggles("arrange")
  GB.refresh_toggles("midi")
  if tostring(GB.get("disp_wanted", "0")) == "1" and reaper.file_exists(GB.ROOT .. GB.FILES.display) then
    GB.launch("display")
  end
end)
