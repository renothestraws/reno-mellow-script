-- @noindex
-- ReNo Mellow - Chord Buddy : music theory library
-- (spelling, chord building, inversions, voicings, chord recognition)
-- Pure Lua, no REAPER call: can be tested outside REAPER.

local T = {}

---------------------------------------------------------------------------
-- Circle of fifths
---------------------------------------------------------------------------

-- Pitch class of the major key at each wheel position (0 = top, clockwise),
-- as on the reference picture: C G D A E B F# Db Ab Eb Bb F
T.FIFTHS = { [0] = 0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5 }

-- Wheel position of a major key pitch class
T.POS_OF_PC = {}
for pos = 0, 11 do T.POS_OF_PC[T.FIFTHS[pos]] = pos end

-- Name of the major key (tonic) for each pitch class
local KEY_NAME = { [0] = "C", [7] = "G", [2] = "D", [9] = "A", [4] = "E", [11] = "B",
                   [6] = "F#", [1] = "Db", [8] = "Ab", [3] = "Eb", [10] = "Bb", [5] = "F" }

local LETTERS   = { "C", "D", "E", "F", "G", "A", "B" }
local LETTER_PC = { 0, 2, 4, 5, 7, 9, 11 }
local MAJOR     = { 0, 2, 4, 5, 7, 9, 11 }

local SHARPS = { [0] = "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
local FLATS  = { [0] = "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local MIXED  = { [0] = "C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" }

local SHARP_KEYS = { [7] = true, [2] = true, [9] = true, [4] = true, [11] = true, [6] = true }
local FLAT_KEYS  = { [5] = true, [10] = true, [3] = true, [8] = true, [1] = true }

local function acc_str(n)
  if n > 0 then return string.rep("#", n) end
  if n < 0 then return string.rep("b", -n) end
  return ""
end

local function letter_index(name)
  local l = name:sub(1, 1)
  for i = 1, 7 do if LETTERS[i] == l then return i end end
  return 1
end

local spell_cache = {}

-- Spelling table [pc] = name.
-- key_pc : tonic of the MAJOR key (for a minor key, pass its relative major)
-- mode   : "key" (default, follows the key), "sharps" or "flats"
function T.Spelling(key_pc, mode)
  mode = mode or "key"
  if mode == "sharps" then return SHARPS end
  if mode == "flats" then return FLATS end
  key_pc = (key_pc or 0) % 12
  if spell_cache[key_pc] then return spell_cache[key_pc] end

  local base
  if SHARP_KEYS[key_pc] then base = SHARPS
  elseif FLAT_KEYS[key_pc] then base = FLATS
  else base = MIXED end

  local names = {}
  for pc = 0, 11 do names[pc] = base[pc] end

  -- Diatonic notes spelled with one letter per degree (gives E# in F#)
  local li = letter_index(KEY_NAME[key_pc])
  for d = 0, 6 do
    local L = (li - 1 + d) % 7 + 1
    local pc = (key_pc + MAJOR[d + 1]) % 12
    local acc = (pc - LETTER_PC[L] + 6) % 12 - 6
    names[pc] = LETTERS[L] .. acc_str(acc)
  end

  spell_cache[key_pc] = names
  return names
end

function T.KeyName(key_pc, minor, spell_mode)
  if minor then
    local rel = (key_pc + 9) % 12          -- relative minor tonic
    return T.Spelling(key_pc, spell_mode)[rel] .. "m"
  end
  return T.Spelling(key_pc, spell_mode)[key_pc % 12]
end

-- Octave naming: offset 0 = REAPER default (note 60 = C4)
function T.NoteName(pitch, spell, oct_offset)
  local pc = pitch % 12
  local oct = math.floor(pitch / 12) - 1 + (oct_offset or 0)
  return spell[pc] .. tostring(oct)
end

-- MIDI pitch of a root note in a displayed octave
function T.RootPitch(root_pc, display_oct, oct_offset)
  return (display_oct + 1 - (oct_offset or 0)) * 12 + (root_pc % 12)
end

---------------------------------------------------------------------------
-- Wheel cells
---------------------------------------------------------------------------

-- ring: 1 = major (outer), 2 = minor (middle), 3 = diminished (inner)
-- Returns root pitch class and quality of the cell at a wheel position
function T.CellChord(pos, ring)
  local maj = T.FIFTHS[pos % 12]
  if ring == 1 then return maj, "maj" end
  if ring == 2 then return (maj + 9) % 12, "min" end
  return (maj + 11) % 12, "dim"
end

-- Degree of a cell in the active key, or nil if outside the key.
-- key_pos : wheel position of the active (relative) major key
-- Returns label ("I", "vi", "vii°"...) and the degree index 1..7 counted
-- in the relative major (used for colors, so a chord keeps its color in
-- both modes).
local MAJ_DEGREES = {
  -- [offset from key position][ring] = { label, degree index (1..7 in major) }
  [0]  = { [1] = { "I", 1 },  [2] = { "vi", 6 },  [3] = { "vii°", 7 } },
  [1]  = { [1] = { "V", 5 },  [2] = { "iii", 3 } },
  [11] = { [1] = { "IV", 4 }, [2] = { "ii", 2 } },
}
local MIN_LABEL = { -- same chords, labels seen from the relative minor
  [1] = "III", [2] = "iv", [3] = "v", [4] = "VI", [5] = "VII", [6] = "i", [7] = "ii°",
}

function T.CellDegree(pos, ring, key_pos, minor)
  local off = (pos - key_pos) % 12
  local row = MAJ_DEGREES[off]
  local d = row and row[ring]
  if not d then return nil end
  local deg = d[2]
  if minor then return MIN_LABEL[deg], deg end
  return d[1], deg
end

---------------------------------------------------------------------------
-- Chord building
---------------------------------------------------------------------------

T.TYPES = { "triad", "7", "maj7", "6", "sus2", "sus4", "add9" }
T.TYPE_LABEL = { triad = "Triad", ["7"] = "7", maj7 = "maj7", ["6"] = "6",
                 sus2 = "sus2", sus4 = "sus4", add9 = "add9" }

T.VOICINGS = { "close", "open", "drop2" }
T.VOICING_LABEL = { close = "Close", open = "Open", drop2 = "Drop 2" }

local QUALITY = { maj = { 4, 7 }, min = { 3, 7 }, dim = { 3, 6 } }

-- Intervals (semitones above the root) of a chord
--   quality : "maj", "min", "dim"  (from the wheel ring)
--   ctype   : one of T.TYPES
--   "7" adds a minor 7th, "maj7" a major 7th, "6" a major 6th, "add9" a 9th,
--   "sus2"/"sus4" replace the third.
function T.Intervals(quality, ctype)
  local q = QUALITY[quality] or QUALITY.maj
  local third, fifth = q[1], q[2]
  if ctype == "sus2" then third = 2 elseif ctype == "sus4" then third = 5 end
  local iv = { 0, third, fifth }
  if ctype == "7" then iv[4] = 10
  elseif ctype == "maj7" then iv[4] = 11
  elseif ctype == "6" then iv[4] = 9
  elseif ctype == "add9" then iv[4] = 14 end
  return iv
end

-- Number of notes of a chord type (= inversion range)
function T.ToneCount(quality, ctype)
  return #T.Intervals(quality, ctype)
end

local function sorted_copy(t)
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  table.sort(c)
  return c
end

-- Inversion: +1 moves the lowest note up an octave, -1 moves the highest
-- note down an octave, repeated |inv| times.
function T.Invert(pitches, inv)
  local p = sorted_copy(pitches)
  if #p == 0 then return p end
  inv = inv or 0
  for _ = 1, math.abs(inv) do
    if inv > 0 then
      local low = table.remove(p, 1)
      p[#p + 1] = low + 12
    else
      local high = table.remove(p)
      table.insert(p, 1, high - 12)
    end
    table.sort(p)
  end
  return p
end

-- Voicing applied after the inversion
--   close : unchanged
--   open  : second lowest note up an octave
--   drop2 : second highest note down an octave
function T.Voice(pitches, voicing)
  local p = sorted_copy(pitches)
  if #p < 3 or voicing == nil or voicing == "close" then return p end
  if voicing == "open" then
    p[2] = p[2] + 12
  elseif voicing == "drop2" then
    p[#p - 1] = p[#p - 1] - 12
  end
  table.sort(p)
  return p
end

local function clamp_range(p)
  local out = {}
  for i = 1, #p do
    if p[i] >= 0 and p[i] <= 127 then out[#out + 1] = p[i] end
  end
  return out
end

-- Upper structure (without added bass)
function T.Upper(root_pitch, quality, ctype, inv, voicing)
  local iv = T.Intervals(quality, ctype)
  local p = {}
  for i = 1, #iv do p[i] = root_pitch + iv[i] end
  p = T.Invert(p, inv)
  return T.Voice(p, voicing)
end

-- Root doubled an octave below, always under the lowest note
function T.AddBass(pitches, root_pitch)
  local p = sorted_copy(pitches)
  local b = root_pitch - 12
  if #p > 0 then
    while b >= p[1] do b = b - 12 end
  end
  table.insert(p, 1, b)
  return p
end

-- Full chord.
--   opts = { root_pc, octave (displayed), oct_offset, quality, ctype,
--            inv, voicing, bass (bool) }
-- Returns the sorted pitch list (0..127 only)
function T.Build(opts)
  local root = T.RootPitch(opts.root_pc, opts.octave or 4, opts.oct_offset)
  local p = T.Upper(root, opts.quality, opts.ctype, opts.inv or 0, opts.voicing)
  if opts.bass then p = T.AddBass(p, root) end
  return clamp_range(p)
end

---------------------------------------------------------------------------
-- Auto inversion (voice leading)
---------------------------------------------------------------------------

-- Distance between two chords: each note to its nearest note in the other
-- chord, both ways.
function T.VoiceLeadingCost(a, b)
  local cost = 0
  local function nearest_sum(x, y)
    local s = 0
    for i = 1, #x do
      local m = math.huge
      for j = 1, #y do
        local d = math.abs(x[i] - y[j])
        if d < m then m = d end
      end
      s = s + m
    end
    return s
  end
  cost = nearest_sum(a, b) + nearest_sum(b, a)
  return cost
end

-- Best inversion for opts compared to the previous chord's pitches.
-- The previous chord's lowest note is ignored when it lies more than an
-- octave under the rest (it is probably a bass note).
function T.BestInversion(opts, prev)
  if not prev or #prev == 0 then return opts.inv or 0 end
  local ref = sorted_copy(prev)
  if #ref >= 3 and ref[2] - ref[1] >= 12 then table.remove(ref, 1) end

  local n = T.ToneCount(opts.quality, opts.ctype)
  local root = T.RootPitch(opts.root_pc, opts.octave or 4, opts.oct_offset)
  local best, best_cost = 0, math.huge
  for inv = -n, n do
    local p = T.Upper(root, opts.quality, opts.ctype, inv, opts.voicing)
    local c = T.VoiceLeadingCost(p, ref)
    -- ties: keep the smallest |inv|
    if c < best_cost or (c == best_cost and math.abs(inv) < math.abs(best)) then
      best, best_cost = inv, c
    end
  end
  return best
end

---------------------------------------------------------------------------
-- Chord recognition
---------------------------------------------------------------------------

-- Ordered by priority (first match wins when the bass is not a root)
T.TEMPLATES = {
  { "",      { 0, 4, 7 } },
  { "m",     { 0, 3, 7 } },
  { "7",     { 0, 4, 7, 10 } },
  { "maj7",  { 0, 4, 7, 11 } },
  { "m7",    { 0, 3, 7, 10 } },
  { "dim",   { 0, 3, 6 } },
  { "m7b5",  { 0, 3, 6, 10 } },
  { "dim7",  { 0, 3, 6, 9 } },
  { "aug",   { 0, 4, 8 } },
  { "sus4",  { 0, 5, 7 } },
  { "sus2",  { 0, 2, 7 } },
  { "7sus4", { 0, 5, 7, 10 } },
  { "6",     { 0, 4, 7, 9 } },
  { "m6",    { 0, 3, 7, 9 } },
  { "add9",  { 0, 2, 4, 7 } },
  { "madd9", { 0, 2, 3, 7 } },
  { "mMaj7", { 0, 3, 7, 11 } },
  { "dimMaj7", { 0, 3, 6, 11 } },
  { "7",     { 0, 4, 10 } },      -- 7th without 5th
  { "maj7",  { 0, 4, 11 } },
  { "m7",    { 0, 3, 10 } },
  { "5",     { 0, 7 } },
}

local function pc_mask(list)
  local m = 0
  for i = 1, #list do m = m | (1 << (list[i] % 12)) end
  return m
end

local TEMPLATE_MASKS = {}
for i, t in ipairs(T.TEMPLATES) do TEMPLATE_MASKS[i] = pc_mask(t[2]) end

local function rotate_mask(mask, root)
  -- intervals of 'mask' relative to 'root'
  local m = 0
  for pc = 0, 11 do
    if mask & (1 << pc) ~= 0 then m = m | (1 << ((pc - root) % 12)) end
  end
  return m
end

-- Name the chord formed by a list of MIDI pitches.
-- Returns name, root_pc, bass_pc  (name = "?" if unknown, nil if empty)
-- A single pitch class returns its note name.
function T.Identify(pitches, spell)
  if not pitches or #pitches == 0 then return nil end
  local p = sorted_copy(pitches)
  local bass = p[1] % 12
  local mask = pc_mask(p)

  local count = 0
  for pc = 0, 11 do if mask & (1 << pc) ~= 0 then count = count + 1 end end
  if count == 1 then return spell[bass], bass, bass end

  local best_root, best_idx = nil, math.huge
  local bass_root, bass_idx = nil, math.huge
  for pc = 0, 11 do
    if mask & (1 << pc) ~= 0 then
      local rel = rotate_mask(mask, pc)
      for i = 1, #TEMPLATE_MASKS do
        if TEMPLATE_MASKS[i] == rel then
          if pc == bass and i < bass_idx then bass_root, bass_idx = pc, i end
          if i < best_idx then best_root, best_idx = pc, i end
          break
        end
      end
    end
  end

  -- A chord whose root is the bass wins, unless only a weak reading
  -- (no-5th 7ths, power chord) exists in root position.
  local root, idx = best_root, best_idx
  if bass_root and bass_idx <= 18 then root, idx = bass_root, bass_idx end
  if not root then return "?", nil, bass end

  local name = spell[root] .. T.TEMPLATES[idx][1]
  if root ~= bass then name = name .. "/" .. spell[bass] end
  return name, root, bass
end

-- Label of a wheel cell with the selected chord type (root position name).
local Q_SUFFIX = { maj = "", min = "m", dim = "dim" }
function T.CellLabel(root_pc, quality, ctype, spell)
  local p = T.Upper(60 + root_pc, quality, ctype, 0, "close")
  local name, root = T.Identify(p, spell)
  if name and name ~= "?" and root == root_pc then return name end
  -- rare combinations (dim + sus...): plain description
  return spell[root_pc] .. Q_SUFFIX[quality] .. (ctype ~= "triad" and (" " .. ctype) or "")
end

return T
