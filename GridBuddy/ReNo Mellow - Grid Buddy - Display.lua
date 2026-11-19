-- @noindex
-- Small floating window showing the arrange grid (place it anywhere, e.g. next to the transport).
-- Wheel: grid size | Click: grid menu | Alt+click / Alt+wheel: swing | Right-click: Grid Buddy window
local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "GB_lib.lua")
GB_DISP = "arrange"
dofile(dir .. "GB_display.lua")
