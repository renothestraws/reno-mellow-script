-- Reaback Set up
-- Window with shortcuts to configure a REAPER session and to build a session for backing tracks.
-- Independent from REABACK.lua. Requires ReaImGui. SWS / js_ReaScriptAPI are not needed.
--
-- Every button looks for its REAPER action BY NAME (English action list), then falls back to a known ID.
-- Hover a button to see which action it will run; the line at the bottom of the window shows what was run.
-- If a name does not match on your REAPER version, edit the matching entry in the ACTIONS table below.
-- Section "Export to B.Beat": see Reaback_BBeat_export.lua (same folder).
-- Button "10. Live preferences": see Reaback_LivePrefs.lua (same folder).

local TITLE = "Reaback Set up"

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script requires the ReaImGui extension.\n\n" ..
            "Install it via ReaPack (ReaTeam Extensions > ReaImGui), then restart REAPER.", TITLE, 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

-- Export to B.Beat (library next to this script)
local SCRIPT_DIR = ({ reaper.get_action_context() })[2]:match("^(.*[\\/])") or ""
local okBB, BBeat = pcall(dofile, SCRIPT_DIR .. "Reaback_BBeat_export.lua")
local bbeatErr = (not okBB) and tostring(BBeat) or nil
if not okBB then BBeat = nil end

-- Live preferences (library next to this script)
local okLP, LivePrefs = pcall(dofile, SCRIPT_DIR .. "Reaback_LivePrefs.lua")
local lpErr = (not okLP) and tostring(LivePrefs) or nil
if not okLP then LivePrefs = nil end

local ctx = ImGui.CreateContext(TITLE)
local font = ImGui.CreateFont('sans-serif', 14)
ImGui.Attach(ctx, font)

------------------------------------------------------------------------
-- Action lookup
------------------------------------------------------------------------
-- spec = {
--   names = { "exact action name", ... },       -- compared in lower case
--   pats  = { {"word","word"}, ... },            -- every word must appear in the action name
--   nots  = { "word", ... },                     -- words that must NOT appear (for pats)
--   ids   = { 40000, ... },                      -- last resort
--   page  = 0x099, pagename = "...",             -- Preferences page number (ViewPrefs), opened if no action was found
-- }
local ACTIONS = {
  audio       = { ids = { 40099 }, trust = true },
  -- Preferences pages are opened by their page number (ViewPrefs(page, ""))
  -- MIDI inputs and outputs are on the same REAPER page: "Audio > MIDI Devices"
  midi_in     = { page = 0x099, pagename = "Audio > MIDI Devices" },
  midi_out    = { page = 0x099, pagename = "Audio > MIDI Devices" },
  web         = { page = 0x09d, pagename = "Control, OSC, web" },
  project     = { names = { "file: project settings..." }, ids = { 40021 } },
  metronome   = { names = { "options: show metronome/pre-roll settings" }, ids = { 40363 } },
  routing     = { names = { "view: show routing matrix window" }, ids = { 40251 } },
  video       = { names = { "video: show/hide video window", "view: show video window" }, ids = { 50125 } },
  ext_sync    = { names = { "options: show external timecode synchronization settings" },
                  pats = { { "external", "timecode", "sync" }, { "synchronization", "timecode" } },
                  ids = { 40021 } },                       -- fallback: project settings

  template    = { ids = { 43719 }, trust = true },
  open_proj   = { names = { "file: open project..." }, ids = { 40025 } },
  save_as     = { names = { "file: save project as..." }, ids = { 40022 } },
  media_expl  = { names = { "media explorer: show/hide media explorer", "view: show/hide media explorer" }, ids = { 50124 } },
  normalize   = { ids = { 42460 }, trust = true },          -- native action 42460 (normalize)
  tempo_mark  = { names = { "markers: insert tempo/time signature change marker...", "insert tempo/time signature change marker..." },
                  pats = { { "insert", "tempo", "time signature", "marker" }, { "insert", "tempo", "marker" } } },
  ts_items    = { names = { "time selection: set time selection to items" }, ids = { 40290 } },
  item_notes  = { names = { "item: show notes for items..." }, ids = { 40850 } },
  midi_open_dock = { pats = { { "open", "midi editor", "dock" } } },
  midi_open   = { names = { "item: open in built-in midi editor (set default behavior in preferences)" }, ids = { 40153 } },
  src_props   = { names = { "item: show media item source properties", "item settings: source properties..." },
                  pats = { { "source properties" } }, nots = { "preserve" } },
  timecode    = { ids = { 40208 } },                         -- Insert SMPTE LTC/MTC timecode generator
  item_props  = { ids = { 40009 } },
  windowsets  = { pats = { { "screenset", "load/save" }, { "screenset", "manager" }, { "window set", "dialog" },
                           { "screenset", "show" }, { "window set" } } },
}

-- index of the actions of the main section (and of the MIDI editor section)
local index = { [0] = {}, [32060] = {} }
local function build_index(secId)
  local sec = reaper.SectionFromUniqueID(secId)
  local list = index[secId]
  if not sec then return end
  if reaper.kbd_enumerateActions then
    local i = 0
    while i < 200000 do
      local cmd, name = reaper.kbd_enumerateActions(sec, i)
      if not cmd or cmd == 0 then break end
      list[#list + 1] = { cmd = cmd, name = (name or ""):lower(), raw = name or "" }
      i = i + 1
    end
  elseif reaper.kbd_getTextFromCmd then
    for id = 1, 65535 do
      local name = reaper.kbd_getTextFromCmd(id, sec)
      if name and name ~= "" then list[#list + 1] = { cmd = id, name = name:lower(), raw = name } end
    end
  end
end
build_index(0)
build_index(32060)

local function cmd_name(cmd, secId)
  if reaper.kbd_getTextFromCmd then
    local n = reaper.kbd_getTextFromCmd(cmd, reaper.SectionFromUniqueID(secId or 0))
    if n and n ~= "" then return n end
  end
  return ""
end

-- returns cmd, displayed name  (or nil)
local function resolve(spec, secId)
  secId = secId or 0
  local list = index[secId]
  if spec.names then
    for _, n in ipairs(spec.names) do
      for _, a in ipairs(list) do if a.name == n then return a.cmd, a.raw end end
    end
  end
  if spec.pats then
    for _, words in ipairs(spec.pats) do
      for _, a in ipairs(list) do
        local ok = true
        for _, w in ipairs(words) do if not a.name:find(w, 1, true) then ok = false; break end end
        if ok and spec.nots then
          for _, w in ipairs(spec.nots) do if a.name:find(w, 1, true) then ok = false; break end end
        end
        if ok then return a.cmd, a.raw end
      end
    end
  end
  if spec.ids then
    for _, id in ipairs(spec.ids) do
      local n = cmd_name(id, secId)
      if spec.trust then return id, (n ~= "" and n or ("action " .. id)) end   -- ID given by the user: always run it
      if n ~= "" then return id, n end
    end
  end
  return nil
end

------------------------------------------------------------------------
-- Status line
------------------------------------------------------------------------
local status, statusErr = "Ready.", false
local function say(msg, isErr) status, statusErr = msg, isErr or false end

local function run_spec(spec, label)
  local cmd, name = resolve(spec)
  if cmd then
    reaper.Main_OnCommand(cmd, 0)
    say("Ran: " .. name)
    return true
  end
  if spec.page and reaper.ViewPrefs then
    reaper.ViewPrefs(spec.page, "")
    say("Opened Preferences: " .. (spec.pagename or tostring(spec.page)) .. ".")
    return true
  end
  say("Action not found for: " .. label .. " (edit the ACTIONS table at the top of the script).", true)
  return false
end

local function run_quiet(spec)          -- run an action without touching the status line; returns true if run
  local cmd = resolve(spec)
  if cmd then reaper.Main_OnCommand(cmd, 0); return true end
  return false
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function find_track(word)
  word = word:lower()
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if name:lower():find(word, 1, true) then return tr end
  end
end

local function time_selection()
  local s, e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  return s, e
end

local function select_only_item(item)
  reaper.Main_OnCommand(40289, 0)                       -- unselect all items
  reaper.SetMediaItemSelected(item, true)
  reaper.UpdateArrange()
end

------------------------------------------------------------------------
-- Session build: functions
------------------------------------------------------------------------
local function tempo_marker()
  if run_quiet(ACTIONS.tempo_mark) then
    local _, name = resolve(ACTIONS.tempo_mark)
    say("Ran: " .. name)
    return
  end
  -- fallback: tempo marker at the edit cursor, same tempo and time signature as at that position
  local pos = reaper.GetCursorPosition()
  local num, den, tempo = reaper.TimeMap_GetTimeSigAtTime(0, pos)
  reaper.Undo_BeginBlock()
  reaper.SetTempoTimeSigMarker(0, -1, pos, -1, -1, tempo, num, den, false)
  reaper.UpdateTimeline()
  reaper.Undo_EndBlock("Reaback: insert tempo marker", -1)
  say(string.format("Tempo marker inserted at the edit cursor (%.2f BPM). Double-click it on the ruler to edit.", tempo))
end

local function region_from_selection()
  local s, e = time_selection()
  if e - s <= 0 then say("No time selection.", true); return end
  reaper.Undo_BeginBlock()
  reaper.AddProjectMarker2(0, true, s, e, "", -1, 0)
  reaper.Undo_EndBlock("Reaback: region from time selection", -1)
  reaper.UpdateTimeline()
  say("Region created from the time selection.")
end

-- empty item over the time selection on the track whose name contains `word`, open its notes, shift the selection right
local function note_item(word)
  local s, e = time_selection()
  if e - s <= 0 then say("No time selection.", true); return end
  local tr = find_track(word)
  if not tr then say("No track with \"" .. word .. "\" in its name.", true); return end
  reaper.Undo_BeginBlock()
  local item = reaper.AddMediaItemToTrack(tr)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", s)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", e - s)
  select_only_item(item)
  reaper.GetSet_LoopTimeRange(true, false, e, e + (e - s), false)     -- selection shifted right by its own length
  reaper.Undo_EndBlock("Reaback: new " .. word .. " item", -1)
  local cmd, name = resolve(ACTIONS.item_notes)
  if cmd then reaper.Main_OnCommand(cmd, 0); say("Item created on '" .. word .. "'; notes opened (" .. name .. ").")
  else say("Item created, but the item-notes action was not found.", true) end
end

local function midi_item()
  local s, e = time_selection()
  if e - s <= 0 then say("No time selection.", true); return end
  local tr = reaper.GetSelectedTrack(0, 0)
  if not tr then say("No track selected.", true); return end
  reaper.Undo_BeginBlock()
  local item = reaper.CreateNewMIDIItemInProj(tr, s, e, false)
  reaper.Undo_EndBlock("Reaback: new MIDI item", -1)
  if not item then say("Could not create the MIDI item.", true); return end
  select_only_item(item)
  local docked = resolve(ACTIONS.midi_open_dock)
  if docked then
    reaper.Main_OnCommand(docked, 0)
  else
    run_quiet(ACTIONS.midi_open)
  end
  -- turn on "sync editor timeline to arrange view" in the MIDI editor if it is off
  local hwnd = reaper.MIDIEditor_GetActive()
  local msg = docked and "MIDI item created and opened in the docked MIDI editor." or
              "MIDI item created and opened (no 'docked MIDI editor' action found: dock the editor once, REAPER remembers it)."
  if hwnd then
    local cmd, name = resolve({ pats = { { "sync", "arrange" }, { "timeline", "arrange" } }, nots = { "scroll" } }, 32060)
    if cmd then
      if reaper.GetToggleCommandStateEx(32060, cmd) ~= 1 then reaper.MIDIEditor_OnCommand(hwnd, cmd) end
      msg = msg .. " Sync: " .. name .. "."
    else
      msg = msg .. " Sync action not found: enable it once in the MIDI editor."
    end
    say(msg)
  else
    say(msg .. " MIDI editor window not detected yet: sync not applied.", true)
  end
end

local function timecode_track()
  local tr = find_track("timecode")
  if not tr then say("No track with \"timecode\" in its name.", true); return end
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  reaper.SetOnlyTrackSelected(tr)
  for i = reaper.CountTrackMediaItems(tr) - 1, 0, -1 do
    reaper.DeleteTrackMediaItem(tr, reaper.GetTrackMediaItem(tr, i))
  end
  for k = 0, reaper.CountTrackEnvelopes(tr) - 1 do
    reaper.DeleteEnvelopePointRange(reaper.GetTrackEnvelope(tr, k), -math.huge, math.huge)
  end
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)

  local len = reaper.GetProjectLength(0)
  local cur = reaper.GetCursorPosition()
  local ts_s, ts_e = time_selection()
  if len > 0 then reaper.GetSet_LoopTimeRange(true, false, 0, len, false) end
  reaper.SetEditCurPos(0, false, false)
  local cmd = resolve(ACTIONS.timecode)
  if cmd then reaper.Main_OnCommand(cmd, 0) end
  local item
  local n = reaper.CountTrackMediaItems(tr)
  if n > 0 then
    item = reaper.GetTrackMediaItem(tr, n - 1)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", 0)
    if len > 0 then reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len) end
    select_only_item(item)
  end
  reaper.GetSet_LoopTimeRange(true, false, ts_s, ts_e, false)
  reaper.SetEditCurPos(cur, false, false)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)
  reaper.Undo_EndBlock("Reaback: insert timecode", -1)

  if not item then say("The timecode generator item was not created.", true); return end
  local pc, pname = resolve(ACTIONS.src_props)
  if pc then
    reaper.Main_OnCommand(pc, 0)
    say("Timecode inserted. Ran: " .. pname)
  else
    local ic = resolve(ACTIONS.item_props)
    if ic then reaper.Main_OnCommand(ic, 0) end
    say("Timecode inserted. 'Source properties' action not found: item properties opened instead (use Source properties there).", true)
  end
end

-- items that START inside the widest region containing the edit cursor
-- (a stem whose tail goes past the region end is included; no time selection needed)
local function lock_items(lock)
  local eps = 0.000001
  local c = reaper.GetCursorPosition()
  local rs, re
  for i = 0, reaper.CountProjectMarkers(0) - 1 do
    local _, isrgn, pos, rend = reaper.EnumProjectMarkers3(0, i)
    if isrgn and c >= pos - eps and c <= rend + eps then
      if not rs or (rend - pos) > (re - rs) then rs, re = pos, rend end
    end
  end
  if not rs then
    local s, e = time_selection()
    if e - s > 0 then rs, re = s, e end
  end
  if not rs then say("Place the edit cursor inside a region (or make a time selection).", true); return end
  local n = 0
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for t = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, t)
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local it = reaper.GetTrackMediaItem(tr, i)
      local p = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
      if p >= rs - eps and p < re - eps then
        local v = math.floor(reaper.GetMediaItemInfo_Value(it, "C_LOCK") + 0.5)
        if lock then
          if v % 2 == 0 then v = v + 1 end
        else
          if v % 2 == 1 then v = v - 1 end
        end
        reaper.SetMediaItemInfo_Value(it, "C_LOCK", v)
        n = n + 1
      end
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(lock and "Reaback: lock items in region" or "Reaback: unlock items in region", -1)
  reaper.UpdateArrange()
  if n == 0 then
    say("No item starts inside this region.", true)
  else
    say(string.format("%s %d item(s) of the region.", lock and "Locked" or "Unlocked", n))
  end
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
local function tip_for(spec, extra)
  local cmd, name = resolve(spec)
  local t = cmd and ("Action: " .. name .. "  (ID " .. tostring(cmd) .. ")")
                 or (spec.page and ("Preferences page: " .. (spec.pagename or spec.page)) or "Action not found in this REAPER")
  return extra and (extra .. "\n" .. t) or t
end

local function btn(label, tip, fn)
  local w = ImGui.GetContentRegionAvail(ctx)
  if ImGui.Button(ctx, label, w, 28) then fn() end
  if tip and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, tip) end
end

local function spec_btn(label, key)
  btn(label, tip_for(ACTIONS[key]), function() run_spec(ACTIONS[key], label) end)
end

local function draw()
  ImGui.SeparatorText(ctx, "Configuration")
  spec_btn("1. Audio device settings", "audio")
  spec_btn("2. MIDI devices - Inputs", "midi_in")
  spec_btn("3. MIDI devices - Outputs", "midi_out")
  spec_btn("4. Web control surface", "web")
  spec_btn("5. Project settings", "project")
  spec_btn("6. Metronome settings", "metronome")
  spec_btn("7. Routing matrix", "routing")
  spec_btn("8. Video window", "video")
  spec_btn("9. External synchronization settings", "ext_sync")
  btn("10. Live preferences (stage settings)",
      "Opens a window that applies the REAPER preferences needed on stage\n(startup project, ReaBack template, seeking, audio device, item buttons, video...).\nRequires SWS to write the preferences.",
      function()
        if LivePrefs then LivePrefs.toggle()
        else say("Reaback_LivePrefs.lua could not be loaded: " .. tostring(lpErr), true) end
      end)

  ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "Session Built")
  spec_btn("1. Project templates", "template")
  spec_btn("2. Open project", "open_proj")
  spec_btn("3. Save project as...", "save_as")
  spec_btn("4. Media explorer (open / close)", "media_expl")
  spec_btn("5. Normalize", "normalize")
  btn("6. Insert tempo change marker", "Tempo/time signature marker at the edit cursor", tempo_marker)
  spec_btn("7. Time selection to selected items", "ts_items")
  btn("8. Region from time selection", "Creates a region over the time selection", region_from_selection)
  btn("9. Lyrics item + notes, selection shifted", "Empty item on the track containing 'Lyrics', opens its notes, moves the time selection right", function() note_item("lyrics") end)
  btn("10. Chords item + notes, selection shifted", "Same on the track containing 'Chords'", function() note_item("chords") end)
  btn("11. Comment item + notes, selection shifted", "Same on the track containing 'Comment'", function() note_item("comment") end)
  btn("12. MIDI item + MIDI editor (docked, synced)", "Empty MIDI item over the time selection on the selected track", midi_item)
  btn("13. Timecode track: clear, insert, source props", "Track containing 'Timecode': cleared, no master send, timecode generator over the whole project", timecode_track)
  btn("14. Lock items of the region", "Items starting in the widest region under the edit cursor (or in the time selection)", function() lock_items(true) end)
  btn("15. Unlock items of the region", "Items starting in the widest region under the edit cursor (or in the time selection)", function() lock_items(false) end)
  spec_btn("16. Windows set (screenset) manager", "windowsets")

  ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "Export to B.Beat")
  if BBeat then
    local ok, err = pcall(BBeat.draw, ctx, ImGui, say)
    if not ok then say("Export to B.Beat: " .. tostring(err), true) end
  else
    ImGui.TextWrapped(ctx, "Reaback_BBeat_export.lua could not be loaded: " .. tostring(bbeatErr))
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  if statusErr then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6B5AFF) end
  ImGui.TextWrapped(ctx, status)
  if statusErr then ImGui.PopStyleColor(ctx) end
end

------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------
local function loop()
  ImGui.SetNextWindowSize(ctx, 560, 900, ImGui.Cond_FirstUseEver)
  ImGui.PushFont(ctx, font)
  local visible, open = ImGui.Begin(ctx, TITLE, true)
  if visible then
    draw()
    ImGui.End(ctx)
  end
  if LivePrefs and open then           -- second window, same context and font
    local ok, err = pcall(LivePrefs.draw_window, ctx, ImGui, say)
    if not ok then say("Live preferences: " .. tostring(err), true) end
  end
  ImGui.PopFont(ctx)
  if BBeat and open then                -- renders and dialogs run outside of the ImGui frame
    local ok, err = pcall(BBeat.run_pending, say)
    if not ok then say("Export to B.Beat: " .. tostring(err), true) end
  end
  if open then reaper.defer(loop) end
end

-- toolbar icon lit while the window is open
local _, _, tg_sec, tg_cmd = reaper.get_action_context()
local function set_toggle(v)
  if tg_cmd and tg_cmd > 0 then
    reaper.SetToggleCommandState(tg_sec, tg_cmd, v)
    reaper.RefreshToolbar2(tg_sec, tg_cmd)
  end
end
set_toggle(1)
reaper.atexit(function() set_toggle(0) end)

reaper.defer(loop)
