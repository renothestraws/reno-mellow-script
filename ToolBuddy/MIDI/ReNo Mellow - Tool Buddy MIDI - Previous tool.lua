-- @noindex
local dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
dofile(dir .. "../TB_lib.lua")
TB.set_context("midi")
TB.prepare_script()
TB.register_self("cmd_prev")
TB.step(-1)
