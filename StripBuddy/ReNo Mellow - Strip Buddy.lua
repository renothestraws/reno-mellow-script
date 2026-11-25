-- @description Strip Buddy (track presets window)
-- @author ReNo Mellow
-- @version 1.31
-- @about Fenêtre à 2 onglets : appliquer ses « strips » favoris aux pistes sélectionnées (nom, tag, couleur, icône, layout, entrée / record output, sorties, pan mode, metering, FX chain, FX d'entrée, enveloppes, items, normalisation, groupe) et les configurer. Nécessite ReaImGui.
-- @changelog Display dockable : clic droit sur la barre > « Dock in REAPER docker » (cocher / décocher), état retenu au prochain lancement
-- @provides
--   [main] ReNo Mellow - Strip Buddy - Display.lua
--   [data] Data/toolbar_icons/ReNo_StripBuddy.png > toolbar_icons/ReNo_StripBuddy.png
--   [data] Data/toolbar_icons/150/ReNo_StripBuddy.png > toolbar_icons/150/ReNo_StripBuddy.png
--   [data] Data/toolbar_icons/200/ReNo_StripBuddy.png > toolbar_icons/200/ReNo_StripBuddy.png
--   [data] Data/track_icons/cs_tags_808.png > track_icons/cs_tags_808.png
--   [data] Data/track_icons/cs_tags_909.png > track_icons/cs_tags_909.png
--   [data] Data/track_icons/cs_tags_ACC.png > track_icons/cs_tags_ACC.png
--   [data] Data/track_icons/cs_tags_ACG.png > track_icons/cs_tags_ACG.png
--   [data] Data/track_icons/cs_tags_ADL.png > track_icons/cs_tags_ADL.png
--   [data] Data/track_icons/cs_tags_ALT.png > track_icons/cs_tags_ALT.png
--   [data] Data/track_icons/cs_tags_AMB.png > track_icons/cs_tags_AMB.png
--   [data] Data/track_icons/cs_tags_AMP.png > track_icons/cs_tags_AMP.png
--   [data] Data/track_icons/cs_tags_ARP.png > track_icons/cs_tags_ARP.png
--   [data] Data/track_icons/cs_tags_AUX.png > track_icons/cs_tags_AUX.png
--   [data] Data/track_icons/cs_tags_BGV.png > track_icons/cs_tags_BGV.png
--   [data] Data/track_icons/cs_tags_BJO.png > track_icons/cs_tags_BJO.png
--   [data] Data/track_icons/cs_tags_BKG.png > track_icons/cs_tags_BKG.png
--   [data] Data/track_icons/cs_tags_BNG.png > track_icons/cs_tags_BNG.png
--   [data] Data/track_icons/cs_tags_BOX.png > track_icons/cs_tags_BOX.png
--   [data] Data/track_icons/cs_tags_BRA.png > track_icons/cs_tags_BRA.png
--   [data] Data/track_icons/cs_tags_BSS.png > track_icons/cs_tags_BSS.png
--   [data] Data/track_icons/cs_tags_BUS.png > track_icons/cs_tags_BUS.png
--   [data] Data/track_icons/cs_tags_CAJ.png > track_icons/cs_tags_CAJ.png
--   [data] Data/track_icons/cs_tags_CHD.png > track_icons/cs_tags_CHD.png
--   [data] Data/track_icons/cs_tags_CHN.png > track_icons/cs_tags_CHN.png
--   [data] Data/track_icons/cs_tags_CHO.png > track_icons/cs_tags_CHO.png
--   [data] Data/track_icons/cs_tags_CHR.png > track_icons/cs_tags_CHR.png
--   [data] Data/track_icons/cs_tags_CLK.png > track_icons/cs_tags_CLK.png
--   [data] Data/track_icons/cs_tags_CLO.png > track_icons/cs_tags_CLO.png
--   [data] Data/track_icons/cs_tags_CLP.png > track_icons/cs_tags_CLP.png
--   [data] Data/track_icons/cs_tags_CMT.png > track_icons/cs_tags_CMT.png
--   [data] Data/track_icons/cs_tags_CNG.png > track_icons/cs_tags_CNG.png
--   [data] Data/track_icons/cs_tags_CRS.png > track_icons/cs_tags_CRS.png
--   [data] Data/track_icons/cs_tags_CTB.png > track_icons/cs_tags_CTB.png
--   [data] Data/track_icons/cs_tags_CUE.png > track_icons/cs_tags_CUE.png
--   [data] Data/track_icons/cs_tags_CYM.png > track_icons/cs_tags_CYM.png
--   [data] Data/track_icons/cs_tags_DBL.png > track_icons/cs_tags_DBL.png
--   [data] Data/track_icons/cs_tags_DCA.png > track_icons/cs_tags_DCA.png
--   [data] Data/track_icons/cs_tags_DI.png > track_icons/cs_tags_DI.png
--   [data] Data/track_icons/cs_tags_DIA.png > track_icons/cs_tags_DIA.png
--   [data] Data/track_icons/cs_tags_DLY.png > track_icons/cs_tags_DLY.png
--   [data] Data/track_icons/cs_tags_DMX.png > track_icons/cs_tags_DMX.png
--   [data] Data/track_icons/cs_tags_DRM.png > track_icons/cs_tags_DRM.png
--   [data] Data/track_icons/cs_tags_ELG.png > track_icons/cs_tags_ELG.png
--   [data] Data/track_icons/cs_tags_FLT.png > track_icons/cs_tags_FLT.png
--   [data] Data/track_icons/cs_tags_FOK.png > track_icons/cs_tags_FOK.png
--   [data] Data/track_icons/cs_tags_FOL.png > track_icons/cs_tags_FOL.png
--   [data] Data/track_icons/cs_tags_FX.png > track_icons/cs_tags_FX.png
--   [data] Data/track_icons/cs_tags_GHO.png > track_icons/cs_tags_GHO.png
--   [data] Data/track_icons/cs_tags_GLJ.png > track_icons/cs_tags_GLJ.png
--   [data] Data/track_icons/cs_tags_GNG.png > track_icons/cs_tags_GNG.png
--   [data] Data/track_icons/cs_tags_GON.png > track_icons/cs_tags_GON.png
--   [data] Data/track_icons/cs_tags_GRP.png > track_icons/cs_tags_GRP.png
--   [data] Data/track_icons/cs_tags_GTR.png > track_icons/cs_tags_GTR.png
--   [data] Data/track_icons/cs_tags_HAR.png > track_icons/cs_tags_HAR.png
--   [data] Data/track_icons/cs_tags_HH.png > track_icons/cs_tags_HH.png
--   [data] Data/track_icons/cs_tags_HRM.png > track_icons/cs_tags_HRM.png
--   [data] Data/track_icons/cs_tags_HRN.png > track_icons/cs_tags_HRN.png
--   [data] Data/track_icons/cs_tags_IEM.png > track_icons/cs_tags_IEM.png
--   [data] Data/track_icons/cs_tags_IMG.png > track_icons/cs_tags_IMG.png
--   [data] Data/track_icons/cs_tags_KEY.png > track_icons/cs_tags_KEY.png
--   [data] Data/track_icons/cs_tags_KIK.png > track_icons/cs_tags_KIK.png
--   [data] Data/track_icons/cs_tags_LDV.png > track_icons/cs_tags_LDV.png
--   [data] Data/track_icons/cs_tags_LED.png > track_icons/cs_tags_LED.png
--   [data] Data/track_icons/cs_tags_LIS.png > track_icons/cs_tags_LIS.png
--   [data] Data/track_icons/cs_tags_LOP.png > track_icons/cs_tags_LOP.png
--   [data] Data/track_icons/cs_tags_LTC.png > track_icons/cs_tags_LTC.png
--   [data] Data/track_icons/cs_tags_LYR.png > track_icons/cs_tags_LYR.png
--   [data] Data/track_icons/cs_tags_MC.png > track_icons/cs_tags_MC.png
--   [data] Data/track_icons/cs_tags_MID.png > track_icons/cs_tags_MID.png
--   [data] Data/track_icons/cs_tags_MIX.png > track_icons/cs_tags_MIX.png
--   [data] Data/track_icons/cs_tags_MLR.png > track_icons/cs_tags_MLR.png
--   [data] Data/track_icons/cs_tags_MND.png > track_icons/cs_tags_MND.png
--   [data] Data/track_icons/cs_tags_MON.png > track_icons/cs_tags_MON.png
--   [data] Data/track_icons/cs_tags_MSC.png > track_icons/cs_tags_MSC.png
--   [data] Data/track_icons/cs_tags_MST.png > track_icons/cs_tags_MST.png
--   [data] Data/track_icons/cs_tags_MTC.png > track_icons/cs_tags_MTC.png
--   [data] Data/track_icons/cs_tags_MTX.png > track_icons/cs_tags_MTX.png
--   [data] Data/track_icons/cs_tags_MUS.png > track_icons/cs_tags_MUS.png
--   [data] Data/track_icons/cs_tags_NOI.png > track_icons/cs_tags_NOI.png
--   [data] Data/track_icons/cs_tags_NY.png > track_icons/cs_tags_NY.png
--   [data] Data/track_icons/cs_tags_OCT.png > track_icons/cs_tags_OCT.png
--   [data] Data/track_icons/cs_tags_OHS.png > track_icons/cs_tags_OHS.png
--   [data] Data/track_icons/cs_tags_ORC.png > track_icons/cs_tags_ORC.png
--   [data] Data/track_icons/cs_tags_ORG.png > track_icons/cs_tags_ORG.png
--   [data] Data/track_icons/cs_tags_PAD.png > track_icons/cs_tags_PAD.png
--   [data] Data/track_icons/cs_tags_PAR.png > track_icons/cs_tags_PAR.png
--   [data] Data/track_icons/cs_tags_PLB.png > track_icons/cs_tags_PLB.png
--   [data] Data/track_icons/cs_tags_PNO.png > track_icons/cs_tags_PNO.png
--   [data] Data/track_icons/cs_tags_PRC.png > track_icons/cs_tags_PRC.png
--   [data] Data/track_icons/cs_tags_PRD.png > track_icons/cs_tags_PRD.png
--   [data] Data/track_icons/cs_tags_RAP.png > track_icons/cs_tags_RAP.png
--   [data] Data/track_icons/cs_tags_REF.png > track_icons/cs_tags_REF.png
--   [data] Data/track_icons/cs_tags_REV.png > track_icons/cs_tags_REV.png
--   [data] Data/track_icons/cs_tags_RHD.png > track_icons/cs_tags_RHD.png
--   [data] Data/track_icons/cs_tags_RHY.png > track_icons/cs_tags_RHY.png
--   [data] Data/track_icons/cs_tags_RID.png > track_icons/cs_tags_RID.png
--   [data] Data/track_icons/cs_tags_ROO.png > track_icons/cs_tags_ROO.png
--   [data] Data/track_icons/cs_tags_ROT.png > track_icons/cs_tags_ROT.png
--   [data] Data/track_icons/cs_tags_RSP.png > track_icons/cs_tags_RSP.png
--   [data] Data/track_icons/cs_tags_RVB.png > track_icons/cs_tags_RVB.png
--   [data] Data/track_icons/cs_tags_SAX.png > track_icons/cs_tags_SAX.png
--   [data] Data/track_icons/cs_tags_SC.png > track_icons/cs_tags_SC.png
--   [data] Data/track_icons/cs_tags_SCR.png > track_icons/cs_tags_SCR.png
--   [data] Data/track_icons/cs_tags_SEQ.png > track_icons/cs_tags_SEQ.png
--   [data] Data/track_icons/cs_tags_SFX.png > track_icons/cs_tags_SFX.png
--   [data] Data/track_icons/cs_tags_SHK.png > track_icons/cs_tags_SHK.png
--   [data] Data/track_icons/cs_tags_SMP.png > track_icons/cs_tags_SMP.png
--   [data] Data/track_icons/cs_tags_SNR.png > track_icons/cs_tags_SNR.png
--   [data] Data/track_icons/cs_tags_SNS.png > track_icons/cs_tags_SNS.png
--   [data] Data/track_icons/cs_tags_SOL.png > track_icons/cs_tags_SOL.png
--   [data] Data/track_icons/cs_tags_SPD.png > track_icons/cs_tags_SPD.png
--   [data] Data/track_icons/cs_tags_SPL.png > track_icons/cs_tags_SPL.png
--   [data] Data/track_icons/cs_tags_STM.png > track_icons/cs_tags_STM.png
--   [data] Data/track_icons/cs_tags_STR.png > track_icons/cs_tags_STR.png
--   [data] Data/track_icons/cs_tags_SUB.png > track_icons/cs_tags_SUB.png
--   [data] Data/track_icons/cs_tags_SYB.png > track_icons/cs_tags_SYB.png
--   [data] Data/track_icons/cs_tags_SYN.png > track_icons/cs_tags_SYN.png
--   [data] Data/track_icons/cs_tags_TAM.png > track_icons/cs_tags_TAM.png
--   [data] Data/track_icons/cs_tags_TBK.png > track_icons/cs_tags_TBK.png
--   [data] Data/track_icons/cs_tags_TBN.png > track_icons/cs_tags_TBN.png
--   [data] Data/track_icons/cs_tags_TBX.png > track_icons/cs_tags_TBX.png
--   [data] Data/track_icons/cs_tags_TC.png > track_icons/cs_tags_TC.png
--   [data] Data/track_icons/cs_tags_TLK.png > track_icons/cs_tags_TLK.png
--   [data] Data/track_icons/cs_tags_TMC.png > track_icons/cs_tags_TMC.png
--   [data] Data/track_icons/cs_tags_TMP.png > track_icons/cs_tags_TMP.png
--   [data] Data/track_icons/cs_tags_TOM.png > track_icons/cs_tags_TOM.png
--   [data] Data/track_icons/cs_tags_TPT.png > track_icons/cs_tags_TPT.png
--   [data] Data/track_icons/cs_tags_TRI.png > track_icons/cs_tags_TRI.png
--   [data] Data/track_icons/cs_tags_UHS.png > track_icons/cs_tags_UHS.png
--   [data] Data/track_icons/cs_tags_UKE.png > track_icons/cs_tags_UKE.png
--   [data] Data/track_icons/cs_tags_VCA.png > track_icons/cs_tags_VCA.png
--   [data] Data/track_icons/cs_tags_VID.png > track_icons/cs_tags_VID.png
--   [data] Data/track_icons/cs_tags_VLA.png > track_icons/cs_tags_VLA.png
--   [data] Data/track_icons/cs_tags_VLN.png > track_icons/cs_tags_VLN.png
--   [data] Data/track_icons/cs_tags_VOC.png > track_icons/cs_tags_VOC.png
--   [data] Data/track_icons/cs_tags_VOX.png > track_icons/cs_tags_VOX.png
--   [data] Data/track_icons/cs_tags_WOO.png > track_icons/cs_tags_WOO.png
--   [data] Data/track_icons/cs_tags_WRL.png > track_icons/cs_tags_WRL.png

--------------------------------------------------------------------------------
-- ReaImGui check
--------------------------------------------------------------------------------
local SCRIPT_TITLE = "ReNo Mellow - Strip Buddy"
local VERSION = "1.31"

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
local DATA_DIR  = RES .. "/Data/ReNo_StripBuddy"
local DATA_FILE = DATA_DIR .. "/strips.lua"
local ICON_DIR  = RES .. "/Data/track_icons"
local FXC_DIR   = RES .. "/FXChains"
local DND_TYPE  = "RNCS_STRIP"
local DND_FOLDER = "RNCS_FOLDER"
local EXT = "ReNo_StripBuddy"

-- one-time migration from the former name "Custom Strips" (data folder + settings); the old folder is kept
do
  local OLD_DIR, OLD_EXT = RES .. "/Data/ReNo_CustomStrips", "ReNo_CustomStrips"
  local function copy_file(a, b)
    local f = io.open(a, "rb"); if not f then return false end
    local d = f:read("a"); f:close()
    local g = io.open(b, "wb"); if not g then return false end
    g:write(d); g:close(); return true
  end
  if not reaper.file_exists(DATA_DIR .. "/strips.lua") and reaper.file_exists(OLD_DIR .. "/strips.lua") then
    reaper.RecursiveCreateDirectory(DATA_DIR .. "/Exports", 0)
    copy_file(OLD_DIR .. "/strips.lua", DATA_DIR .. "/strips.lua")
    local i = 0
    while true do
      local fn = reaper.EnumerateFiles(OLD_DIR .. "/Exports", i)
      if not fn then break end
      copy_file(OLD_DIR .. "/Exports/" .. fn, DATA_DIR .. "/Exports/" .. fn)
      i = i + 1
    end
  end
  if reaper.GetExtState(EXT, "migrated") ~= "1" then
    for _, k in ipairs({ "folder", "disp_view", "disp_scroll", "disp_startup", "disp_font",
                         "disp_opt_zoom", "disp_opt_view", "disp_opt_scroll", "disp_opt_select" }) do
      local v = reaper.GetExtState(OLD_EXT, k)
      if v ~= "" and reaper.GetExtState(EXT, k) == "" then reaper.SetExtState(EXT, k, v, true) end
    end
    reaper.SetExtState(EXT, "migrated", "1", true)
  end
end

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
-- default strips: { folder, { { strip name, tag } } } (track name = strip name)
-- tag 2 of a default strip = the folder tag (FOLDER_TAG2), unless it is its tag 1
local DEFAULT_STRIPS = {
  { "Drums", { { "Drums", "DRM" }, { "Kick", "KIK" }, { "Kick in", "KIK" }, { "Kick out", "KIK" }, { "Kick sub", "KIK" }, { "Kick trig", "KIK" }, { "Snare", "SNR" }, { "Snare top", "SNR" }, { "Snare bottom", "SNR" }, { "Snare even", "SNR" }, { "Snare trig", "SNR" }, { "Piccolo", "SNR" }, { "Toms", "TOM" }, { "Tom high", "TOM" }, { "Tom mid", "TOM" }, { "Tom low", "TOM" }, { "Tom trig", "TOM" }, { "Octobans", "OCT" }, { "Rototoms", "ROT" }, { "Gong", "GON" }, { "Overheads", "OHS" }, { "Underheads", "UHS" }, { "Glyn Johns", "GLJ" }, { "Front of kit", "FOK" }, { "Sensor mic", "SNS" }, { "Cymbals", "CYM" }, { "Hi-hat", "HH" }, { "Ride", "RID" }, { "Crash", "CRS" }, { "Splash", "SPL" }, { "China", "CHN" }, { "Stack", "CYM" }, { "Clap cymbal", "CYM" }, { "FX cymbal", "CYM" }, { "Ambiance", "AMB" }, { "Room", "ROO" }, { "Talkback mic", "TLK" }, { "New-York", "NY" }, { "Parallel buss", "PAR" }, { "Trigger", "TRI" } } },
  { "Drum pad", { { "Drum pad", "PAD" }, { "Drum machine", "DRM" }, { "Drum module", "DRM" }, { "Drum replacer", "DRM" }, { "Drum bank", "DRM" }, { "E-drums", "DRM" }, { "SPD", "SPD" }, { "Groovebox", "BOX" }, { "Beat box", "BOX" }, { "808", "808" }, { "909", "909" } } },
  { "Percussion", { { "Percussion", "PRC" }, { "Clap", "CLP" }, { "Conga", "CNG" }, { "Bongo", "BNG" }, { "Djembe", "PRC" }, { "Cajon", "CAJ" }, { "Frame drum", "PRC" }, { "Hand pan", "PRC" }, { "Steel tongue", "PRC" }, { "Claves", "PRC" }, { "Shaker", "SHK" }, { "Cabasas", "PRC" }, { "Caxixi", "PRC" }, { "Chimes", "PRC" }, { "Tambourine", "TAM" }, { "Bloc", "PRC" }, { "Guiros", "PRC" }, { "Maracas", "PRC" }, { "Vibraslap", "PRC" }, { "Timbales", "PRC" }, { "World percussion", "PRC" } } },
  { "Bass", { { "Bass", "BSS" }, { "Bass DI", "DI" }, { "Bass amp", "AMP" }, { "Bass pedal", "BSS" }, { "Bass 808", "808" }, { "Sub Bass", "BSS" }, { "Synth bass", "SYB" } } },
  { "Acoustic guitar", { { "Acoustic guitar", "ACG" }, { "Nylon guitar", "ACG" }, { "Classic guitar", "ACG" }, { "Ukulele", "UKE" }, { "Banjo", "BJO" }, { "Mandolin", "MND" }, { "Lap steel", "ACG" } } },
  { "Guitar", { { "Guitar", "GTR" }, { "Guitar DI", "DI" }, { "Guitar amp", "AMP" }, { "Guitar pedal", "GTR" }, { "Electric guitar", "ELG" }, { "Rhythm guitar", "RHY" }, { "Guitar solo", "SOL" } } },
  { "Keyboard", { { "Keyboard", "KEY" }, { "Synth", "SYN" }, { "Pad", "KEY" }, { "Piano", "PNO" }, { "Electric piano", "KEY" }, { "Organ", "ORG" }, { "Low keys", "KEY" }, { "Leads", "LED" }, { "Soundscape", "KEY" }, { "Rhodes", "RHD" }, { "Wurlitzer", "WRL" }, { "Arpeggio", "ARP" }, { "Sequence", "SEQ" } } },
  { "Sound FX", { { "Sound FX", "SFX" }, { "Foley", "FOL" }, { "Noise", "NOI" }, { "Risers", "SFX" }, { "Woosh", "SFX" }, { "Sample", "SFX" }, { "Impact", "SFX" } } },
  { "Strings", { { "Strings", "STR" }, { "Violin", "VLN" }, { "Viola", "VLA" }, { "Cello", "CLO" }, { "Double bass", "CTB" }, { "Harp", "STR" } } },
  { "Woodwinds", { { "Woodwinds", "WOO" }, { "Flute", "FLT" }, { "Piccolo", "WOO" }, { "Oboe", "WOO" }, { "Horn", "WOO" }, { "Clarinet", "WOO" }, { "Bassoon", "WOO" }, { "Harmonica", "HRM" }, { "Accordion", "ACC" } } },
  { "Brass", { { "Brass", "BRA" }, { "Trumpet", "TPT" }, { "French Horn", "HRN" }, { "Trombone", "TBN" }, { "Tuba", "BRA" }, { "Euphonium", "BRA" }, { "Sax", "SAX" } } },
  { "Orchestral percussion", { { "Orchestral percussion", "ORC" }, { "Xylophone", "ORC" }, { "Glockenspiel", "ORC" }, { "Tubular Bells", "ORC" }, { "Celesta", "ORC" }, { "Vibraphone", "ORC" } } },
  { "Choir", { { "Choir", "CHO" }, { "Sopranos", "CHO" }, { "Alto", "CHO" }, { "Tenors", "CHO" }, { "Baritone", "CHO" }, { "Basses", "CHO" } } },
  { "Vocals", { { "Vocals", "VOC" }, { "Lead vocals", "LDV" }, { "Background vocals", "BGV" }, { "Harmonies", "HAR" }, { "Gang", "GNG" }, { "Screams", "SCR" }, { "Dialogue", "DIA" }, { "Master of ceremonies", "MC" }, { "Talkback", "TLK" }, { "Listenback", "LIS" }, { "Doubles", "DBL" }, { "Ad-libs", "ADL" }, { "Rap", "RAP" }, { "Chorus vocals", "CHR" }, { "Talkbox", "TBX" }, { "Vocal bus", "VOX" } } },
  { "Mix", { { "Reverb", "RVB" }, { "Delay", "DLY" }, { "Effects", "FX" }, { "Sidechain", "SC" }, { "Master bus", "MST" }, { "Stems", "STM" }, { "Reference", "REF" }, { "Music", "MUS" }, { "Background", "BKG" }, { "Alternate take", "ALT" }, { "Temporary", "TMP" }, { "Spare", "RSP" }, { "Comment", "CMT" } } },
  { "Live", { { "Monitor mix", "MIX" }, { "In-ears", "IEM" }, { "Monitors", "MON" }, { "Talkback return", "TBK" }, { "Timecode track", "TC" }, { "LTC", "LTC" }, { "MTC", "MTC" }, { "Sampler", "SMP" }, { "Loop", "LOP" }, { "Ghost track", "GHO" } } },
  { "Miscellaneous", { { "Miscellaneous", "MSC" }, { "Playback", "PLB" }, { "Production", "PRD" }, { "Click", "CLK" }, { "Metronome", "CLK" }, { "Cues", "CUE" }, { "Timecode", "TMC" }, { "MIDI", "MID" }, { "DMX", "DMX" }, { "Video", "VID" }, { "Image", "IMG" }, { "Lyrics", "LYR" }, { "Chords", "CHD" }, { "Auxiliary", "AUX" }, { "Busses", "BUS" }, { "Dca", "DCA" }, { "Vca", "VCA" }, { "Group", "GRP" }, { "Subgroup", "SUB" }, { "Matrix", "MTX" }, { "Master", "MLR" } } },
}

-- folder tag given as tag 2 to the default strips (Mix, Live, Miscellaneous: none)
local FOLDER_TAG2 = {
  ["Drums"] = "DRM", ["Drum pad"] = "PAD", ["Percussion"] = "PRC", ["Bass"] = "BSS",
  ["Acoustic guitar"] = "ACG", ["Guitar"] = "GTR", ["Keyboard"] = "KEY", ["Sound FX"] = "SFX",
  ["Strings"] = "STR", ["Woodwinds"] = "WOO", ["Brass"] = "BRA", ["Orchestral percussion"] = "ORC",
  ["Choir"] = "CHO", ["Vocals"] = "VOC",
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

-- split the trailing tags (1 to 3 characters, 2 at most) off a name:
-- "Kick in [KIK][DRM]" -> "Kick in", "KIK", "DRM" ; "Kick [KIK]" -> "Kick", "KIK", nil
local function split_tags(name)
  local t = {}
  for _ = 1, 2 do
    local base, tg = name:match("^(.-)%s*%[([^%[%]]+)%]%s*$")
    if not base or utf8_len(tg) > 3 then break end
    table.insert(t, 1, tg)
    name = base
  end
  return name, t[1], t[2]
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
-- Storage (Data/ReNo_StripBuddy/strips.lua)
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
  if not f then return { strips = {} }, true end
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
  f:write("-- ReNo Mellow - Strip Buddy data\nreturn ", ser(d), "\n")
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

-- record output modes (I_RECMODE)
local REC_OUTS = {
  { label = "Record output: stereo", value = 1 },
  { label = "Record output: mono",   value = 5 },
  { label = "Record output: MIDI",   value = 4 },
}
local OUTPUT_RECMODES = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [10] = true, [11] = true }

local function rec_out_label(v)
  for _, o in ipairs(REC_OUTS) do if o.value == v then return o.label end end
  return ""
end

-- pan modes (I_PANMODE)
local PAN_MODES = {
  { label = "Project default",          v = -1 },
  { label = "Stereo balance / mono pan", v = 3 },
  { label = "Stereo pan",               v = 5 },
  { label = "Dual pan",                 v = 6 },
  { label = "Balance (classic 3.x)",    v = 0 },
}
local function pan_mode_label(v)
  if v == nil then return "" end
  for _, t in ipairs(PAN_MODES) do if t.v == v then return t.label end end
  return "Mode " .. v
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

-- adds the lines of a .RfxChain to the input FX (<FXCHAIN_REC block)
local function chunk_add_rec(tr, fx_lines)
  local ok, chunk = reaper.GetTrackStateChunk(tr, "", false)
  if not ok then return false end
  local L = split_lines(chunk)
  local children, track_end = scan_track_chunk(L)
  local rec, first_item
  for _, c in ipairs(children) do
    if c.name == "FXCHAIN_REC" and not rec then rec = c end
    if c.name == "ITEM" and not first_item then first_item = c end
  end
  if rec then
    L = insert_lines(L, rec.e, fx_lines)
  else
    local blk = { "<FXCHAIN_REC", "SHOW 0", "LASTSEL 0", "DOCKED 0" }
    for _, l in ipairs(fx_lines) do blk[#blk + 1] = l end
    blk[#blk + 1] = ">"
    L = insert_lines(L, (first_item and first_item.s) or track_end, blk)
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

-- loads an FX chain on the track FX (rec = false) or on the input FX (rec = true);
-- replace = true removes the FX already there first, otherwise the chain is added after them
local REC_OFS = 0x1000000
local function add_fxchain(tr, path, warn, rec, replace)
  local function count() return rec and reaper.TrackFX_GetRecCount(tr) or reaper.TrackFX_GetCount(tr) end
  if replace then
    for i = count() - 1, 0, -1 do reaper.TrackFX_Delete(tr, rec and (REC_OFS + i) or i) end
  end
  local before = count()
  local p = norm_path(path)
  local rel = p
  if p:lower():sub(1, #FXC_DIR + 1) == (FXC_DIR .. "/"):lower() then rel = p:sub(#FXC_DIR + 2) end
  reaper.TrackFX_AddByName(tr, rel, rec and true or false, -1)
  if count() > before then return end
  -- fallback: insert the chain file into the track chunk
  local lines = read_fxchain_lines(path)
  if not lines then warn["FX chain file not found: " .. basename(path)] = true; return end
  if rec then chunk_add_rec(tr, lines) else chunk_add(tr, nil, lines) end
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
      local g, len = take_norm_gain(item, take, nz.type or 2, nz.target or -15)
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
    if (nz.type or 2) >= 2 then -- peak / true peak: loudest item reaches the target
      for _, it in ipairs(list) do if not common or it.g < common then common = it.g end end
    else -- LUFS / RMS: length-weighted energy of all items
      local target = nz.target or -15
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

-- outputs: { main = bool, hw = { { ch = 0-based first channel, mono = bool }, ... },
--            midi = { name = device name, dev = index, chan = 0 (all) / 1-16 } or nil }
local function out_ch_label(o)
  if o.mono then return tostring(o.ch + 1) end
  return (o.ch + 1) .. "/" .. (o.ch + 2)
end

local function out_ch_name(o)
  local function nm(i)
    local n = reaper.GetOutputChannelName(i)
    return (n and n ~= "") and n or ("Out " .. (i + 1))
  end
  if o.mono then return "Mono " .. out_ch_label(o) .. "  (" .. nm(o.ch) .. ")" end
  return "Stereo " .. out_ch_label(o) .. "  (" .. nm(o.ch) .. " / " .. nm(o.ch + 1) .. ")"
end

local function midi_out_name(i)
  local ok, nm = reaper.GetMIDIOutputName(i, "")
  if ok and nm ~= "" then return nm end
end

local function midi_out_index(m)
  if not m then return nil end
  for i = 0, reaper.GetNumMIDIOutputs() - 1 do
    if m.name and midi_out_name(i) == m.name then return i end
  end
  return m.dev
end

local function sum_output(o)
  if not o then return "" end
  local t = { o.main and "Master" or "No master" }
  if o.hw and #o.hw > 0 then
    local c = {}
    for _, h in ipairs(o.hw) do c[#c + 1] = out_ch_label(h) end
    t[#t + 1] = "HW " .. table.concat(c, " + ")
  end
  if o.midi then
    t[#t + 1] = "MIDI " .. (o.midi.name or ("#" .. ((o.midi.dev or 0) + 1))) ..
      (((o.midi.chan or 0) == 0) and "" or (" ch" .. o.midi.chan))
  end
  return table.concat(t, ", ")
end

-- replaces the track's master/parent send, hardware audio outputs and MIDI hardware output;
-- sends to other tracks are kept
local function apply_output(tr, o)
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", o.main and 1 or 0)
  for i = reaper.GetTrackNumSends(tr, 1) - 1, 0, -1 do reaper.RemoveTrackSend(tr, 1, i) end
  for _, h in ipairs(o.hw or {}) do
    local idx = reaper.CreateTrackSend(tr, nil)
    if idx and idx >= 0 then
      reaper.SetTrackSendInfo_Value(tr, 1, idx, "I_SRCCHAN", 0)
      reaper.SetTrackSendInfo_Value(tr, 1, idx, "I_DSTCHAN", h.ch | (h.mono and 1024 or 0))
    end
  end
  local dev = midi_out_index(o.midi)
  if dev then
    reaper.SetMediaTrackInfo_Value(tr, "I_MIDIHWOUT", (dev << 5) | ((o.midi.chan or 0) & 31))
  else
    reaper.SetMediaTrackInfo_Value(tr, "I_MIDIHWOUT", -1)
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
    if s.track_name or s.tag or s.tag2 then
      local _, cur = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local base, t1, t2 = split_tags(cur)
      if s.track_name then
        base = s.track_name
        if #tracks > 1 then base = base .. " " .. idx end
        t1, t2 = nil, nil           -- a new track name drops the old tags
      end
      t1 = s.tag or t1              -- an empty tag cell keeps the track's tag
      t2 = s.tag2 or t2
      if t2 == t1 then t2 = nil end
      if not t1 then t1, t2 = t2, nil end
      local name = base
      if t1 then name = trim(base .. " [" .. t1 .. "]" .. (t2 and ("[" .. t2 .. "]") or "")) end
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
    if s.recout then
      reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", s.recout)
    elseif s.recinput then
      reaper.SetMediaTrackInfo_Value(tr, "I_RECINPUT", s.recinput)
      -- back to recording the input if the track was recording its output
      local m = math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_RECMODE"))
      if OUTPUT_RECMODES[m] then reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0) end
    end
    -- 7c : outputs (master / parent, hardware audio, hardware MIDI)
    if s.output then apply_output(tr, s.output) end
    -- 7a : pan mode
    if s.panmode then reaper.SetMediaTrackInfo_Value(tr, "I_PANMODE", s.panmode) end
    -- 7b : metering type (other meter bits kept)
    if s.meter and s.meter.mode then
      local cur = math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_VUMODE"))
      local v = (cur & ~(1 | 30)) | s.meter.mode
      reaper.SetMediaTrackInfo_Value(tr, "I_VUMODE", v)
    end
    -- 8 : FX chain and input FX chain (added after the existing FX, or replacing them)
    if s.fxchain then add_fxchain(tr, s.fxchain, warn, false, s.fxchain_replace) end
    if s.fxin then add_fxchain(tr, s.fxin, warn, true, s.fxin_replace) end
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
  reaper.Undo_EndBlock("Strip Buddy: " .. (s.name or ""), -1)

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
  return string.format("%.1f %s, %s", nz.target or -15, norm_label(nz.type or 2),
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
  add("Tag 2", s.tag2 and ("[" .. s.tag2 .. "]"))
  add("Colour", s.color and string.format("#%06X", s.color))
  add("Icon", s.icon and basename(s.icon))
  add("Layout", sum_layout(s.layout))
  add("Record input", s.recout and rec_out_label(s.recout) or (s.recinput and rec_input_label(s.recinput, REC_OPTS)))
  add("Output", sum_output(s.output))
  add("Pan mode", pan_mode_label(s.panmode))
  add("Metering", sum_meter(s.meter))
  add("FX chain", s.fxchain and (basename(s.fxchain) .. (s.fxchain_replace and " (replace)" or " (add)")))
  add("Input FX", s.fxin and (basename(s.fxin) .. (s.fxin_replace and " (replace)" or " (add)")))
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
local data, first_run = load_data()
local strips = data.strips
data.folders = data.folders or {}
local folders = data.folders
local sel_folder = reaper.GetExtState(EXT, "folder")
if sel_folder == "" then sel_folder = "__all" end
local open_fnew, fnew_buf = false, ""
local open_frename, frename_id, frename_buf = false, nil, ""
local open_fdelete, fdelete_id = false, nil
local dirty, last_save = false, 0
local status, status_col = "", 0xBBBBBBFF
local LAYOUTS = { tcp = list_layouts("tcp"), mcp = list_layouts("mcp") }

local open_rename, rename_idx, rename_buf = false, nil, ""
local open_delete, delete_idx = false, nil
local goto_setup, scroll_row = false, nil
local setup_filter = "" -- text filter of the Setup tab
local pending -- structural change (move / duplicate) run after drawing the list

-- adds the default strips that are missing (folders matched by name)
local function load_default_strips()
  local added = 0
  for _, blk in ipairs(DEFAULT_STRIPS) do
    local fname, names = blk[1], blk[2]
    local fid
    for _, f in ipairs(folders) do if f.name == fname then fid = f.id break end end
    if not fid then
      fid = "f" .. reaper.genGuid(""):gsub("[{}%-]", ""):sub(1, 12)
      folders[#folders + 1] = { id = fid, name = fname }
    end
    local have = {}
    for _, s in ipairs(strips) do if s.folder == fid and s.name then have[s.name] = true end end
    for _, e in ipairs(names) do
      local nm, tag = e[1], e[2]
      if not have[nm] then
        local icon = tag ~= "" and ("cs_tags_" .. tag .. ".png") or nil
        if icon and not reaper.file_exists(ICON_DIR .. "/" .. icon) then icon = nil end
        local t2 = FOLDER_TAG2[fname]
        if t2 == tag then t2 = nil end
        strips[#strips + 1] = { name = nm, track_name = nm, tag = tag ~= "" and tag or nil, tag2 = t2, icon = icon, folder = fid }
        added = added + 1
      end
    end
  end
  dirty = true
  return added
end

if first_run and #strips == 0 then load_default_strips() end

-- 1.19 : the default strips no longer normalize. One-time clean-up: untick the
-- old default (-15 dBFS peak, together) on every strip; other settings are kept.
if reaper.GetExtState(EXT, "norm_default_off") ~= "1" then
  for _, s in ipairs(strips) do
    local nz = s.normalize
    if nz and (nz.type or 2) == 2 and math.abs((nz.target or -15) + 15) < 0.001
       and (nz.mode or "together") == "together" then
      s.normalize = nil
      dirty = true
    end
  end
  reaper.SetExtState(EXT, "norm_default_off", "1", true)
end

-- 1.20 : new tags for some default strips. One-time update of the strips still on
-- their old default tag (and old default icon or no icon); edited ones are kept.
local RETAG_120 = {
  { "Ride", "CYM", "RID" },
  { "Crash", "CYM", "CRS" },
  { "Splash", "CYM", "SPL" },
  { "China", "CYM", "CHN" },
  { "Conga", "PRC", "CNG" },
  { "Bongo", "PRC", "BNG" },
  { "Cajon", "PRC", "CAJ" },
  { "Shaker", "PRC", "SHK" },
  { "Tambourine", "PRC", "TAM" },
  { "Bass DI", "BSS", "DI" },
  { "Bass amp", "BSS", "AMP" },
  { "Bass 808", "BSS", "808" },
  { "Ukulele", "ACG", "UKE" },
  { "Banjo", "ACG", "BJO" },
  { "Mandolin", "ACG", "MND" },
  { "Guitar DI", "GTR", "DI" },
  { "Guitar amp", "GTR", "AMP" },
  { "Synth", "KEY", "SYN" },
  { "Piano", "KEY", "PNO" },
  { "Organ", "KEY", "ORG" },
  { "Leads", "KEY", "LED" },
  { "Foley", "SFX", "FOL" },
  { "Noise", "SFX", "NOI" },
  { "Violin", "STR", "VLN" },
  { "Viola", "STR", "VLA" },
  { "Cello", "STR", "CLO" },
  { "Double bass", "STR", "CTB" },
  { "Flute", "WOO", "FLT" },
  { "Trumpet", "BRA", "TPT" },
  { "French Horn", "BRA", "HRN" },
  { "Trombone", "BRA", "TBN" },
  { "Sax", "BRA", "SAX" },
}
if reaper.GetExtState(EXT, "retag_120") ~= "1" then
  local map = {}
  for _, r in ipairs(RETAG_120) do map[r[1] .. "\0" .. r[2]] = r[3] end
  for _, s in ipairs(strips) do
    local new = s.name and s.tag and map[s.name .. "\0" .. s.tag]
    if new and (s.icon == nil or s.icon == "cs_tags_" .. s.tag .. ".png") then
      local icon = "cs_tags_" .. new .. ".png"
      s.tag = new
      if reaper.file_exists(ICON_DIR .. "/" .. icon) then s.icon = icon end
      dirty = true
    end
  end
  reaper.SetExtState(EXT, "retag_120", "1", true)
end

-- 1.20 : tag 2. One-time: the default strips already saved get their folder tag
-- as tag 2, when they still have their default tag 1 and no tag 2.
if reaper.GetExtState(EXT, "tag2_120") ~= "1" then
  local fname = {}
  for _, f in ipairs(folders) do fname[f.id] = f.name end
  local def = {}
  for _, fd in ipairs(DEFAULT_STRIPS) do
    for _, e in ipairs(fd[2]) do def[fd[1] .. "\0" .. e[1]] = e[2] end
  end
  for _, s in ipairs(strips) do
    local fn = s.folder and fname[s.folder]
    local t2 = fn and FOLDER_TAG2[fn]
    if t2 and not s.tag2 and s.name and s.tag and def[fn .. "\0" .. s.name] == s.tag and s.tag ~= t2 then
      s.tag2 = t2
      dirty = true
    end
  end
  reaper.SetExtState(EXT, "tag2_120", "1", true)
end

-- 1.23 : the default strip "Clap" (Percussion) gets its own tag CLP. One-time update
-- when it still has its old tag PRC and its old icon (or none); edited strips are kept.
if reaper.GetExtState(EXT, "retag_123") ~= "1" then
  for _, s in ipairs(strips) do
    if s.name == "Clap" and s.tag == "PRC" and (s.icon == nil or s.icon == "cs_tags_PRC.png") then
      s.tag = "CLP"
      if not s.tag2 then s.tag2 = "PRC" end
      if reaper.file_exists(ICON_DIR .. "/cs_tags_CLP.png") then s.icon = "cs_tags_CLP.png" end
      dirty = true
    end
  end
  reaper.SetExtState(EXT, "retag_123", "1", true)
end

-- 1.26 : reverb tag REV -> RVB. One-time update of every strip tagged REV (tag 1 or 2);
-- the icon follows when it is the old REV icon or empty.
if reaper.GetExtState(EXT, "retag_126") ~= "1" then
  for _, s in ipairs(strips) do
    if s.tag == "REV" then
      s.tag = "RVB"
      if (s.icon == nil or s.icon == "cs_tags_REV.png") and reaper.file_exists(ICON_DIR .. "/cs_tags_RVB.png") then
        s.icon = "cs_tags_RVB.png"
      end
      dirty = true
    end
    if s.tag2 == "REV" then s.tag2 = "RVB"; dirty = true end
  end
  reaper.SetExtState(EXT, "retag_126", "1", true)
end

local function set_status(msg, kind)
  status = msg or ""
  status_col = (kind == "err" and 0xFF6060FF) or (kind == "warn" and 0xFFB040FF) or 0x70D070FF
end

local function mark() dirty = true end

local function new_strip()
  local n = #strips + 1
  local f = (sel_folder ~= "__all" and sel_folder ~= "__none") and sel_folder or nil
  strips[#strips + 1] = { name = "New strip " .. n, folder = f }
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

-- applies only the tags, the colour and the icon of a strip: the track keeps its name
-- (the tags are written after it) and every other setting
local function do_apply_color_tags(i)
  local s = strips[i]
  if not s then return end
  if not (s.color or s.tag or s.tag2 or s.icon) then
    set_status("This strip has no tag, colour or icon.", "warn") return
  end
  local part = { name = (s.name or "") .. " (tags, colour and icon)", color = s.color, tag = s.tag, tag2 = s.tag2, icon = s.icon }
  local ok, msg, w = apply_strip(part)
  set_status(msg, (not ok and "err") or (w and "warn") or "ok")
end

--------------------------------------------------------------------------------
-- Tab 1 : strips
--------------------------------------------------------------------------------
local function strip_menu_items(i)
  if ImGui.MenuItem(ctx, "Apply to selected tracks") then do_apply(i) end
  if ImGui.MenuItem(ctx, "Apply tags, colour and icon to selected tracks") then do_apply_color_tags(i) end
  if ImGui.MenuItem(ctx, "Rename...") then open_rename, rename_idx, rename_buf = true, i, strips[i].name or "" end
  if ImGui.MenuItem(ctx, "Edit in Setup") then goto_setup, scroll_row, setup_filter = true, i, "" end
  if ImGui.MenuItem(ctx, "Duplicate") then
    pending = function()
      local c = copy(strips[i]); c.name = (c.name or "") .. " copy"
      table.insert(strips, i + 1, c); mark()
    end
  end
  ImGui.Separator(ctx)
  if ImGui.MenuItem(ctx, "Delete...") then open_delete, delete_idx = true, i end
end

local FOLDER_ALL, FOLDER_NONE = "__all", "__none"

local function folder_by_id(id)
  for i, f in ipairs(folders) do if f.id == id then return f, i end end
end

local function new_folder_id()
  return "f" .. reaper.genGuid(""):gsub("[{}%-]", ""):sub(1, 12)
end

local function strip_in_view(s)
  if sel_folder == FOLDER_ALL then return true end
  if sel_folder == FOLDER_NONE then return s.folder == nil or not folder_by_id(s.folder) end
  return s.folder == sel_folder
end

-- Setup filter: folder (shared with the Strips tab) + text on name, track name and tags

local function strip_matches_text(s)
  if setup_filter == "" then return true end
  local q = setup_filter:lower()
  for _, v in ipairs({ s.name, s.track_name, s.tag, s.tag2 }) do
    if v and v:lower():find(q, 1, true) then return true end
  end
  return false
end

local function row_visible(s) return strip_in_view(s) and strip_matches_text(s) end

local function select_folder(id)
  sel_folder = id
  reaper.SetExtState(EXT, "folder", id, true)
end

local function count_in(id)
  local n = 0
  for _, s in ipairs(strips) do
    if id == FOLDER_ALL or (id == FOLDER_NONE and (s.folder == nil or not folder_by_id(s.folder)))
       or s.folder == id then n = n + 1 end
  end
  return n
end

-- one entry of the folder list (also a drop target for strips and folders)
local function folder_entry(id, label, fidx)
  local n = count_in(id)
  if ImGui.Selectable(ctx, label .. "  (" .. n .. ")##" .. id, sel_folder == id) then select_folder(id) end
  if fidx then
    if ImGui.BeginDragDropSource(ctx) then
      ImGui.SetDragDropPayload(ctx, DND_FOLDER, tostring(fidx))
      ImGui.Text(ctx, label)
      ImGui.EndDragDropSource(ctx)
    end
    if ImGui.BeginPopupContextItem(ctx, "fctx" .. id) then
      if ImGui.MenuItem(ctx, "Rename...") then open_frename, frename_id, frename_buf = true, id, label end
      if ImGui.MenuItem(ctx, "Delete...") then open_fdelete, fdelete_id = true, id end
      ImGui.EndPopup(ctx)
    end
  end
  if ImGui.BeginDragDropTarget(ctx) then
    local rv, payload = ImGui.AcceptDragDropPayload(ctx, DND_TYPE)
    if rv and id ~= FOLDER_ALL then
      local si = tonumber(payload)
      if strips[si] then
        strips[si].folder = (id ~= FOLDER_NONE) and id or nil
        mark()
        set_status("Moved \"" .. (strips[si].name or "") .. "\" to " .. label .. ".", "ok")
      end
    end
    if fidx then
      local rv2, p2 = ImGui.AcceptDragDropPayload(ctx, DND_FOLDER)
      local from = tonumber(p2)
      if rv2 and from and folders[from] and from ~= fidx then
        local f = table.remove(folders, from)
        table.insert(folders, fidx, f)
        mark()
      end
    end
    ImGui.EndDragDropTarget(ctx)
  end
end

local function draw_folder_list()
  folder_entry(FOLDER_ALL, "All strips")
  ImGui.Separator(ctx)
  for fi, f in ipairs(folders) do
    ImGui.PushID(ctx, "fold" .. fi)
    folder_entry(f.id, f.name or "?", fi)
    ImGui.PopID(ctx)
  end
  if #folders > 0 then ImGui.Separator(ctx) end
  folder_entry(FOLDER_NONE, "No folder")
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "+ New folder", -FLT_MIN) then open_fnew, fnew_buf = true, "" end
end

-- split a button label into at most 2 lines that fit maxw (current font):
-- by words first, a word too long is cut by characters, overflow ends with "…"
local function utf8_chars(str)
  local t = {}
  for _, c in utf8.codes(str) do t[#t + 1] = utf8.char(c) end
  return t
end

local function fit_chars(str, maxw, ellipsis)
  local ch = utf8_chars(str)
  local out = ""
  for k = 1, #ch do
    local try = out .. ch[k]
    if ImGui.CalcTextSize(ctx, try .. (ellipsis and "…" or "")) > maxw then
      return out .. (ellipsis and "…" or ""), table.concat(ch, "", k)
    end
    out = try
  end
  return out, ""
end

local function wrap_label(label, maxw)
  if ImGui.CalcTextSize(ctx, label) <= maxw then return { label } end
  local words = {}
  for w in label:gmatch("%S+") do words[#words + 1] = w end
  local line1, rest = "", nil
  for k, w in ipairs(words) do
    local try = (line1 == "") and w or (line1 .. " " .. w)
    if ImGui.CalcTextSize(ctx, try) <= maxw then
      line1 = try
    else
      if line1 == "" then -- first word alone is too long: cut it
        local a, b = fit_chars(w, maxw, false)
        line1 = a
        rest = b .. ((k < #words) and (" " .. table.concat(words, " ", k + 1)) or "")
      else
        rest = table.concat(words, " ", k)
      end
      break
    end
  end
  if not rest or rest == "" then return { line1 } end
  local line2 = rest
  if ImGui.CalcTextSize(ctx, line2) > maxw then line2 = fit_chars(rest, maxw, true) end
  return { line1, line2 }
end

local function draw_strip_buttons()
  local shown = {}
  for i, s in ipairs(strips) do if strip_in_view(s) then shown[#shown + 1] = i end end
  if #shown == 0 then
    if #strips == 0 then
      ImGui.TextWrapped(ctx, "No strips yet. Create them in the Setup tab.")
      if ImGui.Button(ctx, "Create a strip") then setup_filter = ""; new_strip(); goto_setup, scroll_row = true, #strips end
    else
      ImGui.TextDisabled(ctx, "This folder is empty.")
      ImGui.TextWrapped(ctx, "Drag strips from \"All strips\" onto the folder name to file them here.")
    end
    return
  end

  local avail = ImGui.GetContentRegionAvail(ctx)
  local bw, bh, sp = 112, 42, 6
  local per_row = math.max(1, math.floor((avail + sp) / (bw + sp)))
  local mv_from, mv_to

  for k, i in ipairs(shown) do
    local s = strips[i]
    ImGui.PushID(ctx, i)
    if (k - 1) % per_row ~= 0 then ImGui.SameLine(ctx, 0, sp) end
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
    local lines = wrap_label(label, bw - 8)
    if #lines == 1 then
      if ImGui.Button(ctx, label .. "##strip", bw, bh) then do_apply(i) end
    else
      -- long name: two centred lines drawn over an empty button
      if ImGui.Button(ctx, "##strip", bw, bh) then do_apply(i) end
      local x1, y1 = ImGui.GetItemRectMin(ctx)
      local dl = ImGui.GetWindowDrawList(ctx)
      local col = ImGui.GetColor(ctx, ImGui.Col_Text)
      local lh = ImGui.GetTextLineHeight(ctx)
      local y = y1 + math.floor((bh - lh * #lines) / 2)
      for _, ln in ipairs(lines) do
        local w = ImGui.CalcTextSize(ctx, ln)
        ImGui.DrawList_AddText(dl, x1 + math.floor((bw - w) / 2), y, col, ln)
        y = y + lh
      end
    end
    ImGui.PopFont(ctx)
    if pushed > 0 then ImGui.PopStyleColor(ctx, pushed) end

    if ImGui.BeginDragDropSource(ctx) then
      ImGui.SetDragDropPayload(ctx, DND_TYPE, tostring(i))
      ImGui.Text(ctx, label)
      ImGui.EndDragDropSource(ctx)
    elseif ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
      local f = s.folder and folder_by_id(s.folder)
      ImGui.SetTooltip(ctx, (f and ("Folder: " .. f.name .. "\n") or "") .. describe(s))
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

local function draw_strips_tab()
  if sel_folder ~= FOLDER_ALL and sel_folder ~= FOLDER_NONE and not folder_by_id(sel_folder) then
    sel_folder = FOLDER_ALL
  end
  ImGui.TextDisabled(ctx, "Click: apply to selected tracks.  Drag: reorder, or drop on a folder to file it.  Right-click: menu.")
  ImGui.Spacing(ctx)
  local _, h = ImGui.GetContentRegionAvail(ctx)
  if status ~= "" then h = h - ImGui.GetFrameHeightWithSpacing(ctx) - 4 end
  if h < 60 then h = 60 end
  if ImGui.BeginChild(ctx, "folders", 170, h, ImGui.ChildFlags_Border) then
    draw_folder_list()
    ImGui.EndChild(ctx)
  end
  ImGui.SameLine(ctx)
  if ImGui.BeginChild(ctx, "strips", 0, h) then
    draw_strip_buttons()
    ImGui.EndChild(ctx)
  end
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

-- tag inheritance: the first strip of a tag in a folder passes its colour / icon
-- to the next strips with the same tag in that folder, when they are empty
-- (or still hold the value they had inherited)
local function is_tag_leader(i)
  local s = strips[i]
  if not s or not s.tag then return false end
  for j = 1, i - 1 do
    local o = strips[j]
    if o.tag == s.tag and o.folder == s.folder then return false end
  end
  return true
end

local function propagate(i, key, old, new)
  if not is_tag_leader(i) then return 0 end
  local s, n = strips[i], 0
  for j = i + 1, #strips do
    local o = strips[j]
    if o.tag == s.tag and o.folder == s.folder and (o[key] == nil or (old ~= nil and o[key] == old)) then
      o[key] = new; n = n + 1
    end
  end
  return n
end

-- multi-selection in the Setup table (set of strip tables, survives reordering)
local sel_rows, sel_anchor = {}, nil

local function count_selected()
  local n = 0
  for _, st in ipairs(strips) do if sel_rows[st] then n = n + 1 end end
  return n
end

local function deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deep_equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- copies every changed setting (except the strip name) of row i to the other selected rows
local function spread_changes(i, before)
  local s = strips[i]
  if not sel_rows[s] or count_selected() < 2 then return end
  local keys = {}
  for k in pairs(before) do keys[k] = true end
  for k in pairs(s) do keys[k] = true end
  for k in pairs(keys) do
    if k ~= "name" and not deep_equal(before[k], s[k]) then
      for _, o in ipairs(strips) do
        if o ~= s and sel_rows[o] then o[k] = copy(s[k]) end
      end
    end
  end
end

local function row_select_click(i)
  local s = strips[i]
  local mods = ImGui.GetKeyMods(ctx)
  local ctrl = (mods & ImGui.Mod_Ctrl) ~= 0 or (mods & ImGui.Mod_Super) ~= 0
  local shift = (mods & ImGui.Mod_Shift) ~= 0
  if shift and sel_anchor then
    local a
    for j, st in ipairs(strips) do if st == sel_anchor then a = j end end
    if a then
      if not ctrl then sel_rows = {} end
      for j = math.min(a, i), math.max(a, i) do
        if row_visible(strips[j]) then sel_rows[strips[j]] = true end
      end
      return
    end
  end
  if ctrl then
    sel_rows[s] = not sel_rows[s] or nil
  elseif sel_rows[s] and count_selected() == 1 then
    sel_rows = {}
  else
    sel_rows = { [s] = true }
  end
  sel_anchor = s
end

local function draw_row(i, s)
  ImGui.TableNextRow(ctx)
  if sel_rows[s] then
    ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg1, 0x4A7FC0A0)
  elseif scroll_row == i then
    ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg1, 0x3A6EA580)
  end

  -- # (click = select, Ctrl+click = add / remove, Shift+click = range)
  ImGui.TableNextColumn(ctx)
  if ImGui.Selectable(ctx, tostring(i) .. "##sel", sel_rows[s] == true) then row_select_click(i) end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    ImGui.SetTooltip(ctx, "Click: select this strip\nCtrl+click: add / remove\nShift+click: select a range\nA change in a selected row goes to all selected rows (except the strip name).")
  end
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

  -- 3b tag 2 (Display only: colour and icon follow tag 1)
  ImGui.TableNextColumn(ctx)
  ImGui.SetNextItemWidth(ctx, -FLT_MIN)
  local rv3, tg2 = ImGui.InputTextWithHint(ctx, "##tag2", "ABC", s.tag2 or "", ImGui.InputTextFlags_CharsUppercase)
  if rv3 then s.tag2 = clean_tag(tg2); mark() end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    ImGui.SetTooltip(ctx, "Second tag, written after the first one: Kick in [KIK][DRM].\nThe Display lists the track under both tags. Colour and icon follow the first tag.")
  end

  -- 4 colour
  ImGui.TableNextColumn(ctx)
  local function set_color(v)
    local old = s.color
    s.color = v; mark()
    propagate(i, "color", old, v)
  end
  if s.color then
    local rvc, c = ImGui.ColorEdit3(ctx, "##col", s.color, ImGui.ColorEditFlags_NoInputs)
    if rvc then set_color(c) end
    if clear_btn("col") then set_color(nil) end
  else
    if ImGui.Button(ctx, "Set##col") then set_color(0x7F7F7F) end
  end
  if is_tag_leader(i) and ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "First [" .. s.tag .. "] strip of this folder:\nits colour and icon go to the other [" .. s.tag .. "] strips that have none.")
  end

  -- 5 icon
  ImGui.TableNextColumn(ctx)
  if ImGui.Button(ctx, (s.icon and basename(s.icon) or "Browse...") .. "##icon", s.icon and 110 or 0) then
    local f = file_browse("Choose a track icon", ICON_DIR, "png",
      "Images (*.png;*.jpg;*.ico;*.bmp)\0*.png;*.jpg;*.jpeg;*.ico;*.bmp\0All files (*.*)\0*.*\0\0")
    if f then
      if f:lower():sub(1, #ICON_DIR + 1) == (ICON_DIR .. "/"):lower() then f = f:sub(#ICON_DIR + 2) end
      local old = s.icon
      s.icon = f; mark()
      propagate(i, "icon", old, f)
    end
  end
  if s.icon then
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, s.icon) end
    if clear_btn("icon") then
      local old = s.icon
      s.icon = nil; mark()
      propagate(i, "icon", old, nil)
    end
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
  local prev = (s.recout and rec_out_label(s.recout)) or (s.recinput and rec_input_label(s.recinput, REC_OPTS)) or "-"
  if ImGui.BeginCombo(ctx, "##rec", prev, ImGui.ComboFlags_HeightLarge) then
    if ImGui.Selectable(ctx, "(ignore)", s.recinput == nil and s.recout == nil) then
      s.recinput, s.recout = nil, nil; mark()
    end
    ImGui.SeparatorText(ctx, "Record output")
    for _, o in ipairs(REC_OUTS) do
      if ImGui.Selectable(ctx, o.label, s.recout == o.value) then s.recout, s.recinput = o.value, nil; mark() end
    end
    ImGui.SeparatorText(ctx, "Input")
    for _, o in ipairs(REC_OPTS) do
      if ImGui.Selectable(ctx, o.label, s.recout == nil and s.recinput == o.value) then
        s.recinput, s.recout = o.value, nil; mark()
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- 7c output
  ImGui.TableNextColumn(ctx)
  if cell_popup_button("out", sum_output(s.output)) then
    local rvb, nv = ImGui.Checkbox(ctx, "Set the track outputs", s.output ~= nil)
    if rvb then s.output = nv and { main = true, hw = {} } or nil; mark() end
    local o = s.output
    if o then
      o.hw = o.hw or {}
      local rvm, mv = ImGui.Checkbox(ctx, "Master / parent send", o.main == true)
      if rvm then o.main = mv; mark() end

      ImGui.SeparatorText(ctx, "Hardware audio outputs")
      local del
      for k, h in ipairs(o.hw) do
        if ImGui.SmallButton(ctx, "x##hw" .. k) then del = k end
        ImGui.SameLine(ctx)
        ImGui.Text(ctx, out_ch_name(h))
      end
      if del then table.remove(o.hw, del); mark() end
      if #o.hw == 0 then ImGui.TextDisabled(ctx, "None") end
      local nout = reaper.GetNumAudioOutputs()
      ImGui.SetNextItemWidth(ctx, 260)
      if ImGui.BeginCombo(ctx, "##addhw", "Add an output...", ImGui.ComboFlags_HeightLarge) then
        if nout == 0 then ImGui.TextDisabled(ctx, "No audio output (check the audio device)") end
        for ch = 0, nout - 2 do
          local e = { ch = ch, mono = false }
          if ImGui.Selectable(ctx, out_ch_name(e) .. "##st" .. ch) then o.hw[#o.hw + 1] = e; mark() end
        end
        if nout > 0 then ImGui.Separator(ctx) end
        for ch = 0, nout - 1 do
          local e = { ch = ch, mono = true }
          if ImGui.Selectable(ctx, out_ch_name(e) .. "##mo" .. ch) then o.hw[#o.hw + 1] = e; mark() end
        end
        ImGui.EndCombo(ctx)
      end

      ImGui.SeparatorText(ctx, "Hardware MIDI output")
      ImGui.SetNextItemWidth(ctx, 260)
      local mprev = o.midi and (o.midi.name or ("Device " .. ((o.midi.dev or 0) + 1))) or "None"
      if ImGui.BeginCombo(ctx, "Device##midiout", mprev, ImGui.ComboFlags_HeightLarge) then
        if ImGui.Selectable(ctx, "None", o.midi == nil) then o.midi = nil; mark() end
        for i = 0, reaper.GetNumMIDIOutputs() - 1 do
          local nm = midi_out_name(i)
          if nm and ImGui.Selectable(ctx, nm .. "##mdev" .. i, o.midi ~= nil and o.midi.name == nm) then
            o.midi = { name = nm, dev = i, chan = o.midi and o.midi.chan or 0 }; mark()
          end
        end
        ImGui.EndCombo(ctx)
      end
      if o.midi then
        ImGui.SetNextItemWidth(ctx, 260)
        local c = o.midi.chan or 0
        if ImGui.BeginCombo(ctx, "Channel##midich", c == 0 and "All channels" or ("Channel " .. c)) then
          if ImGui.Selectable(ctx, "All channels", c == 0) then o.midi.chan = 0; mark() end
          for k = 1, 16 do
            if ImGui.Selectable(ctx, "Channel " .. k, c == k) then o.midi.chan = k; mark() end
          end
          ImGui.EndCombo(ctx)
        end
      end
      ImGui.TextDisabled(ctx, "Replaces the track's master send, hardware outputs\nand MIDI output. Sends to other tracks are kept.")
    end
    ImGui.EndPopup(ctx)
  end

  -- 7a pan mode
  ImGui.TableNextColumn(ctx)
  ImGui.SetNextItemWidth(ctx, -FLT_MIN)
  if ImGui.BeginCombo(ctx, "##pan", s.panmode ~= nil and pan_mode_label(s.panmode) or "-") then
    if ImGui.Selectable(ctx, "(ignore)", s.panmode == nil) then s.panmode = nil; mark() end
    for _, t in ipairs(PAN_MODES) do
      if ImGui.Selectable(ctx, t.label, s.panmode == t.v) then s.panmode = t.v; mark() end
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

  -- 8 FX chain / 8b input FX chain: file + Add / Replace
  local function fx_cell(key, rkey, id, title)
    ImGui.TableNextColumn(ctx)
    local path = s[key]
    if ImGui.Button(ctx, (path and basename(path):gsub("%.[Rr][Ff][Xx][Cc]hain$", "") or "Browse...") .. "##" .. id,
        path and 82 or 0) then
      local f = file_browse(title, FXC_DIR, "RfxChain",
        "FX chains (*.RfxChain)\0*.RfxChain\0All files (*.*)\0*.*\0\0")
      if f then s[key] = f; mark() end
    end
    if path then
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, path) end
      ImGui.SameLine(ctx, 0, 2)
      if ImGui.SmallButton(ctx, (s[rkey] and "Rep" or "Add") .. "##m" .. id) then s[rkey] = (not s[rkey]) or nil; mark() end
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, s[rkey] and "Replace: the FX already on the track are removed first.\nClick to add after them instead."
          or "Add: the chain goes after the FX already on the track.\nClick to replace them instead.")
      end
      if clear_btn(id) then s[key] = nil; s[rkey] = nil; mark() end
    end
  end
  fx_cell("fxchain", "fxchain_replace", "fx", "Choose an FX chain")
  fx_cell("fxin", "fxin_replace", "fxin", "Choose an input FX chain")

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
      s.normalize = nv and { type = 2, target = -15.0, mode = "together" } or nil -- default: -15 dBFS peak, together
      mark()
    end
    if s.normalize then
      local nz = s.normalize
      ImGui.SetNextItemWidth(ctx, 140)
      if ImGui.BeginCombo(ctx, "Type", norm_label(nz.type or 2)) then
        for _, t in ipairs(NORM_TYPES) do
          if ImGui.Selectable(ctx, t.label, nz.type == t.v) then nz.type = t.v; mark() end
        end
        ImGui.EndCombo(ctx)
      end
      ImGui.SetNextItemWidth(ctx, 140)
      local rvt, tv = ImGui.InputDouble(ctx, "Target (dB / LUFS)", nz.target or -15, 0.5, 1.0, "%.1f")
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
  { "#", 24 }, { "Strip name *", 130 }, { "Track name", 110 }, { "Tag", 44 }, { "Tag 2", 44 }, { "Colour", 52 },
  { "Icon", 130 }, { "Layout", 100 }, { "Record input", 150 }, { "Output", 130 }, { "Pan mode", 130 }, { "Metering", 120 }, { "FX chain", 150 }, { "Input FX chain", 150 },
  { "Envelopes", 110 }, { "Item name", 110 }, { "Normalize", 130 }, { "Group", 130 }, { "", 100 },
}


--------------------------------------------------------------------------------
-- Export / import (.rnstrips files)
--------------------------------------------------------------------------------
local EXPORT_DIR = DATA_DIR .. "/Exports"
local EXPORT_EXT = "rnstrips"
local EXPORT_FILTER = "Strip Buddy (*.rnstrips)\0*.rnstrips\0All files (*.*)\0*.*\0\0"
local import_data, import_name, open_import = nil, "", false

local function safe_filename(n)
  n = (n or "strips"):gsub('[\\/:%*%?"<>|]', "_")
  return n
end

-- scope: nil = everything, folder id, or FOLDER_NONE
local function export_strips(scope, scope_name)
  local out = { format = "ReNo Mellow Strip Buddy", version = 1, folders = {}, strips = {} }
  for _, f in ipairs(folders) do
    if scope == nil or scope == f.id then out.folders[#out.folders + 1] = copy(f) end
  end
  for _, st in ipairs(strips) do
    local fid = st.folder
    local known = fid and folder_by_id(fid)
    local in_scope = scope == nil or (scope == FOLDER_NONE and not known) or (known and fid == scope)
    if in_scope then
      local c = copy(st)
      if not known then c.folder = nil end
      out.strips[#out.strips + 1] = c
    end
  end
  if #out.strips == 0 then set_status("Nothing to export: this folder is empty.", "warn") return end

  reaper.RecursiveCreateDirectory(EXPORT_DIR, 0)
  local default = safe_filename(scope_name or "All strips") .. "." .. EXPORT_EXT
  local path
  if reaper.JS_Dialog_BrowseForSaveFile then
    local rv, fn = reaper.JS_Dialog_BrowseForSaveFile("Export strips", native(EXPORT_DIR), default, EXPORT_FILTER)
    if rv ~= 1 or not fn or fn == "" then return end
    path = norm_path(fn)
  else
    local ok, nm = reaper.GetUserInputs("Export strips", 1, "File name (saved in Data/ReNo_StripBuddy/Exports):,extrawidth=150",
      (default:gsub("%." .. EXPORT_EXT .. "$", "")))
    if not ok or trim(nm) == "" then return end
    path = EXPORT_DIR .. "/" .. safe_filename(trim(nm))
  end
  if not path:lower():match("%." .. EXPORT_EXT .. "$") then path = path .. "." .. EXPORT_EXT end

  local f = io.open(path, "w")
  if not f then set_status("Could not write " .. path, "err") return end
  f:write("-- ReNo Mellow - Strip Buddy export\nreturn ", ser(out), "\n")
  f:close()
  set_status(string.format("Exported %d strip%s to %s", #out.strips, #out.strips > 1 and "s" or "", path), "ok")
end

local function pick_import_file()
  reaper.RecursiveCreateDirectory(EXPORT_DIR, 0)
  local path = file_browse("Import strips", EXPORT_DIR, EXPORT_EXT, EXPORT_FILTER)
  if not path then return end
  local f = io.open(path, "r")
  if not f then set_status("Could not read " .. path, "err") return end
  local txt = f:read("a"); f:close()
  local fn = load(txt, "import", "t", {})
  local ok, d = false, nil
  if fn then ok, d = pcall(fn) end
  if not ok or type(d) ~= "table" or type(d.strips) ~= "table" then
    set_status("This file is not a Strip Buddy export.", "err") return
  end
  d.folders = type(d.folders) == "table" and d.folders or {}
  import_data, import_name, open_import = d, basename(path), true
end

-- mode "add": folders matched by name, strips already there (same name + folder) skipped
-- mode "replace": all current strips and folders replaced
local function do_import(mode)
  local d = import_data
  if not d then return 0 end
  if mode == "replace" then
    for i = #strips, 1, -1 do strips[i] = nil end
    for i = #folders, 1, -1 do folders[i] = nil end
  end
  local map = {}
  for _, f in ipairs(d.folders) do
    if f.id and f.name then
      local found
      for _, g in ipairs(folders) do if g.name == f.name then found = g.id break end end
      if not found then
        found = "f" .. reaper.genGuid(""):gsub("[{}%-]", ""):sub(1, 12)
        folders[#folders + 1] = { id = found, name = f.name }
      end
      map[f.id] = found
    end
  end
  local have = {}
  for _, st in ipairs(strips) do have[(st.folder or "") .. "\0" .. (st.name or "")] = true end
  local added = 0
  for _, st in ipairs(d.strips) do
    if type(st) == "table" then
      local c = copy(st)
      c.folder = c.folder and map[c.folder] or nil
      local key = (c.folder or "") .. "\0" .. (c.name or "")
      if not have[key] then
        strips[#strips + 1] = c; have[key] = true; added = added + 1
      end
    end
  end
  mark()
  return added
end

local function draw_import_modal()
  if open_import then ImGui.OpenPopup(ctx, "Import strips"); open_import = false end
  if ImGui.BeginPopupModal(ctx, "Import strips", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    local d = import_data or { strips = {}, folders = {} }
    ImGui.Text(ctx, string.format("%s : %d strip%s, %d folder%s", import_name, #d.strips, #d.strips > 1 and "s" or "",
      #d.folders, #d.folders > 1 and "s" or ""))
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Add to my strips", 200) then
      local n = do_import("add")
      set_status(n .. " strip" .. (n > 1 and "s" or "") .. " imported (strips already there were skipped).", "ok")
      import_data = nil; ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.TextDisabled(ctx, "Folders with the same name are merged.")
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Replace all my strips", 200) then
      local n = do_import("replace")
      set_status("All strips replaced by " .. n .. " imported strip" .. (n > 1 and "s" or "") .. ".", "ok")
      select_folder(FOLDER_ALL)
      import_data = nil; ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.TextColored(ctx, 0xFFB040FF, "Deletes your current strips and folders.")
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Cancel", 200) then import_data = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

local open_clear, clear_folders = false, true

local function draw_clear_modal()
  if open_clear then ImGui.OpenPopup(ctx, "Clear all strips"); open_clear = false end
  if ImGui.BeginPopupModal(ctx, "Clear all strips", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Delete all " .. #strips .. " strips?")
    local rv, v = ImGui.Checkbox(ctx, "Also delete the folders", clear_folders)
    if rv then clear_folders = v end
    ImGui.TextDisabled(ctx, "Tip: Export... first to keep a copy. Load default strips brings the default set back.")
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Clear", 100) then
      for i = #strips, 1, -1 do strips[i] = nil end
      if clear_folders then
        for i = #folders, 1, -1 do folders[i] = nil end
        select_folder(FOLDER_ALL)
      end
      scroll_row = nil
      mark()
      set_status(clear_folders and "All strips and folders deleted." or "All strips deleted (folders kept).", "ok")
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

local function draw_export_import_buttons()
  if ImGui.Button(ctx, "Export...") then ImGui.OpenPopup(ctx, "export_menu") end
  if ImGui.BeginPopup(ctx, "export_menu") then
    ImGui.TextDisabled(ctx, "Export to a .rnstrips file:")
    if ImGui.MenuItem(ctx, "All strips") then export_strips(nil, "All strips") end
    for _, f in ipairs(folders) do
      if ImGui.MenuItem(ctx, "Folder: " .. (f.name or "?") .. "##" .. f.id) then export_strips(f.id, f.name) end
    end
    if ImGui.MenuItem(ctx, "Strips without folder") then export_strips(FOLDER_NONE, "No folder") end
    ImGui.EndPopup(ctx)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Import...") then pick_import_file() end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear all strips") then
    if #strips == 0 and #folders == 0 then set_status("There are no strips to clear.", "warn")
    else open_clear = true end
  end
end

local function draw_setup_tab()
  if ImGui.Button(ctx, "+ Add strip") then setup_filter = ""; new_strip(); scroll_row = #strips; goto_setup = "scroll" end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Load default strips") then
    local n = load_default_strips()
    set_status(n > 0 and (n .. " default strip" .. (n > 1 and "s" or "") .. " added.") or "All default strips are already there.", "ok")
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Adds the missing default strips (drums, bass, guitars, keys, vocals...)\nin their folders. Existing strips are not changed.")
  end
  ImGui.SameLine(ctx)
  draw_export_import_buttons()
  ImGui.SameLine(ctx)
  local nsel = count_selected()
  if nsel > 1 then
    ImGui.TextColored(ctx, 0x7FB2F0FF, nsel .. " strips selected: a change in one of them goes to all (except the name).")
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Clear selection") then sel_rows = {} end
  else
    ImGui.TextDisabled(ctx, "Click # to select, Ctrl / Shift for several. An empty cell is ignored. Only the name is required.")
  end

  -- filter bar
  local fchanged = false
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, "Show")
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 180)
  local fprev = (sel_folder == FOLDER_ALL and "All strips") or (sel_folder == FOLDER_NONE and "No folder")
                or ((folder_by_id(sel_folder) or {}).name or "All strips")
  if ImGui.BeginCombo(ctx, "##sfolder", fprev .. "  (" .. count_in(sel_folder) .. ")", ImGui.ComboFlags_HeightLarge) then
    local function item(id, label)
      if ImGui.Selectable(ctx, label .. "  (" .. count_in(id) .. ")##sf" .. id, sel_folder == id) then
        select_folder(id); fchanged = true
      end
    end
    item(FOLDER_ALL, "All strips")
    for _, fo in ipairs(folders) do item(fo.id, fo.name) end
    item(FOLDER_NONE, "No folder")
    ImGui.EndCombo(ctx)
  end
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Same folder as in the Strips tab.") end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 220)
  local rvf, fv = ImGui.InputTextWithHint(ctx, "##sfilter", "Filter: name, track name, tag...", setup_filter)
  if rvf then setup_filter = fv; fchanged = true end
  if setup_filter ~= "" then
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "x##sfclear") then setup_filter = ""; fchanged = true end
  end
  local nvis = 0
  for _, st in ipairs(strips) do if row_visible(st) then nvis = nvis + 1 end end
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, nvis .. " / " .. #strips .. " strips shown")
  if fchanged then -- hidden rows leave the selection
    for st in pairs(sel_rows) do if not row_visible(st) then sel_rows[st] = nil end end
  end

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
      if row_visible(s) then
        ImGui.PushID(ctx, i)
        local before = sel_rows[s] and copy(s) or nil
        draw_row(i, s)
        if before then spread_changes(i, before) end
        ImGui.PopID(ctx)
      end
    end
    ImGui.EndTable(ctx)
  end
end

--------------------------------------------------------------------------------
-- Modals
--------------------------------------------------------------------------------
local function name_modal(title, open_flag, buf, on_ok)
  if open_flag then ImGui.OpenPopup(ctx, title) end
  if ImGui.BeginPopupModal(ctx, title, nil, ImGui.WindowFlags_AlwaysAutoResize) then
    if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
    ImGui.SetNextItemWidth(ctx, 250)
    -- plain InputText: with the "Enter returns true" flag the typed text only reached buf
    -- on Enter, so clicking OK saw an empty name
    local _
    _, buf = ImGui.InputText(ctx, "##name", buf)
    local enter = ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)
    if ImGui.Button(ctx, "OK", 80) then enter = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 80) then ImGui.CloseCurrentPopup(ctx) end
    if enter and nonempty(buf) then on_ok(trim(buf)); ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
  return buf
end

local function draw_folder_modals()
  fnew_buf = name_modal("New folder", open_fnew, fnew_buf, function(nm)
    local f = { id = new_folder_id(), name = nm }
    folders[#folders + 1] = f
    select_folder(f.id); mark()
  end)
  open_fnew = false

  frename_buf = name_modal("Rename folder", open_frename, frename_buf, function(nm)
    local f = folder_by_id(frename_id)
    if f then f.name = nm; mark() end
  end)
  open_frename = false

  if open_fdelete then ImGui.OpenPopup(ctx, "Delete folder"); open_fdelete = false end
  if ImGui.BeginPopupModal(ctx, "Delete folder", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    local f, fi = folder_by_id(fdelete_id)
    ImGui.Text(ctx, "Delete the folder \"" .. ((f and f.name) or "") .. "\"?")
    ImGui.TextDisabled(ctx, "Its strips are kept and go back to \"No folder\".")
    if ImGui.Button(ctx, "Delete", 80) then
      if f then
        for _, s in ipairs(strips) do if s.folder == f.id then s.folder = nil end end
        table.remove(folders, fi)
        if sel_folder == f.id then select_folder(FOLDER_ALL) end
        mark()
      end
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 80) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

local function draw_modals()
  draw_folder_modals()
  draw_import_modal()
  draw_clear_modal()
  if open_rename then ImGui.OpenPopup(ctx, "Rename strip"); open_rename = false end
  if ImGui.BeginPopupModal(ctx, "Rename strip", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
    ImGui.SetNextItemWidth(ctx, 250)
    local _
    _, rename_buf = ImGui.InputText(ctx, "##rename", rename_buf)
    local enter = ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)
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
-- Tab 3 : Display settings (the Display itself is "ReNo Mellow - Strip Buddy - Display.lua")
--------------------------------------------------------------------------------
local DISPLAY_FILE = (({reaper.get_action_context()})[2]:match("^(.*[/\\])") or "") .. "ReNo Mellow - Strip Buddy - Display.lua"
local START_FILE = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
local START_A = "-- >>> ReNo Mellow Strip Buddy Display (auto-start)"
local START_B = "-- <<< ReNo Mellow Strip Buddy Display"
local PANES = { { "tcp", "TCP" }, { "mcp", "MCP" }, { "both", "Both" } }

local function remove_startup_block(ma, mb)
  ma, mb = ma or START_A, mb or START_B
  local f = io.open(START_FILE, "r"); if not f then return end
  local s = f:read("a"); f:close()
  local a = s:find(ma, 1, true); if not a then return end
  local _, b = s:find(mb, a, true); if not b then return end
  if s:sub(b + 1, b + 1) == "\n" then b = b + 1 end
  f = io.open(START_FILE, "w"); if f then f:write(s:sub(1, a - 1) .. s:sub(b + 1)); f:close() end
end

-- the startup block of the former "Custom Strips" Display is no longer needed
remove_startup_block("-- >>> ReNo Mellow Custom Strips Display (auto-start)", "-- <<< ReNo Mellow Custom Strips Display")

-- main window at REAPER startup (option, off by default): own block in __startup.lua
local MAIN_FILE = ({reaper.get_action_context()})[2]
local MAIN_A = "-- >>> ReNo Mellow Strip Buddy main window (auto-start)"
local MAIN_B = "-- <<< ReNo Mellow Strip Buddy main window"

local function ensure_main_startup_block()
  local f = io.open(START_FILE, "r")
  local s = ""
  if f then s = f:read("a") or ""; f:close() end
  if s:find(MAIN_A, 1, true) then return end
  local block = MAIN_A .. "\n" ..
    "do\n" ..
    "  local p = " .. string.format("%q", MAIN_FILE) .. "\n" ..
    "  if reaper.file_exists(p) and reaper.GetExtState(\"" .. EXT .. "\", \"main_startup\") == \"1\" then\n" ..
    "    local id = reaper.AddRemoveReaScript(true, 0, p, true)\n" ..
    "    if id and id ~= 0 then reaper.Main_OnCommand(id, 0) end\n" ..
    "  end\n" ..
    "end\n" .. MAIN_B .. "\n"
  f = io.open(START_FILE, "w")
  if f then f:write(s, (s ~= "" and not s:match("\n$")) and "\n" or "", block); f:close() end
end

if reaper.GetExtState(EXT, "main_startup") == "1" then ensure_main_startup_block() end

local function toggle_display()
  if not reaper.file_exists(DISPLAY_FILE) then
    set_status("Display script not found: " .. DISPLAY_FILE, "err") return
  end
  local id = reaper.AddRemoveReaScript(true, 0, DISPLAY_FILE, true)
  if id and id ~= 0 then reaper.Main_OnCommand(id, 0) end
end

local function pane_radio(label, key, default)
  local cur = reaper.GetExtState(EXT, key); if cur == "" then cur = default end
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, label)
  for _, o in ipairs(PANES) do
    ImGui.SameLine(ctx, 0, 14)
    if ImGui.RadioButton(ctx, o[2] .. "##" .. key, cur == o[1]) then reaper.SetExtState(EXT, key, o[1], true) end
  end
end

local function draw_display_tab()
  ImGui.TextWrapped(ctx, "The Display is a small floating bar: Zoom / View / Scroll / Select on the left, " ..
    "the tags of the project on the right. Turn on one or more options, then pick a tag (or All) in the list. " ..
    "Mouse wheel over the list = next / previous tag. Right-click the bar for size, opacity and startup.")
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Open / close the Display") then pending = toggle_display end
  ImGui.Spacing(ctx); ImGui.Separator(ctx); ImGui.Spacing(ctx)
  pane_radio("Display View   ", "disp_view", "both")
  ImGui.TextDisabled(ctx, "View shows only the tracks of the tag (folder parents stay visible) in these panes.")
  ImGui.Spacing(ctx)
  pane_radio("Display Scroll ", "disp_scroll", "tcp")
  ImGui.TextDisabled(ctx, "Scroll brings the first track of the tag to the top (TCP) or to the left (mixer).")
  ImGui.Spacing(ctx); ImGui.Separator(ctx); ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "Look of the Display")
  local dsz = math.max(10, math.min(36, math.floor(tonumber(reaper.GetExtState(EXT, "disp_font")) or 16)))
  ImGui.SetNextItemWidth(ctx, 220)
  local rvz, vz = ImGui.SliderInt(ctx, "Size", dsz, 10, 36)
  if rvz then reaper.SetExtState(EXT, "disp_font", tostring(vz), true) end
  local dop = math.max(0.2, math.min(1, tonumber(reaper.GetExtState(EXT, "disp_opacity")) or 1))
  ImGui.SetNextItemWidth(ctx, 220)
  local rvp, vp = ImGui.SliderInt(ctx, "Opacity", math.floor(dop * 100 + 0.5), 20, 100, "%d %%")
  if rvp then reaper.SetExtState(EXT, "disp_opacity", tostring(vp / 100), true) end
  ImGui.TextDisabled(ctx, "Size scales the whole bar (text, buttons, icon). Opacity is the background's.")
  ImGui.Spacing(ctx)
  ImGui.SeparatorText(ctx, "When REAPER starts")
  local mst = reaper.GetExtState(EXT, "main_startup") == "1"
  local rvm, vm = ImGui.Checkbox(ctx, "Open the Strip Buddy window", mst)
  if rvm then
    reaper.SetExtState(EXT, "main_startup", vm and "1" or "0", true)
    if vm then ensure_main_startup_block() else remove_startup_block(MAIN_A, MAIN_B) end
  end
  local st = reaper.GetExtState(EXT, "disp_startup") ~= "0"
  local rv, v = ImGui.Checkbox(ctx, "Open the Display", st)
  if rv then
    reaper.SetExtState(EXT, "disp_startup", v and "1" or "0", true)
    if not v then remove_startup_block() end
  end
  ImGui.Spacing(ctx)
  ImGui.TextDisabled(ctx, "Zoom fits the tag's tracks to the arrange height (needs js_ReaScriptAPI, or SWS). Zoom All resets the heights.")
end

--------------------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------------------
local _, _, SEC, CMD = reaper.get_action_context()
if reaper.set_action_options then reaper.set_action_options(1 | 4) end -- re-run = close (toolbar toggle)
reaper.SetExtState(EXT, "main_close", "0", false)
reaper.SetToggleCommandState(SEC, CMD, 1)
reaper.RefreshToolbar2(SEC, CMD)

reaper.atexit(function()
  if dirty then save_data(data) end
  reaper.SetToggleCommandState(SEC, CMD, 0)
  reaper.RefreshToolbar2(SEC, CMD)
end)

local function loop()
  ImGui.SetNextWindowSize(ctx, 900, 480, ImGui.Cond_FirstUseEver)
  if reaper.GetExtState(EXT, "main_close") == "1" then -- asked by the Display
    reaper.SetExtState(EXT, "main_close", "0", false)
    return -- atexit saves the strips and turns the toolbar state off
  end
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
      if ImGui.BeginTabItem(ctx, "Display") then
        draw_display_tab()
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
