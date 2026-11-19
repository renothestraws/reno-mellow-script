-- @noindex
-- Small window showing the active Arrange tool (place it anywhere)
local TB_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
TB_ROOT = TB_dir
TB_WIN_CTX = "main"
dofile(TB_dir .. "TB_display.lua")
