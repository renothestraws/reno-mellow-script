-- @description ReNo Mellow - Swiss Army Knife
-- @author ReNo Mellow
-- @version 1.8
-- @about Un même raccourci, plusieurs outils, dans l'arrangement et dans l'éditeur MIDI : choix de l'outil actif (actions main / alt / alt2) dans une toolbox ReaImGui, avec armement par clic droit.
-- @changelog Scripts Select tool 01-24 retirés (Arrange et MIDI) : le choix de l'outil se fait dans la Toolbox ou avec la bulle Display (molette), ou avec Next / Previous tool.
-- @provides
--   [main] ReNo Mellow - Swiss Army Knife (alt).lua
--   [main] ReNo Mellow - Swiss Army Knife (alt2).lua
--   [main] ReNo Mellow - Swiss Army Knife - Display.lua
--   [main] ReNo Mellow - Swiss Army Knife - Next tool.lua
--   [main] ReNo Mellow - Swiss Army Knife - Previous tool.lua
--   [main] ReNo Mellow - Swiss Army Knife.lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI (alt).lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI (alt).lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI (alt2).lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI (alt2).lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI - Display.lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI - Display.lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI - Next tool.lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI - Next tool.lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI - Previous tool.lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI - Previous tool.lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI - Toolbox.lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI - Toolbox.lua
--   [midi_editor] MIDI/ReNo Mellow - Swiss Army Knife MIDI.lua > MIDI/ReNo Mellow - Swiss Army Knife MIDI.lua
--   SAK_lib.lua
--   SAK_toolbox.lua
--   SAK_display.lua
--   SAK_startup.lua
--   [data] Data/toolbar_icons/toolbar_sak_swiss_army_knife.png > toolbar_icons/toolbar_sak_swiss_army_knife.png
local SAK_dir = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
SAK_ROOT = SAK_dir
SAK_TB_CTX = "main"
dofile(SAK_dir .. "SAK_toolbox.lua")
