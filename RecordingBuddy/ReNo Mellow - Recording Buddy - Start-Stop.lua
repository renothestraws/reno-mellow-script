-- @noindex
-- Starts the Recording Buddy passes without any window (for a shortcut or a MIDI
-- control). Launching it again, or while a run is going on, stops the run.
local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "RecBuddy_lib.lua")

-- re-launch: the running instance is ended, then this one starts
if reaper.set_action_options then reaper.set_action_options(1 | 2 | 4) end
local _, _, sec, cmd = reaper.get_action_context()
local function set_toggle(on)
  if cmd and cmd > 0 then
    reaper.SetToggleCommandState(sec, cmd, on and 1 or 0)
    reaper.RefreshToolbar2(sec, cmd)
  end
end

local function quit()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_toggle(false)
end

-- a previous instance was just ended by this launch: that launch meant "stop"
local q = tonumber(reaper.GetExtState(RB.RT, "hl_quit_t"))
reaper.DeleteExtState(RB.RT, "hl_quit_t", false)
if q and reaper.time_precise() - q < 0.5 then
  RB.force_stop() -- in case a window was still driving the run
  quit()
  return
end

-- a run started from a window: this press stops it
if RB.state().run then
  RB.force_stop()
  quit()
  return
end

local ok, err = RB.start()
if not ok then
  quit()
  reaper.MB(err or "Could not start.", "Recording Buddy", 0)
  return
end
set_toggle(true)

local finished = false
local function loop()
  local st = RB.tick("headless")
  if st.run then reaper.defer(loop) else finished = true end
end

reaper.atexit(function()
  if not finished then reaper.SetExtState(RB.RT, "hl_quit_t", tostring(reaper.time_precise()), false) end
  set_toggle(false)
  RB.leave("headless")
end)

reaper.defer(loop)
