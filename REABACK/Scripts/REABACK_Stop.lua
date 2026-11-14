-- REABACK: Stop
-- Standalone action: bind it to a keyboard shortcut or MIDI in REAPER's Action list.

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
