-- REABACK: Stop
-- Standalone action: bind it to a keyboard shortcut or MIDI in REAPER's Action list.

-- Toolbar toggle state (lit / unlit icon). The command ID is also stored so that the REABACK
-- window, while open, keeps this icon in sync with the transport.
local function rb_toggle(key, state)
  local _, _, sec, cmd = reaper.get_action_context()
  if not cmd or cmd <= 0 then return end
  local named = reaper.ReverseNamedCommandLookup(cmd)
  if named and named ~= "" then reaper.SetExtState("REABACK_toggles", key, sec .. "|" .. named, true) end
  reaper.SetToggleCommandState(sec, cmd, state)
  reaper.RefreshToolbar2(sec, cmd)
end


-- Stop: while playing run action 40328, otherwise move the edit cursor to the start of the time selection
local function stop_action()
  if (reaper.GetPlayState() & 1) == 1 then
    reaper.Main_OnCommand(40328, 0)
  else
    local ts_s, ts_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if ts_e > ts_s then reaper.SetEditCurPos(ts_s, true, false) end
  end
end

stop_action()

rb_toggle("Stop", 0)   -- momentary action: never lit
