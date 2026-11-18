-- @noindex
-- Small window showing the active Arrange tool (place it anywhere)
local SAK_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
SAK_ROOT = SAK_dir
SAK_TB_CTX = "main"
dofile(SAK_dir .. "SAK_display.lua")
