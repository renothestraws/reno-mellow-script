-- @noindex
-- ReNo Mellow - Custom Strips - Display
-- Small floating bar: Zoom / View / Scroll / Select on the left, the project's tags on the right.
-- Settings (View in TCP / MCP / both, Scroll in TCP / MCP / both, reopen at startup) are in the
-- Custom Strips window, tab "Display". Run the action again to close the Display.

local TITLE = "Custom Strips Display"
local EXT = "ReNo_CustomStrips"
local _, SCRIPT_FILE, SEC, CMD = reaper.get_action_context()

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs the ReaImGui extension.\n\nInstall it with ReaPack:\nExtensions > ReaPack > Browse packages > search \"ReaImGui\" > Install,\nthen restart REAPER.", TITLE, 0)
  if reaper.ReaPack_BrowsePackages then reaper.ReaPack_BrowsePackages("ReaImGui") end
  return
end

--------------------------------------------------------------------------------
-- Relaunch = close
--------------------------------------------------------------------------------
if reaper.set_action_options then reaper.set_action_options(1 | 4) end -- re-run terminates, toggle on
local hb = tonumber(reaper.GetExtState(EXT, "disp_hb")) or 0
if reaper.time_precise() - hb < 1.0 then
  reaper.SetExtState(EXT, "disp_quit", "1", false) -- the running Display closes itself
  return
end
reaper.SetExtState(EXT, "disp_quit", "0", false)

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------
local function get(key, default)
  local v = reaper.GetExtState(EXT, key)
  if v == "" then return default end
  return v
end
local function set(key, v) reaper.SetExtState(EXT, key, tostring(v), true) end

local opt = {
  zoom   = get("disp_opt_zoom", "0") == "1",
  view   = get("disp_opt_view", "1") == "1",
  scroll = get("disp_opt_scroll", "1") == "1",
  select = get("disp_opt_select", "0") == "1",
}
local font_size = tonumber(get("disp_font", "16")) or 16

--------------------------------------------------------------------------------
-- Startup block (Scripts/__startup.lua)
--------------------------------------------------------------------------------
local START_FILE = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
local MARK_A = "-- >>> ReNo Mellow Custom Strips Display (auto-start)"
local MARK_B = "-- <<< ReNo Mellow Custom Strips Display"

local function read_file(p)
  local f = io.open(p, "r"); if not f then return nil end
  local s = f:read("a"); f:close(); return s
end

local function ensure_startup_block()
  local s = read_file(START_FILE) or ""
  if s:find(MARK_A, 1, true) then return end
  local block = MARK_A .. "\n" ..
    "do\n" ..
    "  local p = " .. string.format("%q", SCRIPT_FILE) .. "\n" ..
    "  if reaper.file_exists(p) and reaper.GetExtState(\"" .. EXT .. "\", \"disp_startup\") ~= \"0\" then\n" ..
    "    local id = reaper.AddRemoveReaScript(true, 0, p, true)\n" ..
    "    if id and id ~= 0 then reaper.Main_OnCommand(id, 0) end\n" ..
    "  end\n" ..
    "end\n" .. MARK_B .. "\n"
  local f = io.open(START_FILE, "w")
  if f then f:write(s, (s ~= "" and not s:match("\n$")) and "\n" or "", block); f:close() end
end

if get("disp_startup", "1") ~= "0" then ensure_startup_block() end

--------------------------------------------------------------------------------
-- Tags of the project
--------------------------------------------------------------------------------
local function utf8_len(s)
  local ok, n = pcall(utf8.len, s); if ok and n then return n end; return #s
end

local function track_tag(tr)
  local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  local t = name:match("%[([^%[%]]+)%]%s*$")
  if t and utf8_len(t) <= 3 then return t end
end

local tags, tag_info = {}, {}   -- ordered list, tag -> {color=0xRRGGBB|nil, count=n}
local last_state = -1

local function scan_tags()
  local st = reaper.GetProjectStateChangeCount(0)
  if st == last_state then return end
  last_state = st
  tags, tag_info = {}, {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local t = track_tag(tr)
    if t then
      local inf = tag_info[t]
      if not inf then
        local c = reaper.GetTrackColor(tr)
        local col
        if c ~= 0 then local r, g, b = reaper.ColorFromNative(c); col = (r << 16) | (g << 8) | b end
        inf = { color = col, count = 0 }
        tag_info[t] = inf
        tags[#tags + 1] = t
      end
      inf.count = inf.count + 1
    end
  end
end

local function tracks_for(tag)
  local list = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    if tag == nil or track_tag(tr) == tag then list[#list + 1] = tr end
  end
  return list
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local function panes(key)
  local v = get(key, key == "disp_view" and "both" or "tcp")
  return v == "tcp" or v == "both", v == "mcp" or v == "both"
end

local function save_sel()
  local s = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do s[#s + 1] = reaper.GetSelectedTrack(0, i) end
  return s
end
local function restore_sel(s)
  for i = reaper.CountTracks(0) - 1, 0, -1 do reaper.SetTrackSelected(reaper.GetTrack(0, i), false) end
  for _, tr in ipairs(s) do if reaper.ValidatePtr(tr, "MediaTrack*") then reaper.SetTrackSelected(tr, true) end end
end
local function select_only(list)
  for i = reaper.CountTracks(0) - 1, 0, -1 do reaper.SetTrackSelected(reaper.GetTrack(0, i), false) end
  for _, tr in ipairs(list) do reaper.SetTrackSelected(tr, true) end
end

local function arrange_hwnd()
  if reaper.JS_Window_FindChildByID then return reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000) end
end

local message = ""

local function do_view(tag, list)
  local in_tcp, in_mcp = panes("disp_view")
  local keep = {}
  if tag then
    for _, tr in ipairs(list) do
      keep[tr] = true
      local p = reaper.GetParentTrack(tr)
      while p do keep[p] = true; p = reaper.GetParentTrack(p) end -- folder parents stay visible
    end
  end
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local v = (tag == nil or keep[tr]) and 1 or 0
    if in_tcp then reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", v) end
    if in_mcp then reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", v) end
  end
end

local function do_zoom(tag, list)
  if tag == nil then -- All: back to default heights
    for i = 0, reaper.CountTracks(0) - 1 do
      reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_HEIGHTOVERRIDE", 0)
    end
    return
  end
  local hwnd = arrange_hwnd()
  if hwnd then
    local ok, l, t, r, b = reaper.JS_Window_GetClientRect(hwnd)
    local h = ok and (b - t) or 0
    if h > 0 and #list > 0 then
      local per = math.max(24, math.floor((h - 8) / #list))
      for _, tr in ipairs(list) do reaper.SetMediaTrackInfo_Value(tr, "I_HEIGHTOVERRIDE", per) end
      return
    end
  end
  local sws = reaper.NamedCommandLookup("_SWS_VZOOMFIT")
  if sws and sws ~= 0 then
    local s = save_sel(); select_only(list)
    reaper.Main_OnCommand(sws, 0)
    if not opt.select then restore_sel(s) end
    return
  end
  message = "Zoom needs js_ReaScriptAPI or SWS (ReaPack)."
end

local function do_scroll(list)
  local tr = list[1]
  if not tr then return end
  local in_tcp, in_mcp = panes("disp_scroll")
  if in_mcp then reaper.SetMixerScroll(tr) end
  if in_tcp and reaper.GetMediaTrackInfo_Value(tr, "B_SHOWINTCP") == 1 then
    local hwnd = arrange_hwnd()
    if hwnd and reaper.JS_Window_GetScrollInfo then
      local ok, pos = reaper.JS_Window_GetScrollInfo(hwnd, "v")
      local y = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
      if ok then reaper.JS_Window_SetScrollPos(hwnd, "v", math.max(0, math.floor(pos + y))) end
    else
      local s = save_sel(); select_only({ tr })
      reaper.Main_OnCommand(40913, 0) -- Track: Vertical scroll selected tracks into view
      if not opt.select then restore_sel(s) end
    end
  end
end

local function run(tag)
  message = ""
  if not (opt.zoom or opt.view or opt.scroll or opt.select) then
    message = "Turn on Zoom, View, Scroll or Select first."
    return
  end
  local list = tracks_for(tag)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  if opt.view then do_view(tag, list) end
  if opt.select then select_only(list) end
  if opt.zoom then do_zoom(tag, list) end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  if opt.scroll then do_scroll(list) end
  local what = {}
  for _, k in ipairs({ "view", "zoom", "scroll", "select" }) do if opt[k] then what[#what + 1] = k end end
  reaper.Undo_EndBlock("Custom Strips Display: " .. table.concat(what, " + ") .. " " .. (tag or "all"), -1)
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

local FONT_SIZES = { 12, 14, 16, 18, 20, 24, 28 }
local ctx, fonts
local current = nil -- nil = All

local function rgba(c, a) return ((c & 0xFFFFFF) << 8) | (a or 0xFF) end

local function make_ctx()
  ctx = ImGui.CreateContext(TITLE)
  fonts = {}
  for _, s in ipairs(FONT_SIZES) do
    fonts[s] = ImGui.CreateFont("sans-serif", s)
    ImGui.Attach(ctx, fonts[s])
  end
end

local OPTS = { { "zoom", "Zoom" }, { "view", "View" }, { "scroll", "Scroll" }, { "select", "Select" } }

local function tag_label(t)
  if t == nil then return "All" end
  return t
end

local function step_tag(dir)
  local idx = 0
  for i, t in ipairs(tags) do if t == current then idx = i end end
  idx = idx + dir
  if idx < 0 then idx = #tags end
  if idx > #tags then idx = 0 end
  current = (idx == 0) and nil or tags[idx]
  run(current)
end

local function draw()
  local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoDocking | ImGui.WindowFlags_AlwaysAutoResize |
                ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoCollapse
  local visible, open = ImGui.Begin(ctx, TITLE, true, flags)
  if not visible then return open end
  ImGui.PushFont(ctx, fonts[font_size] or fonts[16])

  -- left part: options
  for i, o in ipairs(OPTS) do
    if i > 1 then ImGui.SameLine(ctx, 0, 4) end
    local on = opt[o[1]]
    if on then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x2E7D32FF)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x388E3CFF)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x1B5E20FF)
    end
    if ImGui.Button(ctx, o[2] .. "##opt") then
      opt[o[1]] = not on
      set("disp_opt_" .. o[1], opt[o[1]] and "1" or "0")
    end
    if on then ImGui.PopStyleColor(ctx, 3) end
  end

  ImGui.SameLine(ctx, 0, 10)
  ImGui.TextDisabled(ctx, "|")
  ImGui.SameLine(ctx, 0, 10)

  -- right part: tag selector
  local cur_col = current and tag_info[current] and tag_info[current].color
  if cur_col then
    ImGui.ColorButton(ctx, "##curcol", rgba(cur_col), ImGui.ColorEditFlags_NoTooltip, font_size, font_size)
    ImGui.SameLine(ctx, 0, 4)
  end
  local w = font_size * 6
  if ImGui.Button(ctx, tag_label(current) .. "  v##tagbtn", w) then ImGui.OpenPopup(ctx, "tags") end
  if ImGui.IsItemHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel > 0 then step_tag(-1) elseif wheel < 0 then step_tag(1) end
  end
  if ImGui.BeginPopup(ctx, "tags") then
    if ImGui.Selectable(ctx, "All", current == nil) then current = nil; run(nil) end
    ImGui.Separator(ctx)
    if #tags == 0 then ImGui.TextDisabled(ctx, "No [TAG] in this project") end
    for _, t in ipairs(tags) do
      local inf = tag_info[t]
      ImGui.ColorButton(ctx, "##c" .. t, inf.color and rgba(inf.color) or 0x555555FF,
        ImGui.ColorEditFlags_NoTooltip | ImGui.ColorEditFlags_NoBorder, font_size, font_size)
      ImGui.SameLine(ctx, 0, 6)
      if ImGui.Selectable(ctx, t .. "##t" .. t, current == t) then current = t; run(t) end
    end
    ImGui.EndPopup(ctx)
  end

  if message ~= "" then
    ImGui.SameLine(ctx, 0, 8)
    ImGui.TextColored(ctx, 0xFFB040FF, message)
  end

  -- right-click menu
  if ImGui.BeginPopupContextWindow(ctx, "dispmenu", ImGui.PopupFlags_MouseButtonRight | ImGui.PopupFlags_NoOpenOverItems) then
    ImGui.TextDisabled(ctx, "Text size")
    for _, s in ipairs(FONT_SIZES) do
      if ImGui.MenuItem(ctx, tostring(s) .. "##fs", nil, s == font_size) then font_size = s; set("disp_font", s) end
    end
    ImGui.Separator(ctx)
    local st = get("disp_startup", "1") ~= "0"
    if ImGui.MenuItem(ctx, "Reopen when REAPER starts", nil, st) then
      set("disp_startup", st and "0" or "1")
      if not st then ensure_startup_block() end
    end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Close") then open = false end
    ImGui.EndPopup(ctx)
  end

  ImGui.PopFont(ctx)
  ImGui.End(ctx)
  return open
end

--------------------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------------------
reaper.SetToggleCommandState(SEC, CMD, 1)
reaper.RefreshToolbar2(SEC, CMD)
reaper.atexit(function()
  reaper.SetExtState(EXT, "disp_hb", "0", false)
  reaper.SetToggleCommandState(SEC, CMD, 0)
  reaper.RefreshToolbar2(SEC, CMD)
end)

make_ctx() -- after the startup work, just before the first frame

local function loop()
  reaper.SetExtState(EXT, "disp_hb", tostring(reaper.time_precise()), false)
  if reaper.GetExtState(EXT, "disp_quit") == "1" then
    reaper.SetExtState(EXT, "disp_quit", "0", false)
    return
  end
  scan_tags()
  if current and not tag_info[current] then current = nil end
  if draw() then reaper.defer(loop) end
end

reaper.defer(loop)
