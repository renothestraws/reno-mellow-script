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
build("REABACK", "REABACK", header(main, "version"), header(main, "changelog"), files)

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
build("ReNo Mellow - Recording Buddy", "ReNo_Mellow_Recording_Buddy", header(main, "version"),
      header(main, "changelog"), walk(d, BASE + "/RecordingBuddy"),
      no_reg=[BASE + "/RecordingBuddy/RecBuddy_lib.lua", BASE + "/RecordingBuddy/RecBuddy_startup.lua"])
