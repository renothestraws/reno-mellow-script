-- @noindex
-- Small window showing the active MIDI editor tool (place it anywhere)
local SAK_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
SAK_ROOT = SAK_dir:match("^(.*[/\\])[^/\\]+[/\\]$") or (SAK_dir .. "../")
SAK_TB_CTX = "midi"
dofile(SAK_ROOT .. "SAK_display.lua")
