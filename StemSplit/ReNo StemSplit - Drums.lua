-- @noindex
-- Part of the ReNo StemSplit package (see "ReNo StemSplit - Stems.lua").
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local ok, M = pcall(dofile, dir .. "ReNo_StemSplit_core.lua")
if not ok or type(M) ~= "table" then
  reaper.MB("Cannot load ReNo_StemSplit_core.lua\n\n" .. tostring(M), "ReNo StemSplit", 0)
else
  M.run("drums")
end
