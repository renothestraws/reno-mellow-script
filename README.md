# ReNo Mellow Scripts – scripts Lua gratuits pour REAPER

Les plug-ins JSFX **ReNo Mellow** (compresseurs, EQ, couleur, instruments) sont dans un dépôt séparé :
<https://github.com/renothestraws/reno-mellow>

## Scripts

| Script | Description |
|---|---|
| **REABACK** | Lancement des backing tracks sur scène : setlist de régions (une chanson = une région mère), transport, Live loop, contrôle à distance depuis un téléphone et prompteur de paroles / accords pour tablette. Fournit 8 actions, 2 pages web, un project template et des icônes de barre d'outils |
| **ReNo Mellow - Custom Strips** | Fenêtre de « custom strips » (presets de pistes) : un clic applique le strip aux pistes sélectionnées (nom numéroté, tag [ABC], couleur, icône, layouts TCP/MCP, entrée d'enregistrement, FX chain ajoutée, enveloppes visibles, nom des items, normalisation LUFS / RMS / peak, groupe et ses flags). Onglet Setup en tableau, une case vide est ignorée |
| **ReNo Mellow - Swiss Army Knife** | Un même raccourci, plusieurs outils : on choisit l'outil actif dans une toolbox et W / Shift+W / Ctrl+W lancent son action principale, alt ou alt 2. Deux versions séparées, arrangement (section Main) et éditeur MIDI (section MIDI Editor), chacune avec sa toolbox, sa bulle Display qui affiche l'outil actif, 24 outils, Next / Previous tool. |
| **ReNo Mellow - MIDI cleaner** | Nettoie les items MIDI sélectionnés : supprime SysEx, Program Change, pitch bend et tous les CC sauf CC4, CC11 et CC64, passe tout sur le canal 1 et règle le timebase sur Beats (position, length, rate) |
| **ReNo StemSplit** | Séparation de stems par IA, en local (esprit Stem Splitter de Logic Pro). Trois actions : **Stems** (voix, batterie, basse, guitare, piano, autres – 6 ou 4 stems), **Drums** (kick, snare, toms, cymbales – 4, 5 ou 6 pièces, depuis un mix complet ou une piste de batterie seule) et **Install** (installation / réparation du moteur) |

### ReNo StemSplit

Option **Quality** : *Standard* (Demucs pour tout, le plus rapide) ou *Vocals HQ* (voix séparée par BS-RoFormer, de meilleure qualité, puis le reste par Demucs ; environ deux fois plus lent).

Les stems arrivent sur de nouvelles pistes sous la piste d'origine (dossier optionnel), alignés et colorés ;
l'item d'origine peut être muté. Les WAV sont enregistrés dans le dossier `Stems` du dossier média du projet.

**Moteur (installation unique) :** nécessite **Python 3.10 à 3.13** (3.12 conseillé ; si seule la 3.14 est installée, le script l'essaie quand même).
- Windows : `py install 3.12` (Python install manager) ou `winget install Python.Python.3.12`
- macOS : installateur python.org ou `brew install python@3.12`

Au premier lancement, le bouton **Install engine** installe tout dans `Data/ReNo_StemSplit` (environ 1,5 Go,
4,5 Go avec la version GPU NVIDIA, détectée et testée automatiquement ; Apple Silicon utilisé automatiquement ; les Mac Intel ne sont pas pris en charge).
Ensuite, tout fonctionne hors ligne. Pour profiter des nouveaux modèles et corrections de la bibliothèque : action **Install** > **Update engine** (Internet nécessaire). Supprimer `Data/ReNo_StemSplit` désinstalle le moteur.
En cas d'erreur : bouton **Open log** (journaux `install.log` et `last_run.log`).

Durée pour un morceau de 4 min : 20 s à 1 min avec une carte NVIDIA ou un Mac Apple Silicon, 2 à 6 min sur processeur seul.

### ReNo Mellow - Swiss Army Knife

- **Toolbox**, onglet **Tools** : clic = choisir l'outil actif (vert). Clic droit = armer son action principale,
  Shift+clic droit = armer l'action alt, Ctrl+clic droit = armer l'action alt 2 (clic droit à nouveau : désarmer).
- Onglet **Setup** : 24 emplacements, chacun avec un nom et trois actions (main, alt, alt 2), tapées (ID) ou choisies
  dans la liste d'actions (**Pick...**) ; monter, descendre, dupliquer, vider ; infobulles ; export / import de presets.
- Raccourcis à assigner : **ReNo Mellow - Swiss Army Knife**, **(alt)** et **(alt2)** (par exemple W, Shift+W, Ctrl+W).
  Scripts **Next tool** et **Previous tool** pour changer d'outil au clavier.
- **Display** (et **Display MIDI**) : petite bulle à placer où l'on veut qui affiche le nom de l'outil actif ;
  molette = outil précédent / suivant, double-clic = ouvrir la Toolbox, clic droit = taille du texte, icône, fermer.
  Une bulle ouverte se rouvre au même endroit au démarrage de REAPER (un petit bloc est ajouté à `Scripts/__startup.lua`).
- **Version éditeur MIDI** : les mêmes scripts suffixés **MIDI**, dans la section MIDI Editor de la liste d'actions,
  avec leur propre toolbox et leurs 24 outils.
- Les outils sont enregistrés pour toutes les sessions (reaper-extstate.ini, section ReNoMellow_SAK).

**Extensions :** ReaImGui (obligatoire), SWS (conseillée). REAPER 7.03 ou plus pour les infobulles.

### ReNo Mellow - Custom Strips

- Onglet **Strips** : clic = appliquer aux pistes sélectionnées (une seule annulation), glisser = réordonner, clic droit = renommer, dupliquer, supprimer.
- Onglet **Setup** : une ligne par strip, seul le nom est obligatoire. Plusieurs pistes sélectionnées avec un nom de piste : numérotation automatique (Tom 1, Tom 2...).
- Normalisation par strip : LUFS-I, RMS, Peak ou True peak, chaque item à la cible ou tous ensemble (gain commun).
- Les strips sont enregistrés dans `Data/ReNo_CustomStrips/strips.lua`.

**Extensions :** ReaImGui (obligatoire), js_ReaScriptAPI (optionnelle, filtre des fenêtres de choix de fichiers).

### REABACK

- **REABACK** : fenêtre principale (liste des régions réordonnable, renumérotation des IDs, sets de régions,
  Play/Stop, Previous / Next, Live loop, Metronome, Count-in, Auto stop, Smooth seek, export txt).
- Actions isolées à associer à des raccourcis clavier ou MIDI : **REABACK_PlayStop**, **_Stop**, **_Previous**,
  **_Next**, **_LiveLoop**.
- **Reaback Set up** : raccourcis de configuration et de construction de la session.
- **Reaback-prompter** : envoie les notes des items des pistes Lyrics (jaune), Chords (rouge) et Comment (blanc italique)
  vers la page `Reaback-prompter.html` (tablette ou téléphone).
- Nouvelle session : **File > Project templates > ReaBack**.
- Contrôle à distance : Preferences > Control/OSC/web > Add > Web browser interface, puis ouvrir
  `http://<adresse IP de l'ordinateur>:<port>/REABACK.html` (ou `/Reaback-prompter.html`).
- Icônes : clic droit sur une barre d'outils > Customize toolbar > Choose icon, puis l'icône du même nom.

**Extensions :** ReaImGui (obligatoire, via ReaPack > ReaTeam Extensions), SWS (conseillée), js_ReaScriptAPI (optionnelle).

## Installation avec ReaPack (recommandé)

1. Installer ReaPack si nécessaire : <https://reapack.com>
2. Dans REAPER : **Extensions > ReaPack > Import repositories...**
3. Coller l'adresse :
   ```
   https://raw.githubusercontent.com/renothestraws/reno-mellow-script/main/index.xml
   ```
4. **Extensions > ReaPack > Browse packages**, chercher « ReNo », clic droit > Install, puis Apply.

Les mises à jour arrivent ensuite automatiquement (Extensions > ReaPack > Synchronize packages).

## Installation en un fichier (REAPER 7.86 et plus)

Le dossier `packages` contient un fichier `.ReaperPkg` par script (ReNo StemSplit, REABACK, MIDI cleaner, Custom Strips, Swiss Army Knife).
Télécharger le fichier, puis l'ouvrir avec REAPER : les scripts sont installés et ajoutés à la liste d'actions,
et le paquet peut être désinstallé proprement. Pas de mises à jour automatiques : pour cela, préférer ReaPack.

Swiss Army Knife en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_SwissArmyKnife.ReaperPkg>
(la version éditeur MIDI est ajoutée à la section MIDI Editor au premier lancement de la Toolbox).

## Installation manuelle

**REABACK** : télécharger le dossier `REABACK`, puis charger et lancer `REABACK_Install.lua` depuis la liste d'actions
(Actions > Show action list > New action > Load ReaScript) : il copie les scripts, les pages web, le template et les icônes.

**MIDI cleaner** : copier `MIDI/ReNo Mellow - MIDI cleaner.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**Swiss Army Knife** : copier le dossier `SwissArmyKnife` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Swiss Army Knife - Toolbox.lua` : elle ajoute toutes les autres actions (Main et MIDI Editor).

**Custom Strips** : copier `CustomStrips/ReNo Mellow - Custom Strips.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**ReNo StemSplit** : copier le dossier `StemSplit` dans le dossier `Scripts` de REAPER
(Options > Show REAPER resource path), puis charger ses actions dans la liste d'actions
(Actions > Show action list > New action > Load ReaScript).

## Licence

Gratuit pour tout usage, y compris commercial.

**ReNo StemSplit** s'appuie sur [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
Demucs v4 (Meta Research, licence MIT) et le modèle DrumSep MDX23C d'aufr33 et jarredou. Les modèles sont téléchargés
depuis leurs sources d'origine et restent la propriété de leurs auteurs.
Logic Pro et Stem Splitter sont des marques d'Apple ; ReNo n'est affilié à aucune de ces marques.
