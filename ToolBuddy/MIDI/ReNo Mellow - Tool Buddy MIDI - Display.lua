-- @noindex
-- Small window showing the active MIDI editor tool (place it anywhere)
local TB_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
TB_ROOT = TB_dir:match("^(.*[/\\])[^/\\]+[/\\]$") or (TB_dir .. "../")
TB_WIN_CTX = "midi"
dofile(TB_ROOT .. "TB_display.lua")
