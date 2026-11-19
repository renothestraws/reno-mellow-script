-- @noindex
-- ReNo Mellow - Recording Buddy : shared engine.
-- The whole run state lives in a non-saved ExtState, so any of the scripts
-- (main window, Display, Start-Stop action) can drive the sequence: each one
-- calls RB.tick() on every defer cycle. Scripts run one after the other on the
-- same thread, so the state is always consistent.

RB = {}
RB.VERSION = "1.0"
RB.S  = "ReNoMellow_RecBuddy"     -- saved settings
RB.RT = "ReNoMellow_RecBuddy_RT"  -- run state (not saved)
RB.ROLES = { "main", "display", "headless" }

local r = reaper

---------------------------------------------------------------- native actions
local A = {
  PLAY        = 1007,   -- Transport: Play
  RECORD      = 1013,   -- Transport: Record
  STOP_SAVE   = 40667,  -- Transport: Stop (save all recorded media)
  PITCH       = 40671,  -- Transport: Toggle preserve pitch in audio items when changing master playrate
  REC_NORMAL  = 40252,  -- Options: Record mode: normal
  REC_TS      = 40076,  -- Options: Record mode: time selection auto punch
  REC_ITEM    = 40253,  -- Options: Record mode: item selection auto punch
  PREROLL_PLAY = 41818, -- Pre-roll: Toggle pre-roll on play
  PREROLL_REC  = 41819, -- Pre-roll: Toggle pre-roll on record
  COUNTIN      = 40363, -- Options: Toggle count-in before recording
}

---------------------------------------------------------------- serializer
local function ser(v)
  local t = type(v)
  if t == "number" then return string.format("%.17g", v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "table" then
    local parts, keys = {}, {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(p, q)
      if type(p) == type(q) then return p < q end
      return type(p) == "number" -- numbers first, then names (stable output)
    end)
    for _, k in ipairs(keys) do
      local x = v[k]
      local key
      if type(k) == "number" then key = "[" .. k .. "]" else key = "[" .. string.format("%q", tostring(k)) .. "]" end
      parts[#parts + 1] = key .. "=" .. ser(x)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "nil"
end

local function deser(s)
  if not s or s == "" then return nil end
  local f = load("return " .. s, "RecBuddy", "t", {})
  if not f then return nil end
  local ok, v = pcall(f)
  if ok then return v end
  return nil
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copy(v) end
  return c
end
RB.copy = copy

-- "90 %", "97.5 %"
function RB.fmt_rate(pc)
  pc = math.floor(pc * 10 + 0.5) / 10
  if pc == math.floor(pc) then return string.format("%d %%", math.floor(pc)) end
  return string.format("%.1f %%", pc)
end

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
RB.clamp = clamp

---------------------------------------------------------------- settings
function RB.get(key, default)
  local v = r.GetExtState(RB.S, key)
  if v == "" then return default end
  return tonumber(v) or v
end

function RB.set(key, v) r.SetExtState(RB.S, key, tostring(v), true) end

---------------------------------------------------------------- passes
-- pass modes: "listen" (plain playback), "play" (armed tracks silent under the
-- range), "rec" (time selection auto punch recording)
local function P(mode, rate, pause)
  return { on = true, pre = 2, unit = "bars", rate = rate, mode = mode, pause = pause }
end
RB.EXAMPLES = {
  { name = "Default", passes = { P("listen", 100, 3), P("play", 90, 3), P("play", 95, 3), P("rec", 100, 0) } },
  { name = "4 takes", passes = { P("rec", 100, 3), P("rec", 100, 3), P("rec", 100, 3), P("rec", 100, 0) } },
  { name = "Practice", passes = { P("listen", 90, 3), P("play", 90, 0), P("play", 90, 0), P("play", 95, 0),
    P("play", 95, 0), P("play", 100, 0), P("play", 100, 0) } },
}
RB.DEFAULT = RB.EXAMPLES[1].passes
RB.RATE_MIN, RB.RATE_MAX = 25, 200

local MODE_LABEL = { listen = "LISTEN", play = "PLAY", rec = "REC", shift = "MOVE ON" }
function RB.mode_label(m) return MODE_LABEL[m] or "PLAY" end
RB.SHIFT_MIN_PAUSE = 0.5

-- text of a pass for the gauge / Display: "Pass 2 / 4   90 %   PLAY"
function RB.pass_label(i, n, mode, rate, sep)
  sep = sep or "   "
  local s = string.format("Pass %d / %d", i, n)
  if mode == "shift" then return s .. sep .. "MOVE ON" end
  return s .. sep .. RB.fmt_rate(rate) .. sep .. RB.mode_label(mode)
end

local function clean_pass(p)
  p = type(p) == "table" and p or {}
  local q = {}
  q.on = p.on ~= false
  q.unit = (p.unit == "ms") and "ms" or "bars"
  q.pre = math.floor(clamp(tonumber(p.pre) or 0, 0, q.unit == "ms" and 60000 or 64) * 100 + 0.5) / 100
  q.rate = math.floor(clamp(tonumber(p.rate) or 100, RB.RATE_MIN, RB.RATE_MAX) * 10 + 0.5) / 10
  local m = p.mode
  q.mode = (m == "rec" or m == "listen" or m == "shift") and m or "play"
  q.pause = clamp(tonumber(p.pause) or 0, 0, 600)
  if q.mode == "shift" and q.pause < RB.SHIFT_MIN_PAUSE then q.pause = RB.SHIFT_MIN_PAUSE end
  -- own loop of the pass, in quarter notes (follows tempo changes); none = "def"
  local ls, le = tonumber(p.ls), tonumber(p.le)
  if q.mode ~= "shift" and ls and le and le > ls + 0.001 and ls >= 0 then
    q.ls = math.floor(ls * 1e6 + 0.5) / 1e6
    q.le = math.floor(le * 1e6 + 0.5) / 1e6
  end
  return q
end
RB.clean_pass = clean_pass

function RB.load_passes()
  local v = deser(r.GetExtState(RB.S, "passes"))
  if type(v) ~= "table" or #v == 0 then return copy(RB.DEFAULT) end
  local out = {}
  for i = 1, #v do out[i] = clean_pass(v[i]) end
  return out
end

function RB.save_passes(p) r.SetExtState(RB.S, "passes", ser(p), true) end

RB.ser = ser

---------------------------------------------------------------- saved sequences
-- list of { name = "...", passes = { ... } }. Returns the list and true when it
-- was just created with the examples (first launch).
function RB.load_sequences()
  local v = deser(r.GetExtState(RB.S, "sequences"))
  local fresh = false
  if type(v) ~= "table" then v = copy(RB.EXAMPLES) fresh = true end
  local out = {}
  for _, s in ipairs(v) do
    if type(s) == "table" and type(s.name) == "string" and type(s.passes) == "table" and #s.passes > 0 then
      local ps = {}
      for i = 1, #s.passes do ps[i] = clean_pass(s.passes[i]) end
      out[#out + 1] = { name = s.name, passes = ps }
    end
  end
  if fresh then RB.save_sequences(out) end
  return out, fresh
end

function RB.save_sequences(list) r.SetExtState(RB.S, "sequences", ser(list), true) end

function RB.find_sequence(list, name)
  for i, s in ipairs(list) do if s.name == name then return i end end
  return nil
end

-- puts the example sequences back (same names are replaced)
function RB.restore_examples(list)
  for _, e in ipairs(RB.EXAMPLES) do
    local i = RB.find_sequence(list, e.name)
    if i then list[i] = copy(e) else list[#list + 1] = copy(e) end
  end
  RB.save_sequences(list)
end

---------------------------------------------------------------- run state
function RB.state()
  local v = deser(r.GetExtState(RB.RT, "state"))
  if type(v) ~= "table" then return { run = false } end
  return v
end

local function save_state(st) r.SetExtState(RB.RT, "state", ser(st), false) end

function RB.message(txt, is_err)
  r.SetExtState(RB.RT, "msg", txt or "", false)
  r.SetExtState(RB.RT, "msg_err", is_err and "1" or "0", false)
  r.SetExtState(RB.RT, "msg_t", tostring(r.time_precise()), false)
end

-- recent message (shown for a few seconds), or nil
function RB.recent_message(max_age)
  local t = tonumber(r.GetExtState(RB.RT, "msg_t"))
  if not t or r.time_precise() - t > (max_age or 6) then return nil end
  local m = r.GetExtState(RB.RT, "msg")
  if m == "" then return nil end
  return m, r.GetExtState(RB.RT, "msg_err") == "1"
end

---------------------------------------------------------------- helpers
-- loop range: time selection first, then loop points
function RB.get_range()
  local t0, t1 = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if t1 - t0 > 0.001 then return t0, t1, "time selection" end
  local l0, l1 = r.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)
  if l1 - l0 > 0.001 then return l0, l1, "loop" end
  return nil
end

-- start position of the pre-roll of pass p before r0 (project time)
function RB.preroll_start(p, r0)
  local v = tonumber(p.pre) or 0
  if v <= 0 then return r0 end
  local t
  if p.unit == "ms" then
    t = r0 - v / 1000
  else
    -- whole bars back from r0, then the fraction of the bar before them
    local beats, measures = r.TimeMap2_timeToBeats(0, r0)
    local n = math.floor(v)
    local frac = v - n
    t = r.TimeMap2_beatsToTime(0, beats, measures - n)
    if frac > 0.0001 then
      local t2 = r.TimeMap2_beatsToTime(0, beats, measures - n - 1)
      t = t - frac * (t - t2)
    end
  end
  if t < 0 then t = 0 end
  return t
end

-- pre-roll length (unit of the pass) from time `cur` to the range start r0
function RB.preroll_from(cur, r0, unit)
  if cur >= r0 - 0.0005 then return nil end
  local v
  if unit == "ms" then
    v = (r0 - cur) * 1000
  else
    local function mpos(t)
      local b, m, cml = r.TimeMap2_timeToBeats(0, t)
      return m + b / ((cml and cml > 0) and cml or 4)
    end
    v = mpos(r0) - mpos(cur)
  end
  return math.floor(v * 100 + 0.5) / 100
end

-- range of every pass before running, from the arrangement range (b0, b1):
-- "def" passes use the arrangement range, moved forward by each active Move on;
-- passes with their own loop use it. Returns { {r0, r1, custom = bool}, ... }
-- (r0 = nil for a "def" pass when there is no arrangement range).
function RB.plan(passes, b0, b1)
  local out = {}
  for i, p in ipairs(passes) do
    if p.mode == "shift" then
      if p.on and b0 then b0, b1 = b1, b1 + (b1 - b0) end
      out[i] = { b0, b1, shift = true }
    elseif p.ls and p.le then
      out[i] = { r.TimeMap2_QNToTime(0, p.ls), r.TimeMap2_QNToTime(0, p.le), custom = true }
    else
      out[i] = { b0, b1 }
    end
  end
  return out
end

-- approximate real duration of one pass (seconds)
function RB.pass_duration(p, r0, r1)
  if p.mode == "shift" then return p.pause or 0 end
  local pre = RB.preroll_start(p, r0)
  return (r1 - pre) / (p.rate / 100) + (p.pause or 0)
end

local function cmd_name(id)
  if r.kbd_getTextFromCmd and r.SectionFromUniqueID then
    local ok, s = pcall(r.kbd_getTextFromCmd, id, r.SectionFromUniqueID(0))
    if ok and s then return s:lower() end
  end
  if r.CF_GetCommandText then
    local ok, s = pcall(r.CF_GetCommandText, 0, id)
    if ok and s then return s:lower() end
  end
  return nil
end

-- toggle state of a native action whose name must contain `pattern`
-- (protects against an ID that would mean something else in this REAPER version)
local function tog_state(id, pattern)
  if pattern then
    local n = cmd_name(id)
    if n and not n:find(pattern, 1, true) then return -1 end
  end
  return r.GetToggleCommandState(id)
end

local function set_tog(id, on, pattern)
  local s = tog_state(id, pattern)
  if s == -1 then return false end
  if (s == 1) ~= on then r.Main_OnCommand(id, 0) end
  return true
end

local function armed_tracks()
  local n = 0
  for i = 0, r.CountTracks(0) - 1 do
    if r.GetMediaTrackInfo_Value(r.GetTrack(0, i), "I_RECARM") == 1 then n = n + 1 end
  end
  return n
end

local function fmt_time(t)
  return r.format_timestr_pos(t, "", -1)
end
RB.fmt_time = fmt_time

---------------------------------------------------------------- silence the armed tracks (play passes)
-- During a play pass, what the armed tracks hold under the range must be silent,
-- while the pre-roll stays audible and the input monitoring is untouched.
-- REAPER reads the media ahead (Preferences > Buffering, 1200 ms by default), so
-- nothing may change once playback runs: everything is prepared before Play.
--  * items that start inside the range: item mute;
--  * items that start before the range (heard in the pre-roll): the item is saved
--    (state chunk), split at the range start and its right part is muted.
-- After the pass, the split parts are removed and the saved item is put back as
-- it was (same GUID, takes, fades...), and only the items muted here are unmuted.
local function item_guid(it)
  local _, g = r.GetSetMediaItemInfo_String(it, "GUID", "", false)
  return g
end

local function item_by_guid(g)
  for k = 0, r.CountMediaItems(0) - 1 do
    local it = r.GetMediaItem(0, k)
    if item_guid(it) == g then return it end
  end
  return nil
end

local function silence_armed(st)
  st.muted, st.splits = {}, {}
  local list = {}
  for t = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, t)
    if r.GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then
      for k = 0, r.CountTrackMediaItems(tr) - 1 do
        local it = r.GetTrackMediaItem(tr, k)
        local p0 = r.GetMediaItemInfo_Value(it, "D_POSITION")
        local p1 = p0 + r.GetMediaItemInfo_Value(it, "D_LENGTH")
        if p0 < st.r1 - 0.0005 and p1 > st.r0 + 0.0005 and r.GetMediaItemInfo_Value(it, "B_MUTE") == 0 then
          list[#list + 1] = { it = it, tr = tr, p0 = p0 }
        end
      end
    end
  end
  if #list == 0 then return end
  r.PreventUIRefresh(1)
  for _, e in ipairs(list) do
    if e.p0 >= st.r0 - 0.0005 or (st.pre or st.r0) >= st.r0 - 0.0005 then
      -- inside the range (or no pre-roll at all): mute the whole item
      r.SetMediaItemInfo_Value(e.it, "B_MUTE", 1)
      st.muted[#st.muted + 1] = item_guid(e.it)
    else
      local ok, chunk = r.GetItemStateChunk(e.it, "", false)
      local right = ok and r.SplitMediaItem(e.it, st.r0) or nil
      if right then
        r.SetMediaItemInfo_Value(right, "B_MUTE", 1)
        local _, tg = r.GetSetMediaTrackInfo_String(e.tr, "GUID", "", false)
        st.splits[#st.splits + 1] = { track = tg, chunk = chunk, left = item_guid(e.it), right = item_guid(right) }
      end
    end
  end
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
end

local function unmute_all(st)
  local any = (st.muted and #st.muted > 0) or (st.splits and #st.splits > 0)
  if not any then st.muted, st.splits = nil, nil return end
  r.PreventUIRefresh(1)
  for _, s in ipairs(st.splits or {}) do
    local tr
    for t = 0, r.CountTracks(0) - 1 do
      local x = r.GetTrack(0, t)
      local _, g = r.GetSetMediaTrackInfo_String(x, "GUID", "", false)
      if g == s.track then tr = x break end
    end
    if tr then
      for _, g in ipairs({ s.left, s.right }) do
        local it = item_by_guid(g)
        if it then r.DeleteTrackMediaItem(r.GetMediaItem_Track(it), it) end
      end
      local it = r.AddMediaItemToTrack(tr)
      r.SetItemStateChunk(it, s.chunk, false)
    end
  end
  if st.muted and #st.muted > 0 then
    local want = {}
    for _, g in ipairs(st.muted) do want[g] = true end
    for k = 0, r.CountMediaItems(0) - 1 do
      local it = r.GetMediaItem(0, k)
      if want[item_guid(it)] then r.SetMediaItemInfo_Value(it, "B_MUTE", 0) end
    end
  end
  st.muted, st.splits = nil, nil
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
end

---------------------------------------------------------------- sequence
local function start_pass(st, i, now)
  local p = st.seq[i]
  st.i = i
  if p.mode == "shift" then
    -- stop, move the range one range length to the right, then wait the pause
    if r.GetPlayState() ~= 0 then r.Main_OnCommand(A.STOP_SAVE, 0) end
    -- the arrangement range (b0, b1) moves, whatever the previous pass played
    local len = st.b1 - st.b0
    st.b0, st.b1 = st.b1, st.b1 + len
    st.r0, st.r1 = st.b0, st.b1
    r.GetSet_LoopTimeRange2(0, true, false, st.r0, st.r1, false)
    if st.src == "loop" then r.GetSet_LoopTimeRange2(0, true, true, st.r0, st.r1, false) end
    r.SetEditCurPos2(0, st.r0, true, false)
    st.pre = st.r0
    st.shifted = true
    st.phase = "pause"
    st.t = now
    return
  end
  -- range of this pass: its own loop, or the arrangement range ("def")
  if p.ls and p.le then
    st.r0, st.r1 = r.TimeMap2_QNToTime(0, p.ls), r.TimeMap2_QNToTime(0, p.le)
  else
    st.r0, st.r1 = st.b0, st.b1
  end
  r.GetSet_LoopTimeRange2(0, true, false, st.r0, st.r1, false) -- auto punch uses the time selection
  if st.src == "loop" then r.GetSet_LoopTimeRange2(0, true, true, st.r0, st.r1, false) end
  r.CSurf_OnPlayRateChange(p.rate / 100)
  local pre = RB.preroll_start(p, st.r0)
  st.pre = pre
  r.SetEditCurPos2(0, pre, false, false)
  if p.mode == "rec" then
    if armed_tracks() == 0 then RB.message("No track is armed: nothing will be recorded.", true) end
    r.Main_OnCommand(A.RECORD, 0)
  else
    if p.mode == "play" then silence_armed(st) end -- before Play: REAPER reads the media ahead
    r.Main_OnCommand(A.PLAY, 0)
  end
  st.phase = "play"
  st.t = now
  st.seen = false
end

local function restore(old)
  if not old then return end
  r.CSurf_OnPlayRateChange(old.rate or 1)
  r.GetSetRepeat(old.rep or 0)
  if old.recmode then r.Main_OnCommand(old.recmode, 0) end
  if old.pitch ~= nil then set_tog(A.PITCH, old.pitch, "pitch") end
  if old.preplay ~= nil then set_tog(A.PREROLL_PLAY, old.preplay, "roll") end
  if old.prerec ~= nil then set_tog(A.PREROLL_REC, old.prerec, "roll") end
  if old.countin ~= nil then set_tog(A.COUNTIN, old.countin, "count-in") end
  if old.ts0 then r.GetSet_LoopTimeRange2(0, true, false, old.ts0, old.ts1, false) end
  if old.l0 then r.GetSet_LoopTimeRange2(0, true, true, old.l0, old.l1, false) end
  if old.cur then r.SetEditCurPos2(0, old.cur, false, false) end
end

function RB.finish(st, msg, is_err)
  if r.GetPlayState() ~= 0 then r.Main_OnCommand(A.STOP_SAVE, 0) end
  if st then unmute_all(st) end
  restore(st and st.old)
  if st and st.shifted then
    -- the range was moved forward: leave it (and the cursor) at its new place
    r.GetSet_LoopTimeRange2(0, true, false, st.b0, st.b1, false)
    if st.src == "loop" then r.GetSet_LoopTimeRange2(0, true, true, st.b0, st.b1, false) end
    r.SetEditCurPos2(0, st.b0, true, false)
  end
  save_state({ run = false })
  if msg then RB.message(msg, is_err) end
end

-- returns true, or false + message
function RB.start()
  local st = RB.state()
  if st.run then return true end
  local r0, r1, src = RB.get_range()
  local seq = {}
  for _, p in ipairs(RB.load_passes()) do if p.on then seq[#seq + 1] = p end end
  if #seq == 0 then
    local m = "No active pass: tick at least one pass in Set up."
    RB.message(m, true)
    return false, m
  end
  -- the arrangement range is needed unless every pass has its own loop
  local need_def = false
  for _, p in ipairs(seq) do if not (p.ls and p.le) then need_def = true end end
  if not r0 and need_def then
    local m = "Set a time selection or a loop first."
    RB.message(m, true)
    return false, m
  end

  if r.GetPlayState() ~= 0 then r.Main_OnCommand(A.STOP_SAVE, 0) end

  -- remember what is changed, to put it back at the end
  local old = { rate = r.Master_GetPlayRate(0), rep = r.GetSetRepeat(-1), cur = r.GetCursorPosition() }
  for _, id in ipairs({ A.REC_TS, A.REC_ITEM, A.REC_NORMAL }) do
    if r.GetToggleCommandState(id) == 1 then old.recmode = id break end
  end
  local s
  s = tog_state(A.PITCH, "pitch");          if s ~= -1 then old.pitch = (s == 1) end
  s = tog_state(A.PREROLL_PLAY, "roll");    if s ~= -1 then old.preplay = (s == 1) end
  s = tog_state(A.PREROLL_REC, "roll");     if s ~= -1 then old.prerec = (s == 1) end
  s = tog_state(A.COUNTIN, "count-in");     if s ~= -1 then old.countin = (s == 1) end
  old.ts0, old.ts1 = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  old.l0, old.l1 = r.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)

  -- run settings
  r.GetSetRepeat(0)                                       -- the script stops at the end itself
  r.Main_OnCommand(A.REC_TS, 0)                           -- time selection auto punch
  if not set_tog(A.PITCH, true, "pitch") then
    RB.message("Could not switch on 'preserve pitch' (action 40671).", true)
  end
  set_tog(A.PREROLL_PLAY, false, "roll")                  -- the pre-roll is done by the script
  set_tog(A.PREROLL_REC, false, "roll")
  set_tog(A.COUNTIN, false, "count-in")

  RB.message("Started: " .. #seq .. " pass" .. (#seq > 1 and "es" or "") .. ".", false)
  st = { run = true, seq = seq, n = #seq, r0 = r0, r1 = r1, src = src, old = old, b0 = r0, b1 = r1 }
  start_pass(st, 1, r.time_precise())
  save_state(st)
  return true
end

-- forced stop: always stops the transport (saving the recorded media)
function RB.force_stop()
  local st = RB.state()
  if st.run then
    RB.finish(st, "Stopped.", false)
  else
    r.Main_OnCommand(A.STOP_SAVE, 0)
  end
end

local function next_pass(st, now)
  if st.i < st.n then
    start_pass(st, st.i + 1, now)
    save_state(st)
  else
    RB.finish(st, "Done: " .. st.n .. " pass" .. (st.n > 1 and "es" or "") .. " played.", false)
  end
end

-- called by every running script on each defer cycle
function RB.tick(role)
  local now = r.time_precise()
  r.SetExtState(RB.RT, "alive_" .. role, tostring(now), false)
  local st = RB.state()
  if not st.run then return st end

  if st.phase == "play" then
    local ps = r.GetPlayState()
    local age = now - (st.t or now)
    if ps == 0 then
      if age > 0.5 then
        RB.finish(st, "Stopped from the REAPER transport.", false)
        return RB.state()
      end
      return st
    end
    local pos = r.GetPlayPosition()
    -- ignore a stale position just after the start
    if not st.seen and pos < st.r1 - 0.05 and pos >= (st.pre or 0) - 0.05 then
      st.seen = true
      save_state(st)
    end
    if st.seen and pos >= st.r1 - 0.005 then
      r.Main_OnCommand(A.STOP_SAVE, 0)
      unmute_all(st)
      local p = st.seq[st.i]
      if st.i < st.n and (p.pause or 0) > 0 then
        st.phase = "pause"
        st.t = now
        save_state(st)
      else
        next_pass(st, now)
      end
      return RB.state()
    end
  elseif st.phase == "pause" then
    local p = st.seq[st.i]
    if now - (st.t or now) >= (p.pause or 0) then
      next_pass(st, now)
      return RB.state()
    end
  end
  return st
end

---------------------------------------------------------------- script presence
function RB.others_alive(role)
  local now = r.time_precise()
  for _, x in ipairs(RB.ROLES) do
    if x ~= role then
      local t = tonumber(r.GetExtState(RB.RT, "alive_" .. x))
      if t and now - t < 1.0 then return true end
    end
  end
  return false
end

function RB.alive(role)
  local t = tonumber(r.GetExtState(RB.RT, "alive_" .. role))
  return t and r.time_precise() - t < 1.0 or false
end

-- a script leaves: if nobody else can drive the run, it is stopped
function RB.leave(role)
  r.DeleteExtState(RB.RT, "alive_" .. role, false)
  local st = RB.state()
  if st.run and not RB.others_alive(role) then
    RB.finish(st, "Stopped: no Recording Buddy window left open.", false)
  end
end

---------------------------------------------------------------- view (what the UI shows)
-- kind: "idle" | "play" | "rec" | "pause" (between passes) | "tpause" (transport paused)
function RB.view(st)
  st = st or RB.state()
  local v = { run = st.run, rate = r.Master_GetPlayRate(0), prog = 0, preroll = false }
  local ps = r.GetPlayState()
  if ps & 4 == 4 then v.kind = "rec"
  elseif ps & 2 == 2 then v.kind = "tpause"
  elseif ps & 1 == 1 then v.kind = "play"
  else v.kind = "idle" end

  if st.run then
    local p = st.seq[st.i]
    v.i, v.n, v.mode, v.prate = st.i, st.n, p.mode, p.rate
    v.r0, v.r1 = st.r0, st.r1
    if st.phase == "pause" then
      v.kind = "pause"
      v.prog = 1
      v.remain = math.max(0, (p.pause or 0) - (r.time_precise() - (st.t or 0)))
      v.phase = string.format((p.mode == "shift") and "Moved on, pause %.1f s" or "Pause %.1f s", v.remain)
    else
      local pos = r.GetPlayPosition()
      if pos < st.r0 then
        v.preroll = true
        local len = st.r0 - (st.pre or st.r0)
        v.preprog = len > 0 and clamp((pos - st.pre) / len, 0, 1) or 1
        v.phase = "Pre-roll"
      else
        v.prog = clamp((pos - st.r0) / (st.r1 - st.r0), 0, 1)
        v.phase = (p.mode == "rec") and "Recording" or ((p.mode == "listen") and "Listening" or "Playing")
      end
    end
  else
    local r0, r1, src = RB.get_range()
    v.r0, v.r1, v.src = r0, r1, src
    if r0 and v.kind ~= "idle" then
      local pos = r.GetPlayPosition()
      v.prog = clamp((pos - r0) / (r1 - r0), 0, 1)
    end
    v.phase = r0 and "Ready" or "No time selection / loop"
  end
  return v
end

---------------------------------------------------------------- opening the main window
-- tab: 1 = Rec Buddy, 2 = Set up
function RB.open_main(dir, tab)
  r.SetExtState(RB.RT, "want_tab", tostring(tab or 1), false)
  if RB.alive("main") then return end
  local path = dir .. "ReNo Mellow - Recording Buddy.lua"
  local cmd = 0
  local id = r.GetExtState(RB.S, "cmd_main")
  if id ~= "" then cmd = tonumber(id) or r.NamedCommandLookup(id) or 0 end
  if cmd == 0 and r.file_exists(path) then
    cmd = r.AddRemoveReaScript(true, 0, path, true) or 0
  end
  if cmd > 0 then r.Main_OnCommand(cmd, 0)
  else r.MB("Could not find the Recording Buddy main script.", "Recording Buddy", 0) end
end

-- the running script stores its own command ID (main section)
function RB.register_self(key)
  local _, _, sec, cmd = r.get_action_context()
  if sec == 0 and cmd and cmd > 0 then
    local n = r.ReverseNamedCommandLookup(cmd)
    local id = (n and n ~= "") and ("_" .. n) or tostring(cmd)
    if r.GetExtState(RB.S, key) ~= id then r.SetExtState(RB.S, key, id, true) end
  end
end

return RB
