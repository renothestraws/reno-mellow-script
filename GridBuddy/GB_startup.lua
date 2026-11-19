-- @noindex
-- Run at REAPER start by the block that Grid Buddy adds to Scripts/__startup.lua.
-- Reopens the Display if it was open when REAPER was closed.
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
if not dir or not reaper.file_exists(dir .. "GB_lib.lua") then return end
dofile(dir .. "GB_lib.lua")

reaper.defer(function()
  if tostring(GB.get("disp_wanted", "0")) == "1" and reaper.file_exists(GB.ROOT .. GB.FILES.display) then
    GB.launch("display")
  end
end)
