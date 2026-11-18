-- @description Custom Strips (track presets window)
-- @author ReNo Mellow
-- @version 1.2
-- @about Fenêtre à 2 onglets : appliquer ses « custom strips » favoris aux pistes sélectionnées (nom, tag, couleur, icône, layout, entrée, metering, FX chain, enveloppes, items, normalisation, groupe) et les configurer. Nécessite ReaImGui.
-- @changelog Nouvelle colonne Metering : type de mètre de piste par strip (peaks, RMS, LUFS-M, LUFS-S, désactivé)

--------------------------------------------------------------------------------
-- ReaImGui check
--------------------------------------------------------------------------------
local SCRIPT_TITLE = "ReNo Mellow - Custom Strips"
local VERSION = "1.2"

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs the ReaImGui extension.\n\n" ..
    "Install it with ReaPack:\nExtensions > ReaPack > Browse packages > search \"ReaImGui\" > Install,\nthen restart REAPER.",
    SCRIPT_TITLE, 0)
  if reaper.ReaPack_BrowsePackages then reaper.ReaPack_BrowsePackages("ReaImGui") end
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local FLT_MIN   = 1.17549435e-38
local RES       = reaper.GetResourcePath():gsub("\\", "/")
local DATA_DIR  = RES .. "/Data/ReNo_CustomStrips"
local DATA_FILE = DATA_DIR .. "/strips.lua"
local ICON_DIR  = RES .. "/Data/track_icons"
local FXC_DIR   = RES .. "/FXChains"
local DND_TYPE  = "RNCS_STRIP"

local NORM_TYPES = {
  { label = "LUFS-I",    v = 0 },
  { label = "RMS",       v = 1 },
  { label = "Peak",      v = 2 },
  { label = "True peak", v = 3 },
}

-- track meter modes (I_VUMODE & 30, or 1 = disabled)
local METER_MODES = {
  { label = "Stereo peaks",            v = 0 },
  { label = "Multichannel peaks",      v = 2 },
  { label = "Stereo RMS",              v = 4 },
  { label = "Combined RMS",            v = 8 },
  { label = "LUFS-M",                  v = 12 },
  { label = "LUFS-S (readout = max)",  v = 16 },
  { label = "LUFS-S (readout = current)", v = 20 },
  { label = "Meter disabled",          v = 1 },
}

local ENVS = {
  { key = "vol",   label = "Volume",      chunk = "VOLENV2",   action = "track: toggle track volume envelope visible", id = 40406 },
  { key = "pan",   label = "Pan",         chunk = "PANENV2",   action = "track: toggle track pan envelope visible",    id = 40407 },
  { key = "width", label = "Width",       chunk = "WIDTHENV2", action = "track: toggle track width envelope visible" },
  { key = "mute",  label = "Mute",        chunk = "MUTEENV",   action = "track: toggle track mute envelope visible",   id = 40867 },
  { key = "trim",  label = "Trim volume", chunk = "VOLENV3",   action = "track: toggle track trim envelope visible" },
}

-- pairs shown side by side (lead | follow)
local GROUP_FLAGS = {
  { "VOLUME_LEAD",     "Volume lead",     "VOLUME_FOLLOW",     "Volume follow" },
  { "VOLUME_VCA_LEAD", "VCA lead",        "VOLUME_VCA_FOLLOW", "VCA follow" },
  { "PAN_LEAD",        "Pan lead",        "PAN_FOLLOW",        "Pan follow" },
  { "WIDTH_LEAD",      "Width lead",      "WIDTH_FOLLOW",      "Width follow" },
  { "MUTE_LEAD",       "Mute lead",       "MUTE_FOLLOW",       "Mute follow" },
  { "SOLO_LEAD",       "Solo lead",       "SOLO_FOLLOW",       "Solo follow" },
  { "RECARM_LEAD",     "Rec arm lead",    "RECARM_FOLLOW",     "Rec arm follow" },
  { "POLARITY_LEAD",   "Polarity lead",   "POLARITY_FOLLOW",   "Polarity follow" },
  { "AUTOMODE_LEAD",   "Auto mode lead",  "AUTOMODE_FOLLOW",   "Auto mode follow" },
  { "VOLUME_REVERSE",  "Volume reverse",  "PAN_REVERSE",       "Pan reverse" },
  { "WIDTH_REVERSE",   "Width reverse",   "NO_LEAD_WHEN_FOLLOW", "No lead when follow" },
}
local DEFAULT_GROUP_FLAGS = { VOLUME_LEAD = true, VOLUME_FOLLOW = true, MUTE_LEAD = true,
                              MUTE_FOLLOW = true, SOLO_LEAD = true, SOLO_FOLLOW = true }
local MAX_GROUPS = reaper.GetSetTrackGroupMembershipEx and 128 or 64

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function nonempty(s) s = trim(s); if s == "" then return nil end return s end
local function basename(p) return (p or ""):match("([^/\\]+)$") or p end
local function norm_path(p) return (p or ""):gsub("\\", "/") end

local function utf8_sub(s, n)
  local ok, res = pcall(function()
    local out, i = {}, 0
    for _, c in utf8.codes(s) do
      i = i + 1
      if i > n then break end
      out[#out + 1] = utf8.char(c)
    end
    return table.concat(out)
  end)
  if ok then return res end
  return s:sub(1, n)
end

local function clean_tag(s)
  s = (s or ""):gsub("[%[%]%s]", "")
  s = utf8_sub(s, 3):upper()
  if s == "" then return nil end
  return s
end

local function utf8_len(s)
  local ok, n = pcall(utf8.len, s)
  if ok and n then return n end
  return #s
end

-- remove a trailing " [ABC]" tag (1 to 3 characters)
local function remove_tag(name)
  local base, t = name:match("^(.-)%s*%[([^%[%]]+)%]%s*$")
  if base and utf8_len(t) <= 3 then return base end
  return name
end

-- colours (stored as 0xRRGGBB)
local function rgb_split(c) return (c >> 16) & 255, (c >> 8) & 255, c & 255 end
local function rgba(c, a) return ((c & 0xFFFFFF) << 8) | (a or 0xFF) end
local function shade(c, f)
  local r, g, b = rgb_split(c)
  local function cl(v) v = math.floor(v * f + 0.5); if v > 255 then v = 255 end; if v < 0 then v = 0 end; return v end
  return (cl(r) << 16) | (cl(g) << 8) | cl(b)
end
local function text_on(c)
  local r, g, b = rgb_split(c)
  return (0.299 * r + 0.587 * g + 0.114 * b) > 150 and 0x000000FF or 0xFFFFFFFF
end

--------------------------------------------------------------------------------
-- Storage (Data/ReNo_CustomStrips/strips.lua)
--------------------------------------------------------------------------------
local function ser(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.17g", v)
  elseif t == "string" then
    return string.format("%q", v)
  elseif t == "boolean" then
    return tostring(v)
  elseif t == "table" then
    local out, ni, n = { "{\n" }, ind .. "  ", #v
    for i = 1, n do out[#out + 1] = ni .. ser(v[i], ni) .. ",\n" end
    local keys = {}
    for k in pairs(v) do
      if not (math.type(k) == "integer" and k >= 1 and k <= n) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. ser(k) .. "]")
      out[#out + 1] = ni .. ks .. " = " .. ser(v[k], ni) .. ",\n"
    end
    out[#out + 1] = ind .. "}"
    return table.concat(out)
  end
  return "nil"
end

local function load_data()
  local f = io.open(DATA_FILE, "r")
  if not f then return { strips = {} } end
  local s = f:read("a"); f:close()
  local fn = load(s, "strips", "t", {})
  if fn then
    local ok, d = pcall(fn)
    if ok and type(d) == "table" then
      d.strips = d.strips or {}
      return d
    end
  end
  -- keep a copy of the unreadable file
  local bk = io.open(DATA_FILE .. ".bad", "w")
  if bk then bk:write(s); bk:close() end
  return { strips = {} }
end

local function save_data(d)
  reaper.RecursiveCreateDirectory(DATA_DIR, 0)
  local tmp = DATA_FILE .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write("-- ReNo Mellow - Custom Strips data\nreturn ", ser(d), "\n")
  f:close()
  os.remove(DATA_FILE)
  return os.rename(tmp, DATA_FILE)
end

--------------------------------------------------------------------------------
-- Lists from REAPER (inputs, layouts, actions)
--------------------------------------------------------------------------------
local function list_layouts(section)
  local t = {}
  for i = 0, 300 do
    local ok, name = reaper.ThemeLayout_GetLayout(section, i)
    if not ok then break end
    if name and name ~= "" then t[#t + 1] = name end
  end
  return t
end

local function input_name(i)
  local n = reaper.GetInputChannelName(i)
  if not n or n == "" then n = "Input " .. (i + 1) end
  return n
end

local MIDI_ALL = 4096 | (63 << 5)
local MIDI_VKB = 4096 | (62 << 5)

local function rec_input_options()
  local o = { { label = "No input", value = -1 } }
  local n = reaper.GetNumAudioInputs()
  for i = 0, n - 1 do o[#o + 1] = { label = "Mono: " .. input_name(i), value = i } end
  for i = 0, n - 2 do
    o[#o + 1] = { label = "Stereo: " .. input_name(i) .. " / " .. input_name(i + 1), value = 1024 + i }
  end
  o[#o + 1] = { label = "MIDI: All inputs, all channels", value = MIDI_ALL }
  for ch = 1, 16 do o[#o + 1] = { label = "MIDI: All inputs, channel " .. ch, value = MIDI_ALL + ch } end
  o[#o + 1] = { label = "MIDI: Virtual keyboard, all channels", value = MIDI_VKB }
  return o
end

local function rec_input_label(v, opts)
  if v == nil then return "" end
  for _, o in ipairs(opts) do if o.value == v then return o.label end end
  if v >= 4096 then
    local dev, ch = (v >> 5) & 127, v & 31
    return "MIDI dev " .. dev .. ", " .. (ch == 0 and "all ch" or ("ch " .. ch))
  elseif v >= 1024 then
    return "Stereo from input " .. ((v & 1023) + 1)
  end
  return "Mono input " .. (v + 1)
end

local action_cache
local function find_action(lname)
  if not action_cache then
    action_cache = {}
    if reaper.kbd_enumerateActions and reaper.SectionFromUniqueID then
      local sec = reaper.SectionFromUniqueID(0)
      local i = 0
      while true do
        local id, nm = reaper.kbd_enumerateActions(sec, i)
        if not id or id == 0 then break end
        if nm then action_cache[nm:lower()] = id end
        i = i + 1
      end
    end
  end
  return action_cache[lname]
end

--------------------------------------------------------------------------------
-- Track state chunk helpers (fallbacks for FX chain and envelopes)
--------------------------------------------------------------------------------
local function split_lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\r?\n") do t[#t + 1] = l end
  while #t > 0 and t[#t] == "" do t[#t] = nil end
  return t
end

-- returns top-level children of the <TRACK block and the index of its closing ">"
local function scan_track_chunk(L)
  local depth, children, cur, track_end = 0, {}, nil, #L
  for i, line in ipairs(L) do
    local t = trim(line)
    if t:sub(1, 1) == "<" then
      depth = depth + 1
      if depth == 2 then cur = { name = t:match("^<(%S+)"), s = i } end
    elseif t == ">" then
      if depth == 2 and cur then cur.e = i; children[#children + 1] = cur; cur = nil end
      if depth == 1 then track_end = i end
      depth = depth - 1
    end
  end
  return children, track_end
end

local function insert_lines(L, pos, lines)
  local out = {}
  for i = 1, pos - 1 do out[#out + 1] = L[i] end
  for _, l in ipairs(lines) do out[#out + 1] = l end
  for i = pos, #L do out[#out + 1] = L[i] end
  return out
end

local function read_fxchain_lines(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("a"); f:close()
  local out = {}
  for _, l in ipairs(split_lines(s)) do
    if not trim(l):match("^FXID ") then out[#out + 1] = l end -- REAPER makes new IDs
  end
  return out
end

-- env_names: list of chunk names (e.g. "VOLENV2"); fx_lines: content of a .RfxChain
local function chunk_add(tr, env_names, fx_lines)
  local ok, chunk = reaper.GetTrackStateChunk(tr, "", false)
  if not ok then return false end
  local L = split_lines(chunk)
  local children, track_end = scan_track_chunk(L)
  local fxc, first_item
  for _, c in ipairs(children) do
    if c.name == "FXCHAIN" and not fxc then fxc = c end
    if c.name == "ITEM" and not first_item then first_item = c end
  end
  local base_pos = (fxc and fxc.s) or (first_item and first_item.s) or track_end

  -- FX first (highest index), then envelopes
  if fx_lines and #fx_lines > 0 then
    if fxc then
      L = insert_lines(L, fxc.e, fx_lines)
    else
      local blk = { "<FXCHAIN", "SHOW 0", "LASTSEL 0", "DOCKED 0" }
      for _, l in ipairs(fx_lines) do blk[#blk + 1] = l end
      blk[#blk + 1] = ">"
      L = insert_lines(L, (first_item and first_item.s) or track_end, blk)
    end
  end
  if env_names and #env_names > 0 then
    local blk = {}
    for _, nm in ipairs(env_names) do
      blk[#blk + 1] = "<" .. nm
      blk[#blk + 1] = "EGUID " .. reaper.genGuid("")
      blk[#blk + 1] = "ACT 1 -1"
      blk[#blk + 1] = "VIS 1 1 1"
      blk[#blk + 1] = "LANEHEIGHT 0 0"
      blk[#blk + 1] = "ARM 0"
      blk[#blk + 1] = "DEFSHAPE " .. (nm == "MUTEENV" and "1" or "0") .. " -1 -1"
      if nm == "VOLENV2" or nm == "VOLENV3" then blk[#blk + 1] = "VOLTYPE 1" end
      blk[#blk + 1] = ">"
    end
    L = insert_lines(L, base_pos, blk)
  end
  return reaper.SetTrackStateChunk(tr, table.concat(L, "\n") .. "\n", false)
end

--------------------------------------------------------------------------------
-- Apply one strip to the selected tracks
--------------------------------------------------------------------------------
local function set_env_visible(env)
  local ok, ch = reaper.GetEnvelopeStateChunk(env, "", false)
  if not ok then return end
  local n = ch
  n = n:gsub("\nVIS %d+", "\nVIS 1", 1)
  n = n:gsub("\nACT %d+", "\nACT 1", 1)
  if n ~= ch then reaper.SetEnvelopeStateChunk(env, n, false) end
end

local function add_fxchain(tr, path, warn)
  local before = reaper.TrackFX_GetCount(tr)
  local p = norm_path(path)
  local rel = p
  if p:lower():sub(1, #FXC_DIR + 1) == (FXC_DIR .. "/"):lower() then rel = p:sub(#FXC_DIR + 2) end
  reaper.TrackFX_AddByName(tr, rel, false, -1)
  if reaper.TrackFX_GetCount(tr) > before then return end
  -- fallback: insert the chain file into the track chunk
  local lines = read_fxchain_lines(path)
  if not lines then warn["FX chain file not found: " .. basename(path)] = true; return end
  chunk_add(tr, nil, lines)
end

local function take_norm_gain(item, take, ntype, target)
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil end
  local offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local len  = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local s, e = offs, offs + len * rate
  if s < 0 then s = 0 end
  local g = reaper.CalculateNormalization(src, ntype, target, s, e)
  if not g or g <= 0 or g > 1e6 or g ~= g then return nil end
  return g, len
end

local function normalize_track_items(tr, nz, warn)
  if not reaper.CalculateNormalization then
    warn["Normalize needs a more recent REAPER (CalculateNormalization)."] = true
    return
  end
  local list = {}
  for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
    local item = reaper.GetTrackMediaItem(tr, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local g, len = take_norm_gain(item, take, nz.type or 0, nz.target or -18)
      if g then list[#list + 1] = { take = take, g = g, len = len } end
    end
  end
  if #list == 0 then return end

  local function set_gain(take, g)
    local v = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
    reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", (v < 0 and -g) or g)
  end

  if nz.mode == "together" and #list > 1 then
    local common
    if (nz.type or 0) >= 2 then -- peak / true peak: loudest item reaches the target
      for _, it in ipairs(list) do if not common or it.g < common then common = it.g end end
    else -- LUFS / RMS: length-weighted energy of all items
      local target = nz.target or -18
      local e, tl = 0, 0
      for _, it in ipairs(list) do
        local lvl = target - 20 * math.log(it.g, 10)
        e = e + (10 ^ (lvl / 10)) * it.len
        tl = tl + it.len
      end
      if tl > 0 and e > 0 then
        local lc = 10 * math.log(e / tl, 10)
        common = 10 ^ ((target - lc) / 20)
      end
    end
    if common then for _, it in ipairs(list) do set_gain(it.take, common) end end
  else
    for _, it in ipairs(list) do set_gain(it.take, it.g) end
  end
end

local function set_group(tr, gid, key)
  local bit = 1 << ((gid - 1) % 32)
  if reaper.GetSetTrackGroupMembershipEx then
    reaper.GetSetTrackGroupMembershipEx(tr, key, math.floor((gid - 1) / 32) * 32, bit, bit)
  elseif gid <= 32 then
    reaper.GetSetTrackGroupMembership(tr, key, bit, bit)
  elseif gid <= 64 then
    reaper.GetSetTrackGroupMembershipHigh(tr, key, bit, bit)
  end
end

local function apply_strip(s)
  local n = reaper.CountSelectedTracks(0)
  if n == 0 then return false, "Select one or more tracks first." end
  local tracks = {}
  for i = 0, n - 1 do tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i) end

  local warn = {}
  local env_missing = {} -- key -> {tracks}
  local want_env = {}
  if s.envelopes then
    for _, d in ipairs(ENVS) do if s.envelopes[d.key] then want_env[#want_env + 1] = d end end
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for idx, tr in ipairs(tracks) do
    -- 2-3 : name + tag
    if s.track_name or s.tag then
      local _, cur = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local name
      if s.track_name then
        name = s.track_name
        if #tracks > 1 then name = name .. " " .. idx end
      else
        name = s.tag and remove_tag(cur) or cur
      end
      if s.tag then name = trim(name .. " [" .. s.tag .. "]") end
      reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
    end
    -- 4 : colour
    if s.color then
      local r, g, b = rgb_split(s.color)
      reaper.SetTrackColor(tr, reaper.ColorToNative(r, g, b))
    end
    -- 5 : icon
    if s.icon then reaper.GetSetMediaTrackInfo_String(tr, "P_ICON", s.icon, true) end
    -- 6 : layouts
    if s.layout then
      if s.layout.tcp then reaper.GetSetMediaTrackInfo_String(tr, "P_TCP_LAYOUT", s.layout.tcp, true) end
      if s.layout.mcp then reaper.GetSetMediaTrackInfo_String(tr, "P_MCP_LAYOUT", s.layout.mcp, true) end
    end
    -- 7 : record input
    if s.recinput then reaper.SetMediaTrackInfo_Value(tr, "I_RECINPUT", s.recinput) end
    -- 7b : metering type (other meter bits kept)
    if s.meter and s.meter.mode then
      local cur = math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_VUMODE"))
      local v = (cur & ~(1 | 30)) | s.meter.mode
      reaper.SetMediaTrackInfo_Value(tr, "I_VUMODE", v)
    end
    -- 8 : FX chain (added after existing FX)
    if s.fxchain then add_fxchain(tr, s.fxchain, warn) end
    -- 9 : envelopes (existing ones made visible now, missing ones created below)
    for _, d in ipairs(want_env) do
      local env = reaper.GetTrackEnvelopeByChunkName(tr, "<" .. d.chunk)
      if env then set_env_visible(env)
      else
        env_missing[d.key] = env_missing[d.key] or {}
        table.insert(env_missing[d.key], tr)
      end
    end
    -- 10 : item names
    if s.item_name then
      local items = {}
      for i = 0, reaper.CountTrackMediaItems(tr) - 1 do items[#items + 1] = reaper.GetTrackMediaItem(tr, i) end
      table.sort(items, function(a, b)
        return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
      end)
      for i, item in ipairs(items) do
        local take = reaper.GetActiveTake(item)
        local nm = (#items > 1) and (s.item_name .. " " .. i) or s.item_name
        if take then
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", nm, true)
        else
          reaper.GetSetMediaItemInfo_String(item, "P_NOTES", nm, true) -- empty item: no take
        end
      end
    end
    -- 11 : normalisation
    if s.normalize then normalize_track_items(tr, s.normalize, warn) end
    -- 12 : group
    if s.group and s.group.id then
      for key, on in pairs(s.group.flags or {}) do
        if on then set_group(tr, s.group.id, key) end
      end
    end
  end

  -- group name (project setting)
  if s.group and s.group.id and s.group.name then
    pcall(reaper.GetSetProjectInfo_String, 0, "TRACK_GROUP_NAME:" .. s.group.id, s.group.name, true)
  end

  -- create missing envelopes: native toggle action on just those tracks, chunk fallback
  if next(env_missing) then
    for _, d in ipairs(want_env) do
      local list = env_missing[d.key]
      if list then
        local id = find_action(d.action) or d.id
        if id then
          reaper.SetOnlyTrackSelected(list[1])
          for i = 2, #list do reaper.SetTrackSelected(list[i], true) end
          reaper.Main_OnCommand(id, 0)
        end
        for _, tr in ipairs(list) do
          local env = reaper.GetTrackEnvelopeByChunkName(tr, "<" .. d.chunk)
          if env then set_env_visible(env) else chunk_add(tr, { d.chunk }, nil) end
        end
      end
    end
    -- restore the original selection
    reaper.SetOnlyTrackSelected(tracks[1])
    for i = 2, #tracks do reaper.SetTrackSelected(tracks[i], true) end
  end

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Custom strip: " .. (s.name or ""), -1)

  local msg = string.format("Applied \"%s\" to %d track%s.", s.name or "", #tracks, #tracks > 1 and "s" or "")
  local w = {}
  for k in pairs(warn) do w[#w + 1] = k end
  if #w > 0 then msg = msg .. "  Warning: " .. table.concat(w, " ") end
  return true, msg, #w > 0
end

--------------------------------------------------------------------------------
-- Text summaries
--------------------------------------------------------------------------------
local function norm_label(v)
  for _, t in ipairs(NORM_TYPES) do if t.v == v then return t.label end end
  return "?"
end

local function sum_layout(l)
  if not l then return "" end
  local t = {}
  if l.tcp then t[#t + 1] = "TCP " .. (l.tcp == "" and "default" or l.tcp) end
  if l.mcp then t[#t + 1] = "MCP " .. (l.mcp == "" and "default" or l.mcp) end
  return table.concat(t, ", ")
end

local function sum_meter(m)
  if not m or not m.mode then return "" end
  local lbl = "?"
  for _, t in ipairs(METER_MODES) do if t.v == m.mode then lbl = t.label end end
  return lbl
end

local function sum_envs(e)
  if not e then return "" end
  local t = {}
  for _, d in ipairs(ENVS) do if e[d.key] then t[#t + 1] = d.label end end
  return table.concat(t, ", ")
end

local function sum_norm(nz)
  if not nz then return "" end
  return string.format("%.1f %s, %s", nz.target or -18, norm_label(nz.type or 0),
    nz.mode == "together" and "together" or "each")
end

local function sum_group(g)
  if not g or not g.id then return "" end
  local c = 0
  for _, on in pairs(g.flags or {}) do if on then c = c + 1 end end
  return "Group " .. g.id .. (g.name and (" \"" .. g.name .. "\"") or "") .. " (" .. c .. " flags)"
end

local REC_OPTS = rec_input_options()

local function describe(s)
  local t = {}
  local function add(k, v) if v and v ~= "" then t[#t + 1] = k .. ": " .. v end end
  add("Track name", s.track_name)
  add("Tag", s.tag and ("[" .. s.tag .. "]"))
  add("Colour", s.color and string.format("#%06X", s.color))
  add("Icon", s.icon and basename(s.icon))
  add("Layout", sum_layout(s.layout))
  add("Record input", s.recinput and rec_input_label(s.recinput, REC_OPTS))
  add("Metering", sum_meter(s.meter))
  add("FX chain", s.fxchain and basename(s.fxchain))
  add("Envelopes", sum_envs(s.envelopes))
  add("Item name", s.item_name)
  add("Normalize", sum_norm(s.normalize))
  add("Group", sum_group(s.group))
  if #t == 0 then return "Nothing set yet (see the Setup tab)." end
  return table.concat(t, "\n")
end

--------------------------------------------------------------------------------
-- UI state
--------------------------------------------------------------------------------
local ctx = ImGui.CreateContext(SCRIPT_TITLE)
local STRIP_FONT = ImGui.CreateFont("sans-serif", 17, ImGui.FontFlags_Bold)
ImGui.Attach(ctx, STRIP_FONT)
local data = load_data()
local strips = data.strips
local dirty, last_save = false, 0
local status, status_col = "", 0xBBBBBBFF
local LAYOUTS = { tcp = list_layouts("tcp"), mcp = list_layouts("mcp") }

local open_rename, rename_idx, rename_buf = false, nil, ""
local open_delete, delete_idx = false, nil
local goto_setup, scroll_row = false, nil
local pending -- structural change (move / duplicate) run after drawing the list

local function set_status(msg, kind)
  status = msg or ""
  status_col = (kind == "err" and 0xFF6060FF) or (kind == "warn" and 0xFFB040FF) or 0x70D070FF
end

local function mark() dirty = true end

local function new_strip()
  local n = #strips + 1
  strips[#strips + 1] = { name = "New strip " .. n }
  mark()
end

local function move_strip(from, to)
  if not from or not to or from == to or not strips[from] then return end
  local s = table.remove(strips, from)
  table.insert(strips, to, s)
  mark()
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end

local function do_apply(i)
  local s = strips[i]
  if not s then return end
  if not nonempty(s.name) then set_status("This strip has no name. Give it one in the Setup tab.", "err") return end
  local ok, msg, w = apply_strip(s)
  set_status(msg, (not ok and "err") or (w and "warn") or "ok")
end

--------------------------------------------------------------------------------
-- Tab 1 : strips
--------------------------------------------------------------------------------
local function strip_menu_items(i)
  if ImGui.MenuItem(ctx, "Apply to selected tracks") then do_apply(i) end
  if ImGui.MenuItem(ctx, "Rename...") then open_rename, rename_idx, rename_buf = true, i, strips[i].name or "" end
  if ImGui.MenuItem(ctx, "Edit in Setup") then goto_setup, scroll_row = true, i end
  if ImGui.MenuItem(ctx, "Duplicate") then
    pending = function()
      local c = copy(strips[i]); c.name = (c.name or "") .. " copy"
      table.insert(strips, i + 1, c); mark()
    end
  end
  ImGui.Separator(ctx)
  if ImGui.MenuItem(ctx, "Delete...") then open_delete, delete_idx = true, i end
end

local function draw_strips_tab()
  if #strips == 0 then
    ImGui.TextWrapped(ctx, "No strips yet. Create them in the Setup tab.")
    if ImGui.Button(ctx, "Create a strip") then new_strip(); goto_setup, scroll_row = true, #strips end
    return
  end
  ImGui.TextDisabled(ctx, "Click: apply to selected tracks.  Drag: reorder.  Right-click: rename / delete.")
  ImGui.Spacing(ctx)

  local avail = ImGui.GetContentRegionAvail(ctx)
  local bw, bh, sp = 112, 42, 6
  local per_row = math.max(1, math.floor((avail + sp) / (bw + sp)))
  local mv_from, mv_to

  for i, s in ipairs(strips) do
    ImGui.PushID(ctx, i)
    if (i - 1) % per_row ~= 0 then ImGui.SameLine(ctx, 0, sp) end
    local pushed = 0
    if s.color then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, rgba(s.color))
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, rgba(shade(s.color, 1.2)))
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, rgba(shade(s.color, 0.8)))
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_on(s.color))
      pushed = 4
    end
    local label = nonempty(s.name) or "(no name)"
    ImGui.PushFont(ctx, STRIP_FONT)
    if ImGui.Button(ctx, label .. "##strip", bw, bh) then do_apply(i) end
    ImGui.PopFont(ctx)
    if pushed > 0 then ImGui.PopStyleColor(ctx, pushed) end

    if ImGui.BeginDragDropSource(ctx) then
      ImGui.SetDragDropPayload(ctx, DND_TYPE, tostring(i))
      ImGui.Text(ctx, label)
      ImGui.EndDragDropSource(ctx)
    elseif ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
      ImGui.SetTooltip(ctx, describe(s))
    end
    if ImGui.BeginDragDropTarget(ctx) then
      local rv, payload = ImGui.AcceptDragDropPayload(ctx, DND_TYPE)
      if rv then mv_from, mv_to = tonumber(payload), i end
      ImGui.EndDragDropTarget(ctx)
    end
    if ImGui.BeginPopupContextItem(ctx, "ctxmenu") then
      strip_menu_items(i)
      ImGui.EndPopup(ctx)
    end
    ImGui.PopID(ctx)
  end
  if mv_from then move_strip(mv_from, mv_to) end
end

--------------------------------------------------------------------------------
-- Tab 2 : setup table
--------------------------------------------------------------------------------
local function clear_btn(id)
  ImGui.SameLine(ctx, 0, 2)
  return ImGui.SmallButton(ctx, "x##" .. id)
end

local IS_WIN = reaper.GetOS():match("Win") ~= nil
local function native(p) return IS_WIN and p:gsub("/", "\\") or p end

-- opens the file dialog directly in start_dir
local function file_browse(title, start_dir, ext, filter)
  reaper.RecursiveCreateDirectory(start_dir, 0)
  if reaper.JS_Dialog_BrowseForOpenFiles then -- js_ReaScriptAPI: reliable start folder + filter
    local rv, fn = reaper.JS_Dialog_BrowseForOpenFiles(title, native(start_dir), "", filter, false)
    if rv == 1 and fn and fn ~= "" then return norm_path(fn) end
    return nil
  end
  local ok, fn = reaper.GetUserFileNameForRead(native(start_dir .. "/"), title, ext)
  if ok and fn ~= "" then return norm_path(fn) end
end

local function cell_text(s, key, hint, width, flags)
  ImGui.SetNextItemWidth(ctx, width or -FLT_MIN)
  local rv, v = ImGui.InputTextWithHint(ctx, "##" .. key, hint, s[key] or "", flags or 0)
  if rv then s[key] = nonempty(v); mark() end
end

local function cell_popup_button(id, summary, w)
  local lbl = summary ~= "" and summary or "-"
  if ImGui.Button(ctx, lbl .. "##" .. id, w or -FLT_MIN) then ImGui.OpenPopup(ctx, "pop_" .. id) end
  if summary ~= "" and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, summary) end
  return ImGui.BeginPopup(ctx, "pop_" .. id)
end

local function layout_combo(s, sec)
  local cur = s.layout and s.layout[sec]
  local preview = (cur == nil and "(ignore)") or (cur == "" and "Theme default") or cur
  ImGui.SetNextItemWidth(ctx, 200)
  if ImGui.BeginCombo(ctx, sec:upper() .. " layout##" .. sec, preview) then
    local function pick(v)
      s.layout = s.layout or {}
      s.layout[sec] = v
      if s.layout.tcp == nil and s.layout.mcp == nil then s.layout = nil end
      mark()
    end
    if ImGui.Selectable(ctx, "(ignore)", cur == nil) then pick(nil) end
    if ImGui.Selectable(ctx, "Theme default", cur == "") then pick("") end
    for _, nm in ipairs(LAYOUTS[sec]) do
      if ImGui.Selectable(ctx, nm, cur == nm) then pick(nm) end
    end
    ImGui.EndCombo(ctx)
  end
end

local function draw_row(i, s)
  ImGui.TableNextRow(ctx)
  if scroll_row == i then
    ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg1, 0x3A6EA580)
  end

  -- #
  ImGui.TableNextColumn(ctx)
  ImGui.Text(ctx, tostring(i))
  if scroll_row == i and goto_setup == "scroll" then ImGui.SetScrollHereY(ctx, 0.5); goto_setup = false end

  -- 1 strip name (required)
  ImGui.TableNextColumn(ctx)
  ImGui.SetNextItemWidth(ctx, -FLT_MIN)
  local rv, v = ImGui.InputTextWithHint(ctx, "##name", "required", s.name or "")
  if rv then s.name = v; mark() end

  -- 2 track name
  ImGui.TableNextColumn(ctx)
  cell_text(s, "track_name", "keep current")

  -- 3 tag
  ImGui.TableNextColumn(ctx)
  ImGui.SetNextItemWidth(ctx, -FLT_MIN)
  local rv2, tg = ImGui.InputTextWithHint(ctx, "##tag", "ABC", s.tag or "", ImGui.InputTextFlags_CharsUppercase)
  if rv2 then s.tag = clean_tag(tg); mark() end

  -- 4 colour
  ImGui.TableNextColumn(ctx)
  if s.color then
    local rvc, c = ImGui.ColorEdit3(ctx, "##col", s.color, ImGui.ColorEditFlags_NoInputs)
    if rvc then s.color = c; mark() end
    if clear_btn("col") then s.color = nil; mark() end
  else
    if ImGui.Button(ctx, "Set##col") then s.color = 0x7F7F7F; mark() end
  end

  -- 5 icon
  ImGui.TableNextColumn(ctx)
  if ImGui.Button(ctx, (s.icon and basename(s.icon) or "Browse...") .. "##icon", s.icon and 110 or 0) then
    local f = file_browse("Choose a track icon", ICON_DIR, "png",
      "Images (*.png;*.jpg;*.ico;*.bmp)\0*.png;*.jpg;*.jpeg;*.ico;*.bmp\0All files (*.*)\0*.*\0\0")
    if f then
      if f:lower():sub(1, #ICON_DIR + 1) == (ICON_DIR .. "/"):lower() then f = f:sub(#ICON_DIR + 2) end
      s.icon = f; mark()
    end
  end
  if s.icon then
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, s.icon) end
    if clear_btn("icon") then s.icon = nil; mark() end
  end

  -- 6 layout
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("layout", sum_layout(s.layout)) then
    layout_combo(s, "tcp")
    layout_combo(s, "mcp")
    if #LAYOUTS.tcp == 0 and #LAYOUTS.mcp == 0 then ImGui.TextDisabled(ctx, "The current theme has no layouts.") end
    ImGui.EndPopup(ctx)
  end

  -- 7 record input
  ImGui.TableNextColumn(ctx)
  ImGui.SetNextItemWidth(ctx, -FLT_MIN)
  local prev = s.recinput and rec_input_label(s.recinput, REC_OPTS) or "-"
  if ImGui.BeginCombo(ctx, "##rec", prev, ImGui.ComboFlags_HeightLarge) then
    if ImGui.Selectable(ctx, "(ignore)", s.recinput == nil) then s.recinput = nil; mark() end
    for _, o in ipairs(REC_OPTS) do
      if ImGui.Selectable(ctx, o.label, s.recinput == o.value) then s.recinput = o.value; mark() end
    end
    ImGui.EndCombo(ctx)
  end

  -- 7b metering
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("meter", sum_meter(s.meter)) then
    ImGui.TextDisabled(ctx, "Track meter type:")
    if ImGui.RadioButton(ctx, "(ignore)", s.meter == nil) then s.meter = nil; mark() end
    for _, t in ipairs(METER_MODES) do
      if ImGui.RadioButton(ctx, t.label, s.meter ~= nil and s.meter.mode == t.v) then
        s.meter = s.meter or {}
        s.meter.mode = t.v; mark()
      end
    end
    ImGui.EndPopup(ctx)
  end

  -- 8 FX chain
  ImGui.TableNextColumn(ctx)
  if ImGui.Button(ctx, (s.fxchain and basename(s.fxchain):gsub("%.[Rr][Ff][Xx][Cc]hain$", "") or "Browse...") .. "##fx",
      s.fxchain and 110 or 0) then
    local f = file_browse("Choose an FX chain", FXC_DIR, "RfxChain",
      "FX chains (*.RfxChain)\0*.RfxChain\0All files (*.*)\0*.*\0\0")
    if f then s.fxchain = f; mark() end
  end
  if s.fxchain then
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, s.fxchain) end
    if clear_btn("fx") then s.fxchain = nil; mark() end
  end

  -- 9 envelopes
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("env", sum_envs(s.envelopes)) then
    ImGui.TextDisabled(ctx, "Show these track envelopes:")
    for _, d in ipairs(ENVS) do
      local on = s.envelopes and s.envelopes[d.key] or false
      local rvb, nv = ImGui.Checkbox(ctx, d.label, on)
      if rvb then
        s.envelopes = s.envelopes or {}
        s.envelopes[d.key] = nv or nil
        if not next(s.envelopes) then s.envelopes = nil end
        mark()
      end
    end
    ImGui.EndPopup(ctx)
  end

  -- 10 item name
  ImGui.TableNextColumn(ctx)
  cell_text(s, "item_name", "keep current")

  -- 11 normalize
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("norm", sum_norm(s.normalize)) then
    local en = s.normalize ~= nil
    local rvb, nv = ImGui.Checkbox(ctx, "Normalize items", en)
    if rvb then
      s.normalize = nv and { type = 0, target = -18.0, mode = "each" } or nil
      mark()
    end
    if s.normalize then
      local nz = s.normalize
      ImGui.SetNextItemWidth(ctx, 140)
      if ImGui.BeginCombo(ctx, "Type", norm_label(nz.type or 0)) then
        for _, t in ipairs(NORM_TYPES) do
          if ImGui.Selectable(ctx, t.label, nz.type == t.v) then nz.type = t.v; mark() end
        end
        ImGui.EndCombo(ctx)
      end
      ImGui.SetNextItemWidth(ctx, 140)
      local rvt, tv = ImGui.InputDouble(ctx, "Target (dB / LUFS)", nz.target or -18, 0.5, 1.0, "%.1f")
      if rvt then nz.target = tv; mark() end
      if ImGui.RadioButton(ctx, "Each item to the target", nz.mode ~= "together") then nz.mode = "each"; mark() end
      if ImGui.RadioButton(ctx, "All items together (common gain, keeps balance)", nz.mode == "together") then
        nz.mode = "together"; mark()
      end
      ImGui.TextDisabled(ctx, "Audio items only. Sets the take volume.")
    end
    ImGui.EndPopup(ctx)
  end

  -- 12 group
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("grp", sum_group(s.group)) then
    local g = s.group
    ImGui.SetNextItemWidth(ctx, 140)
    if ImGui.BeginCombo(ctx, "Group", g and ("Group " .. g.id) or "(ignore)", ImGui.ComboFlags_HeightLarge) then
      if ImGui.Selectable(ctx, "(ignore)", g == nil) then s.group = nil; mark() end
      for id = 1, MAX_GROUPS do
        if ImGui.Selectable(ctx, "Group " .. id, g and g.id == id) then
          if g then g.id = id else s.group = { id = id, flags = copy(DEFAULT_GROUP_FLAGS) } end
          mark()
        end
      end
      ImGui.EndCombo(ctx)
    end
    g = s.group
    if g then
      ImGui.SetNextItemWidth(ctx, 200)
      local rvn, nm = ImGui.InputTextWithHint(ctx, "Group name", "keep current", g.name or "")
      if rvn then g.name = nonempty(nm); mark() end
      ImGui.Separator(ctx)
      g.flags = g.flags or {}
      for _, row in ipairs(GROUP_FLAGS) do
        local r1, v1 = ImGui.Checkbox(ctx, row[2], g.flags[row[1]] or false)
        if r1 then g.flags[row[1]] = v1 or nil; mark() end
        ImGui.SameLine(ctx, 170)
        local r2, v2 = ImGui.Checkbox(ctx, row[4], g.flags[row[3]] or false)
        if r2 then g.flags[row[3]] = v2 or nil; mark() end
      end
      if not next(g.flags) then ImGui.TextColored(ctx, 0xFFB040FF, "No flag ticked: tracks will not join the group.") end
    end
    ImGui.EndPopup(ctx)
  end

  -- tools
  ImGui.TableNextColumn(ctx)
  if ImGui.ArrowButton(ctx, "up", ImGui.Dir_Up) and i > 1 then
    pending = function() move_strip(i, i - 1) end
  end
  ImGui.SameLine(ctx, 0, 2)
  if ImGui.ArrowButton(ctx, "dn", ImGui.Dir_Down) and i < #strips then
    pending = function() move_strip(i, i + 1) end
  end
  ImGui.SameLine(ctx, 0, 2)
  if ImGui.SmallButton(ctx, "Dup") then
    pending = function()
      local c = copy(s); c.name = (c.name or "") .. " copy"
      table.insert(strips, i + 1, c); mark()
    end
  end
  ImGui.SameLine(ctx, 0, 2)
  if ImGui.SmallButton(ctx, "Del") then open_delete, delete_idx = true, i end
end

local COLUMNS = {
  { "#", 24 }, { "Strip name *", 130 }, { "Track name", 110 }, { "Tag", 44 }, { "Colour", 52 },
  { "Icon", 130 }, { "Layout", 100 }, { "Record input", 150 }, { "Metering", 120 }, { "FX chain", 130 },
  { "Envelopes", 110 }, { "Item name", 110 }, { "Normalize", 130 }, { "Group", 130 }, { "", 100 },
}

local function draw_setup_tab()
  if ImGui.Button(ctx, "+ Add strip") then new_strip(); scroll_row = #strips; goto_setup = "scroll" end
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, "Only the strip name is required. An empty cell is ignored when the strip is applied.")

  local flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollX |
                ImGui.TableFlags_ScrollY | ImGui.TableFlags_Resizable | ImGui.TableFlags_SizingFixedFit
  local _, h = ImGui.GetContentRegionAvail(ctx)
  if status ~= "" then h = h - ImGui.GetFrameHeightWithSpacing(ctx) - 4 end
  if h < 80 then h = 80 end
  if ImGui.BeginTable(ctx, "setup", #COLUMNS, flags, 0, h) then
    ImGui.TableSetupScrollFreeze(ctx, 2, 1)
    for _, c in ipairs(COLUMNS) do ImGui.TableSetupColumn(ctx, c[1], ImGui.TableColumnFlags_WidthFixed, c[2]) end
    ImGui.TableHeadersRow(ctx)
    for i, s in ipairs(strips) do
      ImGui.PushID(ctx, i)
      draw_row(i, s)
      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end
end

--------------------------------------------------------------------------------
-- Modals
--------------------------------------------------------------------------------
local function draw_modals()
  if open_rename then ImGui.OpenPopup(ctx, "Rename strip"); open_rename = false end
  if ImGui.BeginPopupModal(ctx, "Rename strip", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
    ImGui.SetNextItemWidth(ctx, 250)
    local enter
    enter, rename_buf = ImGui.InputText(ctx, "##rename", rename_buf, ImGui.InputTextFlags_EnterReturnsTrue)
    if ImGui.Button(ctx, "OK", 80) then enter = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 80) then ImGui.CloseCurrentPopup(ctx) end
    if enter and nonempty(rename_buf) and strips[rename_idx] then
      strips[rename_idx].name = trim(rename_buf); mark()
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end

  if open_delete then ImGui.OpenPopup(ctx, "Delete strip"); open_delete = false end
  if ImGui.BeginPopupModal(ctx, "Delete strip", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    local s = strips[delete_idx]
    ImGui.Text(ctx, "Delete \"" .. ((s and s.name) or "") .. "\"?")
    if ImGui.Button(ctx, "Delete", 80) then
      if s then table.remove(strips, delete_idx); mark() end
      if scroll_row == delete_idx then scroll_row = nil end
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 80) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

--------------------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------------------
local _, _, SEC, CMD = reaper.get_action_context()
reaper.SetToggleCommandState(SEC, CMD, 1)
reaper.RefreshToolbar2(SEC, CMD)

reaper.atexit(function()
  if dirty then save_data(data) end
  reaper.SetToggleCommandState(SEC, CMD, 0)
  reaper.RefreshToolbar2(SEC, CMD)
end)

local function loop()
  ImGui.SetNextWindowSize(ctx, 900, 480, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, SCRIPT_TITLE .. " " .. VERSION, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Strips") then
        draw_strips_tab()
        ImGui.EndTabItem(ctx)
      end
      local sel_flag = (goto_setup == true) and ImGui.TabItemFlags_SetSelected or 0
      if goto_setup == true then goto_setup = "scroll" end
      if ImGui.BeginTabItem(ctx, "Setup", nil, sel_flag) then
        draw_setup_tab()
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    if pending then pending(); pending = nil end
    draw_modals()
    if status ~= "" then
      ImGui.Separator(ctx)
      ImGui.TextColored(ctx, status_col, status)
    end
    ImGui.End(ctx)
  end

  -- autosave (throttled)
  if dirty and reaper.time_precise() - last_save > 0.5 then
    save_data(data); dirty = false; last_save = reaper.time_precise()
  end

  if open then reaper.defer(loop) end
end

reaper.defer(loop)
