-- @noindex
-- Run at REAPER start by the block that the Display scripts add to Scripts/__startup.lua.
-- Reopens the Display windows (Arrange and MIDI) that were open when REAPER was closed.
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
if not dir then return end
dofile(dir .. "SAK_lib.lua")

local files = {
  main = dir .. "ReNo Mellow - Swiss Army Knife - Display.lua",
  midi = dir .. "MIDI/ReNo Mellow - Swiss Army Knife MIDI - Display.lua",
}

reaper.defer(function()
  for _, c in ipairs({ "main", "midi" }) do
    SAK.set_context(c)
    if SAK.cgets("disp_wanted") == "1" and reaper.file_exists(files[c]) then
      -- a Main-section command is needed to launch it here (also for the MIDI version)
      local cmd = SAK.resolve(SAK.cgets("cmd_display_boot"))
      if cmd == 0 then
        cmd = reaper.AddRemoveReaScript(true, 0, files[c], true)
        if cmd and cmd > 0 then SAK.csets("cmd_display_boot", SAK.id_from_cmd(cmd)) end
      end
      if cmd and cmd > 0 then reaper.Main_OnCommand(cmd, 0) end
    end
  end
end)
