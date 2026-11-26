-- @description REABACK (backing tracks on stage: setlist of regions, transport, remote control)
-- @author ReNo Mellow
-- @version 1.6
-- @about Setlist de scène pour lancer les backing tracks : une chanson = une région mère. Liste des régions réordonnable par glisser-déposer avec renumérotation des IDs (régions filles = ID mère x 100 + n), sets de régions, gros bouton Play/Stop, Previous / Next, Live loop, Metronome, Count-in, Auto stop, Smooth seek, export txt. Contrôle à distance depuis un téléphone (REABACK.html) et prompteur de paroles / accords pour tablette (Reaback-prompter.html) via l'interface web de REAPER. Fournit aussi le project template ReaBack et les icônes de barre d'outils. Nécessite l'extension ReaImGui (ReaPack > ReaTeam Extensions) ; SWS conseillée, js_ReaScriptAPI optionnelle.
-- @changelog Reaback Set up : Lock / Unlock items of the region prennent maintenant les items qui commencent dans la région (même si leur fin dépasse), curseur sur le bord accepté, sélection temporelle en secours, message clair si aucun item
-- @provides
--   [main] Scripts/REABACK_PlayStop.lua
--   [main] Scripts/REABACK_Stop.lua
--   [main] Scripts/REABACK_Previous.lua
--   [main] Scripts/REABACK_Next.lua
--   [main] Scripts/REABACK_LiveLoop.lua
--   [main] Scripts/Reaback Set up.lua
--   [main] Scripts/Reaback-prompter.lua
--   Scripts/Reaback_BBeat_export.lua
--   [webinterface] reaper_www_root/REABACK.html > REABACK.html
--   [webinterface] reaper_www_root/Reaback-prompter.html > Reaback-prompter.html
--   [projecttpl] ProjectTemplates/ReaBack.rpp > ReaBack.rpp
--   [data] Data/toolbar_icons/REABACK.png > toolbar_icons/REABACK.png
--   [data] Data/toolbar_icons/REABACK_LiveLoop.png > toolbar_icons/REABACK_LiveLoop.png
--   [data] Data/toolbar_icons/REABACK_Next.png > toolbar_icons/REABACK_Next.png
--   [data] Data/toolbar_icons/REABACK_PlayStop.png > toolbar_icons/REABACK_PlayStop.png
--   [data] Data/toolbar_icons/REABACK_Previous.png > toolbar_icons/REABACK_Previous.png
--   [data] Data/toolbar_icons/REABACK_Stop.png > toolbar_icons/REABACK_Stop.png
--   [data] Data/toolbar_icons/Reaback-prompter.png > toolbar_icons/Reaback-prompter.png
--   [data] Data/toolbar_icons/Reaback_Set_up.png > toolbar_icons/Reaback_Set_up.png
--   [data] Data/toolbar_icons/REABACK_Toolbar.png > toolbar_icons/REABACK_Toolbar.png
--   [data] Data/toolbar_icons/150/REABACK.png > toolbar_icons/150/REABACK.png
--   [data] Data/toolbar_icons/150/REABACK_LiveLoop.png > toolbar_icons/150/REABACK_LiveLoop.png
--   [data] Data/toolbar_icons/150/REABACK_Next.png > toolbar_icons/150/REABACK_Next.png
--   [data] Data/toolbar_icons/150/REABACK_PlayStop.png > toolbar_icons/150/REABACK_PlayStop.png
--   [data] Data/toolbar_icons/150/REABACK_Previous.png > toolbar_icons/150/REABACK_Previous.png
--   [data] Data/toolbar_icons/150/REABACK_Stop.png > toolbar_icons/150/REABACK_Stop.png
--   [data] Data/toolbar_icons/150/Reaback-prompter.png > toolbar_icons/150/Reaback-prompter.png
--   [data] Data/toolbar_icons/150/Reaback_Set_up.png > toolbar_icons/150/Reaback_Set_up.png
--   [data] Data/toolbar_icons/150/REABACK_Toolbar.png > toolbar_icons/150/REABACK_Toolbar.png
--   [data] Data/toolbar_icons/200/REABACK.png > toolbar_icons/200/REABACK.png
--   [data] Data/toolbar_icons/200/REABACK_LiveLoop.png > toolbar_icons/200/REABACK_LiveLoop.png
--   [data] Data/toolbar_icons/200/REABACK_Next.png > toolbar_icons/200/REABACK_Next.png
--   [data] Data/toolbar_icons/200/REABACK_PlayStop.png > toolbar_icons/200/REABACK_PlayStop.png
--   [data] Data/toolbar_icons/200/REABACK_Previous.png > toolbar_icons/200/REABACK_Previous.png
--   [data] Data/toolbar_icons/200/REABACK_Stop.png > toolbar_icons/200/REABACK_Stop.png
--   [data] Data/toolbar_icons/200/Reaback-prompter.png > toolbar_icons/200/Reaback-prompter.png
--   [data] Data/toolbar_icons/200/Reaback_Set_up.png > toolbar_icons/200/Reaback_Set_up.png
--   [data] Data/toolbar_icons/200/REABACK_Toolbar.png > toolbar_icons/200/REABACK_Toolbar.png
--[[
 * Name        : REABACK
 * Description : Lists the project's regions, reorders them by drag and drop and renumbers their
 *               IDs following the list order (nested regions get parent ID x 100 + n), manages
 *               region sets saved in the project, click = go to/time-select, double-click = play
 *               (smooth seek), playing region in yellow/bigger, regions covered by the time
 *               selection in green/italic, big Play/Stop button,
 *               Alt+click to disable/enable a region, and export of the list to .txt.
 * Requires    : ReaImGui extension (ReaPack > ReaTeam Extensions > ReaImGui)
 * Optional    : js_ReaScriptAPI ("Save as" dialog for the export)
--]]

local TITLE = "REABACK"
local EXT   = "RegionIDManager"   -- nom de section pour les region sets (stockés dans le .rpp)

-- A region whose ID is >= DISABLED_BASE is a disabled region (ID = DISABLED_BASE + its previous ID).
-- Computed IDs (top-level 1..N, nested = parent x 100 + n) must therefore stay below DISABLED_BASE.
local DISABLED_BASE = 10000

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script requires the ReaImGui extension.\n\n" ..
            "Install it via ReaPack (ReaTeam Extensions > ReaImGui), then restart REAPER.",
            TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

------------------------------------------------------------------------
-- État
------------------------------------------------------------------------
local ctx  = ImGui.CreateContext(TITLE)
local FONT_SIZE, FONT_BIG = 14, 20
local font      = ImGui.CreateFont('sans-serif', FONT_SIZE)
local fontBig   = ImGui.CreateFont('sans-serif', FONT_BIG)
local fontIt    = ImGui.CreateFont('sans-serif', FONT_SIZE, ImGui.FontFlags_Italic)
local fontBigIt = ImGui.CreateFont('sans-serif', FONT_BIG,  ImGui.FontFlags_Italic)
for _, f in ipairs({ font, fontBig, fontIt, fontBigIt }) do ImGui.Attach(ctx, f) end

local list           = {}     -- régions dans l'ordre affiché
local selected       = {}     -- [key] = true
local lastClickedKey = nil
local sets           = {}     -- region sets du projet
local selSetId       = nil
local newSetName     = ""
local applyOnLoad    = false
local lastCount      = -1
local lastProj       = nil
local status         = ""

local tops, rows, targets = {}, {}, {}   -- régions principales / lignes affichées / nouveaux IDs
local nestedCount, activeTops, disabledCount = 0, 0, 0
local overflow = false                   -- true = a computed ID would reach DISABLED_BASE
local dirty = true                       -- true = structure à recalculer

local COL_ORANGE = 0xFFB347FF
local COL_BLUE   = 0x8EC5FFFF
local COL_NESTED_BG = 0x4A7BA838
local COL_GREEN  = 0x7FD17FFF
local COL_YELLOW   = 0xFFE81AFF      -- région en cours de lecture
local COL_SELGREEN = 0x3DDC5AFF      -- région couverte par la sélection temporelle
local COL_RED      = 0xFF4D4DFF      -- région désactivée

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function fmt_time(s)
  s = math.max(0, s or 0)
  local ms = math.floor(s * 1000 + 0.5)
  local h = math.floor(ms / 3600000); ms = ms - h * 3600000
  local m = math.floor(ms / 60000);   ms = ms - m * 60000
  local sec = math.floor(ms / 1000);  ms = ms - sec * 1000
  if h > 0 then return string.format("%d:%02d:%02d.%03d", h, m, sec, ms) end
  return string.format("%d:%02d.%03d", m, sec, ms)
end

local function tip(text)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end

-- Clé stable d'une région : son GUID (survit aux changements d'ID, de nom, de position)
local function region_key(idx, pos, rgnend)
  local ok, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)
  if ok and guid and guid ~= "" then return guid end
  return string.format("pos:%.9f-%.9f", pos, rgnend)
end

local function read_regions()
  local out = {}
  local total = reaper.CountProjectMarkers(0)
  for i = 0, total - 1 do
    local ret, isrgn, pos, rgnend, name, id, color = reaper.EnumProjectMarkers3(0, i)
    if ret and ret > 0 and isrgn then
      out[#out + 1] = {
        key = region_key(i, pos, rgnend), id = id, name = name or "",
        pos = pos, rgnend = rgnend, dur = rgnend - pos, color = color,
        disabled = id >= DISABLED_BASE,
      }
    end
  end
  return out
end

-- Imbrication : a contient strictement b (bords identiques = pas imbriquées)
local EPS = 1e-6
local function contains(a, b)
  if a == b then return false end
  if a.pos <= b.pos + EPS and b.rgnend <= a.rgnend + EPS then
    return (b.pos - a.pos > EPS) or (a.rgnend - b.rgnend > EPS)
  end
  return false
end

-- Recalcule parents/enfants, lignes affichées et nouveaux IDs.
-- Régions principales : 1..N dans l'ordre de la liste.
-- Régions imbriquées  : ID de la mère x 100 + n (n = rang par position dans le temps).
local function rebuild()
  dirty = false
  for _, r in ipairs(list) do r.parent = nil; r.children = {} end
  -- Une région désactivée n'est ni mère ni enfant : elle reste une ligne à part, hors numérotation.
  for _, b in ipairs(list) do
    if not b.disabled then
      local best
      for _, a in ipairs(list) do
        if not a.disabled and contains(a, b) and (not best or a.dur < best.dur) then
          best = a                       -- mère directe = la plus petite
        end
      end
      b.parent = best
      if best then best.children[#best.children + 1] = b end
    end
  end

  tops, rows, targets, nestedCount, activeTops, disabledCount = {}, {}, {}, 0, 0, 0
  overflow = false
  for _, r in ipairs(list) do
    if r.parent then nestedCount = nestedCount + 1 else tops[#tops + 1] = r end
    table.sort(r.children, function(x, y)
      if x.pos ~= y.pos then return x.pos < y.pos end
      if x.rgnend ~= y.rgnend then return x.rgnend < y.rgnend end
      return x.key < y.key
    end)
  end

  local function assign(r, id, depth, topIdx)
    targets[r.key] = id
    if id >= DISABLED_BASE then overflow = true end
    rows[#rows + 1] = { r = r, depth = depth, top = topIdx }
    for k, c in ipairs(r.children) do assign(c, id * 100 + k, depth + 1, topIdx) end
  end
  local n = 0
  for i, r in ipairs(tops) do
    if r.disabled then
      disabledCount = disabledCount + 1
      targets[r.key] = r.id              -- inchangé
      rows[#rows + 1] = { r = r, depth = 0, top = i }
    else
      n = n + 1
      assign(r, n, 0, i)
    end
  end
  activeTops = n
end

local function is_pending()
  if dirty then rebuild() end
  for _, r in ipairs(list) do
    if not r.disabled and r.id ~= targets[r.key] then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Region sets (stockés dans le projet via ProjExtState)
------------------------------------------------------------------------
local function esc(s)
  return (s:gsub("[^%w]", function(c) return string.format("%%%02X", c:byte()) end))
end
local function unesc(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- Comments: one per region, stored in the project under the key "C_<region GUID>"
local comments = {}
local function load_comments()
  comments = {}
  local i = 0
  while true do
    local ok, k, v = reaper.EnumProjExtState(0, EXT, i)
    if not ok then break end
    if k:sub(1, 2) == "C_" and v ~= "" then comments[k:sub(3)] = unesc(v) end
    i = i + 1
  end
end
local function save_comment(key, text)
  comments[key] = text
  reaper.SetProjExtState(0, EXT, "C_" .. key, esc(text))   -- empty text removes the key
  reaper.MarkProjectDirty(0)
end

-- Un set mémorise, pour chaque région : clé (GUID), position, fin, couleur, nom.
-- Format : nom|clé~début~fin~couleur~nom;clé~...   (l'ancien format "clé;clé" reste lisible)
local function serialize_set(name, entries)
  local parts = {}
  for _, e in ipairs(entries) do
    if e.pos then
      parts[#parts + 1] = string.format("%s~%.10f~%.10f~%d~%s", e.key, e.pos, e.rgnend,
        math.floor(e.color or 0), esc(e.name or ""))
    else
      parts[#parts + 1] = e.key
    end
  end
  return esc(name) .. "|" .. table.concat(parts, ";")
end

local function load_sets()
  sets = {}
  local i = 0
  while true do
    local ok, k, v = reaper.EnumProjExtState(0, EXT, i)
    if not ok then break end
    if k:match("^S%d+$") then
      local namep, keysp = v:match("^([^|]*)|(.*)$")
      if namep then
        local entries = {}
        for ent in keysp:gmatch("[^;]+") do
          local key, p, e, c, n = ent:match("^([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
          if key and tonumber(p) and tonumber(e) then
            entries[#entries + 1] = { key = key, pos = tonumber(p), rgnend = tonumber(e),
                                      color = tonumber(c) or 0, name = unesc(n) }
          else
            entries[#entries + 1] = { key = ent }      -- ancien format : pas de données de restauration
          end
        end
        sets[#sets + 1] = { id = k, num = tonumber(k:sub(2)), name = unesc(namep), entries = entries }
      end
    end
    i = i + 1
  end
  table.sort(sets, function(a, b) return a.name:lower() < b.name:lower() end)
  local still = false
  for _, s in ipairs(sets) do if s.id == selSetId then still = true end end
  if not still then selSetId = nil end
end

local function current_set()
  for _, s in ipairs(sets) do if s.id == selSetId then return s end end
end

------------------------------------------------------------------------
-- Synchronisation liste <-> projet
------------------------------------------------------------------------
local function sync(force)
  local proj = reaper.EnumProjects(-1)
  local cnt  = reaper.GetProjectStateChangeCount(0)
  if not force and proj == lastProj and cnt == lastCount then return end

  if proj ~= lastProj then          -- changement d'onglet de projet
    list, selected, lastClickedKey = {}, {}, nil
    lastProj = proj
    load_sets()
    load_comments()
  end
  lastCount = cnt

  local fresh = read_regions()
  table.sort(fresh, function(a, b) return a.id < b.id end)
  local byKey = {}
  for _, r in ipairs(fresh) do byKey[r.key] = r end

  local newlist, used = {}, {}
  for _, old in ipairs(list) do          -- conserve l'ordre choisi par l'utilisateur
    local f = byKey[old.key]
    if f then newlist[#newlist + 1] = f; used[old.key] = true end
  end
  for _, f in ipairs(fresh) do           -- nouvelles régions à la fin
    if not used[f.key] then newlist[#newlist + 1] = f end
  end
  list = newlist
  dirty = true

  for k in pairs(selected) do if not byKey[k] then selected[k] = nil end end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
local function locate(key, cache)
  local i = cache[key]
  if i then
    local ret, isrgn, pos, rgnend = reaper.EnumProjectMarkers3(0, i)
    if ret and ret > 0 and isrgn and region_key(i, pos, rgnend) == key then return i end
  end
  local total = reaper.CountProjectMarkers(0)
  for j = 0, total - 1 do
    local ret, isrgn, pos, rgnend = reaper.EnumProjectMarkers3(0, j)
    if ret and ret > 0 and isrgn then cache[region_key(j, pos, rgnend)] = j end
  end
  return cache[key]
end

local function set_region_id(key, newid, cache)
  local idx = locate(key, cache)
  if not idx then return false end
  local _, isrgn, pos, rgnend, name, _, color = reaper.EnumProjectMarkers3(0, idx)
  return reaper.SetProjectMarkerByIndex2(0, idx, true, pos, rgnend, newid, name, color, 0)
end

local function rename_region(key, newname)
  local idx = locate(key, {})
  if not idx then return false end
  local _, isrgn, pos, rgnend, _, id, color = reaper.EnumProjectMarkers3(0, idx)
  reaper.Undo_BeginBlock()
  local ok = reaper.SetProjectMarkerByIndex2(0, idx, true, pos, rgnend, id, newname, color, 0)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Rename region", -1)
  sync(true)
  status = ok and string.format("Region renamed to '%s'.", newname) or "Failed: the region could not be renamed."
  return ok
end

local function apply_ids()
  if #list == 0 then return end
  if not is_pending() then
    status = "IDs already match the list order."
    return
  end
  if dirty then rebuild() end
  local nnested = nestedCount
  local enabled = {}
  for _, r in ipairs(list) do if not r.disabled then enabled[#enabled + 1] = r end end
  if #enabled == 0 then status = "No active region to renumber."; return end
  local maxid, seen = 0, {}
  for _, r in ipairs(list) do if r.id > maxid then maxid = r.id end end   -- disabled regions included
  for _, r in ipairs(enabled) do
    local t = targets[r.key]
    if t >= DISABLED_BASE then
      status = string.format("Too many regions or nesting too deep: an ID would reach %d or more (reserved for disabled regions). Nothing was changed.", DISABLED_BASE)
      return
    end
    if seen[t] then
      status = string.format("Conflict: two regions would get ID %d (more than 99 nested regions inside one parent). Nothing was changed.", t)
      return
    end
    seen[t] = true
    if t > maxid then maxid = t end
    if r.id > maxid then maxid = r.id end
  end
  local base = maxid + 10000          -- IDs temporaires pour éviter les doublons
  local cache, fails = {}, 0

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for i, r in ipairs(enabled) do
    if not set_region_id(r.key, base + i, cache) then fails = fails + 1 end
  end
  for _, r in ipairs(enabled) do
    if not set_region_id(r.key, targets[r.key], cache) then fails = fails + 1 end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Reorder region IDs", -1)

  sync(true)
  if fails == 0 then
    status = string.format("IDs reassigned: %d region(s), including %d nested.", #enabled, nnested)
    if #list > #enabled then
      status = status .. string.format(" %d disabled region(s) skipped.", #list - #enabled)
    end
  else
    status = string.format("Finished with %d error(s): please check the IDs in the project.", fails)
  end
end

local function reset_order()
  table.sort(list, function(a, b) return a.id < b.id end)
  dirty = true
  status = "Order reset to the current IDs."
end

-- Équivalent de "SWS/S&M: Go to/time-select region N (obeys smooth seek)".
-- startPlay = true (double-clic) : lance aussi la lecture si le transport est à l'arrêt.
local function goto_region(r, startPlay)
  reaper.GetSet_LoopTimeRange(true, false, r.pos, r.rgnend, false)   -- time-select
  local playing = (reaper.GetPlayState() & 1) == 1
  if playing then
    if reaper.GoToRegion then reaper.GoToRegion(0, r.id, false) end  -- smooth seek (réglages de REAPER)
  else
    reaper.SetEditCurPos(r.pos, true, false)
    if startPlay then reaper.OnPlayButton() end
  end
end

-- Alt+clic : désactive une région (ID = DISABLED_BASE + ancien ID) ou la réactive.
local function toggle_disabled(r)
  local used = {}
  for _, x in ipairs(list) do if x ~= r then used[x.id] = true end end

  local wasDisabled = r.disabled
  local newid
  if wasDisabled then
    local orig = r.id - DISABLED_BASE            -- ancien ID, s'il est encore libre
    if orig >= 1 and orig < DISABLED_BASE and not used[orig] then
      newid = orig
    else
      newid = 1
      while used[newid] do newid = newid + 1 end
    end
  else
    newid = DISABLED_BASE + math.max(r.id, 0)
    while used[newid] do newid = newid + 1 end
  end

  reaper.Undo_BeginBlock()
  local ok = set_region_id(r.key, newid, {})
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(wasDisabled and "Enable region" or "Disable region", -1)

  selected[r.key] = nil
  sync(true)
  local name = (r.name ~= "") and r.name or "(unnamed)"
  if not ok then
    status = "Failed: region '" .. name .. "' could not be modified."
  elseif wasDisabled then
    status = string.format("Region '%s' enabled (temporary ID %d). Click 'Apply IDs'.", name, newid)
  else
    status = string.format("Region '%s' disabled: excluded from numbering and durations.", name)
  end
end

local function save_set(name, force)
  name = trim(name or "")
  if name == "" then status = "Enter a name for the set before saving it."; return end
  if #list == 0 then status = "No region to save."; return end

  local existing
  for _, s in ipairs(sets) do
    if s.name:lower() == name:lower() then existing = s end
  end
  local setid
  if existing then
    if not force then
      local ans = reaper.MB("A set named '" .. existing.name .. "' already exists.\nReplace it?", TITLE, 4)
      if ans ~= 6 then return end
    end
    setid = existing.id
  else
    local maxn = 0
    for _, s in ipairs(sets) do if s.num > maxn then maxn = s.num end end
    setid = "S" .. (maxn + 1)
  end

  local entries = {}
  for _, r in ipairs(list) do
    entries[#entries + 1] = { key = r.key, pos = r.pos, rgnend = r.rgnend, color = r.color, name = r.name }
  end
  reaper.SetProjExtState(0, EXT, setid, serialize_set(name, entries))
  reaper.MarkProjectDirty(0)
  load_sets()
  for _, s in ipairs(sets) do if s.name == name then selSetId = s.id end end
  status = string.format("Set '%s' saved (%d regions).", name, #entries)
end

-- Associe chaque entrée du set à une région existante : même GUID, sinon même position/fin.
local function match_entries(set)
  local byKey = {}
  for _, r in ipairs(list) do byKey[r.key] = r end
  local found, used = {}, {}
  for i, e in ipairs(set.entries) do
    local r = byKey[e.key]
    if r and not used[r.key] then found[i] = r; used[r.key] = true end
  end
  for i, e in ipairs(set.entries) do
    if not found[i] and e.pos then
      for _, x in ipairs(list) do
        if not used[x.key] and math.abs(x.pos - e.pos) < 1e-6 and math.abs(x.rgnend - e.rgnend) < 1e-6 then
          found[i] = x; used[x.key] = true
          break
        end
      end
    end
  end
  return found
end

local function load_set(set)
  local found = match_entries(set)

  -- Régions du set qui n'existent plus dans le projet : on les recrée (nom, position, fin, couleur)
  local toCreate = {}
  for i, e in ipairs(set.entries) do
    if not found[i] and e.pos then toCreate[#toCreate + 1] = e end
  end
  local recreated = 0
  if #toCreate > 0 then
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    for _, e in ipairs(toCreate) do
      local idx = reaper.AddProjectMarker2(0, true, e.pos, e.rgnend, e.name or "", -1, e.color or 0)
      if idx and idx >= 0 then recreated = recreated + 1 end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Restore regions from set", -1)
    sync(true)
    found = match_entries(set)
  end

  -- Une région recréée a un nouveau GUID : on met à jour les clés dans tous les sets du projet
  local remap, nremap = {}, 0
  for i, e in ipairs(set.entries) do
    local r = found[i]
    if r and r.key ~= e.key then remap[e.key] = r.key; nremap = nremap + 1 end
  end
  for oldk, newk in pairs(remap) do
    if (comments[oldk] or "") ~= "" and (comments[newk] or "") == "" then save_comment(newk, comments[oldk]) end
  end
  if nremap > 0 then
    for _, s in ipairs(sets) do
      local changed = false
      for _, e in ipairs(s.entries) do
        if remap[e.key] then e.key = remap[e.key]; changed = true end
      end
      if changed then reaper.SetProjExtState(0, EXT, s.id, serialize_set(s.name, s.entries)) end
    end
    reaper.MarkProjectDirty(0)
  end

  local newlist, used = {}, {}
  local missing = 0
  for i in ipairs(set.entries) do
    local r = found[i]
    if r then newlist[#newlist + 1] = r; used[r.key] = true else missing = missing + 1 end
  end
  local extra = 0
  for _, r in ipairs(list) do
    if not used[r.key] then newlist[#newlist + 1] = r; extra = extra + 1 end
  end
  list = newlist
  dirty = true

  local msg = string.format("Set '%s' loaded.", set.name)
  if recreated > 0 then msg = msg .. string.format(" %d deleted region(s) restored.", recreated) end
  if missing > 0 then
    msg = msg .. string.format(" %d region(s) of the set not found and not restorable (set saved by an older version: save it again).", missing)
  end
  if extra > 0 then msg = msg .. string.format(" %d region(s) not in the set placed at the end.", extra) end
  status = msg

  if applyOnLoad then
    apply_ids()
    status = msg .. " IDs applied."
  else
    status = msg .. " Click 'Apply IDs'."
  end
end

local function delete_set(set, force)
  if not force then
    local ans = reaper.MB("Delete set '" .. set.name .. "'?", TITLE, 4)
    if ans ~= 6 then return end
  end
  reaper.SetProjExtState(0, EXT, set.id, "")
  reaper.MarkProjectDirty(0)
  load_sets()
  status = "Set '" .. set.name .. "' deleted."
end

local function default_export_path()
  local _, projfn = reaper.EnumProjects(-1)
  local dir, base
  if projfn and projfn ~= "" then
    dir  = projfn:match("^(.*)[/\\][^/\\]*$")
    base = projfn:match("([^/\\]+)%.[Rr][Pp][Pp]$") or "projet"
  end
  if not dir then dir = reaper.GetResourcePath(); base = "projet" end
  return dir, base .. "_regions.txt"
end

local function export_txt()
  if #list == 0 then status = "No region to export."; return end
  local dir, fname = default_export_path()
  local path
  if reaper.JS_Dialog_BrowseForSaveFile then
    local rv, fn = reaper.JS_Dialog_BrowseForSaveFile(
      "Export region list", dir, fname,
      "Text files (*.txt)\0*.txt\0All files (*.*)\0*.*\0\0")
    if rv ~= 1 or not fn or fn == "" then status = "Export cancelled."; return end
    path = fn
    if not path:match("%.[^/\\%.]+$") then path = path .. ".txt" end
  else
    path = dir .. package.config:sub(1, 1) .. fname
  end

  local f, err = io.open(path, "w")
  if not f then status = "Export failed: " .. tostring(err); return end
  if dirty then rebuild() end
  local total, totalAll = 0, 0
  f:write("ID\tName\tComment\tDuration\n")
  for _, row in ipairs(rows) do
    local r = row.r
    local nm = (r.name:gsub("[\t\r\n]", " "))
    local cm = ((comments[r.key] or ""):gsub("[\t\r\n]", " "))
    if r.disabled then
      f:write(string.format("-\t%s [disabled]\t%s\t%s\n", nm, cm, fmt_time(r.dur)))
    else
      totalAll = totalAll + r.dur
      if row.depth == 0 then total = total + r.dur end
      f:write(string.format("%d\t%s%s\t%s\t%s\n", r.id, string.rep("  ", row.depth), nm, cm, fmt_time(r.dur)))
    end
  end
  f:write(string.format("\tTOTAL top-level regions (%d)\t\t%s\n", activeTops, fmt_time(total)))
  if nestedCount > 0 then
    f:write(string.format("\tRaw sum, nested regions included (%d)\t\t%s\n", #list - disabledCount, fmt_time(totalAll)))
  end
  if disabledCount > 0 then
    f:write(string.format("\t(%d disabled region(s) excluded from totals)\t\t\n", disabledCount))
  end
  f:close()
  status = "List exported: " .. path
end

------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------
local function handle_click(r)
  local mods  = ImGui.GetKeyMods(ctx)
  local ctrl  = (mods & (ImGui.Mod_Ctrl | ImGui.Mod_Super)) ~= 0
  local shift = (mods & ImGui.Mod_Shift) ~= 0
  if shift and lastClickedKey then
    local a, b
    for j, x in ipairs(rows) do
      if x.r.key == lastClickedKey then a = j end
      if x.r.key == r.key then b = j end
    end
    if a and b then
      if a > b then a, b = b, a end
      if not ctrl then selected = {} end
      for j = a, b do
        if not rows[j].r.disabled then selected[rows[j].r.key] = true end
      end
    end
  elseif ctrl then
    selected[r.key] = (not selected[r.key]) or nil
    lastClickedKey = r.key
  else
    selected = {}
    selected[r.key] = true
    lastClickedKey = r.key
  end
end

-- Texte barré (ReaImGui n'a pas de style "barré" : on trace une ligne par-dessus)
local function text_strike(label, color)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = ImGui.CalcTextSize(ctx, label)
  ImGui.TextColored(ctx, color, label)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddLine(dl, x, y + h * 0.5, x + w, y + h * 0.5, color, 1.5)
end

-- Nom d'une région selon son état :
--   désactivée : rouge barré | en lecture : jaune + grand | couverte par la sélection : vert + italique
local function draw_name(r, isPlaying, inSel)
  local label = (r.name == "") and "(unnamed)" or r.name
  local nch = #r.children
  if nch > 0 then
    label = string.format("%s  (%d nested)", label, nch)
  end

  if r.disabled then
    text_strike(label, COL_RED)
    return
  end

  local color
  if isPlaying then color = COL_YELLOW
  elseif inSel then color = COL_SELGREEN
  elseif nch > 0 then color = COL_BLUE
  elseif r.name == "" then color = ImGui.GetStyleColor(ctx, ImGui.Col_TextDisabled) end

  local f
  if isPlaying then f = inSel and fontBigIt or fontBig
  else f = inSel and fontIt or font end

  ImGui.PushFont(ctx, f)
  if color then ImGui.TextColored(ctx, color, label) else ImGui.Text(ctx, label) end
  ImGui.PopFont(ctx)
end

-- Previous / Next region (by ID, wrapping around). dir = 1 : next, dir = -1 : previous.
-- Disabled regions are skipped. If the edit cursor is not inside a region, falls back to the
-- SWS "select next/previous marker or region" action.
local function go_relative(dir)
  local cursor_pos = reaper.GetCursorPosition()
  local regions = {}
  for _, r in ipairs(read_regions()) do
    if not r.disabled then regions[#regions + 1] = r end
  end
  table.sort(regions, function(a, b) return a.id < b.id end)

  local current
  for _, r in ipairs(regions) do
    if cursor_pos >= r.pos and cursor_pos <= r.rgnend then current = r; break end
  end

  if current then
    local target
    if dir > 0 then
      for _, r in ipairs(regions) do
        if r.id > current.id then target = r; break end
      end
      target = target or regions[1]                 -- wrap to the first region
    else
      for i = #regions, 1, -1 do
        if regions[i].id < current.id then target = regions[i]; break end
      end
      target = target or regions[#regions]          -- wrap to the last region
    end
    reaper.SetEditCurPos(target.pos, true, true)
    reaper.GetSet_LoopTimeRange(true, false, target.pos, target.rgnend, false)
  else
    local cmd = reaper.NamedCommandLookup(dir > 0 and "_SWS_SELNEXTMORR" or "_SWS_SELPREVMORR")
    if cmd ~= 0 then
      reaper.Main_OnCommand(cmd, 0)
    else
      status = "Cursor is not inside a region and the SWS action was not found."
    end
  end
end

-- Finds a native REAPER action by its (English) name; falls back to a known ID.
-- The resolved name is shown in the button tooltip so you can check it is the right action.
local function find_action(exactName, fallback)
  if reaper.kbd_getTextFromCmd and reaper.SectionFromUniqueID then
    local sec = reaper.SectionFromUniqueID(0)
    for id = 40000, 42500 do
      local name = reaper.kbd_getTextFromCmd(id, sec)
      if name and name:lower() == exactName then return id, name end
    end
    return fallback, reaper.kbd_getTextFromCmd(fallback, sec) or ""
  end
  return fallback, ""
end

local cmdMetro,   nameMetro   = find_action("options: toggle metronome", 40364)

-- Native toggle actions with fixed IDs
local cmdAutoStop = 41834     -- Transport: Toggle stop playback at end of loop if repeat is disabled
local cmdSmooth   = 40390     -- Options: Toggle smooth seek
local function action_name(id)
  if reaper.kbd_getTextFromCmd and reaper.SectionFromUniqueID then
    return reaper.kbd_getTextFromCmd(id, reaper.SectionFromUniqueID(0)) or ""
  end
  return ""
end
local nameAutoStop, nameSmooth = action_name(cmdAutoStop), action_name(cmdSmooth)

-- SWS/AW: Toggle count-in before playback (needs the SWS extension; 0 if not found)
local cmdCountIn  = reaper.NamedCommandLookup("_SWS_AWCOUNTPLAYTOG")
local nameCountIn = action_name(cmdCountIn)

-- Stop: while playing run action 40328, otherwise move the edit cursor to the start of the time selection
local function stop_action()
  if (reaper.GetPlayState() & 1) == 1 then
    reaper.Main_OnCommand(40328, 0)
  else
    local ts_s, ts_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if ts_e > ts_s then
      reaper.SetEditCurPos(ts_s, true, false)
    else
      status = "No time selection."
    end
  end
end

-- Play/Stop:
--   playing + loop on  -> loop off, time selection moved to the parent (top-level) region under the play cursor
--   playing + loop off -> same as Stop
--   not playing        -> play
local function playstop_action()
  if (reaper.GetPlayState() & 1) == 0 then
    reaper.OnPlayButton()
  elseif reaper.GetSetRepeat(-1) == 1 then
    reaper.GetSetRepeat(0)
    if dirty then rebuild() end
    local pos = reaper.GetPlayPosition()
    for _, t in ipairs(tops) do
      if not t.disabled and pos >= t.pos and pos < t.rgnend then
        reaper.GetSet_LoopTimeRange(true, false, t.pos, t.rgnend, false)
        break
      end
    end
  else
    stop_action()
  end
end

-- Live loop:
--   loop off -> loop on, time selection on the nested (child) region at the current position
--               (play position while playing, else edit cursor); the parent region if there is no child
--   loop on  -> loop off, time selection back on the parent region
local function liveloop_action()
  if dirty then rebuild() end
  local playing = (reaper.GetPlayState() & 1) == 1
  local pos = playing and reaper.GetPlayPosition() or reaper.GetCursorPosition()
  local mother, child
  for _, r in ipairs(list) do
    if not r.disabled and pos >= r.pos and pos < r.rgnend then
      if r.parent then
        if not child or (r.rgnend - r.pos) < (child.rgnend - child.pos) then child = r end
      elseif not mother then
        mother = r
      end
    end
  end
  if not mother then status = "Live loop: no song at the current position."; return end
  if reaper.GetSetRepeat(-1) == 1 then
    reaper.GetSetRepeat(0)
    reaper.GetSet_LoopTimeRange(true, false, mother.pos, mother.rgnend, false)
  else
    local t = child or mother
    reaper.GetSet_LoopTimeRange(true, false, t.pos, t.rgnend, false)
    reaper.GetSetRepeat(1)
  end
end

-- Horizontal zoom of the arrange view on a region (small margin on both sides)
local function zoom_region(r)
  local pad = (r.rgnend - r.pos) * 0.02
  reaper.GetSet_ArrangeView2(0, true, 0, 0, math.max(0, r.pos - pad), r.rgnend + pad)
  reaper.UpdateArrange()
end

-- Horizontal zoom on the whole project (media items, markers and regions)
local function zoom_all()
  local len = reaper.GetProjectLength(0)
  for _, r in ipairs(list) do if r.rgnend > len then len = r.rgnend end end
  if len <= 0 then return end
  reaper.GetSet_ArrangeView2(0, true, 0, 0, 0, len * 1.02)
  reaper.UpdateArrange()
end

local function push_on_colors()
  ImGui.PushStyleColor(ctx, ImGui.Col_Button,        0x2E9E4FFF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x3DBF64FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,  0x58D883FF)
end

-- Button that runs a toggle action and lights up (green) while the action is on
local function toggle_button(label, cmd, name, w, h)
  local found = cmd ~= nil and cmd ~= 0
  local on = found and reaper.GetToggleCommandState(cmd) == 1
  if on then push_on_colors() end
  local clicked = ImGui.Button(ctx, label, w, h)
  if on then ImGui.PopStyleColor(ctx, 3) end
  tip(name ~= "" and name or label)
  if clicked and found then reaper.Main_OnCommand(cmd, 0) end
end

-- Transport rows:  [Previous] [Play/Stop] [Stop] [Next]
--                  [Metronome] [Count-in] [Zoom all]
-- Play/Stop: see playstop_action (lit while playing)
local function transport_buttons()
  local on = (reaper.GetPlayState() & 1) == 1
  local w = ImGui.GetContentRegionAvail(ctx)
  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
  local sideW, stopW = 110, 90
  local playW = math.max(80, w - 2 * sideW - stopW - 3 * spacing)

  ImGui.PushFont(ctx, fontBig)

  if ImGui.Button(ctx, "Previous", sideW, 46) then go_relative(-1) end
  tip("Previous region")
  ImGui.SameLine(ctx)

  if on then push_on_colors() end
  if ImGui.Button(ctx, "Play/Stop", playW, 46) then playstop_action() end
  if on then ImGui.PopStyleColor(ctx, 3) end
  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, "Stop", stopW, 46) then stop_action() end
  tip("Stop")
  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, "Next", sideW, 46) then go_relative(1) end
  tip("Next region")

  ImGui.PopFont(ctx)

  local bw = math.max(60, math.floor((w - 5 * spacing) / 6))
  toggle_button("Metronome", cmdMetro, nameMetro, bw, 28)
  ImGui.SameLine(ctx)
  toggle_button("Count-in", cmdCountIn, nameCountIn, bw, 28)
  ImGui.SameLine(ctx)
  toggle_button("Auto stop", cmdAutoStop, nameAutoStop, bw, 28)
  ImGui.SameLine(ctx)
  toggle_button("Smooth seek", cmdSmooth, nameSmooth, bw, 28)
  ImGui.SameLine(ctx)
  local loopOn = reaper.GetSetRepeat(-1) == 1
  if loopOn then push_on_colors() end
  if ImGui.Button(ctx, "Live loop", bw, 28) then liveloop_action() end
  if loopOn then ImGui.PopStyleColor(ctx, 3) end
  tip("Loop the nested region at the current position (parent if none). Click again: loop off, back to the parent region.")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Zoom all", bw, 28) then zoom_all() end
  tip("Zoom on the whole project")
end

-- Rename popup (opened by Shift+click on a region)
local renameKey, renameText, renameWantOpen, renameFocus = nil, "", false, false
local function rename_popup()
  if renameWantOpen then
    ImGui.OpenPopup(ctx, "Rename region")
    renameWantOpen = false
  end
  local visible = ImGui.BeginPopupModal(ctx, "Rename region", true, ImGui.WindowFlags_AlwaysAutoResize)
  if visible then
    if renameFocus then ImGui.SetKeyboardFocusHere(ctx); renameFocus = false end
    ImGui.SetNextItemWidth(ctx, 320)
    local _, txt = ImGui.InputText(ctx, "##rename", renameText)
    renameText = txt
    local enter = ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)
    local ok = ImGui.Button(ctx, "OK", 100, 0) or enter
    ImGui.SameLine(ctx)
    local cancel = ImGui.Button(ctx, "Cancel", 100, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)
    if ok then
      rename_region(renameKey, renameText)
      ImGui.CloseCurrentPopup(ctx)
    elseif cancel then
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end
end

local function draw()
  sync(false)
  if dirty then rebuild() end

  local pending = is_pending()

  -- Barre d'outils -----------------------------------------------------
  transport_buttons()

  if ImGui.Button(ctx, "Apply IDs") then apply_ids() end
  tip("Renumber regions following the list order")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset order") then reset_order() end
  tip("Back to the current IDs order")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Export .txt") then export_txt() end

  ImGui.PushTextWrapPos(ctx, 0)
  if overflow then
    ImGui.TextColored(ctx, COL_RED, string.format("Warning: some IDs would reach %d or more (a parent numbered 100+ with nested regions, or several nesting levels). 'Apply IDs' will refuse to run.", DISABLED_BASE))
  end
  if pending then
    ImGui.TextColored(ctx, COL_ORANGE, "Order changed: click 'Apply IDs' to write it to the project.")
  else
    ImGui.TextDisabled(ctx, "Click: select. Double-click: play. Shift+click: rename. Ctrl+click: zoom. Alt+click: disable. Drag: reorder.")
  end
  ImGui.PopTextWrapPos(ctx)

  -- Tableau ------------------------------------------------------------
  if dirty then rebuild() end   -- une action de la barre d'outils a pu modifier la liste
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local fh = ImGui.GetFrameHeightWithSpacing(ctx)
  local table_h = math.max(120, avail_h - fh * (7.2 + (nestedCount > 0 and 1 or 0)))

  local tflags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY
  local move_from, move_to
  local toggle_target, goto_target, play_target, zoom_target, rename_target
  local scrolling = false
  local total, totalAll = 0, 0

  -- Position de lecture (lecture / pause / enregistrement) et sélection temporelle
  local curpos
  if (reaper.GetPlayState() & 7) ~= 0 then curpos = reaper.GetPlayPosition() end
  local ts_s, ts_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local hasSel = (ts_e - ts_s) > EPS
  ImGui.PushFont(ctx, fontBig)
  local hBig = ImGui.GetTextLineHeight(ctx)      -- hauteur d'une ligne "grande" (surbrillance de la ligne)
  ImGui.PopFont(ctx)

  if ImGui.BeginTable(ctx, "regions", 5, tflags, avail_w, table_h) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "ID",       ImGui.TableColumnFlags_WidthFixed, 46)
    ImGui.TableSetupColumn(ctx, "Name",      ImGui.TableColumnFlags_WidthStretch, 1.0)
    ImGui.TableSetupColumn(ctx, "Comment",   ImGui.TableColumnFlags_WidthStretch, 1.4)
    ImGui.TableSetupColumn(ctx, "Duration",    ImGui.TableColumnFlags_WidthFixed, 100)
    ImGui.TableSetupColumn(ctx, "New ID", ImGui.TableColumnFlags_WidthFixed, 66)
    ImGui.TableHeadersRow(ctx)

    local overlapFlag = 0                       -- lets the comment field sit on top of the row's Selectable
    for _, name in ipairs({ "SelectableFlags_AllowOverlap", "SelectableFlags_AllowItemOverlap" }) do
      local ok, v = pcall(function() return ImGui[name] end)
      if ok and type(v) == "number" then overlapFlag = v; break end
    end
    local selFlags = ImGui.SelectableFlags_SpanAllColumns | ImGui.SelectableFlags_AllowDoubleClick | overlapFlag

    for _, row in ipairs(rows) do
      local r = row.r
      if not r.disabled then
        totalAll = totalAll + r.dur
        if row.depth == 0 then total = total + r.dur end
      end
      local isPlaying = (not r.disabled) and curpos ~= nil and curpos >= r.pos and curpos < r.rgnend
      local inSel = (not r.disabled) and hasSel and r.pos >= ts_s - EPS and r.rgnend <= ts_e + EPS

      ImGui.TableNextRow(ctx)
      if row.depth > 0 then ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg1, COL_NESTED_BG) end
      ImGui.TableNextColumn(ctx)
      ImGui.PushID(ctx, r.key)

      local idLabel = r.disabled and "OFF" or tostring(r.id)
      local clicked = ImGui.Selectable(ctx, idLabel, selected[r.key] == true, selFlags, 0, isPlaying and hBig or 0)
      local dbl = ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0)
      if clicked then
        local mods = ImGui.GetKeyMods(ctx)
        if (mods & ImGui.Mod_Alt) ~= 0 then
          toggle_target = r                         -- Alt+clic : désactiver / réactiver
        elseif (mods & ImGui.Mod_Shift) ~= 0 and (mods & (ImGui.Mod_Ctrl | ImGui.Mod_Super)) == 0 then
          rename_target = r                         -- Shift+click: rename the region
        elseif not r.disabled and (mods & (ImGui.Mod_Ctrl | ImGui.Mod_Super)) ~= 0 then
          zoom_target = r                           -- Ctrl+click: horizontal zoom on the region
        elseif not r.disabled then                  -- a disabled region can be neither selected nor played
          handle_click(r)
          if dbl then
            play_target = r                         -- double-clic : lecture
          elseif (mods & (ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Mod_Super)) == 0 then
            goto_target = r                         -- clic simple : go to / time-select
          end
        end
      end

      -- Glisser-déposer (doit suivre immédiatement le Selectable ; reste possible pour une région désactivée)
      if row.depth == 0 and ImGui.BeginDragDropSource(ctx, ImGui.DragDropFlags_None) then
        ImGui.SetDragDropPayload(ctx, "REGION_ROW", tostring(row.top))
        ImGui.Text(ctx, string.format("%s  %s", idLabel, r.name))
        ImGui.EndDragDropSource(ctx)
      end
      if ImGui.BeginDragDropTarget(ctx) then
        local ok, payload = ImGui.AcceptDragDropPayload(ctx, "REGION_ROW")
        if ok then move_from, move_to = tonumber(payload), row.top end
        ImGui.EndDragDropTarget(ctx)
      end

      ImGui.TableNextColumn(ctx)
      if row.depth > 0 then ImGui.Indent(ctx, row.depth * 18) end
      draw_name(r, isPlaying, inSel)
      if row.depth > 0 then ImGui.Unindent(ctx, row.depth * 18) end

      ImGui.TableNextColumn(ctx)
      ImGui.SetNextItemWidth(ctx, (ImGui.GetContentRegionAvail(ctx)))
      local changed, newtext = ImGui.InputText(ctx, "##comment", comments[r.key] or "")
      if changed then save_comment(r.key, newtext) end

      ImGui.TableNextColumn(ctx)
      if r.disabled then ImGui.TextDisabled(ctx, fmt_time(r.dur)) else ImGui.Text(ctx, fmt_time(r.dur)) end
      ImGui.TableNextColumn(ctx)
      if r.disabled then
        ImGui.TextDisabled(ctx, "-")
      else
        local newid = targets[r.key]
        if r.id ~= newid then ImGui.TextColored(ctx, COL_ORANGE, tostring(newid))
        else ImGui.TextDisabled(ctx, tostring(newid)) end
      end

      ImGui.PopID(ctx)
    end

    if #list == 0 then
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.TextDisabled(ctx, "No regions in this project.")
    end

    scrolling = ImGui.GetScrollMaxY(ctx) > 0
    ImGui.EndTable(ctx)
  end

  if move_from and move_to and move_from ~= move_to and tops[move_from] then
    local item = table.remove(tops, move_from)
    table.insert(tops, move_to, item)
    local newlist = {}
    for _, t in ipairs(tops) do newlist[#newlist + 1] = t end            -- principales dans le nouvel ordre
    for _, r in ipairs(list) do if r.parent then newlist[#newlist + 1] = r end end
    list = newlist
    dirty = true
  end

  -- Actions déclenchées par un clic (exécutées après le tableau)
  if toggle_target then
    toggle_disabled(toggle_target)
  elseif play_target then
    goto_region(play_target, true)
  elseif goto_target then
    goto_region(goto_target, false)
  elseif zoom_target then
    zoom_region(zoom_target)
  elseif rename_target then
    renameKey, renameText = rename_target.key, rename_target.name
    renameWantOpen, renameFocus = true, true
  end

  -- Ligne de total (colonnes alignées sur le tableau) ---------------------
  local foot_w = avail_w
  if scrolling then foot_w = foot_w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ScrollbarSize) end
  if ImGui.BeginTable(ctx, "footer", 5, ImGui.TableFlags_Borders, foot_w, 0) then
    ImGui.TableSetupColumn(ctx, "ID",       ImGui.TableColumnFlags_WidthFixed, 46)
    ImGui.TableSetupColumn(ctx, "Name",      ImGui.TableColumnFlags_WidthStretch, 1.0)
    ImGui.TableSetupColumn(ctx, "Comment",   ImGui.TableColumnFlags_WidthStretch, 1.4)
    ImGui.TableSetupColumn(ctx, "Duration",    ImGui.TableColumnFlags_WidthFixed, 100)
    ImGui.TableSetupColumn(ctx, "New ID", ImGui.TableColumnFlags_WidthFixed, 66)
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
    ImGui.TableNextColumn(ctx)
    local lbl = string.format((nestedCount > 0) and "Total (%d top-level regions" or "Total (%d regions", activeTops)
    if disabledCount > 0 then
      lbl = lbl .. string.format(", %d disabled", disabledCount)
    end
    lbl = lbl .. ")"
    ImGui.TextColored(ctx, COL_GREEN, lbl)
    ImGui.TableNextColumn(ctx)
    ImGui.TableNextColumn(ctx)
    ImGui.TextColored(ctx, COL_GREEN, fmt_time(total))
    ImGui.TableNextColumn(ctx)
    if nestedCount > 0 then
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.TextDisabled(ctx, string.format("Raw sum (%d regions, nested included)", #list - disabledCount))
      ImGui.TableNextColumn(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.TextDisabled(ctx, fmt_time(totalAll))
    end
    ImGui.EndTable(ctx)
  end

  -- Region sets --------------------------------------------------------
  ImGui.SeparatorText(ctx, "Region sets")

  ImGui.SetNextItemWidth(ctx, 220)
  local rv, txt = ImGui.InputTextWithHint(ctx, "##newset", "Set name", newSetName)
  if rv then newSetName = txt end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Save set") then save_set(newSetName) end
  tip("Save the current order as a set")

  local cur = current_set()
  ImGui.SetNextItemWidth(ctx, 220)
  if ImGui.BeginCombo(ctx, "##setcombo", cur and cur.name or "- choose a set -") then
    for _, s in ipairs(sets) do
      if ImGui.Selectable(ctx, string.format("%s (%d)##%s", s.name, #s.entries, s.id), s.id == selSetId) then
        selSetId = s.id
        newSetName = s.name
      end
    end
    if #sets == 0 then ImGui.TextDisabled(ctx, "No set in this project") end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  ImGui.BeginDisabled(ctx, cur == nil)
  if ImGui.Button(ctx, "Load") and cur then load_set(cur) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Delete set") and cur then delete_set(cur) end
  ImGui.EndDisabled(ctx)

  local changed, v = ImGui.Checkbox(ctx, "Apply IDs immediately when loading a set", applyOnLoad)
  if changed then applyOnLoad = v end

  if status ~= "" then ImGui.TextWrapped(ctx, status) end

  rename_popup()
end

------------------------------------------------------------------------
-- Remote bridge for REABACK.html (REAPER web interface)
-- The script publishes a JSON snapshot of the list in ExtState and executes the commands
-- sent by the page. It works as long as this script is running (the window can be closed
-- only by stopping the script).
------------------------------------------------------------------------
local BRIDGE = "REABACK_REMOTE"
local lastCmd = reaper.GetExtState(BRIDGE, "cmd")    -- ignore a command left over from a previous run
local snapVer, lastSnap, lastBuild, lastHb = os.time(), "", 0, 0

local function jstr(v)
  v = tostring(v or "")
  v = v:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"'
    elseif c == "\\" then return "\\\\"
    elseif c == "\n" then return "\\n"
    elseif c == "\r" then return "\\r"
    elseif c == "\t" then return "\\t" end
    return string.format("\\u%04x", c:byte())
  end)
  return '"' .. v .. '"'
end
local function jnum(n) return string.format("%.6f", n or 0) end
local function jbool(b) return b and "true" or "false" end

local function build_snapshot()
  if dirty then rebuild() end
  local ts_s, ts_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local function tog(cmd)
    if cmd and cmd ~= 0 and reaper.GetToggleCommandState(cmd) == 1 then return 1 end
    return 0
  end

  local o = {}
  o[#o + 1] = '{"v":1,"ts":[' .. jnum(ts_s) .. ',' .. jnum(ts_e) .. ']'
  o[#o + 1] = ',"play":' .. ((reaper.GetPlayState() & 1) == 1 and 1 or 0) .. ',"loop":' .. (reaper.GetSetRepeat(-1) == 1 and 1 or 0) .. ',"metro":' .. tog(cmdMetro) .. ',"count":' .. tog(cmdCountIn)
  o[#o + 1] = ',"cmdMetro":' .. tostring(cmdMetro or 0) .. ',"cmdCount":' .. tostring(cmdCountIn or 0)
  o[#o + 1] = ',"pending":' .. jbool(is_pending()) .. ',"overflow":' .. jbool(overflow)
  o[#o + 1] = ',"tops":' .. activeTops .. ',"nested":' .. nestedCount .. ',"disabled":' .. disabledCount
  o[#o + 1] = ',"applyOnLoad":' .. jbool(applyOnLoad) .. ',"status":' .. jstr(status)

  o[#o + 1] = ',"rows":['
  for i, row in ipairs(rows) do
    local r = row.r
    o[#o + 1] = (i > 1 and "," or "") .. string.format(
      '{"k":%s,"id":%d,"nm":%s,"cm":%s,"s":%s,"e":%s,"d":%d,"off":%d,"nid":%d,"ch":%d}',
      jstr(r.key), r.id, jstr(r.name), jstr(comments[r.key] or ""), jnum(r.pos), jnum(r.rgnend),
      row.depth, r.disabled and 1 or 0, targets[r.key] or r.id, #r.children)
  end

  o[#o + 1] = '],"sets":['
  for i, st in ipairs(sets) do
    o[#o + 1] = (i > 1 and "," or "") .. string.format('{"id":%s,"nm":%s,"n":%d}', jstr(st.id), jstr(st.name), #st.entries)
  end
  o[#o + 1] = '],"sel":' .. jstr(selSetId or "") .. '}'
  return table.concat(o)
end

local function bridge_publish()
  local now = reaper.time_precise()
  if now - lastHb > 1 then                       -- heartbeat: tells the page the script is alive
    reaper.SetExtState(BRIDGE, "hb", tostring(math.floor(now)), false)
    lastHb = now
  end
  if now - lastBuild < 0.15 then return end
  lastBuild = now
  local snap = build_snapshot()
  if snap ~= lastSnap then
    lastSnap = snap
    snapVer = snapVer + 1
    reaper.SetExtState(BRIDGE, "snap", snap, false)
    reaper.SetExtState(BRIDGE, "ver", tostring(snapVer), false)
  end
end

local function find_region(key)
  for _, r in ipairs(list) do if r.key == key then return r end end
end
local function find_set(id)
  for _, st in ipairs(sets) do if st.id == id then return st end end
end

-- Moves a top-level region (and its nested regions) up (-1) or down (+1) in the list
local function move_top(key, delta)
  if dirty then rebuild() end
  local i
  for idx, t in ipairs(tops) do if t.key == key then i = idx end end
  local j = i and (i + delta)
  if not i or j < 1 or j > #tops then return end
  tops[i], tops[j] = tops[j], tops[i]
  local newlist = {}
  for _, t in ipairs(tops) do newlist[#newlist + 1] = t end
  for _, r in ipairs(list) do if r.parent then newlist[#newlist + 1] = r end end
  list = newlist
  dirty = true
end

local function handle_remote(op, a1, a2)
  if op == "goto" then
    local r = find_region(a1)
    if r and not r.disabled then goto_region(r, a2 == "1") end
  elseif op == "toggle" then
    local r = find_region(a1)
    if r then toggle_disabled(r) end
  elseif op == "comment" then
    if find_region(a1) then save_comment(a1, a2 or "") end
  elseif op == "rename" then
    if find_region(a1) then rename_region(a1, a2 or "") end
  elseif op == "move" then
    move_top(a1, tonumber(a2) or 0)
  elseif op == "apply" then
    apply_ids()
  elseif op == "reset" then
    reset_order()
  elseif op == "save_set" then
    save_set(a1, true)
  elseif op == "load_set" then
    local st = find_set(a1)
    if st then
      local old = applyOnLoad
      applyOnLoad = (a2 == "1")
      load_set(st)
      applyOnLoad = old
    end
  elseif op == "delete_set" then
    local st = find_set(a1)
    if st then delete_set(st, true) end
  elseif op == "prev" then
    go_relative(-1)
  elseif op == "next" then
    go_relative(1)
  elseif op == "stop" then
    stop_action()
  elseif op == "playstop" then
    playstop_action()
  elseif op == "liveloop" then
    liveloop_action()
  end
end

-- Command format (ExtState "cmd"): seq|op|arg1|arg2, each part percent-encoded
local function bridge_poll()
  local c = reaper.GetExtState(BRIDGE, "cmd")
  if c == "" or c == lastCmd then return end
  lastCmd = c
  local parts = {}
  for p in (c .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = unesc(p) end
  local ok, err = pcall(handle_remote, parts[2], parts[3], parts[4])
  if not ok then status = "Remote command failed: " .. tostring(err) end
  reaper.SetExtState(BRIDGE, "ack", parts[1] or "", false)   -- acknowledges the command
  lastBuild = 0                                              -- republish the snapshot right away
end

------------------------------------------------------------------------
-- Toolbar toggle states: this window lit while open; the standalone scripts
-- (Play/Stop, Live loop...) kept in sync with the transport while it is open
------------------------------------------------------------------------
local _, _, tg_sec, tg_cmd = reaper.get_action_context()
local function set_toggle(sec, cmd, v)
  if cmd and cmd > 0 and reaper.GetToggleCommandStateEx(sec, cmd) ~= v then
    reaper.SetToggleCommandState(sec, cmd, v)
    reaper.RefreshToolbar2(sec, cmd)
  end
end

local TOGGLE_KEYS = { "PlayStop", "LiveLoop", "Stop", "Next", "Previous" }
local toggle_cmds, toggle_t = {}, 0
local function sync_toggles()
  local now = reaper.time_precise()
  if now - toggle_t < 0.2 then return end
  toggle_t = now
  local playing = (reaper.GetPlayState() & 1) == 1
  local looping = reaper.GetSetRepeat(-1) == 1
  for _, key in ipairs(TOGGLE_KEYS) do
    local reg = reaper.GetExtState("REABACK_toggles", key)
    if reg ~= "" then
      local c = toggle_cmds[key]
      if not c or c.reg ~= reg then
        local sec, named = reg:match("^(%-?%d+)|(.+)$")
        c = { reg = reg, sec = tonumber(sec) or 0, cmd = named and reaper.NamedCommandLookup("_" .. named) or 0 }
        toggle_cmds[key] = c
      end
      local v = 0
      if key == "PlayStop" then v = playing and 1 or 0
      elseif key == "LiveLoop" then v = looping and 1 or 0 end
      set_toggle(c.sec, c.cmd, v)
    end
  end
end

set_toggle(tg_sec, tg_cmd, 1)
reaper.atexit(function()
  reaper.SetExtState(BRIDGE, "hb", "", false)
  set_toggle(tg_sec, tg_cmd, 0)
end)

------------------------------------------------------------------------
-- Boucle principale
------------------------------------------------------------------------
sync(true)
load_sets()
load_comments()

local function loop()
  sync_toggles()
  sync(false)
  if dirty then rebuild() end
  bridge_poll()
  bridge_publish()

  ImGui.SetNextWindowSize(ctx, 640, 640, ImGui.Cond_FirstUseEver)
  ImGui.PushFont(ctx, font)
  local visible, open = ImGui.Begin(ctx, TITLE, true)
  if visible then
    draw()
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
