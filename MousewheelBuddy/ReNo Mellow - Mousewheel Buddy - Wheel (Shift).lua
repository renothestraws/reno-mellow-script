-- @noindex
-- Mousewheel Buddy (Arrange): bind it to the mouse wheel in the Main section of the Action List,
-- with the modifier keys written in the file name (none, Ctrl, Shift, Alt... ; Cmd / Opt on macOS).
-- The action run depends on where the mouse is (set it up in "ReNo Mellow - Mousewheel Buddy").
local ac = { reaper.get_action_context() }  -- first: keeps the wheel value
-- fast wheel turns re-launch the script: end the previous instance and start again, no dialog
if reaper.set_action_options then reaper.set_action_options(1 | 2) end
local dir = ac[2]:match("^(.*[/\\])")
dofile(dir .. "MWB_lib.lua")
MWB.run_wheel("main", ac)
