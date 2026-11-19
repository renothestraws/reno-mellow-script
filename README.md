# ReNo Mellow Scripts – scripts Lua gratuits pour REAPER

Les plug-ins JSFX **ReNo Mellow** (compresseurs, EQ, couleur, instruments) sont dans un dépôt séparé :
<https://github.com/renothestraws/reno-mellow>

## Scripts

| Script | Description |
|---|---|
| **REABACK** | Lancement des backing tracks sur scène : setlist de régions (une chanson = une région mère), transport, Live loop, contrôle à distance depuis un téléphone et prompteur de paroles / accords pour tablette. Fournit 8 actions, 2 pages web, un project template et des icônes de barre d'outils |
| **ReNo Mellow - Recording Buddy** | Répéter puis enregistrer une boucle en plusieurs passes : chaque passe a son pré-roll (mesures ou ms), sa vitesse de lecture (hauteur conservée), son mode (Listen, Play avec les pistes armées muettes sous la boucle, Record en auto punch, Move on pour avancer dans l'arrangement), sa pause et, au choix, sa propre boucle. Séquences sauvegardables (Default, 4 takes, Practice fournies), mini Display et actions Start-Stop / Stop. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manual_EN.pdf) |
| **ReNo Mellow - Strip Buddy** | Fenêtre de « strips » (presets de pistes) : un clic applique le strip aux pistes sélectionnées (nom numéroté, tag [ABC], couleur, icône, layouts TCP/MCP, entrée d'enregistrement ou record output (stereo, mono, MIDI), pan mode, type de metering, FX chain ajoutée, enveloppes visibles, nom des items, normalisation LUFS / RMS / peak, groupe et ses flags). Onglet Setup en tableau, une case vide est ignorée. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manual_EN.pdf) |
| **ReNo Mellow - Tool Buddy** (ex Swiss Army Knife) | Un même raccourci, plusieurs outils : on choisit l'outil actif dans une toolbox et trois raccourcis au choix (ex. W / Shift+W / Ctrl+W) lancent son action principale, alt ou alt 2. Deux versions séparées, arrangement (section Main) et éditeur MIDI (section MIDI Editor), chacune avec sa toolbox, sa bulle Display qui affiche l'outil actif, 24 outils, Next / Previous tool. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manual_EN.pdf) |
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

### ReNo Mellow - Tool Buddy

Anciennement **Swiss Army Knife** : au premier lancement, Tool Buddy reprend automatiquement les outils (Arrange et MIDI), l'outil actif et les réglages de Swiss Army Knife, et remplace sa ligne de réouverture des bulles dans `Scripts/__startup.lua`. Si Swiss Army Knife était installé par ReaPack, le désinstaller (Browse packages > clic droit > Uninstall), puis réassigner les raccourcis aux nouvelles actions « ReNo Mellow - Tool Buddy », « (alt) » et « (alt2) » (et leurs versions MIDI). Les presets exportés avec Swiss Army Knife s'importent tels quels.

- **Toolbox**, onglet **Tools** : clic = choisir l'outil actif (vert). Clic droit = armer son action principale,
  Shift+clic droit = armer l'action alt, Ctrl+clic droit = armer l'action alt 2 (clic droit à nouveau : désarmer).
- Onglet **Setup** : 24 emplacements, chacun avec un nom et trois actions (main, alt, alt 2), tapées (ID) ou choisies
  dans la liste d'actions (**Pick...**) ; monter, descendre, dupliquer, vider ; infobulles ; export / import de presets.
- Raccourcis à assigner, au choix : **ReNo Mellow - Tool Buddy**, **(alt)** et **(alt2)** (par exemple W, Shift+W, Ctrl+W).
  Scripts **Next tool** et **Previous tool** pour changer d'outil au clavier.
- **Display** (et **Display MIDI**) : petite bulle à placer où l'on veut qui affiche le nom de l'outil actif ;
  molette = outil précédent / suivant, double-clic = ouvrir la Toolbox, clic droit = taille du texte, fermer.
  Une bulle ouverte se rouvre au même endroit au démarrage de REAPER (un petit bloc est ajouté à `Scripts/__startup.lua`).
- **Version éditeur MIDI** : les mêmes scripts suffixés **MIDI**, dans la section MIDI Editor de la liste d'actions,
  avec leur propre toolbox et leurs 24 outils.
- Les outils sont enregistrés pour toutes les sessions (reaper-extstate.ini, section ReNoMellow_ToolBuddy).

**Extensions :** ReaImGui (obligatoire), SWS (conseillée). REAPER 7.03 ou plus pour les infobulles.

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manual_EN.pdf)

### ReNo Mellow - Recording Buddy

- Définir une **time selection** (ou une boucle) dans l'arrangement, puis lancer **ReNo Mellow - Recording Buddy**.
- Onglet **Rec Buddy** : gros bouton Play (couleur selon lecture / enregistrement / pause, vitesse affichée), jauge
  « Pass » qui suit la progression dans la boucle (en bleu pendant le pré-roll), bouton **STOP** forcé.
- Onglet **Set up** : une ligne par passe, jouées de haut en bas.
  - **Loop** : « def » = la boucle de l'arrangement ; `[` et `]` fixent une boucle propre à la passe depuis le curseur
    d'édition (gardée en position musicale), bouton « def » pour revenir à la boucle de l'arrangement.
  - **Pre-roll** en mesures ou en ms (2 décimales) ; bouton **C** = du curseur d'édition au début de la boucle
    (ou **All pre-rolls from edit cursor** pour toutes les lignes).
  - **Rate** : vitesse de lecture, la hauteur est conservée.
  - **Mode** : **Listen** (lecture simple), **Play** (les items des pistes armées sont muets sous la boucle, le pré-roll
    reste audible, le monitoring aussi), **Record** (time selection auto punch), **Move on** (arrêt, la boucle de
    l'arrangement avance de sa propre longueur, puis pause d'au moins 0,5 s).
  - **Pause** après la passe.
- **Séquences** : charger, Save, Save as..., Delete ; **Examples** remet Default, 4 takes et Practice.
- Chaque stop sauvegarde les prises. Pendant la séquence, le script coupe le repeat, le pré-roll et le count-in de
  REAPER et active la conservation du pitch ; tout est remis comme avant à la fin.
- **Display** : petite fenêtre sans barre de titre ; double-clic = démarrer, Ctrl+Alt+double-clic = stop forcé,
  clic droit = ouvrir l'onglet Set up. Se rouvre au démarrage de REAPER (bloc ajouté à `Scripts/__startup.lua`),
  relancer le script la ferme.
- Actions isolées : **Start-Stop** (sans fenêtre, relancer = arrêter) et **Stop**.

**Extensions :** ReaImGui (obligatoire).

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manual_EN.pdf)

### ReNo Mellow - Strip Buddy

Anciennement **Custom Strips** : au premier lancement, Strip Buddy reprend automatiquement les strips, dossiers, exports et réglages de Custom Strips (l'ancien dossier `Data/ReNo_CustomStrips` est gardé). Si Custom Strips était installé par ReaPack, le désinstaller (Browse packages > clic droit > Uninstall) et remplacer son bouton de barre d'outils par l'action « ReNo Mellow - Strip Buddy ».

- Onglet **Strips** : clic = appliquer aux pistes sélectionnées (une seule annulation), glisser = réordonner, clic droit = renommer, dupliquer, supprimer.
- **Dossiers** (liste à gauche de l'onglet Strips) : « + New folder », glisser un strip sur un dossier pour l'y ranger, clic droit sur un dossier pour le renommer ou le supprimer (ses strips repassent dans « No folder »), glisser les dossiers pour les réordonner.
- Onglet **Setup** : une ligne par strip, seul le nom est obligatoire. **Multisélection** : clic sur le numéro (#), Ctrl+clic pour ajouter / retirer, Shift+clic pour une plage ; une modification dans une ligne sélectionnée (couleur, normalisation, groupe…) s'applique à toutes les lignes sélectionnées, sauf le nom du strip. Plusieurs pistes sélectionnées avec un nom de piste : numérotation automatique (Tom 1, Tom 2...).
- **Héritage par tag** : la couleur et l'icône données au premier strip d'un tag (ex. Kick pour [KIK]) passent aux autres strips du même tag dans le même dossier, s'ils n'en ont pas encore.
- **Display** (action « ReNo Mellow - Strip Buddy - Display ») : petite barre flottante avec un bouton **Strip Buddy** (ouvre la fenêtre principale ou la ramène au premier plan), Zoom / View / Scroll / Select à gauche et la liste des tags du projet à droite (All + chaque tag, à la couleur de sa première piste). Un clic sur un tag applique les options allumées : View n'affiche que les pistes du tag (dossiers parents gardés), Zoom les agrandit à la hauteur de l'arrangement, Scroll amène la première en haut (TCP) ou à gauche (mixer), Select les sélectionne. Molette sur la liste = tag suivant / précédent. Onglet **Display** de la fenêtre principale : Display View et Display Scroll (TCP / MCP / Both), réouverture au démarrage. Relancer l'action ferme le Display.
- Normalisation par strip : LUFS-I, RMS, Peak ou True peak, chaque item à la cible ou tous ensemble (gain commun) ; par défaut -15 dBFS Peak, tous ensemble.
- **Strips de base** : 164 strips (batterie, percussions, basse, guitares, claviers, cordes, vents, cuivres, chœur, voix, divers…) rangés en 15 dossiers, chacun avec son nom de piste et son tag ([KIK], [SNR], [VOC]…), créés au premier lancement ; le bouton **Load default strips** (onglet Setup) rajoute ceux qui manquent sans toucher aux autres.
- Les strips sont enregistrés dans `Data/ReNo_StripBuddy/strips.lua`.
- **Export / Import** (onglet Setup) : sauver tous les strips ou un seul dossier dans un fichier `.rnstrips` (par défaut dans `Data/ReNo_StripBuddy/Exports`), puis le recharger en ajout (dossiers de même nom fusionnés, doublons ignorés) ou en remplacement. **Clear all strips** efface tous les strips (et, au choix, les dossiers) après confirmation.

**Icônes de piste :** 61 icônes `cs_tags_XXX.png` (le tag en blanc, 128 × 128), une par tag des strips de base, installées dans `Data/track_icons` ; les strips de base créés par Load default strips les utilisent, avec la normalisation activée (-15 dBFS Peak, ensemble).

**Icône de barre d'outils :** `ReNo_StripBuddy.png` (style TCP, 3 états), installée avec le script dans `Data/toolbar_icons` (+ 150 / 200 %).

**Extensions :** ReaImGui (obligatoire), js_ReaScriptAPI (optionnelle : filtre des fenêtres de choix de fichiers, Zoom et Scroll précis du Display ; sans elle, le Zoom utilise SWS s'il est installé).

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manual_EN.pdf)

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

Le dossier `packages` contient un fichier `.ReaperPkg` par script (ReNo StemSplit, REABACK, MIDI cleaner, Strip Buddy, Tool Buddy, Recording Buddy).
Télécharger le fichier, puis l'ouvrir avec REAPER : les scripts sont installés et ajoutés à la liste d'actions,
et le paquet peut être désinstallé proprement. Pas de mises à jour automatiques : pour cela, préférer ReaPack.

Tool Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Tool_Buddy.ReaperPkg>
(la version éditeur MIDI est ajoutée à la section MIDI Editor au premier lancement de la Toolbox).

Strip Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Strip_Buddy.ReaperPkg>

Recording Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Recording_Buddy.ReaperPkg>

## Installation manuelle

**REABACK** : télécharger le dossier `REABACK`, puis charger et lancer `REABACK_Install.lua` depuis la liste d'actions
(Actions > Show action list > New action > Load ReaScript) : il copie les scripts, les pages web, le template et les icônes.

**MIDI cleaner** : copier `MIDI/ReNo Mellow - MIDI cleaner.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**Tool Buddy** : copier le dossier `ToolBuddy` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Tool Buddy - Toolbox.lua` : elle ajoute toutes les autres actions (Main et MIDI Editor).

**Recording Buddy** : copier le dossier `RecordingBuddy` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Recording Buddy.lua` : il ajoute les actions Display, Start-Stop et Stop.

**Strip Buddy** : copier `StripBuddy/ReNo Mellow - Strip Buddy.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**ReNo StemSplit** : copier le dossier `StemSplit` dans le dossier `Scripts` de REAPER
(Options > Show REAPER resource path), puis charger ses actions dans la liste d'actions
(Actions > Show action list > New action > Load ReaScript).

## Licence

Gratuit pour tout usage, y compris commercial.

**ReNo StemSplit** s'appuie sur [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
Demucs v4 (Meta Research, licence MIT) et le modèle DrumSep MDX23C d'aufr33 et jarredou. Les modèles sont téléchargés
depuis leurs sources d'origine et restent la propriété de leurs auteurs.
Logic Pro et Stem Splitter sont des marques d'Apple ; ReNo n'est affilié à aucune de ces marques.
