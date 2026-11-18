-- @noindex
-- Toolbox for the MIDI editor tools (load it in the MIDI Editor section of the Action List)
local SAK_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
SAK_ROOT = SAK_dir .. "../"
SAK_TB_CTX = "midi"
dofile(SAK_ROOT .. "SAK_toolbox.lua")
