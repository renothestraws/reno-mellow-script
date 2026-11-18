-- @noindex
local dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
dofile(dir .. "../SAK_lib.lua")
SAK.set_context("midi")
SAK.prepare_script()
SAK.register_self("cmd_prev")
SAK.step(-1)
