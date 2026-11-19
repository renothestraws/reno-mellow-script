-- @noindex
local dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
dofile(dir .. "TB_lib.lua")
TB.prepare_script()
TB.run("alt2")
