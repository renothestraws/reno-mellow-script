-- @description Recording Buddy (rehearse and record a loop in several passes)
-- @author ReNo Mellow
-- @version 1.1
-- @about Fenêtre à 2 onglets pour répéter puis enregistrer une boucle en plusieurs passes (pré-roll en mesures ou en ms, vitesse de lecture avec hauteur conservée, lecture ou enregistrement en auto-punch, pause entre les passes), mini Display et actions Start-Stop / Stop. Nécessite ReaImGui.
-- @changelog Icône de barre d'outils ReNo_RecordingBuddy (100 / 150 / 200 %), installée avec le script
-- @provides
--   RecBuddy_lib.lua
--   RecBuddy_startup.lua
--   [main] ReNo Mellow - Recording Buddy - Display.lua
--   [main] ReNo Mellow - Recording Buddy - Start-Stop.lua
--   [main] ReNo Mellow - Recording Buddy - Stop.lua
--   [data] Data/toolbar_icons/ReNo_RecordingBuddy.png > toolbar_icons/ReNo_RecordingBuddy.png
--   [data] Data/toolbar_icons/150/ReNo_RecordingBuddy.png > toolbar_icons/150/ReNo_RecordingBuddy.png
--   [data] Data/toolbar_icons/200/ReNo_RecordingBuddy.png > toolbar_icons/200/ReNo_RecordingBuddy.png

local dir = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
dofile(dir .. "RecBuddy_lib.lua")

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB("This script needs ReaImGui.\nInstall it with ReaPack (ReaTeam Extensions), then restart REAPER.",
    "Recording Buddy", 0)
  return
end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.9"

-- toolbar toggle on while open, launching it again closes the window
if reaper.set_action_options then reaper.set_action_options(1 | 4) end
local _, _, self_sec, self_cmd = reaper.get_action_context()
local function set_self_toggle(on)
  if self_cmd and self_cmd > 0 then
    reaper.SetToggleCommandState(self_sec, self_cmd, on and 1 or 0)
    reaper.RefreshToolbar2(self_sec, self_cmd)
  end
end
set_self_toggle(true)
RB.register_self("cmd_main")

-- first launch (manual install): adds the other actions to the action list
if reaper.GetExtState(RB.S, "reg_v") ~= RB.VERSION then
  for _, n in ipairs({ "Display", "Start-Stop", "Stop" }) do
    local path = dir .. "ReNo Mellow - Recording Buddy - " .. n .. ".lua"
    if reaper.file_exists(path) then reaper.AddRemoveReaScript(true, 0, path, n == "Stop") end
  end
  RB.set("reg_v", RB.VERSION)
end

---------------------------------------------------------------- colours (RRGGBBAA)
local COL_IDLE_BG = 0x33373DFF
local COL_GREEN   = 0x7CF0A6FF
local COL_PLAY_BG = 0x2F7D4FFF
local COL_REC_BG  = 0xB03A2EFF
local COL_PAUSE_BG = 0xC2871FFF
local COL_WHITE   = 0xFFFFFFFF
local COL_GREY    = 0x9A9A9AFF
local COL_RED     = 0xE05555FF
local COL_ORANGE  = 0xF0A040FF
local COL_GAUGE_BG = 0x24272BFF
local COL_PREROLL = 0x4A6FA5FF

local function lighten(c, a)
  local rr = math.min(255, ((c >> 24) & 255) + a)
  local g = math.min(255, ((c >> 16) & 255) + a)
  local b = math.min(255, ((c >> 8) & 255) + a)
  return (rr << 24) | (g << 16) | (b << 8) | (c & 255)
end

---------------------------------------------------------------- state
local ctx -- created just before the first frame
local FONT_MIN, FONT_MAX = 10, 28
local BIG_SIZES = { 16, 20, 24, 28, 32, 40, 48, 56, 64 }
local fonts, big = {}, {}

local passes = RB.load_passes()
local seqs, fresh = RB.load_sequences()
local cur_seq = tostring(RB.get("cur_seq", ""))
if fresh then -- first launch with sequences: start from the Default sequence
  passes = RB.copy(RB.DEFAULT)
  cur_seq = "Default"
  RB.set("cur_seq", cur_seq)
  RB.save_passes(passes)
end
local dirty = false
local post = nil -- modal dialogs / launches run after ImGui.End
local function later(fn) post = fn end

local function opt(k, d) return tonumber(RB.get(k, d)) or d end
local function text_size() return math.floor(RB.clamp(opt("font", 14), FONT_MIN, FONT_MAX)) end
local function btn_size() return math.floor(RB.clamp(opt("btn", 220), 100, 400)) end

local function big_font(px)
  local best = BIG_SIZES[1]
  for _, s in ipairs(BIG_SIZES) do if s <= px then best = s end end
  return big[best]
end

local function pct(rate) return RB.fmt_rate(rate * 100) end

---------------------------------------------------------------- tab 1 : Rec Buddy
local function draw_play_button(v)
  local bw = btn_size()
  local bh = math.floor(bw * 0.8)
  local avail = ImGui.GetContentRegionAvail(ctx)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (avail - bw) / 2))
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local clicked = ImGui.InvisibleButton(ctx, "##play", bw, bh)
  local hovered = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local bg, fg = COL_IDLE_BG, COL_GREEN
  if v.kind == "play" then bg, fg = COL_PLAY_BG, COL_WHITE
  elseif v.kind == "rec" then bg, fg = COL_REC_BG, COL_WHITE
  elseif v.kind == "pause" or v.kind == "tpause" then bg, fg = COL_PAUSE_BG, COL_WHITE end
  if hovered and not v.run then bg = lighten(bg, 18) end

  ImGui.DrawList_AddRectFilled(dl, x, y, x + bw, y + bh, bg, 14)
  if v.kind == "idle" then ImGui.DrawList_AddRect(dl, x, y, x + bw, y + bh, COL_GREEN, 14, 0, 2) end

  local cx, cy, s = x + bw / 2, y + bh * 0.40, bh * 0.2
  if v.kind == "rec" then
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, s, fg)
  elseif v.kind == "pause" or v.kind == "tpause" then
    local bwid = s * 0.55
    ImGui.DrawList_AddRectFilled(dl, cx - s * 0.8, cy - s, cx - s * 0.8 + bwid, cy + s, fg, 3)
    ImGui.DrawList_AddRectFilled(dl, cx + s * 0.8 - bwid, cy - s, cx + s * 0.8, cy + s, fg, 3)
  else
    ImGui.DrawList_AddTriangleFilled(dl, cx - s * 0.8, cy - s, cx - s * 0.8, cy + s, cx + s * 1.0, cy, fg)
  end

  local label
  if v.kind == "pause" then label = string.format("%.1f s", v.remain or 0)
  else label = pct(v.rate) end
  ImGui.PushFont(ctx, big_font(bh * 0.17))
  local tw, th = ImGui.CalcTextSize(ctx, label)
  ImGui.DrawList_AddText(dl, cx - tw / 2, y + bh * 0.76 - th / 2, fg, label)
  ImGui.PopFont(ctx)

  if hovered then
    if v.run then ImGui.SetTooltip(ctx, "Running. Use STOP to abort.")
    else ImGui.SetTooltip(ctx, "Start the passes on the time selection / loop") end
  end
  return clicked
end

local function draw_gauge(v, w, h, label)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COL_GAUGE_BG, 6)
  if v.preroll then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w * (v.preprog or 0), y + h, COL_PREROLL, 6)
  elseif (v.prog or 0) > 0 then
    local col = COL_PLAY_BG
    if v.kind == "rec" then col = COL_REC_BG elseif v.kind == "pause" then col = COL_PAUSE_BG end
    ImGui.DrawList_AddRectFilled(dl, x, y, x + math.max(6, w * v.prog), y + h, col, 6)
  end
  local th = ImGui.GetTextLineHeight(ctx)
  ImGui.DrawList_AddText(dl, x + 10, y + (h - th) / 2, COL_WHITE, label)
  local right = v.phase or ""
  local tw = ImGui.CalcTextSize(ctx, right)
  ImGui.DrawList_AddText(dl, x + w - tw - 10, y + (h - th) / 2, COL_WHITE, right)
end

local function tab_buddy(v)
  ImGui.Dummy(ctx, 0, 4)
  if draw_play_button(v) and not v.run then RB.start() end
  ImGui.Dummy(ctx, 0, 6)

  local w = ImGui.GetContentRegionAvail(ctx)
  local label
  if v.run then
    label = RB.pass_label(v.i, v.n, v.mode, v.prate)
  else
    label = "Pass : -"
  end
  draw_gauge(v, w, math.floor(ImGui.GetTextLineHeight(ctx) * 2), label)

  -- message or range
  local m, is_err = RB.recent_message()
  if m then
    ImGui.TextColored(ctx, is_err and COL_RED or COL_GREEN, m)
  else
    ImGui.Text(ctx, " ")
  end
  if v.r0 then
    ImGui.TextColored(ctx, COL_GREY, string.format("Range: %s  ->  %s%s", RB.fmt_time(v.r0), RB.fmt_time(v.r1),
      v.src and ("  (" .. v.src .. ")") or ""))
  else
    ImGui.TextColored(ctx, COL_ORANGE, "Set a time selection or a loop in the arrange view.")
  end

  ImGui.Dummy(ctx, 0, 6)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x8E2A22FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xB03A2EFF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xD04A3EFF)
  if ImGui.Button(ctx, "STOP", -1, math.floor(ImGui.GetTextLineHeight(ctx) * 2.2)) then RB.force_stop() end
  ImGui.PopStyleColor(ctx, 3)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Forced stop (recorded media is saved)") end
end

---------------------------------------------------------------- tab 2 : Set up
local function combo(id, cur, items)
  local val = cur
  local preview = cur
  for _, it in ipairs(items) do if it[1] == cur then preview = it[2] end end
  if ImGui.BeginCombo(ctx, id, preview) then
    for _, it in ipairs(items) do
      if ImGui.Selectable(ctx, it[2], it[1] == cur) then val = it[1] end
    end
    ImGui.EndCombo(ctx)
  end
  return val ~= cur, val
end

local UNITS = { { "bars", "bars" }, { "ms", "ms" } }
local MODES = { { "listen", "Listen" }, { "play", "Play" }, { "rec", "Record" }, { "shift", "Move on" } }
local MODE_BG = { listen = 0x24456EFF, rec = 0x6E2620FF, shift = 0x5E4C1CFF }

-- pre-roll = time between the edit cursor and the loop start of each pass
-- (unit of the pass). idx: list of pass indexes
local function preroll_from_cursor(idx)
  local plan = RB.plan(passes, RB.get_range())
  local cur = reaper.GetCursorPosition()
  local n = 0
  for _, i in ipairs(idx) do
    local p = passes[i]
    if p.mode ~= "shift" then
      local r0 = plan[i][1]
      if not r0 then RB.message("Set a time selection or a loop first.", true) return end
      local v = RB.preroll_from(cur, r0, p.unit)
      if not v then RB.message("Put the edit cursor before the loop start of pass " .. i .. ".", true) return end
      p.pre = v
      n = n + 1
    end
  end
  if n > 0 then dirty = true end
end

local function fmt_pos(t) return reaper.format_timestr_pos(t, "", 2) end -- measures.beats

-- loop start ("s") or end ("e") of pass i = edit cursor
local function set_loop_point(i, which)
  local p = passes[i]
  local pl = RB.plan(passes, RB.get_range())[i]
  local a, b = pl[1], pl[2]
  local cur = reaper.GetCursorPosition()
  if which == "s" then
    local len = (a and b) and (b - a) or nil
    a = cur
    if not b or b <= a + 0.01 then
      -- keep the length of the loop (one 4/4 bar when there is none)
      b = len and (a + len) or reaper.TimeMap2_QNToTime(0, reaper.TimeMap2_timeToQN(0, a) + 4)
    end
  else
    if not a then RB.message("Set the loop start of pass " .. i .. " first.", true) return end
    if cur <= a + 0.01 then RB.message("Put the edit cursor after the loop start of pass " .. i .. ".", true) return end
    b = cur
  end
  p.ls = reaper.TimeMap2_timeToQN(0, a)
  p.le = reaper.TimeMap2_timeToQN(0, b)
  dirty = true
end

local function fmt_dur(s)
  s = math.floor(s + 0.5)
  return string.format("%d:%02d", s // 60, s % 60)
end

local function launch_display()
  local path = dir .. "ReNo Mellow - Recording Buddy - Display.lua"
  local id = RB.get("cmd_display", "")
  local cmd = 0
  if id ~= "" then cmd = tonumber(id) or reaper.NamedCommandLookup(tostring(id)) or 0 end
  if cmd == 0 and reaper.file_exists(path) then cmd = reaper.AddRemoveReaScript(true, 0, path, true) or 0 end
  if cmd > 0 then reaper.Main_OnCommand(cmd, 0)
  else reaper.MB("Display script not found.", "Recording Buddy", 0) end
end

---------------------------------------------------------------- sequences (save / load)
local function seq_modified()
  local i = RB.find_sequence(seqs, cur_seq)
  if not i then return true end
  local a = {}
  for k = 1, #passes do a[k] = RB.clean_pass(passes[k]) end
  return RB.ser(a) ~= RB.ser(seqs[i].passes)
end

local function set_cur(name)
  cur_seq = name
  RB.set("cur_seq", name)
end

local function load_seq(i)
  passes = RB.copy(seqs[i].passes)
  dirty = true
  set_cur(seqs[i].name)
end

local function save_seq_as(name)
  local a = {}
  for k = 1, #passes do a[k] = RB.clean_pass(passes[k]) end
  local i = RB.find_sequence(seqs, name)
  if i then seqs[i].passes = a else seqs[#seqs + 1] = { name = name, passes = a } end
  RB.save_sequences(seqs)
  set_cur(name)
end

local function ask_save_as()
  local ok, name = reaper.GetUserInputs("Save sequence", 1, "Sequence name:,extrawidth=180", cur_seq)
  if not ok then return end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return end
  if RB.find_sequence(seqs, name) and name ~= cur_seq then
    if reaper.MB("A sequence named '" .. name .. "' already exists. Replace it?", "Recording Buddy", 1) ~= 1 then return end
  end
  save_seq_as(name)
end

local function draw_sequences()
  local modified = seq_modified()
  local known = RB.find_sequence(seqs, cur_seq) ~= nil
  local preview = known and (cur_seq .. (modified and " *" or "")) or "(not saved)"
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, "Sequence")
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 180)
  if ImGui.BeginCombo(ctx, "##seq", preview, ImGui.ComboFlags_HeightLarge) then
    for i, s in ipairs(seqs) do
      if ImGui.Selectable(ctx, s.name .. "  (" .. #s.passes .. ")", s.name == cur_seq) then
        if modified and #passes > 0 then
          later(function()
            if reaper.MB("Load '" .. s.name .. "'? The current changes are lost.", "Recording Buddy", 1) == 1 then
              load_seq(i)
            end
          end)
        else
          load_seq(i)
        end
      end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Save") then
    if known then save_seq_as(cur_seq) else later(ask_save_as) end
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Save the passes in the current sequence") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Save as...") then later(ask_save_as) end
  ImGui.SameLine(ctx)
  ImGui.BeginDisabled(ctx, not known)
  if ImGui.Button(ctx, "Delete") then
    later(function()
      if reaper.MB("Delete the sequence '" .. cur_seq .. "'?\n(The passes below stay as they are.)", "Recording Buddy", 1) == 1 then
        local i = RB.find_sequence(seqs, cur_seq)
        if i then table.remove(seqs, i) RB.save_sequences(seqs) end
        set_cur("")
      end
    end)
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Examples") then
    later(function()
      if reaper.MB("Put back the example sequences (Default, 4 takes, Practice)?\nSequences with the same names are replaced.",
          "Recording Buddy", 1) == 1 then
        RB.restore_examples(seqs)
      end
    end)
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Restore the example sequences") end
end

local function tab_setup(v)
  local running = v.run
  if running then
    ImGui.TextColored(ctx, COL_ORANGE, "A run is in progress: the passes can be edited once it is stopped.")
  else
    ImGui.TextColored(ctx, COL_GREY, "The passes run from top to bottom on the time selection (or the loop).")
  end
  ImGui.BeginDisabled(ctx, running)
  draw_sequences()
  ImGui.Dummy(ctx, 0, 2)

  local arr0, arr1 = RB.get_range()
  local plan = RB.plan(passes, arr0, arr1)
  local flags = ImGui.TableFlags_RowBg | ImGui.TableFlags_BordersInnerH | ImGui.TableFlags_SizingFixedFit
  local COLS = { { "#", 24 }, { "On", 28 }, { "Loop", 230 }, { "Pre-roll", 100 }, { "", 24 }, { "Unit", 64 }, { "Rate", 80 },
    { "Mode", 84 }, { "Pause", 80 }, { "", 84 } }
  local move, del = nil, nil
  if ImGui.BeginTable(ctx, "passes", #COLS, flags) then
    for _, c in ipairs(COLS) do ImGui.TableSetupColumn(ctx, c[1], ImGui.TableColumnFlags_WidthFixed, c[2]) end
    ImGui.TableHeadersRow(ctx)
    for i, p in ipairs(passes) do
      ImGui.PushID(ctx, i)
      ImGui.TableNextRow(ctx)
      local ch, val

      ImGui.TableNextColumn(ctx)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, tostring(i))

      ImGui.TableNextColumn(ctx)
      ch, val = ImGui.Checkbox(ctx, "##on", p.on)
      if ch then p.on = val dirty = true end

      local mv = (p.mode == "shift")
      -- loop of the pass: its own (set from the edit cursor) or "def" (arrangement loop)
      ImGui.TableNextColumn(ctx)
      local pl = plan[i]
      ImGui.AlignTextToFramePadding(ctx)
      if mv then
        ImGui.TextColored(ctx, COL_GREY, pl[1] and ("moves to " .. fmt_pos(pl[1])) or "moves on")
      else
        if ImGui.SmallButton(ctx, "[") then set_loop_point(i, "s") end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Loop start = edit cursor") end
        ImGui.SameLine(ctx, 0, 2)
        if ImGui.SmallButton(ctx, "]") then set_loop_point(i, "e") end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Loop end = edit cursor") end
        ImGui.SameLine(ctx)
        if pl.custom then
          ImGui.Text(ctx, fmt_pos(pl[1]) .. " - " .. fmt_pos(pl[2]))
          if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Own loop of this pass. Right-click: back to def") end
          if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then p.ls, p.le = nil, nil dirty = true end
          ImGui.SameLine(ctx)
          if ImGui.SmallButton(ctx, "def") then p.ls, p.le = nil, nil dirty = true end
          if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Back to def (the arrangement loop)") end
        else
          ImGui.TextColored(ctx, COL_GREY, pl[1] and ("def  " .. fmt_pos(pl[1]) .. " - " .. fmt_pos(pl[2])) or "def")
          if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "def: the arrangement loop (moved by the Move on passes above)")
          end
        end
      end
      ImGui.TableNextColumn(ctx)
      if mv then
        ImGui.AlignTextToFramePadding(ctx)
        ImGui.TextColored(ctx, COL_GREY, "  -")
      else
        ImGui.SetNextItemWidth(ctx, -1)
        if p.unit == "ms" then
          ch, val = ImGui.DragDouble(ctx, "##pre", p.pre, 1, 0, 60000, "%.2f ms")
        else
          ch, val = ImGui.DragDouble(ctx, "##pre", p.pre, 0.01, 0, 64, "%.2f bars")
        end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Drag, or Ctrl+click to type a value (2 decimals)") end
        if ch then p.pre = val dirty = true end
      end

      -- pre-roll from the edit cursor
      ImGui.TableNextColumn(ctx)
      if not mv then
        if ImGui.Button(ctx, "C") then preroll_from_cursor({ i }) end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Pre-roll = from the edit cursor to the loop start") end
      end

      ImGui.TableNextColumn(ctx)
      if not mv then
        ImGui.SetNextItemWidth(ctx, -1)
        ch, val = combo("##unit", p.unit, UNITS)
        if ch then
          -- keep about the same length when switching units
          local bpm = reaper.Master_GetTempo()
          if val == "ms" then p.pre = math.floor(p.pre * 4 * 60000 / bpm * 100 + 0.5) / 100
          else p.pre = math.max(0, math.floor(p.pre * bpm / (4 * 60000) * 100 + 0.5) / 100) end
          p.unit = val dirty = true
        end
      end

      ImGui.TableNextColumn(ctx)
      if mv then
        ImGui.AlignTextToFramePadding(ctx)
        ImGui.TextColored(ctx, COL_GREY, "  -")
      else
        ImGui.SetNextItemWidth(ctx, -1)
        ch, val = ImGui.DragDouble(ctx, "##rate", p.rate, 0.1, RB.RATE_MIN, RB.RATE_MAX, "%.1f %%")
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Drag, or Ctrl+click to type a value (steps of 0.1 %)") end
        if ch then p.rate = val dirty = true end
      end

      ImGui.TableNextColumn(ctx)
      ImGui.SetNextItemWidth(ctx, -1)
      local mbg = MODE_BG[p.mode]
      if mbg then ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, mbg) end
      ch, val = combo("##mode", p.mode, MODES)
      if mbg then ImGui.PopStyleColor(ctx) end
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Listen: plain playback\nPlay: armed tracks silent under the range\n"
          .. "Record: auto punch on the range\nMove on: stop, move the range one range length to the right,\n"
          .. "then wait the pause (no pre-roll, pause of at least " .. RB.SHIFT_MIN_PAUSE .. " s)")
      end
      if ch then
        p.mode = val dirty = true
        if val == "shift" and p.pause < RB.SHIFT_MIN_PAUSE then p.pause = 3 end
      end

      ImGui.TableNextColumn(ctx)
      ImGui.SetNextItemWidth(ctx, -1)
      ch, val = ImGui.DragDouble(ctx, "##pause", p.pause, 0.05, mv and RB.SHIFT_MIN_PAUSE or 0, 600, "%.1f s")
      if ch then p.pause = val dirty = true end

      ImGui.TableNextColumn(ctx)
      if ImGui.ArrowButton(ctx, "up", ImGui.Dir_Up) and i > 1 then move = { i, i - 1 } end
      ImGui.SameLine(ctx)
      if ImGui.ArrowButton(ctx, "dn", ImGui.Dir_Down) and i < #passes then move = { i, i + 1 } end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "X") and #passes > 1 then del = i end
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Delete this pass") end

      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end
  if move then
    passes[move[1]], passes[move[2]] = passes[move[2]], passes[move[1]]
    dirty = true
  end
  if del then table.remove(passes, del) dirty = true end

  if ImGui.Button(ctx, "Add pass") then
    passes[#passes + 1] = RB.copy(passes[#passes] or RB.DEFAULT[1])
    dirty = true
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "All pre-rolls from edit cursor") then
    local all = {}
    for k = 1, #passes do all[k] = k end
    preroll_from_cursor(all)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Every pre-roll = time between the edit cursor and the range start")
  end
  ImGui.EndDisabled(ctx)
  do
    local m, is_err = RB.recent_message(4)
    if m and is_err then ImGui.TextColored(ctx, COL_RED, m) end
  end

  -- notes
  for i, p in ipairs(passes) do
    if p.on and p.mode == "rec" and math.abs(p.rate - 100) > 0.01 then
      ImGui.TextColored(ctx, COL_ORANGE, string.format("Pass %d records at %s: the take will not be at the song speed.",
        i, RB.fmt_rate(p.rate)))
    end
  end
  do
    local tot, n, ok = 0, 0, true
    local last
    for i, p in ipairs(passes) do if p.on then n = n + 1 last = i end end
    for i, p in ipairs(passes) do
      if p.on then
        local pl = plan[i]
        if p.mode == "shift" or pl[1] then
          tot = tot + RB.pass_duration(p, pl[1], pl[2])
          if i == last then tot = tot - p.pause end -- no pause after the last pass
        else
          ok = false
        end
      end
    end
    if ok and n > 0 then
      ImGui.TextColored(ctx, COL_GREY, string.format("%d active pass%s, about %s in all.", n, n > 1 and "es" or "", fmt_dur(tot)))
    end
  end

  ImGui.Dummy(ctx, 0, 4)
  ImGui.Separator(ctx)
  ImGui.TextColored(ctx, COL_GREY, "Pitch is preserved at any rate. Recording uses time selection auto punch.")
  ImGui.TextColored(ctx, COL_GREY, "Every stop saves the recorded media.")
  ImGui.Dummy(ctx, 0, 4)

  ImGui.SetNextItemWidth(ctx, 160)
  local ch, val = ImGui.SliderInt(ctx, "Text size", text_size(), FONT_MIN, FONT_MAX)
  if ch then RB.set("font", val) end
  ImGui.SetNextItemWidth(ctx, 160)
  ch, val = ImGui.SliderInt(ctx, "Play button size", btn_size(), 100, 400)
  if ch then RB.set("btn", val) end
  ImGui.SetNextItemWidth(ctx, 160)
  ch, val = ImGui.SliderInt(ctx, "Display text size", math.floor(RB.clamp(opt("disp_font", 14), FONT_MIN, FONT_MAX)),
    FONT_MIN, FONT_MAX)
  if ch then RB.set("disp_font", val) end
  ImGui.SameLine(ctx, 0, 20)
  if ImGui.Button(ctx, RB.alive("display") and "Hide Display" or "Show Display") then later(launch_display) end
end

---------------------------------------------------------------- main loop
local function loop()
  local st = RB.tick("main")
  local v = RB.view(st)

  local want = reaper.GetExtState(RB.RT, "want_tab")
  local goto_tab = nil
  if want ~= "" then
    reaper.DeleteExtState(RB.RT, "want_tab", false)
    goto_tab = tonumber(want)
    ImGui.SetNextWindowFocus(ctx)
  end

  ImGui.PushFont(ctx, fonts[text_size()])
  ImGui.SetNextWindowSize(ctx, 900, 560, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, "ReNo Mellow - Recording Buddy " .. RB.VERSION, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "tabs") then
      if ImGui.BeginTabItem(ctx, "Rec Buddy", nil, goto_tab == 1 and ImGui.TabItemFlags_SetSelected or 0) then
        tab_buddy(v)
        ImGui.EndTabItem(ctx)
      end
      if ImGui.BeginTabItem(ctx, "Set up", nil, goto_tab == 2 and ImGui.TabItemFlags_SetSelected or 0) then
        tab_setup(v)
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if post then local f = post post = nil f() end
  if dirty then
    for i = 1, #passes do passes[i] = RB.clean_pass(passes[i]) end
    RB.save_passes(passes)
    dirty = false
  end
  if open then reaper.defer(loop) end
end

reaper.atexit(function()
  if reaper.set_action_options then reaper.set_action_options(8) end
  set_self_toggle(false)
  RB.leave("main")
end)

reaper.defer(function()
  ctx = ImGui.CreateContext("ReNo Mellow - Recording Buddy")
  for sz = FONT_MIN, FONT_MAX do
    fonts[sz] = ImGui.CreateFont("sans-serif", sz)
    ImGui.Attach(ctx, fonts[sz])
  end
  for _, sz in ipairs(BIG_SIZES) do
    big[sz] = ImGui.CreateFont("sans-serif", sz, ImGui.FontFlags_Bold)
    ImGui.Attach(ctx, big[sz])
  end
  loop()
end)
