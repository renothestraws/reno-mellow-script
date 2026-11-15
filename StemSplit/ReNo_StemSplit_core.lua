-- @noindex
-- ReNo StemSplit - shared core (UI, audio export, engine launch, stem import)
-- Used by "ReNo StemSplit - Stems.lua", "ReNo StemSplit - Drums.lua" and "ReNo StemSplit - Install.lua".

local R = reaper
local M = {}

M.VERSION = "1.8"
M.EXT = "ReNo_StemSplit"

local SEP = package.config:sub(1, 1)
M.IS_WIN = (SEP == "\\")
local os_name = R.GetOS()
M.IS_MAC = (os_name:find("OSX") ~= nil) or (os_name:find("mac") ~= nil)

local function join(...) return table.concat({ ... }, SEP) end
M.join = join

M.script_dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
M.base       = join(R.GetResourcePath(), "Data", "ReNo_StemSplit")
M.work       = join(M.base, "work")
M.models_dir = join(M.base, "models")
M.log_run    = join(M.base, "last_run.log")
M.log_inst   = join(M.base, "install.log")
M.flag_ok    = join(M.base, "installed.ok")
if M.IS_WIN then
  M.venv_py = join(M.base, "venv", "Scripts", "pythonw.exe")
else
  M.venv_py = join(M.base, "venv", "bin", "python")
end
M.engine    = M.script_dir .. "stemsplit_engine.py"
M.installer = M.script_dir .. "stemsplit_install.py"

---------------------------------------------------------------------------
-- small utilities
---------------------------------------------------------------------------
local function exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end
M.exists = exists

local function mkdir(p) R.RecursiveCreateDirectory(p, 0) end

local function write_file(p, s)
  local f = io.open(p, "wb")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local function q(s) return '"' .. s .. '"' end

local function jstr(s)
  local r = tostring(s):gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"'
    elseif c == "\\" then return "\\\\"
    elseif c == "\n" then return "\\n"
    elseif c == "\r" then return "\\r"
    elseif c == "\t" then return "\\t"
    else return string.format("\\u%04x", c:byte()) end
  end)
  return '"' .. r .. '"'
end

local function to_json(t)
  local parts = {}
  for k, v in pairs(t) do
    local val
    if type(v) == "boolean" then
      val = v and "true" or "false"
    elseif type(v) == "number" then
      val = string.format("%d", math.floor(v))
    else
      val = jstr(v)
    end
    parts[#parts + 1] = jstr(k) .. ":" .. val
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function M.installed()
  return exists(M.venv_py) and exists(M.flag_ok) and exists(M.engine)
end

function M.read_status(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local st = { files = {} }
  for line in f:lines() do
    line = line:gsub("\r$", "")
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "file" then
      st.files[#st.files + 1] = v
    elseif k then
      st[k] = v
    end
  end
  f:close()
  if not st.state then return nil end
  return st
end

function M.launch(py, script, arg)
  R.ExecProcess(M.arch_prefix() .. q(py) .. " " .. q(script) .. " " .. q(arg), -1)
end

function M.kill(pid)
  pid = tonumber(pid)
  if not pid then return end
  if M.IS_WIN then
    R.ExecProcess("taskkill /PID " .. pid .. " /T /F", 5000)
  else
    R.ExecProcess("pkill -TERM -P " .. pid, 3000)
    R.ExecProcess("kill -TERM " .. pid, 3000)
  end
end

function M.open_path(p)
  if R.CF_ShellExecute then
    R.CF_ShellExecute(p)
  elseif M.IS_WIN then
    R.ExecProcess('cmd.exe /C start "" ' .. q(p), -1)
  elseif M.IS_MAC then
    R.ExecProcess("open " .. q(p), -1)
  else
    R.ExecProcess("xdg-open " .. q(p), -1)
  end
end

---------------------------------------------------------------------------
-- Python discovery (for the one-time install)
---------------------------------------------------------------------------
-- macOS: Apple Silicon (true) or Intel (false). Works even when REAPER runs under Rosetta.
function M.mac_arm()
  if not M.IS_MAC then return false end
  if M._arm == nil then
    local out = R.ExecProcess("/usr/sbin/sysctl -n hw.optional.arm64", 5000) or ""
    M._arm = out:match("\n%s*1") ~= nil
  end
  return M._arm
end

-- On Apple Silicon, force native arm64 Python even if REAPER itself runs under Rosetta
-- (an x86_64 Python cannot install PyTorch).
function M.arch_prefix()
  return M.mac_arm() and "/usr/bin/arch -arm64 " or ""
end

local PY_TEST = [[ -c "import sys;print('PYOK',sys.version_info[0],sys.version_info[1],sys.executable)"]]

function M.find_python()
  local c = {}
  -- 3.10-3.13: supported. 3.14: only tried (trial) when nothing else is installed.
  local versions = { "3.12", "3.11", "3.13", "3.10", "3.14" }
  if M.IS_WIN then
    local la = os.getenv("LOCALAPPDATA")
    for _, v in ipairs(versions) do
      if la then
        -- runtimes installed by the new Python install manager
        c[#c + 1] = q(join(la, "Python", "pythoncore-" .. v .. "-64", "python.exe"))
        c[#c + 1] = q(join(la, "Python", "pythoncore-" .. v .. "-arm64", "python.exe"))
        -- classic python.org installers
        c[#c + 1] = q(join(la, "Programs", "Python", "Python" .. v:gsub("%.", ""), "python.exe"))
      end
      c[#c + 1] = "py -V:" .. v
      c[#c + 1] = "py -" .. v
    end
    c[#c + 1] = "python"
    c[#c + 1] = "python3"
  else
    for _, v in ipairs(versions) do
      c[#c + 1] = "/opt/homebrew/opt/python@" .. v .. "/bin/python" .. v
      c[#c + 1] = "/usr/local/opt/python@" .. v .. "/bin/python" .. v
      c[#c + 1] = "/opt/homebrew/bin/python" .. v
      c[#c + 1] = "/usr/local/bin/python" .. v
      c[#c + 1] = "/Library/Frameworks/Python.framework/Versions/" .. v .. "/bin/python3"
      c[#c + 1] = "/usr/bin/python" .. v
    end
    c[#c + 1] = "/opt/homebrew/bin/python3"
    c[#c + 1] = "/usr/local/bin/python3"
    c[#c + 1] = "/usr/bin/python3"
    c[#c + 1] = "python3"
  end
  local other, trial
  for _, cmd in ipairs(c) do
    local out = R.ExecProcess(M.arch_prefix() .. cmd .. PY_TEST, 10000)
    if out then
      local maj, min, exe = out:match("PYOK (%d+) (%d+) ([^\r\n]+)")
      maj, min = tonumber(maj), tonumber(min)
      if maj == 3 and min and min >= 10 and min <= 13 then
        return exe, maj .. "." .. min
      elseif maj == 3 and min == 14 and not trial then
        trial = exe
      elseif maj then
        other = maj .. "." .. min
      end
    end
  end
  if trial then return trial, "3.14", true end
  return nil, other
end

-- new "Python install manager" (2025+): can install a runtime for us, without admin rights
function M.has_pymanager()
  if not M.IS_WIN then return false end
  local out = R.ExecProcess("pymanager list", 15000)
  return out ~= nil and out:match("^0%s") ~= nil
end

function M.pymanager_install(ver)
  local out = R.ExecProcess("pymanager install --yes " .. ver, 600000)
  if not (out and out:match("^0%s")) then
    out = R.ExecProcess("pymanager install " .. ver, 600000)
  end
  return out ~= nil and out:match("^0%s") ~= nil, out
end

local function windowless(exe)
  if M.IS_WIN then
    local w = exe:gsub("[Pp][Yy][Tt][Hh][Oo][Nn]%.[Ee][Xx][Ee]$", "pythonw.exe")
    if w ~= exe and exists(w) then return w end
  end
  return exe
end

function M.has_nvidia()
  if M.IS_MAC then return false end
  local out = R.ExecProcess("nvidia-smi -L", 5000)
  return out ~= nil and out:find("GPU %d") ~= nil
end

---------------------------------------------------------------------------
-- audio export: active take -> 32-bit float WAV at 44.1 kHz (the models' rate)
-- Takes playrate, section, reverse etc. into account (audio accessor).
---------------------------------------------------------------------------
local SR = 44100
local BLOCK = 4096
local fmt_cache = {}

function M.export_begin(take, path)
  local item = R.GetMediaItemTake_Item(take)
  local len = R.GetMediaItemInfo_Value(item, "D_LENGTH")
  local src = R.GetMediaItemTake_Source(take)
  local nch = R.GetMediaSourceNumChannels(src)
  if nch < 1 then nch = 1 elseif nch > 2 then nch = 2 end
  local frames = math.floor(len * SR + 0.5)
  if frames < SR // 10 then return nil, "The item is too short." end
  local f = io.open(path, "wb")
  if not f then return nil, "Cannot write the temporary file:\n" .. path end
  local data_bytes = frames * nch * 4
  f:write("RIFF", string.pack("<I4", 4 + 24 + 12 + 8 + data_bytes), "WAVE")
  f:write("fmt ", string.pack("<I4I2I2I4I4I2I2", 16, 3, nch, SR, SR * nch * 4, nch * 4, 32))
  f:write("fact", string.pack("<I4I4", 4, frames))
  f:write("data", string.pack("<I4", data_bytes))
  local acc = R.CreateTakeAudioAccessor(take)
  return {
    f = f, acc = acc, nch = nch, t0 = R.GetAudioAccessorStartTime(acc),
    frames = frames, pos = 0, buf = R.new_array(BLOCK * nch),
  }
end

function M.export_step(ex, max_blocks)
  for _ = 1, max_blocks do
    if ex.pos >= ex.frames then return true end
    local n = math.min(BLOCK, ex.frames - ex.pos)
    local count = n * ex.nch
    ex.buf.clear()
    R.GetAudioAccessorSamples(ex.acc, SR, ex.nch, ex.t0 + ex.pos / SR, n, ex.buf)
    local fmt = fmt_cache[count]
    if not fmt then
      fmt = "<" .. string.rep("f", count)
      fmt_cache[count] = fmt
    end
    ex.f:write(string.pack(fmt, table.unpack(ex.buf.table(1, count))))
    ex.pos = ex.pos + n
  end
  return ex.pos >= ex.frames
end

function M.export_end(ex)
  if ex.acc then R.DestroyAudioAccessor(ex.acc) ex.acc = nil end
  if ex.f then ex.f:close() ex.f = nil end
end

---------------------------------------------------------------------------
-- stem import
---------------------------------------------------------------------------
local COLORS = {   -- nil = no custom color
  Drums = { 220, 50, 50 },  Bass = { 235, 200, 40 }, Guitar = { 60, 120, 230 },
  Vocals = { 60, 190, 80 }, Piano = { 150, 80, 210 }, Other = nil,
  -- drum kit pieces: shades of red
  Kick = { 200, 30, 30 }, Snare = { 235, 70, 60 }, Toms = { 180, 60, 50 },
  ["Hi-Hat"] = { 240, 110, 100 }, Ride = { 215, 90, 90 }, Crash = { 250, 130, 120 },
  Cymbals = { 245, 120, 110 },
}

local function take_base_name(take)
  local _, name = R.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  name = name:gsub("%.[%w]+$", ""):gsub('[\\/:*?"<>|]', "_")
  if name == "" then name = "Item" end
  return name
end
M.take_base_name = take_base_name

-- results = { {name=, path=}, ... }
function M.import_stems(item, results, opts, mode)
  local track = R.GetMediaItem_Track(item)
  local tidx = math.floor(R.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) -- 1-based = insert index after it
  local depth = math.floor(R.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH"))
  local pos = R.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = R.GetMediaItemInfo_Value(item, "D_LENGTH")
  local base_name = take_base_name(R.GetActiveTake(item))

  R.PreventUIRefresh(1)
  R.Undo_BeginBlock()

  -- if the source track closes a folder, hand that closing over to our last new track
  local carry = 0
  if depth < 0 then
    carry = depth
    R.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
  end

  local at = tidx
  if opts.folder then
    R.InsertTrackAtIndex(at, true)
    local ft = R.GetTrack(0, at)
    R.GetSetMediaTrackInfo_String(ft, "P_NAME",
      base_name .. (mode == "drums" and " - Drum kit" or " - Stems"), true)
    R.SetMediaTrackInfo_Value(ft, "I_FOLDERDEPTH", 1)
    R.SetMediaTrackInfo_Value(ft, "I_CUSTOMCOLOR",
      R.ColorToNative(90, 90, 100) | 0x1000000)
    at = at + 1
  end

  local last
  for _, r in ipairs(results) do
    R.InsertTrackAtIndex(at, true)
    local tr = R.GetTrack(0, at)
    at = at + 1
    R.GetSetMediaTrackInfo_String(tr, "P_NAME",
      opts.folder and r.name or (base_name .. " - " .. r.name), true)
    local c = COLORS[r.name]
    if c then
      R.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", R.ColorToNative(c[1], c[2], c[3]) | 0x1000000)
    end
    local it = R.AddMediaItemToTrack(tr)
    local tk = R.AddTakeToMediaItem(it)
    local src = R.PCM_Source_CreateFromFile(r.path)
    R.SetMediaItemTake_Source(tk, src)
    R.SetMediaItemInfo_Value(it, "D_POSITION", pos)
    R.SetMediaItemInfo_Value(it, "D_LENGTH", len)
    R.GetSetMediaItemTakeInfo_String(tk, "P_NAME", r.name, true)
    last = tr
  end

  if last then
    R.SetMediaTrackInfo_Value(last, "I_FOLDERDEPTH", (opts.folder and -1 or 0) + carry)
  end
  if opts.mute then R.SetMediaItemInfo_Value(item, "B_MUTE", 1) end

  R.Undo_EndBlock("ReNo StemSplit: " .. (mode == "drums" and "drum split" or "stem split"), -1)
  R.PreventUIRefresh(-1)
  R.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks
  R.TrackList_AdjustWindows(false)
  R.UpdateArrange()
end

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local function load_cfg()
  local function g(k, d)
    local v = R.GetExtState(M.EXT, k)
    if v == "" then return d end
    return v
  end
  local kit = math.floor(tonumber(g("kit", "4")) or 4)
  if kit < 4 or kit > 6 then kit = 4 end
  return {
    stems = (g("stems", "6") == "4") and 4 or 6,
    quality = (g("quality", "std") == "hq") and "hq" or "std",
    drums_only = g("drums_only", "0") == "1",
    kit = kit,
    folder = g("folder", "1") == "1",
    mute = g("mute", "1") == "1",
  }
end

local function save_cfg(c)
  R.SetExtState(M.EXT, "stems", tostring(c.stems), true)
  R.SetExtState(M.EXT, "quality", c.quality, true)
  R.SetExtState(M.EXT, "drums_only", c.drums_only and "1" or "0", true)
  R.SetExtState(M.EXT, "kit", tostring(c.kit), true)
  R.SetExtState(M.EXT, "folder", c.folder and "1" or "0", true)
  R.SetExtState(M.EXT, "mute", c.mute and "1" or "0", true)
end

---------------------------------------------------------------------------
-- UI + task runner
---------------------------------------------------------------------------
function M.run(mode)
  local TITLES = { stems = "Stems", drums = "Drums", install = "Engine" }
  local W, H = 520, 350
  local cfg = load_cfg()
  local view                    -- setup / reinstall / nopython / options / busy / result
  local msg, msg_err, msg_log = "", false, nil
  local old_py, has_pym
  local task
  local mx, my, click, prev_cap = 0, 0, false, 0

  if not exists(M.engine) or not exists(M.installer) then
    R.MB("Missing files next to the script:\nstemsplit_engine.py / stemsplit_install.py\n\nFolder: "
      .. M.script_dir, "ReNo StemSplit", 0)
    return
  end

  if M.installed() then
    view = (mode == "install") and "reinstall" or "options"
  else
    view = "setup"
  end
  if M.IS_MAC and not M.mac_arm() then view = "unsupported" end

  -- colors
  local C = {
    bg = { 0.12, 0.12, 0.13 }, panel = { 0.18, 0.18, 0.20 }, text = { 0.90, 0.90, 0.90 },
    dim = { 0.60, 0.60, 0.62 }, accent = { 0.95, 0.62, 0.20 }, err = { 0.95, 0.40, 0.35 },
    ok = { 0.45, 0.85, 0.50 }, btn = { 0.26, 0.26, 0.29 }, btn_hi = { 0.33, 0.33, 0.37 },
  }
  local function col(c, a) gfx.set(c[1], c[2], c[3], a or 1) end

  local function text(s, x, y, c, font)
    gfx.setfont(font or 1)
    col(c or C.text)
    gfx.x, gfx.y = x, y
    gfx.drawstr(s)
  end

  local function wrap(s, maxw)
    gfx.setfont(1)
    local lines = {}
    for para in (s .. "\n"):gmatch("(.-)\n") do
      local line = ""
      for word in para:gmatch("%S+") do
        local test = (line == "") and word or (line .. " " .. word)
        if gfx.measurestr(test) > maxw and line ~= "" then
          lines[#lines + 1] = line
          line = word
        else
          line = test
        end
      end
      lines[#lines + 1] = line
    end
    return lines
  end

  local function paragraph(s, x, y, maxw, c)
    for _, l in ipairs(wrap(s, maxw)) do
      text(l, x, y, c)
      y = y + 19
    end
    return y
  end

  local function hover(x, y, w, h) return mx >= x and mx < x + w and my >= y and my < y + h end

  local function button(label, x, y, w, h, accent)
    local hv = hover(x, y, w, h)
    if accent then col(C.accent, hv and 1 or 0.85) else col(hv and C.btn_hi or C.btn) end
    gfx.rect(x, y, w, h, 1)
    gfx.setfont(1)
    local tw, th = gfx.measurestr(label)
    col(accent and { 0.1, 0.1, 0.1 } or C.text)
    gfx.x, gfx.y = x + (w - tw) / 2, y + (h - th) / 2
    gfx.drawstr(label)
    return hv and click
  end

  local function segmented(label, y, items, cur)
    text(label, 20, y + 5, C.dim)
    local x0, wt = 150, W - 170
    local w = wt / #items
    local sel = cur
    for i, it in ipairs(items) do
      local x = x0 + (i - 1) * w
      local on = (i == cur)
      local hv = hover(x, y, w - 2, 26)
      if on then col(C.accent) else col(hv and C.btn_hi or C.btn) end
      gfx.rect(x, y, w - 2, 26, 1)
      gfx.setfont(1)
      local tw, th = gfx.measurestr(it)
      col(on and { 0.1, 0.1, 0.1 } or C.text)
      gfx.x, gfx.y = x + (w - 2 - tw) / 2, y + (26 - th) / 2
      gfx.drawstr(it)
      if hv and click then sel = i end
    end
    return sel
  end

  local function checkbox(label, x, y, on)
    local hv = hover(x, y, 22 + gfx.measurestr(label) + 10, 20)
    col(hv and C.btn_hi or C.btn)
    gfx.rect(x, y, 18, 18, 1)
    if on then col(C.accent) gfx.rect(x + 4, y + 4, 10, 10, 1) end
    text(label, x + 26, y + 1)
    if hv and click then return not on end
    return on
  end

  ---------------------------------------------------------------------------
  -- task handling
  ---------------------------------------------------------------------------
  local function now() return R.time_precise() end

  local function fail(m, logfile)
    if task and task.ex then M.export_end(task.ex) end
    msg_log = logfile
    msg = m .. (logfile and ("\n\nLog file:\n" .. logfile) or "")
    msg_err = true
    task = nil
    view = "result"
  end

  local function start_install(reinstall, update)
    gfx.setfont(1)
    local py, ver, trial = M.find_python()
    if not py then
      old_py = ver
      has_pym = M.has_pymanager()
      view = "nopython"
      return
    end
    local gpu = "cpu"
    if not update and M.has_nvidia() then
      local r = R.MB("An NVIDIA graphics card was detected.\n\n"
        .. "Install the GPU version? Separation is much faster, but the download is about 3 GB bigger.\n\n"
        .. "Yes = GPU version     No = CPU version", "ReNo StemSplit", 4)
      if r == 6 then gpu = "cuda" end
    end
    mkdir(M.base)
    mkdir(M.work)
    local status = join(M.work, "install_status.txt")
    os.remove(status)
    local jobf = join(M.work, "install_job.json")
    write_file(jobf, to_json({
      base = M.base, engine = M.engine, gpu = gpu, reinstall = reinstall and true or false,
      update = update and true or false,
      status = status, log = M.log_inst,
    }))
    M.launch(windowless(py), M.installer, jobf)
    task = { kind = "install", update = update, trial = trial, status = status, t0 = now(), launch_t = now(),
             last_poll = 0, pct = 0, log = M.log_inst,
             stage = "Starting the installer (Python " .. ver .. (trial and ", trial" or "") .. ")" }
    view = "busy"
  end

  local next_item -- forward

  local function finish_split()
    local n = task.created
    local nitems = task.done_items
    local out = task.out_dir
    task = nil
    msg = string.format("Done: %d stem track(s) created from %d item(s).\n\nFiles saved in:\n%s", n, nitems, out)
    msg_err = false
    view = "result"
  end

  local function launch_engine()
    local status = join(M.work, "status.txt")
    os.remove(status)
    local jobf = join(M.work, "job.json")
    write_file(jobf, to_json({
      mode = mode, input = task.input, out_dir = task.out_dir, base_name = task.base_name,
      base = M.base, models_dir = M.models_dir, work_dir = M.work, status = status,
      log = M.log_run, stems = cfg.stems, drums_only = cfg.drums_only, kit = cfg.kit,
      quality = cfg.quality,
    }))
    M.launch(M.venv_py, M.engine, jobf)
    task.status = status
    task.log = M.log_run
    task.launch_t = now()
    task.last_poll = 0
    task.phase = "wait"
    task.stage = "Starting the engine"
    task.pct = 0
  end

  next_item = function()
    task.idx = task.idx + 1
    if task.idx > #task.items then finish_split() return end
    local it = task.items[task.idx]
    if not R.ValidatePtr2(0, it, "MediaItem*") then return next_item() end
    local tk = R.GetActiveTake(it)
    if not tk then return next_item() end
    task.item = it
    task.base_name = take_base_name(tk)
    task.input = join(M.work, "input.wav")
    os.remove(task.input)
    local ex, err = M.export_begin(tk, task.input)
    if not ex then
      fail("Item " .. task.idx .. ": " .. err)
      return
    end
    task.ex = ex
    task.phase = "export"
    task.item_t0 = now()
    task.stage = "Preparing audio"
    task.pct = 0
  end

  local function start_split()
    local items = {}
    for i = 0, R.CountSelectedMediaItems(0) - 1 do
      local it = R.GetSelectedMediaItem(0, i)
      local tk = R.GetActiveTake(it)
      if tk and not R.TakeIsMIDI(tk) then items[#items + 1] = it end
    end
    if #items == 0 then
      R.MB("Select one or more audio items first.", "ReNo StemSplit", 0)
      return
    end
    save_cfg(cfg)
    mkdir(M.work)
    local out_dir = join(R.GetProjectPath(""), "Stems")
    mkdir(out_dir)
    task = { kind = "split", items = items, idx = 0, out_dir = out_dir, t0 = now(),
             created = 0, done_items = 0 }
    view = "busy"
    next_item()
  end

  local function on_done(st)
    if task.kind == "install" then
      local was_update = task.update
      task = nil
      if M.installed() then
        if was_update then
          msg = "The engine is up to date.\n\nThe separation library and the models have been updated. "
            .. "Everything works offline again."
          msg_err = false
          view = "result"
        elseif mode == "install" then
          msg = "The engine is installed.\n\nYou can now use \"ReNo StemSplit - Stems\" and \"ReNo StemSplit - Drums\". "
            .. "They work offline."
          msg_err = false
          view = "result"
        else
          view = "options"
        end
      else
        fail("The installation finished but the engine was not found.", M.log_inst)
      end
      return
    end
    -- split: import results
    local res = {}
    for _, f in ipairs(st.files) do
      local n, p = f:match("^(.-)|(.*)$")
      if n and exists(p) then res[#res + 1] = { name = n, path = p } end
    end
    if #res == 0 then
      fail("No stem files were found.", M.log_run)
      return
    end
    if R.ValidatePtr2(0, task.item, "MediaItem*") then
      M.import_stems(task.item, res, cfg, mode)
      task.created = task.created + #res
      task.done_items = task.done_items + 1
    end
    next_item()
  end

  local function poll()
    local t = now()
    if t - task.last_poll < 0.3 then return end
    task.last_poll = t
    local st = M.read_status(task.status)
    if not st then
      -- Windows: the file can be briefly locked while Python replaces it -> just retry.
      -- Only a status that never appeared means the process did not start.
      if not task.seen and t - task.launch_t > 90 then
        fail("The engine did not start.", task.log)
      end
      return
    end
    task.seen = true
    task.pid = st.pid
    task.stage = st.stage or task.stage
    task.pct = tonumber(st.progress) or task.pct
    if st.state == "done" then
      on_done(st)
    elseif st.state == "error" then
      local m = st.error or "Unknown error."
      if task.kind == "install" and task.trial then
        m = m .. "\n\nOnly Python 3.14 was found, and it is probably still too new for the AI libraries. "
          .. "Install Python 3.12 (Windows: py install 3.12 - Mac: brew install python@3.12), "
          .. "then click Install engine again."
      end
      fail(m, task.log)
    end
  end

  local function update_task()
    if task.kind == "split" and task.phase == "export" then
      local done = M.export_step(task.ex, 24)
      task.pct = math.floor(100 * task.ex.pos / math.max(1, task.ex.frames))
      if done then
        M.export_end(task.ex)
        task.ex = nil
        launch_engine()
      end
    else
      poll()
    end
  end

  local function cancel()
    if not task then return end
    if task.ex then M.export_end(task.ex) end
    if task.pid then M.kill(task.pid) end
    local was_install = task.kind == "install"
    task = nil
    if was_install then
      view = M.installed() and "options" or "setup"
      if mode == "install" then view = M.installed() and "reinstall" or "setup" end
    else
      view = "options"
    end
  end

  ---------------------------------------------------------------------------
  -- views
  ---------------------------------------------------------------------------
  local function header(sub)
    text("ReNo StemSplit", 20, 16, C.accent, 2)
    gfx.setfont(2)
    local tw = gfx.measurestr("ReNo StemSplit")
    text("  " .. sub, 20 + tw, 19, C.dim)
    col(C.panel)
    gfx.rect(20, 48, W - 40, 1, 1)
  end

  local function fmt_time(s)
    s = math.floor(s)
    return string.format("%d:%02d", s // 60, s % 60)
  end

  local function draw_setup()
    header("Engine setup")
    paragraph("The separation engine (Python + AI models) is not installed yet.\n\n"
      .. "It is installed once: about 1.5 GB to download (around 4.5 GB with NVIDIA GPU support). "
      .. "Internet is needed only for this step; afterwards everything runs offline on this computer.\n\n"
      .. "Requirement: Python 3.10 to 3.13 (3.12 recommended; 3.14 is tried if it is the only one).", 20, 62, W - 40)
    if button("Install engine", 20, H - 50, 150, 30, true) then start_install(false) end
    if button("Close", W - 120, H - 50, 100, 30) then gfx.quit() end
  end

  local function draw_unsupported()
    header("Mac Intel")
    paragraph("Sorry, ReNo StemSplit cannot run on Intel Macs.\n\n"
      .. "PyTorch, the AI engine used for the separation, is no longer published for Intel Macs, "
      .. "and the separation library needs a newer version of it.\n\n"
      .. "ReNo StemSplit works on Apple Silicon Macs (M1, M2, M3, M4...) and on Windows.", 20, 62, W - 40)
    if button("Close", W - 120, H - 50, 100, 30) then gfx.quit() end
  end

  local function draw_reinstall()
    header("Engine")
    local info = ""
    local f = io.open(M.flag_ok, "r")
    if f then info = f:read("a") f:close() end
    local y = paragraph("The engine is installed and ready.", 20, 62, W - 40, C.ok)
    y = paragraph(info, 20, y + 8, W - 40, C.dim)
    paragraph("Update: newer separation library and models, keeps your setup (needs internet). "
      .. "Reinstall: repairs a broken installation or switches between CPU and GPU versions.",
      20, y + 8, W - 40)
    if button("Update engine", 20, H - 50, 130, 30, true) then start_install(false, true) end
    if button("Reinstall", 160, H - 50, 100, 30) then start_install(true) end
    if button("Open data folder", 270, H - 50, 130, 30) then M.open_path(M.base) end
    if button("Close", W - 120, H - 50, 100, 30) then gfx.quit() end
  end

  local function draw_nopython()
    header("Python required")
    local s = "Python 3.10 to 3.13 was not found on this computer."
    if old_py then s = s .. " (Found Python " .. old_py .. ", which is not supported.)" end
    if M.IS_WIN then
      s = s .. "\n\nInstall Python 3.12 from python.org and tick \"Add python.exe to PATH\" during setup, "
        .. "or type this in a terminal:\nwinget install Python.Python.3.12\n\nThen click Retry."
    elseif M.IS_MAC then
      s = s .. "\n\nInstall Python 3.12 (not 3.14, which is too new for the AI libraries) with Homebrew:\n"
        .. "brew install python@3.12\n"
        .. "or with the macOS installer of Python 3.12 from python.org.\n\nThen click Retry."
    else
      s = s .. "\n\nInstall python3.12 and python3.12-venv with your package manager, then click Retry."
    end
    if has_pym then
      s = "Python 3.10 to 3.13 was not found, but the Python install manager is present."
        .. (old_py and (" (Python " .. old_py .. " is installed, but it is too new for the AI libraries.)") or "")
        .. "\n\nClick \"Install Python 3.12\": it is added next to your other versions, "
        .. "for your user only (no admin rights). REAPER will pause for about one minute.\n\n"
        .. "Manual alternative, in a terminal:\npy install 3.12"
    end
    paragraph(s, 20, 62, W - 40)
    if has_pym then
      if button("Install Python 3.12", 20, H - 50, 170, 30, true) then
        local ok, out = M.pymanager_install("3.12")
        if ok then
          start_install(false)
        else
          fail("The Python install manager could not install Python 3.12.\n\n" .. tostring(out or ""))
        end
      end
      if button("Retry", 200, H - 50, 100, 30) then start_install(false) end
    else
      if button("Retry", 20, H - 50, 120, 30, true) then start_install(false) end
    end
    if button("Close", W - 120, H - 50, 100, 30) then gfx.quit() end
  end

  local function count_selected()
    local n = 0
    for i = 0, R.CountSelectedMediaItems(0) - 1 do
      local tk = R.GetActiveTake(R.GetSelectedMediaItem(0, i))
      if tk and not R.TakeIsMIDI(tk) then n = n + 1 end
    end
    return n
  end

  local function draw_options()
    local y = 64
    if mode == "drums" then
      header("Drums")
      local s = segmented("Source", y, { "Full mix", "Drums only" }, cfg.drums_only and 2 or 1)
      cfg.drums_only = (s == 2)
      text(cfg.drums_only and "The item already contains only drums."
        or "The drums are extracted from the mix first.", 150, y + 32, C.dim)
      y = y + 66
      local k = segmented("Kit pieces", y, { "4", "5", "6" }, cfg.kit - 3)
      cfg.kit = k + 3
      local desc = {
        [4] = "Kick, Snare, Toms, Cymbals",
        [5] = "Kick, Snare, Toms, Hi-Hat, Cymbals",
        [6] = "Kick, Snare, Toms, Hi-Hat, Ride, Crash",
      }
      text(desc[cfg.kit], 150, y + 32, C.dim)
      y = y + 66
    else
      header("Stems")
      local s = segmented("Separation", y, { "6 stems", "4 stems" }, cfg.stems == 6 and 1 or 2)
      cfg.stems = (s == 1) and 6 or 4
      text(cfg.stems == 6 and "Vocals, Drums, Bass, Guitar, Piano, Other"
        or "Vocals, Drums, Bass, Other", 150, y + 32, C.dim)
      y = y + 66
      local qsel = segmented("Quality", y, { "Standard", "Vocals HQ" }, cfg.quality == "hq" and 2 or 1)
      cfg.quality = (qsel == 2) and "hq" or "std"
      text(cfg.quality == "hq" and "Vocals with RoFormer (best quality), about twice as slow."
        or "Demucs for every stem (fastest).", 150, y + 32, C.dim)
      y = y + 66
    end
    cfg.folder = checkbox("Put the stems in a folder track", 150, y, cfg.folder)
    cfg.mute = checkbox("Mute the original item", 150, y + 28, cfg.mute)

    local n = count_selected()
    text(n == 0 and "Select one or more audio items." or (n .. " audio item(s) selected."),
      20, H - 84, n == 0 and C.err or C.text)
    if button("Split", 20, H - 50, 120, 30, true) and n > 0 then start_split() end
    if button("Close", W - 120, H - 50, 100, 30) then save_cfg(cfg) gfx.quit() end
  end

  local function draw_busy()
    if not task then return end
    local t = now()
    if task.kind == "install" then
      header("Installing the engine")
      text("One-time installation. Downloads can take several minutes.", 20, 62, C.dim)
    else
      header(mode == "drums" and "Drums" or "Stems")
      text(string.format("Item %d of %d:  %s", task.idx, #task.items, task.base_name or ""), 20, 62)
    end
    text(task.stage or "", 20, 100)
    -- bar
    local bx, by, bw, bh = 20, 130, W - 40, 14
    col(C.panel)
    gfx.rect(bx, by, bw, bh, 1)
    local pct = math.max(0, math.min(100, task.pct or 0))
    col(C.accent, 0.85)
    gfx.rect(bx, by, bw * pct / 100, bh, 1)
    -- moving highlight = "still working"
    local p = (t * 0.6) % 1
    col({ 1, 1, 1 }, 0.18)
    gfx.rect(bx + p * (bw - 60), by, 60, bh, 1)
    local el = t - (task.item_t0 or task.t0)
    text("Elapsed: " .. fmt_time(el), 20, 154, C.dim)
    if task.kind == "split" then
      text("Everything runs locally on this computer.", 20, 178, C.dim)
    end
    if button("Cancel", W - 120, H - 50, 100, 30) then cancel() end
  end

  local function draw_result()
    header(msg_err and "Error" or "Finished")
    paragraph(msg, 20, 62, W - 40, msg_err and C.err or C.text)
    if msg_err and msg_log and exists(msg_log) then
      if button("Open log", 20, H - 50, 120, 30) then M.open_path(msg_log) end
    end
    if button("OK", W - 120, H - 50, 100, 30, true) then
      if M.installed() then
        view = (mode == "install") and "reinstall" or "options"
      else
        view = "setup"
      end
    end
  end

  ---------------------------------------------------------------------------
  local function cleanup()
    if task then
      if task.ex then M.export_end(task.ex) end
      if task.pid then M.kill(task.pid) end
      task = nil
    end
    save_cfg(cfg)
  end

  gfx.init("ReNo StemSplit - " .. TITLES[mode], W, H)
  gfx.setfont(1, "Arial", 15)
  gfx.setfont(2, "Arial", 20, string.byte("b"))
  R.atexit(cleanup)

  local function loop()
    local ch = gfx.getchar()
    if ch < 0 then return end
    if ch == 27 and not task then gfx.quit() return end
    mx, my = gfx.mouse_x, gfx.mouse_y
    local cap = gfx.mouse_cap
    click = (cap & 1 == 1) and (prev_cap & 1 == 0)
    prev_cap = cap

    if task then
      local ok, e = pcall(update_task)
      if not ok then fail("Script error: " .. tostring(e)) end
    end

    col(C.bg)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)
    if view == "setup" then draw_setup()
    elseif view == "reinstall" then draw_reinstall()
    elseif view == "unsupported" then draw_unsupported()
    elseif view == "nopython" then draw_nopython()
    elseif view == "options" then draw_options()
    elseif view == "busy" then draw_busy()
    else draw_result() end
    gfx.update()
    R.defer(loop)
  end
  loop()
end

return M
