-- @noindex
local dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
dofile(dir .. "SAK_lib.lua")
SAK.prepare_script()
SAK.select(15)
