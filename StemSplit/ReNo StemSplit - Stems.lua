-- @description ReNo StemSplit (AI stem separation)
-- @author ReNo Mellow
-- @version 1.6
-- @about Séparation de stems par IA en local, inspirée du Stem Splitter de Logic Pro. Stems : voix, batterie, basse, guitare, piano, autres (6 ou 4 stems). Drums : batterie découpée en kick, snare, toms, cymbales (4, 5 ou 6 pièces). Nécessite Python 3.10 à 3.13 ; le moteur (environ 1,5 Go, 4,5 Go avec GPU NVIDIA) s'installe une seule fois via le bouton Install engine, puis tout fonctionne hors ligne.
-- @changelog Mac : prise en charge Apple Silicon fiabilisée (Python arm64 forcé même si REAPER tourne sous Rosetta, recherche de Python 3.12 Homebrew élargie, certificats SSL), message clair sur les Mac Intel (non pris en charge par PyTorch)
-- @provides
--   [main] ReNo StemSplit - Drums.lua
--   [main] ReNo StemSplit - Install.lua
--   ReNo_StemSplit_core.lua
--   stemsplit_engine.py
--   stemsplit_install.py
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local ok, M = pcall(dofile, dir .. "ReNo_StemSplit_core.lua")
if not ok or type(M) ~= "table" then
  reaper.MB("Cannot load ReNo_StemSplit_core.lua\n\n" .. tostring(M), "ReNo StemSplit", 0)
else
  M.run("stems")
end
