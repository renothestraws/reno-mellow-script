-- @noindex
-- Toolbox for the MIDI editor tools (load it in the MIDI Editor section of the Action List)
local TB_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
TB_ROOT = TB_dir .. "../"
TB_WIN_CTX = "midi"
dofile(TB_ROOT .. "TB_toolbox.lua")
