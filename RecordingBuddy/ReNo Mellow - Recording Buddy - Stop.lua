-- @noindex
-- Forced stop of the Recording Buddy (the recorded media is saved).
local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "RecBuddy_lib.lua")

local _, _, sec, cmd = reaper.get_action_context()
if cmd and cmd > 0 then -- one-shot action: toolbar icon always off
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end
RB.force_stop()
