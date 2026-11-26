#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère les paquets .ReaperPkg (REAPER 7.86+) des scripts ReNo Mellow dans le dossier packages/.

Usage : python3 make_packages.py
Un .ReaperPkg est un zip contenant reaper-package-info.txt + les fichiers rangés dans les
sous-dossiers de REAPER (Scripts, Data, ProjectTemplates, reaper_www_root...).
Les scripts .lua/.py de Scripts/ sont enregistrés automatiquement dans la liste d'actions,
sauf ceux listés en SCRIPT_NO_REG.
"""
import os, re, zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "packages")
BASE = "Scripts/ReNo_Mellow"            # pas d'espaces dans les chemins cités dans le fichier info
AUTHOR = "ReNo Mellow"
URL = "https://github.com/renothestraws/reno-mellow-script"


def header(path, tag):
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"--\s*@%s\s+(.*)" % tag, line)
            if m:
                return m.group(1).strip()
            if not line.startswith("--"):
                break
    return ""


def build(name, fname, version, changelog, files, no_reg=()):
    """files = [(chemin sur disque, chemin dans le paquet)]"""
    os.makedirs(OUT, exist_ok=True)
    info = ['NAME "%s"' % name, 'AUTHOR "%s"' % AUTHOR, 'VERSION "%s"' % version,
            'URL "%s"' % URL, 'INFO "changelog.txt"']
    info += ["SCRIPT_NO_REG %s" % p for p in no_reg]
    dest = os.path.join(OUT, fname + ".ReaperPkg")
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("reaper-package-info.txt", "\n".join(info) + "\n")
        z.writestr("changelog.txt", "%s %s\n\n%s\n" % (name, version, changelog))
        for src, arc in files:
            z.write(src, arc)
    print("%-40s %s (%d fichiers)" % (os.path.basename(dest), version, len(files)))


def walk(folder, prefix, skip=()):
    out = []
    for dp, _, fns in os.walk(folder):
        for fn in sorted(fns):
            if fn in skip or fn.startswith(".") or fn.endswith(".pyc"):
                continue
            src = os.path.join(dp, fn)
            out.append((src, prefix + "/" + os.path.relpath(src, folder).replace(os.sep, "/")))
    return out


# --- ReNo StemSplit -------------------------------------------------------------
d = os.path.join(ROOT, "StemSplit")
main = os.path.join(d, "ReNo StemSplit - Stems.lua")
build("ReNo StemSplit", "ReNo_StemSplit", header(main, "version"), header(main, "changelog"),
      walk(d, BASE + "/StemSplit", skip={"README.md"}),
      no_reg=[BASE + "/StemSplit/ReNo_StemSplit_core.lua", BASE + "/StemSplit/stemsplit_*"])

# --- REABACK --------------------------------------------------------------------
d = os.path.join(ROOT, "REABACK")
main = os.path.join(d, "Scripts", "REABACK.lua")
files = walk(os.path.join(d, "Scripts"), BASE + "/REABACK")
files += walk(os.path.join(d, "reaper_www_root"), "reaper_www_root")
files += walk(os.path.join(d, "ProjectTemplates"), "ProjectTemplates")
files += walk(os.path.join(d, "Data"), "Data")
build("REABACK", "REABACK", header(main, "version"), header(main, "changelog"), files,
      no_reg=[BASE + "/REABACK/Reaback_BBeat_export.lua"])

# --- MIDI cleaner ---------------------------------------------------------------
main = os.path.join(ROOT, "MIDI", "ReNo Mellow - MIDI cleaner.lua")
build("ReNo Mellow - MIDI cleaner", "ReNo_Mellow_MIDI_cleaner", header(main, "version"),
      header(main, "changelog"), [(main, BASE + "/MIDI/ReNo Mellow - MIDI cleaner.lua")])

# --- Strip Buddy --------------------------------------------------------------
main = os.path.join(ROOT, "StripBuddy", "ReNo Mellow - Strip Buddy.lua")
build("ReNo Mellow - Strip Buddy", "ReNo_Mellow_Strip_Buddy", header(main, "version"),
      header(main, "changelog"), [(main, BASE + "/StripBuddy/ReNo Mellow - Strip Buddy.lua"),
       (os.path.join(ROOT, "StripBuddy", "ReNo Mellow - Strip Buddy - Display.lua"),
        BASE + "/StripBuddy/ReNo Mellow - Strip Buddy - Display.lua")]
      + walk(os.path.join(ROOT, "StripBuddy", "Data"), "Data"))          # icône de barre d'outils

# --- Tool Buddy (ex Swiss Army Knife ; versions Arrange + MIDI Editor) -----
d = os.path.join(ROOT, "ToolBuddy")
main = os.path.join(d, "ReNo Mellow - Tool Buddy - Toolbox.lua")
files = [f for f in walk(d, BASE + "/ToolBuddy") if "/ToolBuddy/Data/" not in f[1]]
files += walk(os.path.join(d, "Data"), "Data")          # icône du couteau (bulle Display)
build("ReNo Mellow - Tool Buddy", "ReNo_Mellow_Tool_Buddy", header(main, "version"),
      header(main, "changelog"), files,
      no_reg=[BASE + "/ToolBuddy/TB_lib.lua", BASE + "/ToolBuddy/TB_toolbox.lua", BASE + "/ToolBuddy/TB_display.lua", BASE + "/ToolBuddy/TB_startup.lua",
              BASE + "/ToolBuddy/MIDI/*"])

# --- Recording Buddy -------------------------------------------------------------
d = os.path.join(ROOT, "RecordingBuddy")
main = os.path.join(d, "ReNo Mellow - Recording Buddy.lua")
files = [f for f in walk(d, BASE + "/RecordingBuddy") if "/RecordingBuddy/Data/" not in f[1]]
files += walk(os.path.join(d, "Data"), "Data")          # icône de barre d'outils
build("ReNo Mellow - Recording Buddy", "ReNo_Mellow_Recording_Buddy", header(main, "version"),
      header(main, "changelog"), files,
      no_reg=[BASE + "/RecordingBuddy/RecBuddy_lib.lua", BASE + "/RecordingBuddy/RecBuddy_startup.lua"])

# --- Grid Buddy (grille fixe / adaptative, Display, service ; actions Arrange + MIDI Editor) ---
d = os.path.join(ROOT, "GridBuddy")
main = os.path.join(d, "ReNo Mellow - Grid Buddy.lua")
files = [f for f in walk(d, BASE + "/GridBuddy") if "/GridBuddy/Data/" not in f[1]]
files += walk(os.path.join(d, "Data"), "Data")          # icône de barre d'outils
build("ReNo Mellow - Grid Buddy", "ReNo_Mellow_Grid_Buddy", header(main, "version"),
      header(main, "changelog"), files,
      no_reg=[BASE + "/GridBuddy/GB_lib.lua", BASE + "/GridBuddy/GB_startup.lua", BASE + "/GridBuddy/GB_display.lua",
              BASE + "/GridBuddy/MIDI/*"])

# --- Chord Buddy (fenêtre + Display ; bibliothèques non enregistrées) -------------
d = os.path.join(ROOT, "ChordBuddy")
main = os.path.join(d, "ReNo Mellow - Chord Buddy.lua")
build("ReNo Mellow - Chord Buddy", "ReNo_Mellow_Chord_Buddy", header(main, "version"),
      header(main, "changelog"), walk(d, BASE + "/ChordBuddy"),
      no_reg=[BASE + "/ChordBuddy/ChordBuddy_theory.lua", BASE + "/ChordBuddy/ChordBuddy_midi.lua",
              BASE + "/ChordBuddy/ChordBuddy_export.lua"])

# --- Drum Buddy (fenêtre + Display) -------------------------------------------------
d = os.path.join(ROOT, "DrumBuddy")
main = os.path.join(d, "ReNo Mellow - Drum Buddy.lua")
build("ReNo Mellow - Drum Buddy", "ReNo_Mellow_Drum_Buddy", header(main, "version"),
      header(main, "changelog"), walk(d, BASE + "/DrumBuddy"))

# --- Mousewheel Buddy (8 actions molette Main + 8 MIDI Editor, fenêtre de réglage) ---
d = os.path.join(ROOT, "MousewheelBuddy")
main = os.path.join(d, "ReNo Mellow - Mousewheel Buddy.lua")
build("ReNo Mellow - Mousewheel Buddy", "ReNo_Mellow_Mousewheel_Buddy", header(main, "version"),
      header(main, "changelog"), walk(d, BASE + "/MousewheelBuddy"),
      no_reg=[BASE + "/MousewheelBuddy/MWB_lib.lua", BASE + "/MousewheelBuddy/MIDI/*"])

# --- Toolbar icons (données seules : aucune action) -------------------------------
d = os.path.join(ROOT, "ToolbarIcons")
main = os.path.join(d, "ReNo Mellow - Toolbar icons.lua")
build("ReNo Mellow - Toolbar icons", "ReNo_Mellow_Toolbar_Icons", header(main, "version"),
      header(main, "changelog"), walk(os.path.join(d, "Data"), "Data"))


# --- Toolbar icons RM Orange / RM Teal (données seules : aucune action) ---------------
for tag, nom in (("RMO", "Orange"), ("RMT", "Teal")):
    d = os.path.join(ROOT, "ToolbarIcons" + tag)
    main = os.path.join(d, "ReNo Mellow - Toolbar icons RM %s.lua" % nom)
    build("ReNo Mellow - Toolbar icons RM %s" % nom, "ReNo_Mellow_Toolbar_Icons_RM_%s" % nom, header(main, "version"),
          header(main, "changelog"), walk(os.path.join(d, "Data"), "Data"))

# --- Thèmes Default 7.0 RM Orange / RM Teal ---------------------------------------
# Le .ReaperPkg installe le Theme Adjuster (script + images) ; le thème lui-même est
# copié tel quel dans packages/ (.ReaperThemeZip à glisser dans REAPER).
import shutil
d = os.path.join(ROOT, "ThemeRM")
for nom in ("Orange", "Teal"):
    T = "RM_" + nom
    main = os.path.join(d, "Default_7.0_%s_theme_adjuster.lua" % T)
    files = [(main, BASE + "/ThemeRM/" + os.path.basename(main))]
    files += walk(os.path.join(d, T + "_theme_adjuster_images"), BASE + "/ThemeRM/" + T + "_theme_adjuster_images")
    build("Default 7.0 RM %s Theme Adjuster" % nom, "Default_7.0_%s_Theme_Adjuster" % T, header(main, "version"),
          header(main, "changelog"), files)
    shutil.copy(os.path.join(d, "Default_7.0_%s.ReaperThemeZip" % T), os.path.join(OUT, "Default_7.0_%s.ReaperThemeZip" % T))

# --- Toolbar icons Flat RM Orange / RM Teal (données seules : aucune action) ------
d = os.path.join(ROOT, "ToolbarIconsFlat")
for k, nom in (("rmo", "Orange"), ("rmt", "Teal")):
    main = os.path.join(d, "ReNo Mellow - Toolbar icons Flat RM %s.lua" % nom)
    files = [f for f in walk(os.path.join(d, "Data"), "Data") if "/toolbar_icons_%s_flat_" % k in f[1]]
    build("ReNo Mellow - Toolbar icons Flat RM %s" % nom, "ReNo_Mellow_Toolbar_Icons_Flat_RM_%s" % nom,
          header(main, "version"), header(main, "changelog"), files)
