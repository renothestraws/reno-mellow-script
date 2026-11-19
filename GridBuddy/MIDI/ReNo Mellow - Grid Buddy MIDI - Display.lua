-- @noindex
-- Small floating window showing the MIDI editor grid (hidden while no MIDI editor is open).
-- Wheel: grid size | Click: grid menu (type, hide, link, sync to arrange view) | Right-click: Grid Buddy window
local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
local root = dir:match("^(.*[/\\])[^/\\]+[/\\]$") or (dir .. "../")
dofile(root .. "GB_lib.lua")
GB_DISP = "midi"
dofile(root .. "GB_display.lua")
