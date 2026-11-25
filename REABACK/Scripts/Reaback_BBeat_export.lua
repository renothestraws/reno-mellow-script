-- @noindex
-- Reaback - Export to B.Beat (library used by "Reaback Set up.lua")
-- For every checked parent region (song) it writes a folder  <project folder>/Export to BBeat/<SONG>/  with:
--   <OUT>-<NAME>-<SONG>.wav  one 24-bit WAV per selected Audio track (post-FX, post-fader), mono or stereo
--   <OUT>-METRONOME-<SONG>.wav  the click (REAPER click source over the region), optional
--   <SONG>.mid   all selected MIDI tracks merged (channels untouched) + lyrics of the "lyrics" track
--   <SONG>.mp4   the selected Video tracks rendered together (format captured from the Render dialog)
--   <SONG>.pdf   chord chart: bars, sections (nested regions), chords ("chords" track), comments ("comment" track)
-- The file name prefix (1, 3-4 ...) is read by the B.Beat Manager to assign the outputs.

local M = {}

local SEC        = "REABACK_BBeat"          -- project ExtState section (per project settings)
local GSEC       = "REABACK_BBeat"          -- global ExtState section (templates, video format)
local EXPORT_DIR = "Export to BBeat"
local WAV24      = "ZXZhdxgAAA=="           -- render format string: WAV, 24 bit
local PPQ        = 960
local DISABLED_BASE = 10000                 -- REABACK: region ID >= 10000 = disabled region
local EPS        = 1e-6

local TYPES  = { "Audio", "MIDI", "Video", "PDF", "Lyrics", "Skip" }
local LYR_OUTS = { "MIDI", "MIDI + PDF" }
local LYR_OUTS_Z = "MIDI\0MIDI + PDF\0"
local OUTS = {}                               -- 1..16 mono, then the stereo pairs 1-2 .. 15-16
for i = 1, 16 do OUTS[#OUTS + 1] = tostring(i) end
for i = 1, 15 do OUTS[#OUTS + 1] = i .. "-" .. (i + 1) end
local function list_index(list, v) for i, x in ipairs(list) do if x == v then return i end end return 1 end
local function zstr(list) return table.concat(list, "\0") .. "\0" end
local TYPES_Z, OUTS_Z = zstr(TYPES), zstr(OUTS)
local function out_channels(out) return out:find("-", 1, true) and 2 or 1 end

local SEP = package.config:sub(1, 1)
local IS_WIN = SEP == "\\"

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function lower(s) return (s or ""):lower() end
local function safe_name(s)
  s = trim(s):gsub('[\\/:%*%?"<>|]', " "):gsub("%s+", " ")
  return trim(s)
end
-- "1-2-KEYS" -> "KEYS" : the output number is added by the export, never twice
local function strip_out_prefix(s)
  local r = (s or ""):gsub("^%s*%d%d?%s*%-%s*%d%d?%s*%-%s*", ""):gsub("^%s*%d%d?%s*%-%s*", "")
  return r
end
local function track_name(tr)
  local _, n = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return n or ""
end
local function track_guid(tr) return reaper.GetTrackGUID(tr) end
local function split_lines(s)
  local t = {}
  s = (s or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  s = s:gsub("<%s*/?%s*[bB][rR]%s*/?%s*>", " "):gsub("</?[%a][^<>]*>", "")   -- <br/>, </br> and other tags left in notes: removed
  for line in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = line end
  return t
end

-- UTF-8 -> Windows-1252 (PDF standard fonts, MIDI text)
local ASCII_SUB = { [0x2026]="...", [0x2018]="'", [0x2019]="'", [0x201A]=",", [0x201C]='"', [0x201D]='"',
  [0x201E]='"', [0x2013]="-", [0x2014]="-", [0x2022]="-", [0x2039]="<", [0x203A]=">", [0x0152]="OE", [0x0153]="oe",
  [0x20AC]="EUR", [0x2122]="TM" }
local CP1252 = { [0x20AC]=0x80, [0x201A]=0x82, [0x0192]=0x83, [0x201E]=0x84, [0x2026]=0x85, [0x2020]=0x86,
  [0x2021]=0x87, [0x02C6]=0x88, [0x2030]=0x89, [0x0160]=0x8A, [0x2039]=0x8B, [0x0152]=0x8C, [0x017D]=0x8E,
  [0x2018]=0x91, [0x2019]=0x92, [0x201C]=0x93, [0x201D]=0x94, [0x2022]=0x95, [0x2013]=0x96, [0x2014]=0x97,
  [0x02DC]=0x98, [0x2122]=0x99, [0x0161]=0x9A, [0x203A]=0x9B, [0x0153]=0x9C, [0x017E]=0x9E, [0x0178]=0x9F }
local function to_cp1252(s)
  s = s or ""
  local ok, out = pcall(function()
    local t = {}
    for _, c in utf8.codes(s) do
      if c < 128 or (c >= 160 and c <= 255) then t[#t + 1] = string.char(c)
      elseif ASCII_SUB[c] then t[#t + 1] = ASCII_SUB[c]
      elseif c >= 0x80 and c < 0xA0 then t[#t + 1] = (c == 0x85) and "..." or " "
      elseif CP1252[c] then t[#t + 1] = string.char(CP1252[c])
      else t[#t + 1] = "?" end
    end
    return table.concat(t)
  end)
  return ok and out or s
end
M.to_cp1252 = to_cp1252

-- MIDI text (lyrics, names): the B.Beat Manager reads UTF-8 (tested: Latin-1 accents show as diamonds).
-- REAPER strings are already UTF-8; control characters are removed.
local function midi_txt(s)
  s = (s or ""):gsub("[%z\1-\8\11\12\14-\31]", "")
  if utf8.len(s) then return s end
  return to_cp1252(s)                     -- invalid UTF-8: plain bytes as a last resort
end

local function base64_decode(s)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  s = (s or ""):gsub('[^' .. b .. '=]', '')
  return (s:gsub('.', function(x)
    if x == '=' then return '' end
    local r, f = '', (b:find(x, 1, true) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if #x ~= 8 then return '' end
    local c = 0
    for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
    return string.char(c)
  end))
end
local function format_fourcc(fmt)
  local raw = base64_decode(fmt)
  if #raw < 4 then return "?" end
  return raw:sub(1, 4):reverse()
end

------------------------------------------------------------------------
-- Project / regions
------------------------------------------------------------------------
local function project_dir()
  local _, fn = reaper.EnumProjects(-1)
  if not fn or fn == "" then return nil end
  return fn:match("^(.*)[\\/]")
end

local function region_key(idx, pos, rgnend)
  local ok, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. idx, "", false)
  if ok and guid and guid ~= "" then return guid end
  return string.format("pos:%.6f-%.6f", pos, rgnend)
end

local function read_regions()
  local out = {}
  for i = 0, reaper.CountProjectMarkers(0) - 1 do
    local ret, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers3(0, i)
    if ret and ret > 0 and isrgn and id < DISABLED_BASE then
      out[#out + 1] = { key = region_key(i, pos, rgnend), name = name or "", pos = pos, rgnend = rgnend, id = id }
    end
  end
  return out
end

local function contains(a, b)
  if a == b then return false end
  if a.pos <= b.pos + EPS and b.rgnend <= a.rgnend + EPS then
    return (b.pos - a.pos > EPS) or (a.rgnend - b.rgnend > EPS)
  end
  return false
end

-- parent regions (songs), each with its nested regions (sections) sorted by position
local function songs()
  local all = read_regions()
  local tops = {}
  for _, b in ipairs(all) do
    local inside = false
    for _, a in ipairs(all) do if contains(a, b) then inside = true; break end end
    if not inside then tops[#tops + 1] = b end
  end
  table.sort(tops, function(x, y) return x.pos < y.pos end)
  for n, t in ipairs(tops) do
    t.sections = {}
    for _, b in ipairs(all) do if contains(t, b) then t.sections[#t.sections + 1] = b end end
    table.sort(t.sections, function(x, y) return x.pos < y.pos end)
    t.title = safe_name(t.name)
    if t.title == "" then t.title = "SONG " .. n end
  end
  return tops
end

local function song_dir(song)
  local pd = project_dir()
  if not pd then return nil end
  return pd .. SEP .. EXPORT_DIR .. SEP .. song.title
end

------------------------------------------------------------------------
-- Settings (project ExtState)
------------------------------------------------------------------------
local function pget(key, default)
  local ok, v = reaper.GetProjExtState(0, SEC, key)
  if ok == 0 or v == "" then return default end
  return v
end
local function pset(key, v) reaper.SetProjExtState(0, SEC, key, v) end

local function find_tracks_named(word)
  local t = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    if lower(track_name(tr)):find(word, 1, true) then t[#t + 1] = tr end
  end
  return t
end

local function guess_type(tr)
  local n = lower(track_name(tr))
  if n:find("chords", 1, true) then return "PDF" end
  if n:find("lyrics", 1, true) then return "Lyrics" end
  if n:find("comment", 1, true) then return "Skip" end
  local has_midi, has_video = false, false
  for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
    local tk = reaper.GetActiveTake(reaper.GetTrackMediaItem(tr, i))
    if tk then
      local st = reaper.GetMediaSourceType(reaper.GetMediaItemTake_Source(tk), "")
      if st == "MIDI" or st == "MIDIPOOL" then has_midi = true
      elseif st == "VIDEO" or st == "VIDEOEFFECT" then has_video = true end
    end
  end
  if has_video then return "Video" end
  if has_midi then return "MIDI" end
  return "Audio"
end

-- settings of one track: { type, out, name }
local function track_settings(tr)
  local v = pget("trk_" .. track_guid(tr))
  if v then
    local ty, out, name = v:match("^(.-)\t(.-)\t(.*)$")
    if ty then return { type = ty, out = out, name = name } end
  end
  local ty = guess_type(tr)
  local ch = reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")
  local nm = track_name(tr)
  local out = nm:match("^%s*(%d%d?%-%d%d?)%s*%-") or nm:match("^%s*(%d%d?)%s*%-") or "1-2"
  local known = false
  for _, o in ipairs(OUTS) do if o == out then known = true end end
  if not known then out = "1-2" end
  return { type = ty, out = out, name = safe_name(strip_out_prefix(nm)):upper(), _new = true, _ch = ch }
end
local function save_track_settings(tr, s)
  pset("trk_" .. track_guid(tr), s.type .. "\t" .. s.out .. "\t" .. s.name)
end

local function click_settings()
  return {
    on   = pget("click_on", "1") == "1",
    out  = pget("click_out", "5"),
    name = pget("click_name", "CLICK"),
  }
end
local function save_click(c)
  pset("click_on", c.on and "1" or "0"); pset("click_out", c.out); pset("click_name", c.name)
end

-- checked songs: stored as the list of UNchecked keys (new songs are checked by default)
local function unchecked_set()
  local s, t = pget("unchecked", ""), {}
  for k in s:gmatch("[^;]+") do t[k] = true end
  return t
end
local function save_unchecked(t)
  local l = {}
  for k in pairs(t) do l[#l + 1] = k end
  pset("unchecked", table.concat(l, ";"))
end

------------------------------------------------------------------------
-- Output templates (global)
------------------------------------------------------------------------
local function template_names()
  local s = reaper.GetExtState(GSEC, "tpl_list")
  local t = {}
  for n in s:gmatch("[^\n]+") do t[#t + 1] = n end
  return t
end
local function save_template_names(t) reaper.SetExtState(GSEC, "tpl_list", table.concat(t, "\n"), true) end

local function template_key(name) return "tpl_" .. name:gsub("[^%w]", "_") end

local function save_template(name, rows, click)
  local lines = { "#click\t" .. (click.on and "1" or "0") .. "\t" .. click.out .. "\t" .. click.name }
  for _, r in ipairs(rows) do
    lines[#lines + 1] = lower(track_name(r.tr)) .. "\t" .. r.s.type .. "\t" .. r.s.out .. "\t" .. r.s.name
  end
  reaper.SetExtState(GSEC, template_key(name), table.concat(lines, "\n"), true)
  local names = template_names()
  for _, n in ipairs(names) do if n == name then return end end
  names[#names + 1] = name
  table.sort(names)
  save_template_names(names)
end

local function delete_template(name)
  reaper.DeleteExtState(GSEC, template_key(name), true)
  local names, out = template_names(), {}
  for _, n in ipairs(names) do if n ~= name then out[#out + 1] = n end end
  save_template_names(out)
end

-- returns number of tracks matched
local function apply_template(name, rows, click)
  local s = reaper.GetExtState(GSEC, template_key(name))
  local map, n = {}, 0
  for line in s:gmatch("[^\n]+") do
    local a, b, c, d = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
    if a == "#click" then
      click.on, click.out, click.name = (b == "1"), c, d
      save_click(click)
    elseif a then
      map[a] = { type = b, out = c, name = d }
    end
  end
  for _, r in ipairs(rows) do
    local m = map[lower(track_name(r.tr))]
    if m then
      r.s.type, r.s.out, r.s.name = m.type, m.out, m.name
      save_track_settings(r.tr, r.s)
      n = n + 1
    end
  end
  return n
end

------------------------------------------------------------------------
-- MIDI file writer
------------------------------------------------------------------------
local function vlq(n)
  local b = { n & 0x7F }
  n = n >> 7
  while n > 0 do table.insert(b, 1, (n & 0x7F) | 0x80); n = n >> 7 end
  return string.char(table.unpack(b))
end
local function meta(ty, data) return "\xFF" .. string.char(ty) .. vlq(#data) .. data end

-- evs = { {tick, bytes}, ... } (sorted inside, stable); end_tick = end of track
-- B.Beat Manager bug (tested): with long gaps between events it mis-reads the lyric times (stuck values,
-- 65536-tick shifts). An empty text event every FILL ticks in every track avoids it.
local FILL = 4096
local function chunk(evs, end_tick)
  local last_t = end_tick
  for _, e in ipairs(evs) do if e[1] > last_t then last_t = e[1] end end
  for t = FILL, last_t - 1, FILL do evs[#evs + 1] = { t, "\xFF\x01\x00" } end
  for i, e in ipairs(evs) do e.i = i end
  table.sort(evs, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a.i < b.i end)
  local out, last = {}, 0
  for _, e in ipairs(evs) do
    local t = math.max(e[1], last)
    out[#out + 1] = vlq(t - last) .. e[2]
    last = t
  end
  out[#out + 1] = vlq(math.max(end_tick, last) - last) .. "\xFF\x2F\x00"
  local body = table.concat(out)
  return "MTrk" .. string.pack(">I4", #body) .. body
end
M.midi_chunk = chunk
M.midi_meta = meta

local function midi_file(chunks)
  return "MThd" .. string.pack(">I4I2I2I2", 6, 1, #chunks, PPQ) .. table.concat(chunks)
end
M.midi_file = midi_file

-- lyric lines -> lyric events.  lines = { {t0, t1, text}, ... } in seconds, sorted.
-- B.Beat Manager rule (tested): every "\r" opens the next prompter row at its own time; a row takes the time
-- of its first word. So: text at t0, "\r" at the end of the line; when a gap follows, one more "\r" just
-- before the next line makes an empty row (screen cleared) that starts at the end of the line.
local GAP = 1.0   -- seconds of silence after a line before the prompter is cleared
function M.lyric_events(lines, tick_of)
  local evs = {}
  for i, l in ipairs(lines) do
    local nxt = lines[i + 1]
    local t0, t1 = l[1], l[2]
    if nxt and nxt[1] < t1 then t1 = nxt[1] end
    local k0 = tick_of(t0)
    evs[#evs + 1] = { k0, meta(0x05, midi_txt(l[3])) }
    local k1 = math.max(tick_of(t1), k0 + 1)
    evs[#evs + 1] = { k1, meta(0x05, "\r") }
    if nxt and nxt[1] - t1 > GAP then
      local k2 = math.max(tick_of(nxt[1]) - 1, k1 + 1)
      evs[#evs + 1] = { k2, meta(0x05, "\r") }
    end
  end
  return evs
end

------------------------------------------------------------------------
-- PDF writer (chord chart)
------------------------------------------------------------------------
local function pdf_esc(s) return (to_cp1252(s):gsub("([\\%(%)])", "\\%1")) end
local function text_w(s, size) return #s * size * 0.55 end

-- PDF file from page content streams (standard Helvetica fonts, WinAnsi)
local function pdf_assemble(pages, title, W, H, MARG)
  local objs = {}
  local function add(s) objs[#objs + 1] = s; return #objs end
  add("<< /Type /Catalog /Pages 2 0 R >>")
  add("PAGES")
  add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
  add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
  add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>")
  local kids = {}
  for pi, p in ipairs(pages) do
    local footer = string.format("BT /F1 7 Tf %d 20 Td (%s - %d/%d) Tj ET", MARG, pdf_esc(title), pi, #pages)
    local content = table.concat(p, "\n") .. "\n" .. footer
    local cid = add(string.format("<< /Length %d >>\nstream\n%s\nendstream", #content, content))
    local pid = add(string.format("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] " ..
      "/Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R >> >> /Contents %d 0 R >>", W, H, cid))
    kids[#kids + 1] = pid .. " 0 R"
  end
  objs[2] = string.format("<< /Type /Pages /Kids [%s] /Count %d >>", table.concat(kids, " "), #kids)
  local out, offs = { "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n" }, {}
  local pos = #out[1]
  for i, o in ipairs(objs) do
    offs[i] = pos
    local s = string.format("%d 0 obj\n%s\nendobj\n", i, o)
    out[#out + 1] = s
    pos = pos + #s
  end
  local xref = { string.format("xref\n0 %d\n0000000000 65535 f \n", #objs + 1) }
  for i = 1, #objs do xref[#xref + 1] = string.format("%010d 00000 n \n", offs[i]) end
  out[#out + 1] = table.concat(xref)
  out[#out + 1] = string.format("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", #objs + 1, pos)
  return table.concat(out)
end

-- chart = { title, subtitle, rows = { {label, cells = {"Am","%",...}, first_bar, comment} } }
function M.pdf_chart(chart)
  local W, H, MARG = 595, 842, 40
  local LABEL_W = 95
  local CELL_W = (W - 2 * MARG - LABEL_W) / 4
  local CELL_H = 34
  local pages, cur = {}, nil
  local y
  local function new_page()
    cur = {}
    pages[#pages + 1] = cur
    y = H - MARG
  end
  local function txt(font, size, x, yy, s)
    cur[#cur + 1] = string.format("BT /%s %.1f Tf %.2f %.2f Td (%s) Tj ET", font, size, x, yy, pdf_esc(s))
  end
  local function line(x1, y1, x2, y2) cur[#cur + 1] = string.format("%.2f %.2f m %.2f %.2f l S", x1, y1, x2, y2) end

  new_page()
  txt("F2", 20, MARG, y - 20, chart.title)
  y = y - 34
  if chart.subtitle and chart.subtitle ~= "" then
    txt("F1", 10, MARG, y - 8, chart.subtitle)
    y = y - 22
  end
  y = y - 6
  cur[#cur + 1] = "0.6 w"
  for _, r in ipairs(chart.rows) do
    local need = CELL_H + (r.comment and 16 or 0) + 6
    if y - need < MARG then new_page() ; cur[#cur + 1] = "0.6 w" end
    local top, bottom = y, y - CELL_H
    if r.label and r.label ~= "" then txt("F2", 10, MARG, bottom + CELL_H / 2 - 4, r.label) end
    local x0 = MARG + LABEL_W
    local nc = #r.cells
    line(x0, top, x0 + nc * CELL_W, top)
    line(x0, bottom, x0 + nc * CELL_W, bottom)
    for c = 0, nc do line(x0 + c * CELL_W, top, x0 + c * CELL_W, bottom) end
    for c, s in ipairs(r.cells) do
      local cx = x0 + (c - 1) * CELL_W
      if r.first_bar then txt("F1", 6, cx + 2, top - 7, tostring(r.first_bar + c - 1)) end
      if s ~= "" then
        local size = 14
        local w = text_w(s, size)
        if w > CELL_W - 8 then size = math.max(7, size * (CELL_W - 8) / w); w = text_w(s, size) end
        txt("F2", size, cx + (CELL_W - w) / 2, bottom + CELL_H / 2 - size / 3, s)
      end
    end
    y = bottom - 4
    if r.comment then
      txt("F3", 9, x0 + 2, y - 9, r.comment)
      y = y - 14
    end
    y = y - 4
  end

  return pdf_assemble(pages, chart.title, W, H, MARG)
end

-- text sheet: items = { {kind = "h" (section) | "p" (line) | "i" (comment) | "gap", text} }
function M.pdf_text(title, subtitle, items)
  local W, H, MARG = 595, 842, 50
  local pages, cur, y = {}, nil, 0
  local function new_page() cur = {}; pages[#pages + 1] = cur; y = H - MARG end
  local function txt(font, size, x, yy, s)
    cur[#cur + 1] = string.format("BT /%s %.1f Tf %.2f %.2f Td (%s) Tj ET", font, size, x, yy, pdf_esc(s))
  end
  local function wrap(s, size, width)            -- word wrap with the rough Helvetica width
    local lines, line = {}, ""
    for word in s:gmatch("%S+") do
      local try = (line == "") and word or (line .. " " .. word)
      if text_w(try, size) * 0.92 > width and line ~= "" then lines[#lines + 1] = line; line = word
      else line = try end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
  end
  new_page()
  txt("F2", 20, MARG, y - 20, title)
  y = y - 34
  if subtitle and subtitle ~= "" then txt("F1", 10, MARG, y - 8, subtitle); y = y - 24 end
  local style = { h = { "F2", 12, 10, 22 }, p = { "F1", 13, 0, 18 }, i = { "F3", 10, 0, 15 } }
  for _, it in ipairs(items) do
    if it.kind == "gap" then
      y = y - 10
    else
      local st = style[it.kind] or style.p
      local font, size, before, lh = st[1], st[2], st[3], st[4]
      local lines = wrap(it.text, size, W - 2 * MARG)
      if y - before - lh * #lines < MARG then new_page() end
      y = y - before
      for _, l in ipairs(lines) do txt(font, size, MARG, y - size, l); y = y - lh end
    end
  end
  return pdf_assemble(pages, title, W, H, MARG)
end

-- bars = { {chords = {"Am", ...}, section = "Verse 1" or nil (only on the first bar of a section)} }
-- comments_at = { [bar index] = "text" }  -> rows of 4 bars, a new row at each section start
function M.chart_rows(bars, comments_at, first_bar_number)
  local rows, row = {}, nil
  local last = nil
  for i, b in ipairs(bars) do
    if not row or #row.cells == 4 or b.section then
      row = { label = b.section or "", cells = {}, first_bar = (first_bar_number or 1) + i - 1 }
      rows[#rows + 1] = row
    end
    local s
    if #b.chords > 0 then s = table.concat(b.chords, "  "); last = s
    elseif last then s = "%" else s = "" end
    row.cells[#row.cells + 1] = s
    if comments_at[i] then row.comment = row.comment and (row.comment .. "  /  " .. comments_at[i]) or comments_at[i] end
  end
  return rows
end

------------------------------------------------------------------------
-- Rendering (REAPER render engine)
------------------------------------------------------------------------
local RNUM = { "RENDER_SETTINGS", "RENDER_BOUNDSFLAG", "RENDER_STARTPOS", "RENDER_ENDPOS", "RENDER_CHANNELS",
               "RENDER_SRATE", "RENDER_TAILFLAG", "RENDER_ADDTOPROJ", "RENDER_NORMALIZE" }
local RSTR = { "RENDER_FILE", "RENDER_PATTERN", "RENDER_FORMAT", "RENDER_FORMAT2" }

local function save_render()
  local s = { n = {}, s = {} }
  for _, k in ipairs(RNUM) do s.n[k] = reaper.GetSetProjectInfo(0, k, 0, false) end
  for _, k in ipairs(RSTR) do local _, v = reaper.GetSetProjectInfo_String(0, k, "", false); s.s[k] = v end
  return s
end
local function restore_render(s)
  for k, v in pairs(s.n) do reaper.GetSetProjectInfo(0, k, v, true) end
  for k, v in pairs(s.s) do reaper.GetSetProjectInfo_String(0, k, v, true) end
end

local function save_selection()
  local t = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do t[#t + 1] = reaper.GetSelectedTrack(0, i) end
  local ts, te = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  return { tracks = t, ts = ts, te = te, cur = reaper.GetCursorPosition() }
end
local function restore_selection(s)
  reaper.Main_OnCommand(40297, 0)                       -- unselect all tracks
  for _, tr in ipairs(s.tracks) do
    if reaper.ValidatePtr2(0, tr, "MediaTrack*") then reaper.SetTrackSelected(tr, true) end
  end
  reaper.GetSet_LoopTimeRange(true, false, s.ts, s.te, false)
  reaper.SetEditCurPos(s.cur, false, false)
end

local function select_only(tracks)
  reaper.Main_OnCommand(40297, 0)
  for _, tr in ipairs(tracks) do reaper.SetTrackSelected(tr, true) end
end

local function file_exists(p) local f = io.open(p, "rb"); if f then f:close(); return true end return false end

-- render the selected tracks; settings: 2 = stems (post-FX, post-fader), 128 = selected tracks via master
local function render(dir, base, settings, chans, fmt, rs, re)
  local P, PS = reaper.GetSetProjectInfo, reaper.GetSetProjectInfo_String
  P(0, "RENDER_SETTINGS", settings, true)
  P(0, "RENDER_BOUNDSFLAG", 0, true)
  P(0, "RENDER_STARTPOS", rs, true)
  P(0, "RENDER_ENDPOS", re, true)
  P(0, "RENDER_CHANNELS", chans, true)
  P(0, "RENDER_SRATE", 0, true)
  P(0, "RENDER_TAILFLAG", 0, true)
  P(0, "RENDER_ADDTOPROJ", 0, true)
  P(0, "RENDER_NORMALIZE", 0, true)
  PS(0, "RENDER_FILE", dir, true)
  PS(0, "RENDER_PATTERN", base, true)
  PS(0, "RENDER_FORMAT", fmt, true)
  PS(0, "RENDER_FORMAT2", "", true)
  reaper.Main_OnCommand(42230, 0)   -- File: Render project, using the most recent render settings, auto-close render dialog
end

local function find_action_by_name(name)
  name = name:lower()
  local sec = reaper.SectionFromUniqueID(0)
  if reaper.kbd_enumerateActions then
    local i = 0
    while i < 200000 do
      local cmd, n = reaper.kbd_enumerateActions(sec, i)
      if not cmd or cmd == 0 then break end
      if (n or ""):lower() == name then return cmd end
      i = i + 1
    end
  end
end

local function click_action()
  local n = reaper.kbd_getTextFromCmd and reaper.kbd_getTextFromCmd(40013, reaper.SectionFromUniqueID(0)) or ""
  if n:lower():find("click", 1, true) then return 40013 end
  return find_action_by_name("Insert click source")
end

------------------------------------------------------------------------
-- Lyric lines of one song: { {t0, t1, text}, ... }
------------------------------------------------------------------------
function M.lyric_lines(song)
  local rs, re = song.pos, song.rgnend
  -- lyrics: items of the "lyrics" track(s); several lines in one item are spread over the item
  local lines = {}
  for _, tr in ipairs(find_tracks_named("lyrics")) do
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local item = reaper.GetTrackMediaItem(tr, i)
      local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local iend = ipos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      if iend > rs + EPS and ipos < re - EPS then
        local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        local tl = {}
        for _, l in ipairs(split_lines(notes)) do if trim(l) ~= "" then tl[#tl + 1] = trim(l) end end
        local a, b = math.max(ipos, rs), math.min(iend, re)
        local step = (#tl > 0) and (b - a) / #tl or 0
        for k, l in ipairs(tl) do lines[#lines + 1] = { a + (k - 1) * step, a + k * step, l } end
      end
    end
  end
  table.sort(lines, function(x, y) return x[1] < y[1] end)
  return lines
end

------------------------------------------------------------------------
-- MIDI + lyrics of one song
------------------------------------------------------------------------
local function midi_of_song(song, midi_tracks)
  local rs, re = song.pos, song.rgnend
  local qn0 = reaper.TimeMap2_timeToQN(0, rs)
  local function tick_of(t)
    return math.max(0, math.floor((reaper.TimeMap2_timeToQN(0, t) - qn0) * PPQ + 0.5))
  end
  local end_tick = tick_of(re)

  -- tempo / time signature track
  local tevs = { { 0, meta(0x03, midi_txt(song.title)) } }
  local function tempo_at(t)
    local q = reaper.TimeMap2_timeToQN(0, t)
    local d = reaper.TimeMap2_QNToTime(0, q + 0.001) - reaper.TimeMap2_QNToTime(0, q)
    return math.floor(d / 0.001 * 1e6 + 0.5)
  end
  local function add_tempo(t)
    local us = tempo_at(t + 1e-4)
    local num, den = reaper.TimeMap_GetTimeSigAtTime(0, t + 1e-4)
    local dd = math.floor(math.log(den, 2) + 0.5)
    tevs[#tevs + 1] = { tick_of(t), meta(0x51, string.pack(">I3", us)) }
    tevs[#tevs + 1] = { tick_of(t), meta(0x58, string.char(num, dd, 24, 8)) }
  end
  add_tempo(rs)
  for i = 0, reaper.CountTempoTimeSigMarkers(0) - 1 do
    local _, tp = reaper.GetTempoTimeSigMarker(0, i)
    if tp > rs + EPS and tp < re - EPS then add_tempo(tp) end
  end
  local chunks = { chunk(tevs, end_tick) }

  -- one MIDI track per REAPER track
  for _, tr in ipairs(midi_tracks) do
    local evs = { { 0, meta(0x03, midi_txt(track_name(tr))) } }
    local active = {}
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local item = reaper.GetTrackMediaItem(tr, i)
      local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local iend = ipos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local take = reaper.GetActiveTake(item)
      if take and reaper.TakeIsMIDI(take) and reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 0
         and iend > rs and ipos < re then
        local ok, buf = reaper.MIDI_GetAllEvts(take, "")
        local p, ppq = 1, 0
        while ok and p < #buf do
          local off, flags, msg
          off, flags, msg, p = string.unpack("i4Bs4", buf, p)
          ppq = ppq + off
          local b0 = msg:byte(1)
          if b0 and (flags & 2) == 0 and b0 ~= 0xFF then
            local t = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq)
            local st, ch = b0 & 0xF0, b0 & 0x0F
            local is_on  = st == 0x90 and (msg:byte(3) or 0) > 0
            local is_off = st == 0x80 or (st == 0x90 and (msg:byte(3) or 0) == 0)
            local key = ch * 128 + (msg:byte(2) or 0)
            local inside = t >= math.max(rs, ipos) - EPS and t < math.min(re, iend) - EPS
            if is_off then
              if active[key] and active[key] > 0 then
                active[key] = active[key] - 1
                evs[#evs + 1] = { math.min(tick_of(math.min(t, iend, re)), end_tick), msg }
              end
            elseif inside then
              if is_on then active[key] = (active[key] or 0) + 1 end
              if b0 == 0xF0 then
                local data = msg:sub(2)
                evs[#evs + 1] = { tick_of(t), "\xF0" .. vlq(#data) .. data }
              elseif b0 < 0xF0 then
                evs[#evs + 1] = { tick_of(t), msg }
              end
            end
          end
        end
      end
    end
    for key, n in pairs(active) do               -- notes still held at the end of the song
      for _ = 1, n do
        evs[#evs + 1] = { end_tick, string.char(0x80 | (key // 128), key % 128, 0) }
      end
    end
    chunks[#chunks + 1] = chunk(evs, end_tick)
  end

  local lines = M.lyric_lines(song)
  if #lines > 0 then
    local levs = M.lyric_events(lines, tick_of)
    table.insert(levs, 1, { 0, meta(0x03, "Lyrics") })
    chunks[#chunks + 1] = chunk(levs, end_tick)
  end
  return midi_file(chunks), #lines, #midi_tracks
end

------------------------------------------------------------------------
-- Chord chart of one song
------------------------------------------------------------------------
local function items_in(word, rs, re, tracks)
  local out = {}
  for _, tr in ipairs(tracks or find_tracks_named(word)) do
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local item = reaper.GetTrackMediaItem(tr, i)
      local p = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      if p >= rs - EPS and p < re - EPS then
        local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        out[#out + 1] = { pos = p, text = notes or "" }
      end
    end
  end
  table.sort(out, function(a, b) return a.pos < b.pos end)
  return out
end

-- chart of one song from the item notes of one track (the "PDF" type track); comments from the "comment" track
local function chart_of_song(song, tr, label)
  local rs, re = song.pos, song.rgnend
  local _, m0 = reaper.TimeMap2_timeToBeats(0, rs + 1e-4)
  local bars = {}
  local m = m0
  while true do
    local _, qs, qe = reaper.TimeMap_GetMeasureInfo(0, m)
    local t0, t1 = reaper.TimeMap2_QNToTime(0, qs), reaper.TimeMap2_QNToTime(0, qe)
    if t0 >= re - 1e-3 or #bars > 2000 then break end
    bars[#bars + 1] = { t0 = t0, t1 = t1, chords = {} }
    m = m + 1
  end
  local function bar_of(t)
    for i, b in ipairs(bars) do if t >= b.t0 - 1e-3 and t < b.t1 - 1e-3 then return i end end
    return #bars
  end
  for _, c in ipairs(items_in(nil, rs, re, { tr })) do
    local first = trim(split_lines(c.text)[1] or "")
    if first ~= "" then local bi = bar_of(c.pos); table.insert(bars[bi].chords, first) end
  end
  for _, s in ipairs(song.sections) do
    local bi = bar_of(s.pos)
    if bars[bi] and not bars[bi].section then bars[bi].section = trim(s.name) ~= "" and trim(s.name) or "-" end
  end
  local comments = {}
  for _, c in ipairs(items_in("comment", rs, re)) do
    local t = trim((c.text:gsub("[\r\n]+", " ")))
    if t ~= "" then
      local bi = bar_of(c.pos)
      comments[bi] = comments[bi] and (comments[bi] .. "  /  " .. t) or t
    end
  end
  local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(0, rs + 1e-4)
  local chart = {
    title = (label and label ~= "") and (song.title .. " - " .. label) or song.title,
    subtitle = string.format("%d/%d  -  %.0f BPM", num, den, bpm),
    rows = M.chart_rows(bars, comments, 1),
  }
  return M.pdf_chart(chart), #bars
end

-- lyrics sheet (PDF): sections (nested regions), lyric lines, comments in italic, a gap after each silence
local function lyrics_sheet(song, label)
  local ev = {}
  for _, s in ipairs(song.sections) do
    ev[#ev + 1] = { t = s.pos, o = 0, kind = "h", text = trim(s.name) ~= "" and trim(s.name) or "-" }
  end
  for _, c in ipairs(items_in("comment", song.pos, song.rgnend)) do
    local t = trim((c.text:gsub("[\r\n]+", " ")))
    if t ~= "" then ev[#ev + 1] = { t = c.pos, o = 1, kind = "i", text = t } end
  end
  local lines = M.lyric_lines(song)
  for i, l in ipairs(lines) do
    ev[#ev + 1] = { t = l[1], o = 2, kind = "p", text = l[3] }
    local nxt = lines[i + 1]
    if nxt and nxt[1] - l[2] > GAP then ev[#ev + 1] = { t = l[2], o = 3, kind = "gap" } end
  end
  table.sort(ev, function(a, b) if math.abs(a.t - b.t) > 1e-6 then return a.t < b.t end return a.o < b.o end)
  local items, last = {}, nil
  for _, e in ipairs(ev) do
    if not (e.kind == "gap" and (last == "gap" or last == "h")) then items[#items + 1] = e; last = e.kind end
  end
  local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(0, song.pos + 1e-4)
  local title = (label and label ~= "") and (song.title .. " - " .. label) or song.title
  return M.pdf_text(title, string.format("%d/%d  -  %.0f BPM", num, den, bpm), items), #lines
end

------------------------------------------------------------------------
-- Export of the checked songs
------------------------------------------------------------------------
-- the generated click is always marked "REAPER" so it never takes the name of a click track of the session
local function click_file_name(name)
  local n = safe_name(strip_out_prefix(name))
  if n == "" then n = "CLICK" end
  if not n:upper():find("REAPER", 1, true) then n = n .. " REAPER" end
  return n
end

-- sample rate of the first WAV already rendered in the folder (the click follows the stems)
local function wav_rate(dir)
  local i = 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then return nil end
    if f:lower():sub(-4) == ".wav" then
      local h = io.open(dir .. SEP .. f, "rb")
      if h then
        local d = h:read(64) or ""
        h:close()
        local p = d:find("fmt ", 1, true)
        if p and #d >= p + 15 then
          local sr = string.unpack("<I4", d, p + 12)
          if sr >= 8000 and sr <= 384000 then return sr end
        end
      end
    end
    i = i + 1
  end
end
local function project_rate()
  local use = reaper.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false)
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if use == 1 and sr and sr > 0 then return math.floor(sr) end
  return 48000
end

-- click WAV (24 bit): accent on the first beat of each bar, follows tempo and time signature changes
function M.write_click(path, rs, re, sr, chans)
  local N = math.floor((re - rs) * sr + 0.5)
  if N <= 0 then return false, "empty region" end
  local function burst(freq, amp)
    local len, t = math.floor(sr * 0.03), {}
    for i = 0, len - 1 do
      local env = math.exp(-i / (sr * 0.006))
      local v = math.floor(amp * env * math.sin(2 * math.pi * freq * i / sr) * 8388607 + 0.5)
      local smp = string.pack("<i3", v)
      t[#t + 1] = chans == 2 and (smp .. smp) or smp
    end
    return t
  end
  local ACC, BEAT = burst(1500, 0.8), burst(1000, 0.6)
  -- beat list
  local clicks = {}
  local _, m = reaper.TimeMap2_timeToBeats(0, rs + 1e-6)
  local guard = 0
  while guard < 5000 do
    guard = guard + 1
    local _, qs, qe, num, den = reaper.TimeMap_GetMeasureInfo(0, m)
    if reaper.TimeMap2_QNToTime(0, qs) >= re then break end
    local step = 4 / (den > 0 and den or 4)
    for b = 0, (num > 0 and num or 4) - 1 do
      local q = qs + b * step
      if q >= qe - 1e-9 then break end
      local t = reaper.TimeMap2_QNToTime(0, q)
      if t >= rs - 1e-6 and t < re then clicks[#clicks + 1] = { math.floor((t - rs) * sr + 0.5), b == 0 } end
    end
    m = m + 1
  end
  local f = io.open(path, "wb")
  if not f then return false, "cannot write file" end
  local bpf = 3 * chans
  local size = N * bpf
  f:write("RIFF", string.pack("<I4", 36 + size), "WAVE", "fmt ",
          string.pack("<I4I2I2I4I4I2I2", 16, 1, chans, sr, sr * bpf, bpf, 24), "data", string.pack("<I4", size))
  local zero = string.rep("\0", bpf)
  local function silence(n)
    while n > 0 do
      local k = math.min(n, 262144)
      f:write(string.rep(zero, k))
      n = n - k
    end
  end
  local pos = 0
  for i, c in ipairs(clicks) do
    local s0 = math.max(c[1], pos)
    if s0 < N then
      silence(s0 - pos)
      local buf = c[2] and ACC or BEAT
      local nxt = clicks[i + 1] and clicks[i + 1][1] or N
      local len = math.min(#buf, nxt - s0, N - s0)
      if len > 0 then f:write(table.concat(buf, "", 1, len)) end
      pos = s0 + math.max(len, 0)
    end
  end
  silence(N - pos)
  f:close()
  return true
end

local function clear_dir(dir)
  local i, files = 0, {}
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    files[#files + 1] = dir .. SEP .. f
    i = i + 1
  end
  for _, f in ipairs(files) do os.remove(f) end
end

local function write_file(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data); f:close()
  return true
end

function M.export(list, rows, click)
  if not project_dir() then return false, "Save the project first: the export goes next to the .rpp file." end
  local audio, midi, video, pdfs, lyr = {}, {}, {}, {}, {}
  for _, r in ipairs(rows) do
    if r.s.type == "Audio" then audio[#audio + 1] = r
    elseif r.s.type == "MIDI" then midi[#midi + 1] = r.tr
    elseif r.s.type == "Video" then video[#video + 1] = r.tr
    elseif r.s.type == "PDF" then pdfs[#pdfs + 1] = r
    elseif r.s.type == "Lyrics" and r.s.out == "MIDI + PDF" then lyr[#lyr + 1] = r end
  end
  local vfmt = reaper.GetExtState(GSEC, "video_fmt")
  local warn = {}
  if #video > 0 and vfmt == "" then warn[#warn + 1] = "video skipped (capture the video format first)" end

  local sel = save_selection()
  local rset = save_render()
  local done = 0
  reaper.Undo_BeginBlock()
  for _, song in ipairs(list) do
    local dir = song_dir(song)
    reaper.RecursiveCreateDirectory(dir, 0)
    clear_dir(dir)
    local suffix = "-" .. song.title
    local used = {}
    local function unique(base)            -- two files with the same name: the second one gets " 2", " 3"...
      local b, n = base, 1
      while used[b:lower()] do n = n + 1; b = base .. " " .. n end
      used[b:lower()] = true
      return b
    end
    -- audio stems
    for _, r in ipairs(audio) do
      select_only({ r.tr })
      -- a stem is silent when the track does not send to the master (outputs routed to hardware):
      -- master send turned on for the render only, then restored
      local ms  = reaper.GetMediaTrackInfo_Value(r.tr, "B_MAINSEND")
      local mso = reaper.GetMediaTrackInfo_Value(r.tr, "C_MAINSEND_OFFS")
      reaper.SetMediaTrackInfo_Value(r.tr, "B_MAINSEND", 1)
      reaper.SetMediaTrackInfo_Value(r.tr, "C_MAINSEND_OFFS", 0)
      render(dir, unique(r.s.out .. "-" .. safe_name(strip_out_prefix(r.s.name))) .. suffix, 2, out_channels(r.s.out), WAV24, song.pos, song.rgnend)
      reaper.SetMediaTrackInfo_Value(r.tr, "B_MAINSEND", ms)
      reaper.SetMediaTrackInfo_Value(r.tr, "C_MAINSEND_OFFS", mso)
    end
    -- click: written directly from the tempo / time signature map (no render)
    if click.on then
      local name = unique(click.out .. "-" .. click_file_name(click.name)) .. suffix .. ".wav"
      local ok, err = M.write_click(dir .. SEP .. name, song.pos, song.rgnend, wav_rate(dir) or project_rate(),
                                    out_channels(click.out))
      if not ok then warn[#warn + 1] = "click not written (" .. tostring(err) .. ")" end
    end
    -- video
    if #video > 0 and vfmt ~= "" then
      select_only(video)
      local saved = {}
      for _, tr in ipairs(video) do
        saved[tr] = reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND")
        reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 1)
      end
      render(dir, song.title, 128, 2, vfmt, song.pos, song.rgnend)
      for tr, v in pairs(saved) do reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", v) end
    end
    -- MIDI + lyrics
    local mid, nl = midi_of_song(song, midi)
    if #midi > 0 or nl > 0 then write_file(dir .. SEP .. song.title .. ".mid", mid) end
    -- one chart (PDF) per selected "PDF" track; the B.Beat Manager accepts several PDFs (one per instrument)
    for _, r in ipairs(pdfs) do
      local label = safe_name(strip_out_prefix(r.s.name))
      local pdf = chart_of_song(song, r.tr, label)
      write_file(dir .. SEP .. unique(song.title .. (label ~= "" and (" - " .. label) or "")) .. ".pdf", pdf)
    end
    for _, r in ipairs(lyr) do                 -- lyrics sheet
      local label = safe_name(strip_out_prefix(r.s.name))
      local pdf, n = lyrics_sheet(song, label)
      if n > 0 then
        write_file(dir .. SEP .. unique(song.title .. (label ~= "" and (" - " .. label) or "")) .. ".pdf", pdf)
      end
    end
    done = done + 1
  end
  restore_render(rset)
  restore_selection(sel)
  reaper.Undo_EndBlock("Reaback: export to B.Beat", -1)
  reaper.UpdateArrange()
  local msg = string.format("Exported %d song(s) to '%s'.", done, EXPORT_DIR)
  if #warn > 0 then msg = msg .. " Warning: " .. table.concat(warn, "; ") .. "." end
  return true, msg, #warn > 0
end

------------------------------------------------------------------------
-- Open folder
------------------------------------------------------------------------
local function open_folder(dir)
  if reaper.CF_ShellExecute then reaper.CF_ShellExecute(dir); return end
  if IS_WIN then os.execute('start "" "' .. dir .. '"')
  elseif reaper.GetOS():find("OSX") or reaper.GetOS():find("mac") then os.execute('open "' .. dir .. '"')
  else os.execute('xdg-open "' .. dir .. '" &') end
end

------------------------------------------------------------------------
-- UI (drawn inside the "Reaback Set up" window)
------------------------------------------------------------------------
local ui = { tpl_idx = 0, pending = nil }

local function selected_rows()
  local rows = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local tr = reaper.GetSelectedTrack(0, i)
    local s = track_settings(tr)
    if s._new then s._new = nil; s._ch = nil; save_track_settings(tr, s) end
    rows[#rows + 1] = { tr = tr, s = s }
  end
  return rows
end

function M.draw(ctx, ImGui, say)
  local list = songs()
  local unchecked = unchecked_set()
  local avail = ImGui.GetContentRegionAvail(ctx)

  -- Songs
  ImGui.Text(ctx, "Songs (parent regions)")
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "All") then save_unchecked({}) ; unchecked = {} end
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "None") then
    unchecked = {}
    for _, s in ipairs(list) do unchecked[s.key] = true end
    save_unchecked(unchecked)
  end
  if #list == 0 then ImGui.TextDisabled(ctx, "No region in the project.") end
  local checked = {}
  for i, s in ipairs(list) do
    ImGui.PushID(ctx, "song" .. i)
    local on = not unchecked[s.key]
    local ch, v = ImGui.Checkbox(ctx, "##on", on)
    if ch then
      if v then unchecked[s.key] = nil else unchecked[s.key] = true end
      save_unchecked(unchecked)
      on = v
    end
    if on then checked[#checked + 1] = s end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, s.title)
    ImGui.SameLine(ctx, math.max(avail - 150, 160))
    if ImGui.SmallButton(ctx, "Copy title") then
      ImGui.SetClipboardText(ctx, s.title)
      say("Copied: " .. s.title .. "  (paste it as the Audio Project title in the B.Beat Manager)")
    end
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Open folder") then
      local dir = song_dir(s)
      if not dir then say("Save the project first.", true)
      elseif not reaper.EnumerateFiles(dir, 0) and not reaper.EnumerateSubdirectories(dir, 0) then
        say("Nothing exported yet for '" .. s.title .. "'.", true)
      else open_folder(dir) end
    end
    ImGui.PopID(ctx)
  end

  -- Tracks
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Tracks (the tracks selected in REAPER)")
  local rows = selected_rows()
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "Reset from track names") then
    for _, r in ipairs(rows) do
      reaper.SetProjExtState(0, SEC, "trk_" .. track_guid(r.tr), "")
      local s = track_settings(r.tr); s._new = nil; s._ch = nil
      save_track_settings(r.tr, s); r.s = s
    end
    say("Type, Out and File name set again from the track names (e.g. '5-Metronome' -> Out 5, METRONOME).")
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Forgets the settings of the selected tracks and guesses them again:\nOut from the number at the start of the name, type from the content.") end
  local click = click_settings()
  local flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp
  if ImGui.BeginTable(ctx, "bbeat_tracks", 4, flags) then
    ImGui.TableSetupColumn(ctx, "Track", ImGui.TableColumnFlags_WidthStretch, 1.2)
    ImGui.TableSetupColumn(ctx, "Type", ImGui.TableColumnFlags_WidthFixed, 72)
    ImGui.TableSetupColumn(ctx, "Out", ImGui.TableColumnFlags_WidthFixed, 70)
    ImGui.TableSetupColumn(ctx, "File name", ImGui.TableColumnFlags_WidthStretch, 1.0)
    ImGui.TableHeadersRow(ctx)
    for i, r in ipairs(rows) do
      ImGui.PushID(ctx, "trk" .. i)
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      ImGui.Text(ctx, track_name(r.tr) ~= "" and track_name(r.tr) or ("Track " .. math.floor(reaper.GetMediaTrackInfo_Value(r.tr, "IP_TRACKNUMBER"))))
      ImGui.TableNextColumn(ctx)
      ImGui.SetNextItemWidth(ctx, -1)
      local ch, idx = ImGui.Combo(ctx, "##type", list_index(TYPES, r.s.type) - 1, TYPES_Z)
      if ch then r.s.type = TYPES[idx + 1]; save_track_settings(r.tr, r.s) end
      ImGui.TableNextColumn(ctx)
      if r.s.type == "Audio" then
        ImGui.SetNextItemWidth(ctx, -1)
        local ch2, oi = ImGui.Combo(ctx, "##out", list_index(OUTS, r.s.out) - 1, OUTS_Z)
        if ch2 then r.s.out = OUTS[oi + 1]; save_track_settings(r.tr, r.s) end
      elseif r.s.type == "Lyrics" then
        ImGui.SetNextItemWidth(ctx, -1)
        local ch2, oi = ImGui.Combo(ctx, "##lyr", list_index(LYR_OUTS, r.s.out) - 1, LYR_OUTS_Z)
        if ch2 then r.s.out = LYR_OUTS[oi + 1]; save_track_settings(r.tr, r.s) end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "MIDI: lyrics in <song>.mid (prompter)\nMIDI + PDF: also a lyrics sheet <song> - <name>.pdf") end
      else
        ImGui.TextDisabled(ctx, "-")
      end
      ImGui.TableNextColumn(ctx)
      if r.s.type == "Audio" or r.s.type == "PDF" or (r.s.type == "Lyrics" and r.s.out == "MIDI + PDF") then
        ImGui.SetNextItemWidth(ctx, -1)
        local ch3, nm = ImGui.InputText(ctx, "##name", r.s.name)
        if ch3 then r.s.name = nm; save_track_settings(r.tr, r.s) end
      elseif r.s.type == "MIDI" then ImGui.TextDisabled(ctx, "merged into <song>.mid")
      elseif r.s.type == "Lyrics" then ImGui.TextDisabled(ctx, "lyrics in <song>.mid")
      elseif r.s.type == "Video" then ImGui.TextDisabled(ctx, "rendered into <song>.mp4")
      else ImGui.TextDisabled(ctx, "not exported") end
      ImGui.PopID(ctx)
    end
    -- click row
    ImGui.PushID(ctx, "click")
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
    local chc, von = ImGui.Checkbox(ctx, "Click (metronome)", click.on)
    if chc then click.on = von; save_click(click) end
    ImGui.TableNextColumn(ctx)
    ImGui.TextDisabled(ctx, "Audio")
    ImGui.TableNextColumn(ctx)
    ImGui.SetNextItemWidth(ctx, -1)
    local cho, oi = ImGui.Combo(ctx, "##out", list_index(OUTS, click.out) - 1, OUTS_Z)
    if cho then click.out = OUTS[oi + 1]; save_click(click) end
    ImGui.TableNextColumn(ctx)
    ImGui.SetNextItemWidth(ctx, -1)
    local chn, nm = ImGui.InputText(ctx, "##name", click.name)
    if chn then click.name = nm; save_click(click) end
    ImGui.PopID(ctx)
    ImGui.EndTable(ctx)
  end
  if #rows == 0 then ImGui.TextDisabled(ctx, "Select the tracks to export in REAPER.") end

  -- channel count
  local chans = click.on and out_channels(click.out) or 0
  for _, r in ipairs(rows) do if r.s.type == "Audio" then chans = chans + out_channels(r.s.out) end end
  local over = chans > 16
  if over then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6B5AFF) end
  ImGui.Text(ctx, string.format("Audio channels: %d / 16", chans))
  if over then ImGui.PopStyleColor(ctx) end

  -- Templates
  ImGui.Spacing(ctx)
  local names = template_names()
  ImGui.Text(ctx, "Output template")
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 150)
  if #names > 0 then
    if ui.tpl_idx >= #names then ui.tpl_idx = 0 end
    local _, ti = ImGui.Combo(ctx, "##tpl", ui.tpl_idx, zstr(names))
    ui.tpl_idx = ti
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Load") then
      local n = apply_template(names[ui.tpl_idx + 1], rows, click)
      say(string.format("Template '%s' applied to %d track(s) (matched by track name).", names[ui.tpl_idx + 1], n))
    end
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Delete") then ui.pending = { kind = "tpl_delete", name = names[ui.tpl_idx + 1] } end
    ImGui.SameLine(ctx)
  else
    ImGui.TextDisabled(ctx, "(none)")
    ImGui.SameLine(ctx)
  end
  if ImGui.SmallButton(ctx, "Save as...") then ui.pending = { kind = "tpl_save", rows = rows, click = click } end

  -- Video format
  local vfmt = reaper.GetExtState(GSEC, "video_fmt")
  ImGui.Text(ctx, "Video format: " .. (vfmt ~= "" and format_fourcc(vfmt) or "not captured"))
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "Render dialog...") then ui.pending = { kind = "render_dialog" } end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Opens File > Render (action 40015) to choose the video format.") end
  ImGui.SameLine(ctx)
  if ImGui.SmallButton(ctx, "Capture from Render dialog") then ui.pending = { kind = "capture" } end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "1. File > Render...: choose a video format (MP4 / H.264 + AAC) and its settings.\n" ..
                          "2. Click 'Save changes and close'.\n3. Click this button: the format is kept for all projects.")
  end

  -- Export
  ImGui.Spacing(ctx)
  local label = string.format("Export %d song(s) to B.Beat", #checked)
  if ImGui.Button(ctx, label, ImGui.GetContentRegionAvail(ctx), 34) then
    if #checked == 0 then say("No song checked.", true)
    elseif over then say("More than 16 audio channels: B.Beat cannot play them.", true)
    else ui.pending = { kind = "export", list = checked, rows = rows, click = click } end
  end
end

-- runs what needs dialogs or renders, outside of the ImGui frame
function M.run_pending(say)
  local p = ui.pending
  if not p then return end
  ui.pending = nil
  if p.kind == "export" then
    local ok, msg, w = M.export(p.list, p.rows, p.click)
    say(msg, (not ok) or w)
  elseif p.kind == "tpl_save" then
    local ok, name = reaper.GetUserInputs("Save output template", 1, "Template name:,extrawidth=150", "")
    name = trim(name or "")
    if ok and name ~= "" then
      save_template(name, p.rows, p.click)
      say("Template saved: " .. name)
    end
  elseif p.kind == "tpl_delete" then
    if reaper.MB("Delete the template '" .. p.name .. "'?", "Reaback", 4) == 6 then
      delete_template(p.name)
      say("Template deleted: " .. p.name)
    end
  elseif p.kind == "render_dialog" then
    reaper.Main_OnCommand(40015, 0)       -- File: Render project to disk...
  elseif p.kind == "capture" then
    local _, fmt = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
    local cc = format_fourcc(fmt)
    if fmt == "" or cc == "evaw" or cc == "?" then
      say("The Render dialog is not set to a video format (found: " .. cc .. "). Choose a video format there first.", true)
    else
      reaper.SetExtState(GSEC, "video_fmt", fmt, true)
      say("Video format captured: " .. cc)
    end
  end
end

return M
