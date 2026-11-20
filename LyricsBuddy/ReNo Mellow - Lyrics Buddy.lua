-- @description Lyrics Buddy (transcribe vocal items into lyrics items with whisper.cpp)
-- @author ReNo Mellow
-- @version 1.0
-- @about Transcrit les items audio sélectionnés (voix chantée ou parlée) avec whisper.cpp, en local, et crée sur une piste « Lyrics » un item vide par phrase avec le texte en note, calé sur le moment où elle est dite. Windows et macOS. Nécessite ReaImGui et whisper.cpp (sans Python).
-- @changelog Première version

local r = reaper
local VERSION = "1.0"
local S = "ReNoMellow_LyricsBuddy"
local TITLE = "ReNo Mellow - Lyrics Buddy"

if not r.ImGui_GetBuiltinPath then
  r.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.", "Lyrics Buddy", 0)
  return
end
package.path = r.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

-- toolbar toggle on while open, launching it again closes the window
if r.set_action_options then r.set_action_options(1 | 4) end
local _, _, self_sec, self_cmd = r.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    r.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    r.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)

---------------------------------------------------------------- system / paths
local OS = r.GetOS()
local WIN = OS:find("Win") ~= nil
local MAC = OS:find("OSX") ~= nil or OS:find("mac") ~= nil
local SEP = WIN and "\\" or "/"
local RES = r.GetResourcePath()
local DATA = RES .. SEP .. "Data" .. SEP .. "ReNo_LyricsBuddy"
local TMP = DATA .. SEP .. "tmp"
local MODELS = DATA .. SEP .. "models"
local WHISPER_DIR = DATA .. SEP .. "whisper"
local LOG = DATA .. SEP .. "LyricsBuddy.log"
r.RecursiveCreateDirectory(TMP, 0)
r.RecursiveCreateDirectory(MODELS, 0)
if WIN then r.RecursiveCreateDirectory(WHISPER_DIR, 0) end

local function file_exists(p) return p and p ~= "" and r.file_exists(p) end
local function basename(p) return (p:match("[^/\\]+$") or p) end
local function read_file(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local s = f:read("a"); f:close(); return s
end
local function write_file(p, s)
  local f = io.open(p, "wb"); if not f then return false end
  f:write(s); f:close(); return true
end
local function append_log(s)
  local f = io.open(LOG, "ab"); if not f then return end
  f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. s .. "\n"); f:close()
end

local function open_path(p)
  if r.CF_ShellExecute then r.CF_ShellExecute(p)
  elseif WIN then r.ExecProcess('cmd.exe /C start "" "' .. p .. '"', -1)
  else r.ExecProcess('/usr/bin/open "' .. p .. '"', -1) end
end

---------------------------------------------------------------- settings
local function opt(k, d)
  local v = r.GetExtState(S, k)
  if v == "" then return d end
  if type(d) == "number" then return tonumber(v) or d end
  if type(d) == "boolean" then return v == "1" end
  return v
end
local function set(k, v)
  if type(v) == "boolean" then v = v and "1" or "0" end
  r.SetExtState(S, k, tostring(v), true)
end

local cfg = {
  whisper  = opt("whisper", ""),
  model    = opt("model", ""),
  lang     = opt("lang", "auto"),
  threads  = opt("threads", 4),
  gpu      = opt("gpu", true),
  maxlen   = opt("maxlen", 0),
  prompt   = opt("prompt", ""),
  track    = opt("track", "Lyrics"),
  replace  = opt("replace", true),
  skip_ns  = opt("skip_ns", true),
  trim     = opt("trim", true),
  trim_db  = opt("trim_db", -40),
  font     = opt("font", 14),
}
local function save(k, v) cfg[k] = v; set(k, v) end

local LANGS = {
  { "auto", "Auto detect" }, { "en", "English" }, { "fr", "French" }, { "nl", "Dutch" },
  { "de", "German" }, { "es", "Spanish" }, { "it", "Italian" }, { "pt", "Portuguese" },
}
local function lang_label(code)
  for _, l in ipairs(LANGS) do if l[1] == code then return l[2] end end
  return code
end

local MODEL_LIST = {
  { "ggml-base.bin",           "142 MB", "fast, rough" },
  { "ggml-small.bin",          "466 MB", "good" },
  { "ggml-medium.bin",         "1.5 GB", "very good" },
  { "ggml-large-v3-turbo.bin", "1.6 GB", "best quality / speed (recommended)" },
  { "ggml-medium.en.bin",      "1.5 GB", "English only" },
}
local HF = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
local RELEASES = "https://github.com/ggml-org/whisper.cpp/releases"

---------------------------------------------------------------- whisper detection
local function whisper_candidates()
  local c = {}
  if WIN then
    for _, n in ipairs({ "whisper-cli.exe", "main.exe" }) do
      c[#c + 1] = WHISPER_DIR .. "\\" .. n
      c[#c + 1] = WHISPER_DIR .. "\\Release\\" .. n
    end
    -- one level of sub-folder (zip unpacked in its own folder)
    local i = 0
    while true do
      local sub = r.EnumerateSubdirectories(WHISPER_DIR, i)
      if not sub then break end
      c[#c + 1] = WHISPER_DIR .. "\\" .. sub .. "\\whisper-cli.exe"
      c[#c + 1] = WHISPER_DIR .. "\\" .. sub .. "\\Release\\whisper-cli.exe"
      i = i + 1
    end
    c[#c + 1] = "C:\\whisper.cpp\\whisper-cli.exe"
    c[#c + 1] = "C:\\whisper.cpp\\Release\\whisper-cli.exe"
  else
    for _, d in ipairs({ "/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/" }) do
      c[#c + 1] = d .. "whisper-cli"
      c[#c + 1] = d .. "whisper-cpp"
    end
  end
  return c
end

local function detect_whisper()
  for _, p in ipairs(whisper_candidates()) do
    if file_exists(p) then return p end
  end
  return nil
end

local function list_models()
  local out, i = {}, 0
  while true do
    local f = r.EnumerateFiles(MODELS, i)
    if not f then break end
    if f:match("%.bin$") and not f:match("encoder") then out[#out + 1] = MODELS .. SEP .. f end
    i = i + 1
  end
  table.sort(out)
  return out
end

-- first launch: fill what can be found
if cfg.whisper == "" or not file_exists(cfg.whisper) then
  local w = detect_whisper(); if w then save("whisper", w) end
end
if cfg.model == "" or not file_exists(cfg.model) then
  local m = list_models()
  for _, p in ipairs(m) do if p:find("turbo") then save("model", p) break end end
  if (cfg.model == "" or not file_exists(cfg.model)) and m[1] then save("model", m[1]) end
end

local test_msg, test_ok = nil, nil
local function test_whisper()
  if not file_exists(cfg.whisper) then test_ok = false; test_msg = "whisper.cpp not found." return end
  local out = r.ExecProcess('"' .. cfg.whisper .. '" --help', 8000) or ""
  if out:lower():find("usage") or out:find("%-%-model") then
    test_ok = true; test_msg = "whisper.cpp answers. Ready."
  else
    test_ok = false; test_msg = "whisper.cpp did not answer (see log)."
    append_log("Test failed:\n" .. out)
  end
end

---------------------------------------------------------------- jobs
local SR = 16000
local BLOCK = 4096
local fmt_cache = {}
local function fmt_for(n)
  local f = fmt_cache[n]
  if not f then f = "<" .. string.rep("i2", n); fmt_cache[n] = f end
  return f
end

local queue, cur = {}, nil     -- cur = job in progress
local status, status_col, status_log = "", nil, false
local done_items, total_jobs = 0, 0
local run_id = 0
local running = false

local COL_OK, COL_ERR, COL_INFO = 0x7CF0A6FF, 0xE05555FF, 0xC8C8C8FF
local function say(msg, col, show_log) status = msg; status_col = col or COL_INFO; status_log = show_log or false end

local function track_name(tr)
  local _, n = r.GetTrackName(tr); return n
end

-- items to transcribe: selected items, else every item of the selected tracks
local function collect_targets()
  local t = {}
  local n = r.CountSelectedMediaItems(0)
  if n > 0 then
    for i = 0, n - 1 do t[#t + 1] = r.GetSelectedMediaItem(0, i) end
  else
    for i = 0, r.CountSelectedTracks(0) - 1 do
      local tr = r.GetSelectedTrack(0, i)
      for j = 0, r.CountTrackMediaItems(tr) - 1 do t[#t + 1] = r.GetTrackMediaItem(tr, j) end
    end
  end
  local out, skipped = {}, 0
  for _, it in ipairs(t) do
    local take = r.GetActiveTake(it)
    if take and not r.TakeIsMIDI(take) then out[#out + 1] = it else skipped = skipped + 1 end
  end
  return out, skipped
end

local function target_summary()
  local n = r.CountSelectedMediaItems(0)
  if n > 0 then return string.format("%d selected item%s", n, n > 1 and "s" or "") end
  local tn = r.CountSelectedTracks(0)
  if tn > 0 then return string.format("all items of %d selected track%s", tn, tn > 1 and "s" or "") end
  return nil
end

local function cleanup(job)
  if not job then return end
  if job.acc then r.DestroyAudioAccessor(job.acc); job.acc = nil end
  if job.fh then job.fh:close(); job.fh = nil end
  for _, ext in ipairs({ ".wav", ".srt", ".log", ".done", ".bat", ".vbs", ".sh" }) do os.remove(job.base .. ext) end
end

local function new_job(item)
  run_id = run_id + 1
  local job = { item = item, take = r.GetActiveTake(item), stage = "render" }
  job.pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  job.len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  job.track = r.GetMediaItem_Track(item)
  job.base = TMP .. SEP .. "job_" .. os.time() .. "_" .. run_id
  return job
end

-- step 1: write the item audio as 16 kHz mono 16-bit WAV, a few seconds per cycle
local function wav_header(n)
  local data = n * 2
  return string.pack("<c4I4c4c4I4I2I2I4I4I2I2c4I4", "RIFF", 36 + data, "WAVE", "fmt ", 16, 1, 1,
    SR, SR * 2, 2, 16, "data", data)
end

local function render_step(job)
  if not job.acc then
    if not r.ValidatePtr2(0, job.take, "MediaItem_Take*") then return false, "The item was removed." end
    job.acc = r.CreateTakeAudioAccessor(job.take)
    job.t0 = r.GetAudioAccessorStartTime(job.acc)
    job.t1 = math.min(r.GetAudioAccessorEndTime(job.acc), job.t0 + job.len)
    local src = r.GetMediaItemTake_Source(job.take)
    job.nch = math.max(1, math.min(2, r.GetMediaSourceNumChannels(src)))
    job.total = math.max(0, math.floor((job.t1 - job.t0) * SR))
    job.done = 0
    job.buf = r.new_array(BLOCK * job.nch)
    job.env, job.e_acc, job.e_cnt = {}, 0, 0 -- 10 ms RMS envelope, used to trim items to the voice
    job.fh = io.open(job.base .. ".wav", "wb")
    if not job.fh then return false, "Cannot write in " .. TMP end
    job.fh:write(wav_header(0))
  end
  local budget = SR * 15 -- samples per defer cycle
  local nch, buf = job.nch, job.buf
  while budget > 0 and job.done < job.total do
    local n = math.min(BLOCK, job.total - job.done)
    buf.clear()
    r.GetAudioAccessorSamples(job.acc, SR, nch, job.t0 + job.done / SR, n, buf)
    local t = buf.table(1, n * nch)
    local vals = {}
    local env, e_acc, e_cnt = job.env, job.e_acc, job.e_cnt
    for i = 1, n do
      local v
      if nch == 2 then v = (t[2 * i - 1] + t[2 * i]) * 0.5 else v = t[i] end
      e_acc = e_acc + v * v
      e_cnt = e_cnt + 1
      if e_cnt == 160 then env[#env + 1] = math.sqrt(e_acc / 160); e_acc, e_cnt = 0, 0 end
      v = math.floor(v * 32767 + 0.5)
      if v > 32767 then v = 32767 elseif v < -32768 then v = -32768 end
      vals[i] = v
    end
    job.e_acc, job.e_cnt = e_acc, e_cnt
    job.fh:write(string.pack(fmt_for(n), table.unpack(vals, 1, n)))
    job.done = job.done + n
    budget = budget - n
  end
  if job.done >= job.total then
    job.fh:seek("set", 0)
    job.fh:write(wav_header(job.total))
    job.fh:close(); job.fh = nil
    r.DestroyAudioAccessor(job.acc); job.acc = nil
    job.stage = "launch"
  end
  return true
end

-- step 2: run whisper.cpp in the background through a small .bat / .sh file
local function clean_prompt(s)
  return (s:gsub('["%%$`\\!]', ""):gsub("[\r\n]", " "))
end

-- Windows: cmd.exe would open a console window, so the .bat is started
-- hidden through a tiny VBScript (WScript.Shell.Run, window style 0)
local function utf16le(str)
  local out = { "\255\254" } -- BOM
  for _, c in utf8.codes(str) do
    if c >= 0x10000 then
      c = c - 0x10000
      local hi, lo = 0xD800 + (c >> 10), 0xDC00 + (c & 0x3FF)
      out[#out + 1] = string.char(hi & 255, hi >> 8, lo & 255, lo >> 8)
    else
      out[#out + 1] = string.char(c & 255, c >> 8)
    end
  end
  return table.concat(out)
end

local function hidden_launcher(job, bat)
  local wscript = (os.getenv("WINDIR") or "C:\\Windows") .. "\\System32\\wscript.exe"
  if not file_exists(wscript) then return 'cmd.exe /C "' .. bat .. '"' end
  local vbs = job.base .. ".vbs"
  local line = 'CreateObject("WScript.Shell").Run "cmd.exe /C ""' .. bat .. '""", 0, False\r\n'
  if not write_file(vbs, utf16le(line)) then return 'cmd.exe /C "' .. bat .. '"' end
  return '"' .. wscript .. '" //B //Nologo "' .. vbs .. '"'
end

local function launch_step(job)
  local args = { '-m "' .. cfg.model .. '"', '-f "' .. job.base .. '.wav"', "-l " .. cfg.lang,
    "-osrt", '-of "' .. job.base .. '"', "-t " .. math.floor(cfg.threads), "-pp" }
  if not cfg.gpu then args[#args + 1] = "-ng" end
  if cfg.maxlen > 0 then args[#args + 1] = "-ml " .. math.floor(cfg.maxlen) .. " -sow" end
  local p = clean_prompt(cfg.prompt)
  if p ~= "" then args[#args + 1] = '--prompt "' .. p .. '"' end
  local cmd = '"' .. cfg.whisper .. '" ' .. table.concat(args, " ")
  append_log("Run: " .. cmd)
  local script, launcher
  if WIN then
    script = job.base .. ".bat"
    write_file(script, "@echo off\r\nchcp 65001 >nul\r\n" .. cmd .. ' > "' .. job.base .. '.log" 2>&1\r\n'
      .. 'echo %ERRORLEVEL% > "' .. job.base .. '.done"\r\n')
    launcher = hidden_launcher(job, script)
  else
    script = job.base .. ".sh"
    write_file(script, "#!/bin/sh\n" .. cmd .. ' > "' .. job.base .. '.log" 2>&1\n'
      .. 'echo $? > "' .. job.base .. '.done"\n')
    launcher = '/bin/sh "' .. script .. '"'
  end
  r.ExecProcess(launcher, -1)
  job.stage = "wait"
  job.started = r.time_precise()
  job.progress = 0
  return true
end

-- step 3: read the SRT and create the lyrics items
local function parse_srt(txt)
  txt = txt:gsub("\r", "")
  if txt:sub(1, 3) == "\239\187\191" then txt = txt:sub(4) end
  local segs = {}
  for block in (txt .. "\n\n"):gmatch("(.-)\n\n+") do
    local h1, m1, s1, f1, h2, m2, s2, f2 = block:match(
      "(%d+):(%d+):(%d+)[,%.](%d+)%s*%-%->%s*(%d+):(%d+):(%d+)[,%.](%d+)")
    if h1 then
      local text = block:match("%-%->[^\n]*\n(.*)$") or ""
      text = text:gsub("\n", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
      local a = h1 * 3600 + m1 * 60 + s1 + f1 / 1000
      local b = h2 * 3600 + m2 * 60 + s2 + f2 / 1000
      if text ~= "" then segs[#segs + 1] = { a = a, b = b, text = text } end
    end
  end
  return segs
end

-- whisper timestamps are loose (a phrase after a silence often starts at the
-- end of the previous one): pull start and end in to where the voice really is
local FR = 0.01
local function trim_to_voice(job, segs)
  local env = job.env
  if not cfg.trim or not env or #env == 0 then return end
  local peak = 0
  for i = 1, #env do if env[i] > peak then peak = env[i] end end
  if peak <= 0 then return end
  local thr = peak * 10 ^ (cfg.trim_db / 20)
  local need = 8 -- 80 ms above the threshold = voice (ignores clicks and short noises)
  for _, sg in ipairs(segs) do
    local i0 = math.max(1, math.floor(sg.a / FR) + 1)
    local i1 = math.min(#env, math.ceil(sg.b / FR))
    local first, run = nil, 0
    for i = i0, i1 do
      if env[i] >= thr then
        run = run + 1
        if run >= need then first = i - need + 1 break end
      else run = 0 end
    end
    if first then
      local last, run2 = nil, 0
      for i = i1, first, -1 do
        if env[i] >= thr then
          run2 = run2 + 1
          if run2 >= 3 then last = i + run2 - 1 break end
        else run2 = 0 end
      end
      local na = math.max(sg.a, (first - 1) * FR - 0.05)
      local nb = last and math.min(sg.b, last * FR + 0.15) or sg.b
      if nb > na + 0.1 then sg.a, sg.b = na, nb end
    end
  end
end

local function non_speech(text)
  local s = text:gsub("%b[]", ""):gsub("%b()", ""):gsub("%b**", "")
  s = s:gsub("\226\153[\170\171\172]", "") -- ♪ ♫ ♬
  s = s:gsub("[%s%p]", "")
  return s == ""
end

local function find_lyrics_track(voice)
  local guid = r.GetTrackGUID(voice)
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, v = r.GetSetMediaTrackInfo_String(tr, "P_EXT:ReNo_LyricsBuddy", "", false)
    if v == guid then return tr end
  end
  local idx = math.floor(r.GetMediaTrackInfo_Value(voice, "IP_TRACKNUMBER")) -- 1-based = index of next track
  local depth = r.GetMediaTrackInfo_Value(voice, "I_FOLDERDEPTH")
  r.InsertTrackAtIndex(idx, true)
  local tr = r.GetTrack(0, idx)
  if depth < 0 then -- voice track closed a folder: the new track closes it now
    r.SetMediaTrackInfo_Value(voice, "I_FOLDERDEPTH", 0)
    r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)
  end
  local name = cfg.track ~= "" and cfg.track or "Lyrics"
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  r.GetSetMediaTrackInfo_String(tr, "P_EXT:ReNo_LyricsBuddy", guid, true)
  return tr
end

local function create_items(job, segs)
  if not r.ValidatePtr2(0, job.item, "MediaItem*") then return 0, "The item was removed." end
  local voice = r.GetMediaItem_Track(job.item)
  local pos = r.GetMediaItemInfo_Value(job.item, "D_POSITION")
  local len = r.GetMediaItemInfo_Value(job.item, "D_LENGTH")
  local item_end = pos + len

  local list = {}
  for _, s in ipairs(segs) do
    if not (cfg.skip_ns and non_speech(s.text)) then list[#list + 1] = s end
  end
  if #list == 0 then return 0 end
  trim_to_voice(job, list)

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local tr = find_lyrics_track(voice)
  if cfg.replace then
    for j = r.CountTrackMediaItems(tr) - 1, 0, -1 do
      local it = r.GetTrackMediaItem(tr, j)
      local p = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local l = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      if p < item_end and p + l > pos then r.DeleteTrackMediaItem(tr, it) end
    end
  end
  local made = 0
  for i, s in ipairs(list) do
    local a = pos + job.t0 + s.a
    local b = pos + job.t0 + s.b
    if list[i + 1] then b = math.min(b, pos + job.t0 + list[i + 1].a) end
    b = math.min(b, item_end)
    if a < item_end then
      if b - a < 0.05 then b = a + 0.05 end
      local it = r.AddMediaItemToTrack(tr)
      r.SetMediaItemInfo_Value(it, "D_POSITION", a)
      r.SetMediaItemInfo_Value(it, "D_LENGTH", b - a)
      r.GetSetMediaItemInfo_String(it, "P_NOTES", s.text, true)
      r.GetSetMediaItemInfo_String(it, "P_EXT:ReNo_LyricsBuddy", "1", true)
      made = made + 1
    end
  end
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Lyrics Buddy: create lyrics items", -1)
  return made
end

local function fail(job, msg)
  local lg = read_file(job.base .. ".log")
  if lg then append_log("whisper output:\n" .. lg) end
  append_log("Error: " .. msg)
  cleanup(job)
  queue, cur = {}, nil
  running = false
  say(msg, COL_ERR, true)
end

local function wait_step(job)
  local lg = read_file(job.base .. ".log") or ""
  local last
  for pc in lg:gmatch("progress%s*=%s*(%d+)%%") do last = pc end
  if last then job.progress = tonumber(last) / 100 end
  if not file_exists(job.base .. ".done") then return end
  local code = tonumber((read_file(job.base .. ".done") or ""):match("%-?%d+")) or -1
  local srt = read_file(job.base .. ".srt")
  if code ~= 0 or not srt then
    fail(job, "whisper.cpp stopped with an error (code " .. code .. ").")
    return
  end
  append_log(string.format("Done in %.1f s: %s", r.time_precise() - job.started, basename(job.base)))
  local made, err = create_items(job, parse_srt(srt))
  if err then fail(job, err) return end
  done_items = done_items + made
  cleanup(job)
  cur = nil
end

local function start()
  if cur then return end
  if not file_exists(cfg.whisper) then say("whisper.cpp not found: open the Setup tab.", COL_ERR) return end
  if not file_exists(cfg.model) then say("No model chosen: open the Setup tab.", COL_ERR) return end
  local items, skipped = collect_targets()
  if #items == 0 then
    say(skipped > 0 and "Only MIDI or empty items: select audio items." or "Select one or more audio items first (or a track).", COL_ERR)
    return
  end
  queue = {}
  for _, it in ipairs(items) do queue[#queue + 1] = it end
  total_jobs, done_items = #queue, 0
  running = true
  say("")
end

local function cancel()
  if cur then
    local exe = basename(cfg.whisper)
    if WIN then r.ExecProcess('taskkill /F /IM "' .. exe .. '"', 3000)
    else r.ExecProcess('/usr/bin/pkill -f "' .. cfg.whisper .. '"', 3000) end
    cleanup(cur)
  end
  queue, cur = {}, nil
  running = false
  say("Cancelled.", COL_INFO)
end

local function process()
  if not cur then
    if #queue == 0 then return end
    local it = table.remove(queue, 1)
    if r.ValidatePtr2(0, it, "MediaItem*") then cur = new_job(it) else return end
  end
  if cur.stage == "render" then
    local ok, err = render_step(cur)
    if not ok then fail(cur, err) end
  elseif cur.stage == "launch" then
    launch_step(cur)
  elseif cur.stage == "wait" then
    if not cur.next_poll or r.time_precise() >= cur.next_poll then
      cur.next_poll = r.time_precise() + 0.3
      wait_step(cur)
    end
  end
  if running and not cur and #queue == 0 then
    running = false
    say(string.format("Done: %d lyrics item%s created.", done_items, done_items == 1 and "" or "s"), COL_OK)
  end
end

local function busy() return cur ~= nil or #queue > 0 end

---------------------------------------------------------------- UI
local ctx
local fonts = {}
local FONT_MIN, FONT_MAX = 10, 28
local post = nil -- modal dialogs run after ImGui.End
local function later(fn) post = fn end
local function text_size() return math.floor(math.max(FONT_MIN, math.min(FONT_MAX, cfg.font))) end

local function copy_line(label, text)
  ImGui.PushID(ctx, label)
  if ImGui.SmallButton(ctx, "Copy") then ImGui.SetClipboardText(ctx, text) end
  ImGui.SameLine(ctx)
  ImGui.TextWrapped(ctx, text)
  ImGui.PopID(ctx)
end

local function tab_lyrics()
  local ready = file_exists(cfg.whisper) and file_exists(cfg.model)
  if not ready then
    ImGui.TextColored(ctx, COL_ERR, "whisper.cpp or the model is missing: open the Setup tab.")
    ImGui.Spacing(ctx)
  end

  local tgt = target_summary()
  ImGui.Text(ctx, "Source: ")
  ImGui.SameLine(ctx)
  if tgt then ImGui.Text(ctx, tgt) else ImGui.TextDisabled(ctx, "select vocal items (or a track)") end

  ImGui.SetNextItemWidth(ctx, 200)
  if ImGui.BeginCombo(ctx, "Language", lang_label(cfg.lang)) then
    for _, l in ipairs(LANGS) do
      if ImGui.Selectable(ctx, l[2], cfg.lang == l[1]) then save("lang", l[1]) end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, "Model: " .. (cfg.model ~= "" and basename(cfg.model) or "none"))

  ImGui.SetNextItemWidth(ctx, -1)
  local ch, v = ImGui.InputTextWithHint(ctx, "##prompt", cfg.prompt,
    "Hint (optional): song title, names, unusual words...")
  if ch then save("prompt", v) end

  ImGui.Spacing(ctx)
  if busy() then
    local frac, label = 0, ""
    local idx = total_jobs - #queue
    if cur and cur.stage == "render" then
      frac = cur.total and cur.total > 0 and cur.done / cur.total or 0
      label = string.format("Item %d / %d - preparing audio %d %%", idx, total_jobs, math.floor(frac * 100))
    elseif cur then
      frac = cur.progress or 0
      label = string.format("Item %d / %d - listening %d %%  (%.0f s)", idx, total_jobs, math.floor(frac * 100),
        r.time_precise() - (cur.started or r.time_precise()))
    end
    ImGui.ProgressBar(ctx, frac, -1, 0, label)
    if ImGui.Button(ctx, "Cancel", 120, 0) then cancel() end
  else
    ImGui.BeginDisabled(ctx, not ready)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x2F7D4FFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x3C9963FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x4BB577FF)
    if ImGui.Button(ctx, "Transcribe", -1, text_size() * 2.6) then start() end
    ImGui.PopStyleColor(ctx, 3)
    ImGui.EndDisabled(ctx)
  end

  if status ~= "" then
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, status_col or COL_INFO, status)
    if status_log then
      ImGui.SameLine(ctx)
      if ImGui.SmallButton(ctx, "Open log") then open_path(LOG) end
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.TextDisabled(ctx, "One empty item per phrase, text in the item notes, on the track \"" ..
    (cfg.track ~= "" and cfg.track or "Lyrics") .. "\" under the vocal track.")
  ImGui.TextDisabled(ctx, "Ctrl+Z removes everything created for an item.")
end

local function tab_setup()
  -- whisper.cpp
  ImGui.SeparatorText(ctx, "whisper.cpp")
  local ok_w = file_exists(cfg.whisper)
  ImGui.TextColored(ctx, ok_w and COL_OK or COL_ERR, ok_w and cfg.whisper or "not found")
  if ImGui.Button(ctx, "Auto-detect") then
    local w = detect_whisper()
    if w then save("whisper", w); test_msg = nil else test_ok = false; test_msg = "Nothing found: install it (see below) or use Browse." end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Browse...##w") then
    later(function()
      local okb, p = r.GetUserFileNameForRead(cfg.whisper, "Choose whisper-cli" .. (WIN and ".exe" or ""), WIN and "exe" or "")
      if okb and p ~= "" then save("whisper", p); test_msg = nil end
    end)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Test") then test_whisper() end
  if test_msg then
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, test_ok and COL_OK or COL_ERR, test_msg)
  end

  -- model
  ImGui.SeparatorText(ctx, "Model")
  local models = list_models()
  ImGui.SetNextItemWidth(ctx, 320)
  if ImGui.BeginCombo(ctx, "##model", cfg.model ~= "" and basename(cfg.model) or "none") then
    for _, p in ipairs(models) do
      if ImGui.Selectable(ctx, basename(p), p == cfg.model) then save("model", p) end
    end
    if #models == 0 then ImGui.TextDisabled(ctx, "No model in the models folder yet.") end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Browse...##m") then
    later(function()
      local okb, p = r.GetUserFileNameForRead(cfg.model, "Choose a whisper.cpp model (ggml-*.bin)", "bin")
      if okb and p ~= "" then save("model", p) end
    end)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Open models folder") then open_path(MODELS) end

  -- options
  ImGui.SeparatorText(ctx, "Options")
  ImGui.SetNextItemWidth(ctx, 160)
  local ch, v = ImGui.SliderInt(ctx, "CPU threads", math.floor(cfg.threads), 1, 16)
  if ch then save("threads", v) end
  ch, v = ImGui.Checkbox(ctx, "Use GPU (Metal, CUDA or Vulkan when available)", cfg.gpu)
  if ch then save("gpu", v) end
  ImGui.SetNextItemWidth(ctx, 160)
  ch, v = ImGui.SliderInt(ctx, "Max characters per item (0 = whole phrase)", math.floor(cfg.maxlen), 0, 120)
  if ch then save("maxlen", v) end
  ch, v = ImGui.Checkbox(ctx, "Skip non-speech ([Music], (applause), notes...)", cfg.skip_ns)
  if ch then save("skip_ns", v) end
  ch, v = ImGui.Checkbox(ctx, "Trim items to the voice (removes silences)", cfg.trim)
  if ch then save("trim", v) end
  if cfg.trim then
    ImGui.SetNextItemWidth(ctx, 160)
    ch, v = ImGui.SliderInt(ctx, "Trim threshold (dB under the loudest part)", math.floor(cfg.trim_db), -60, -15)
    if ch then save("trim_db", v) end
  end
  ch, v = ImGui.Checkbox(ctx, "Replace the lyrics already under the item", cfg.replace)
  if ch then save("replace", v) end
  ImGui.SetNextItemWidth(ctx, 160)
  ch, v = ImGui.InputText(ctx, "Lyrics track name", cfg.track)
  if ch then save("track", v) end
  ImGui.SetNextItemWidth(ctx, 160)
  ch, v = ImGui.SliderInt(ctx, "Text size", text_size(), FONT_MIN, FONT_MAX)
  if ch then save("font", v) end
  if ImGui.Button(ctx, "Open log") then open_path(LOG) end

  -- install guide
  ImGui.SeparatorText(ctx, "Install (once)")
  ImGui.TextWrapped(ctx, "No Python needed: whisper.cpp is a small program plus a model file.")
  if ImGui.CollapsingHeader(ctx, "macOS", nil, MAC and ImGui.TreeNodeFlags_DefaultOpen or 0) then
    ImGui.TextWrapped(ctx, "1. Install Homebrew if needed (brew.sh), then in Terminal:")
    copy_line("mac1", "brew install whisper-cpp")
    ImGui.TextWrapped(ctx, "2. Download a model (example: large-v3-turbo):")
    copy_line("mac2", 'curl -L -o "' .. MODELS .. '/ggml-large-v3-turbo.bin" ' .. HF .. "ggml-large-v3-turbo.bin")
    ImGui.TextWrapped(ctx, "3. Click Auto-detect, choose the model, then Test.")
  end
  if ImGui.CollapsingHeader(ctx, "Windows", nil, WIN and ImGui.TreeNodeFlags_DefaultOpen or 0) then
    ImGui.TextWrapped(ctx, "1. Download whisper-bin-x64.zip (any PC) or whisper-cublas-...-bin-x64.zip (NVIDIA GPU) from:")
    copy_line("win1", RELEASES)
    ImGui.TextWrapped(ctx, "2. Unzip it into this folder:")
    copy_line("win2", WHISPER_DIR)
    if WIN and ImGui.SmallButton(ctx, "Open whisper folder") then open_path(WHISPER_DIR) end
    ImGui.TextWrapped(ctx, "3. Download a model (Command Prompt, example: large-v3-turbo):")
    copy_line("win3", 'curl -L -o "' .. MODELS:gsub("/", "\\") .. '\\ggml-large-v3-turbo.bin" ' .. HF .. "ggml-large-v3-turbo.bin")
    ImGui.TextWrapped(ctx, "4. Click Auto-detect, choose the model, then Test.")
  end
  if ImGui.CollapsingHeader(ctx, "Models") then
    for _, m in ipairs(MODEL_LIST) do
      ImGui.BulletText(ctx, m[1] .. "  -  " .. m[2] .. "  -  " .. m[3])
    end
    ImGui.TextWrapped(ctx, "Put the .bin files in the models folder. Download address: " .. HF .. "<model name>")
  end
end

local function loop()
  process()

  ImGui.PushFont(ctx, fonts[text_size()])
  ImGui.SetNextWindowSize(ctx, 620, 420, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, TITLE .. " " .. VERSION, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Lyrics") then tab_lyrics(); ImGui.EndTabItem(ctx) end
      if ImGui.BeginTabItem(ctx, "Setup") then tab_setup(); ImGui.EndTabItem(ctx) end
      ImGui.EndTabBar(ctx)
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if post then local f = post; post = nil; f() end
  if open then r.defer(loop) end
end

r.atexit(function()
  if cur then cancel() end
  if r.set_action_options then r.set_action_options(8) end
  set_self_toggle(false)
end)

r.defer(function()
  ctx = ImGui.CreateContext(TITLE)
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  loop()
end)
