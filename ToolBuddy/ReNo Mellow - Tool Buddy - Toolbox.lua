-- @description ReNo Mellow - Tool Buddy
-- @author ReNo Mellow
-- @version 1.10
-- @about Un même raccourci, plusieurs outils, dans l'arrangement et dans l'éditeur MIDI : choix de l'outil actif (actions main / alt / alt2) dans une toolbox ReaImGui, avec armement par clic droit.
-- @changelog Swiss Army Knife devient Tool Buddy : nouveaux noms d'actions, dossier ToolBuddy, outils et réglages repris automatiquement depuis Swiss Army Knife.
-- @provides
--   [main] ReNo Mellow - Tool Buddy (alt).lua
--   [main] ReNo Mellow - Tool Buddy (alt2).lua
--   [main] ReNo Mellow - Tool Buddy - Display.lua
--   [main] ReNo Mellow - Tool Buddy - Next tool.lua
--   [main] ReNo Mellow - Tool Buddy - Previous tool.lua
--   [main] ReNo Mellow - Tool Buddy.lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI (alt).lua > MIDI/ReNo Mellow - Tool Buddy MIDI (alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI (alt2).lua > MIDI/ReNo Mellow - Tool Buddy MIDI (alt2).lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI - Display.lua > MIDI/ReNo Mellow - Tool Buddy MIDI - Display.lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI - Next tool.lua > MIDI/ReNo Mellow - Tool Buddy MIDI - Next tool.lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI - Previous tool.lua > MIDI/ReNo Mellow - Tool Buddy MIDI - Previous tool.lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI - Toolbox.lua > MIDI/ReNo Mellow - Tool Buddy MIDI - Toolbox.lua
--   [midi_editor] MIDI/ReNo Mellow - Tool Buddy MIDI.lua > MIDI/ReNo Mellow - Tool Buddy MIDI.lua
--   TB_lib.lua
--   TB_toolbox.lua
--   TB_display.lua
--   TB_startup.lua
--   [data] Data/toolbar_icons/ReNo_ToolBuddy.png > toolbar_icons/ReNo_ToolBuddy.png
local TB_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
TB_ROOT = TB_dir
TB_WIN_CTX = "main"
dofile(TB_dir .. "TB_toolbox.lua")
