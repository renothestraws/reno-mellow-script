-- @noindex
-- Run at REAPER start by the block that the Display script adds to Scripts/__startup.lua.
-- Reopens the Recording Buddy Display if it was open when REAPER was closed.
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
if not dir then return end
dofile(dir .. "RecBuddy_lib.lua")

reaper.defer(function()
  local path = dir .. "ReNo Mellow - Recording Buddy - Display.lua"
  if tostring(RB.get("disp_wanted", "0")) ~= "1" or not reaper.file_exists(path) then return end
  local id = tostring(RB.get("cmd_display", ""))
  local cmd = 0
  if id ~= "" then cmd = tonumber(id) or reaper.NamedCommandLookup(id) or 0 end
  if cmd == 0 then cmd = reaper.AddRemoveReaScript(true, 0, path, true) or 0 end
  if cmd > 0 then reaper.Main_OnCommand(cmd, 0) end
end)
