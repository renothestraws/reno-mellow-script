-- @noindex
-- Background service of the adaptive grid: follows the zoom of the arrange view and of
-- the MIDI editor. Started automatically when an adaptive mode is chosen, and stops by
-- itself when both grids are fixed. Launching it while it runs sets both grids to fixed.

local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "GB_lib.lua")

if reaper.set_action_options then reaper.set_action_options(1 | 2 | 4) end
local _, _, self_sec, self_cmd = reaper.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    reaper.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    reaper.RefreshToolbar2(self_sec, self_cmd)
  end
end
GB.register_self("cmd_service")

-- launched again while running (REAPER has just stopped the running one): stop request
local hb = tonumber(reaper.GetExtState(GB.RT, "svc_hb"))
if hb and reaper.time_precise() - hb < 1.0 then
  reaper.DeleteExtState(GB.RT, "svc_hb", false)
  GB.cset("arrange", "mult", 0)
  GB.cset("midi", "mult", 0)
  GB.refresh_toggles("arrange")
  GB.refresh_toggles("midi")
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end

if not GB.any_adaptive() then
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  return
end

set_self_toggle(true)
local tick = GB.service_new()

local function loop()
  reaper.SetExtState(GB.RT, "svc_hb", tostring(reaper.time_precise()), false)
  if tick() then reaper.defer(loop)
  else reaper.DeleteExtState(GB.RT, "svc_hb", false) end -- both grids fixed: done
end

reaper.atexit(function()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
end)

loop()
