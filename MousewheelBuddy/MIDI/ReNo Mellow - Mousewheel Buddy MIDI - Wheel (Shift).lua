-- @noindex
-- Mousewheel Buddy (MIDI Editor): bind it to the mouse wheel in the MIDI Editor section of the Action List,
-- with the modifier keys written in the file name (none, Ctrl, Shift, Alt... ; Cmd / Opt on macOS).
-- The action run depends on where the mouse is (set it up in "ReNo Mellow - Mousewheel Buddy").
local ac = { reaper.get_action_context() }  -- first: keeps the wheel value
local dir = ac[2]:match("^(.*[/\\])")
local lib = dir .. "../MWB_lib.lua"
if not reaper.file_exists(lib) then lib = dir .. "MWB_lib.lua" end
dofile(lib)
MWB.run_wheel("midi", ac)
