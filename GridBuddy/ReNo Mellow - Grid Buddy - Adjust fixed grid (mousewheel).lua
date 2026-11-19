-- @noindex
-- Grid Buddy: Mouse wheel: fixed grid size (switches the adaptive grid off).
local path = ({ reaper.get_action_context() })[2]
local dir = path:match("^(.*[/\\])")
local lib = dir .. "GB_lib.lua"
if not reaper.file_exists(lib) then lib = dir .. "../GB_lib.lua" end
dofile(lib)
GB.run_action(path)
