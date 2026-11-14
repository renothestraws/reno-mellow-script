#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère index.xml (dépôt ReaPack) pour les scripts ReNo Mellow.

Usage :   python3 make_index.py PSEUDO_GITHUB [NOM_DU_DEPOT] [BRANCHE]
Exemple : python3 make_index.py renothestraws reno-mellow-script main

Chaque dossier à la racine (StemSplit/, REABACK/, ...) = une catégorie ReaPack.
Chaque .lua dont l'en-tête contient "-- @description" devient un paquet :
  -- @description, -- @version, -- @author, -- @about, -- @changelog (une ligne chacun)
  -- @provides suivi de lignes "--   fichier" ("--   [main] fichier" = action supplémentaire)
Les fichiers fournis par un paquet portent "@noindex".
Aucune installation n'est nécessaire (Python 3 seul).
"""
import os, re, sys, glob, datetime
from urllib.parse import quote
from xml.sax.saxutils import escape, quoteattr

REPO_NAME = "ReNo Mellow Scripts"
IGNORE = {"images", ".git", ".github"}


def rtf(text):
    """Texte simple -> RTF minimal (ReaPack affiche le 'About' en RTF)."""
    out = []
    for ch in text:
        if ch in "\\{}":
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\par\n")
        elif ord(ch) < 128:
            out.append(ch)
        else:
            out.append("\\u%d?" % (ord(ch) if ord(ch) < 32768 else ord(ch) - 65536))
    return "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 \\fswiss Helvetica;}}\\f0\\fs20 " + "".join(out) + "}"


def lua_header(path):
    """En-tête ReaPack d'un script Lua -> (tags, provides) ; None si pas un paquet."""
    tags, provides, in_prov = {}, [], False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not line.startswith("--"):
                break
            m = re.match(r"--\s*@(\w+)\s*(.*)", line)
            if m:
                key = m.group(1).lower()
                in_prov = (key == "provides")
                if not in_prov:
                    tags[key] = m.group(2).strip()
                continue
            if in_prov:
                item = line[2:].strip()
                if item:
                    main = item.startswith("[main]")
                    provides.append((item[6:].strip() if main else item, main))
    if "noindex" in tags or "description" not in tags:
        return None
    for k in ("version", "author"):
        if k not in tags:
            sys.exit("%s : balise '@%s' manquante" % (path, k))
    return tags, provides


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    user = sys.argv[1]
    repo = sys.argv[2] if len(sys.argv) > 2 else "reno-mellow-script"
    branch = sys.argv[3] if len(sys.argv) > 3 else "main"
    raw = "https://raw.githubusercontent.com/%s/%s/%s/" % (user, repo, branch)
    site = "https://github.com/%s/%s" % (user, repo)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    root = os.path.dirname(os.path.abspath(__file__))

    x = ['<?xml version="1.0" encoding="utf-8"?>',
         '<index version="1" name=%s>' % quoteattr(REPO_NAME)]
    n = 0
    cats = sorted(d for d in os.listdir(root)
                  if os.path.isdir(os.path.join(root, d)) and d not in IGNORE and not d.startswith("."))
    for cat in cats:
        pk = []
        for p in sorted(glob.glob(os.path.join(root, cat, "*.lua"))):
            h = lua_header(p)
            if h:
                pk.append((p, h))
        if not pk:
            continue
        x.append('  <category name=%s>' % quoteattr(cat))
        for p, (t, provides) in pk:
            fn = os.path.basename(p)
            url = lambda name: escape(raw + quote(cat + "/" + name))
            x.append('    <reapack name=%s type="script" desc=%s>' % (quoteattr(fn), quoteattr(t["description"])))
            if "about" in t:
                x.append('      <metadata>')
                x.append('        <description><![CDATA[%s]]></description>' % rtf(t["about"]))
                x.append('        <link rel="website" href=%s>GitHub</link>' % quoteattr(site))
                x.append('      </metadata>')
            x.append('      <version name=%s author=%s time=%s>' % (quoteattr(t["version"]), quoteattr(t["author"]), quoteattr(now)))
            if "changelog" in t:
                x.append('        <changelog><![CDATA[%s]]></changelog>' % t["changelog"])
            x.append('        <source main="main">%s</source>' % url(fn))
            for name, is_main in provides:
                if not os.path.isfile(os.path.join(root, cat, name)):
                    sys.exit("%s : fichier fourni introuvable : %s" % (fn, name))
                x.append('        <source%s file=%s>%s</source>' % (' main="main"' if is_main else '', quoteattr(name), url(name)))
            x.append('      </version>')
            x.append('    </reapack>')
            n += 1
        x.append('  </category>')
    x.append('  <metadata>')
    x.append('    <description><![CDATA[%s]]></description>' % rtf(
        "ReNo Mellow Scripts : scripts Lua gratuits pour REAPER (séparation de stems par IA, outils de scène...).\n"
        "Les plug-ins JSFX ReNo Mellow sont dans le dépôt reno-mellow."))
    x.append('    <link rel="website" href=%s>GitHub</link>' % quoteattr(site))
    x.append('  </metadata>')
    x.append('</index>')
    with open(os.path.join(root, "index.xml"), "w", encoding="utf-8") as f:
        f.write("\n".join(x) + "\n")
    print("index.xml : %d paquets, adresse du dépôt ReaPack :" % n)
    print("  " + raw + "index.xml")


if __name__ == "__main__":
    main()
