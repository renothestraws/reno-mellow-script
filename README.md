# ReNo Mellow Scripts – scripts Lua gratuits pour REAPER

Les plug-ins JSFX **ReNo Mellow** (compresseurs, EQ, couleur, instruments) sont dans un dépôt séparé :
<https://github.com/renothestraws/reno-mellow>

## Scripts

| Script | Description |
|---|---|
| **REABACK** | Lancement des backing tracks sur scène : setlist de régions (une chanson = une région mère), transport, Live loop, contrôle à distance depuis un téléphone et prompteur de paroles / accords pour tablette. Fournit 8 actions, 2 pages web, un project template et des icônes de barre d'outils |
| **ReNo Mellow - Recording Buddy** | Répéter puis enregistrer une boucle en plusieurs passes : chaque passe a son pré-roll (mesures ou ms), sa vitesse de lecture (hauteur conservée), son mode (Listen, Play avec les pistes armées muettes sous la boucle, Record en auto punch, Move on pour avancer dans l'arrangement), sa pause et, au choix, sa propre boucle. Séquences sauvegardables (Default, 4 takes, Practice fournies), mini Display et actions Start-Stop / Stop. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/RecordingBuddy/RecordingBuddy_manual_EN.pdf) |
| **ReNo Mellow - Strip Buddy** | Fenêtre de « strips » (presets de pistes) : un clic applique le strip aux pistes sélectionnées (nom numéroté, tag [ABC] et tag 2 ([KIK][DRM]), couleur, icône, layouts TCP/MCP, entrée d'enregistrement ou record output (stereo, mono, MIDI), sorties (master / parent, sorties hardware audio et MIDI), pan mode, type de metering, FX chain ajoutée, enveloppes visibles, nom des items, normalisation LUFS / RMS / peak, groupe et ses flags). Onglet Setup en tableau, une case vide est ignorée. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/StripBuddy/StripBuddy_manual_EN.pdf) |
| **ReNo Mellow - Tool Buddy** (ex Swiss Army Knife) | Un même raccourci, plusieurs outils : on choisit l'outil actif dans une toolbox et trois raccourcis au choix (ex. W / Shift+W / Ctrl+W) lancent son action principale, alt ou alt 2. Deux versions séparées, arrangement (section Main) et éditeur MIDI (section MIDI Editor), chacune avec sa toolbox, sa bulle Display qui affiche l'outil actif, 24 outils, Next / Previous tool. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ToolBuddy/ToolBuddy_manual_EN.pdf) |
| **ReNo Mellow - Grid Buddy** | La grille de l'arrangement et de l'éditeur MIDI dans une fenêtre à 2 onglets : type (straight, triplet, quintolet, septolet, pointé, swing), tailles de 1/128 à 4, diviseur et limites, snap, et **Link MIDI editor** (même grille dans l'arrangement et l'éditeur MIDI). Deux mini Displays flottants indépendants, arrangement et éditeur MIDI (molette = taille, clic = menu, Alt = swing) et actions isolées pour les raccourcis (molette, plus large / plus étroite, swing), en double pour l'éditeur MIDI. D'après Gridbox de FeedTheCat. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/GridBuddy/GridBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/GridBuddy/GridBuddy_manual_EN.pdf) |
| **ReNo Mellow - Chord Buddy** | Roue des quintes pour écrire des accords dans l'éditeur MIDI : un clic pose l'accord au curseur (longueur de la grille ×1 / ×2 / ×4 ou 1 mesure) et le curseur passe à la fin pour enchaîner. Roue qui pivote (la tonalité en haut est active, ses accords en couleur avec leurs degrés, majeur / mineur), inversion de −3 à +3 par case, octave au centre, types 7 / maj7 / 6 / sus2 / sus4 / add9, inversion **Auto** (voice leading), basse ajoutée, voicings Close / Open / Drop 2, strum et humanize, mini clavier. **Display** : nom de l'accord sous le curseur et export des accords sélectionnés (item sur une piste « Chords », take marker, text event, notation event). Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ChordBuddy/ChordBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ChordBuddy/ChordBuddy_manual_EN.pdf) |
| **ReNo Mellow - Drum Buddy** | Fills de batterie dans l'éditeur MIDI, pensés comme un batteur. Trois batteurs fournis : Charlie (rock-pop), Mike (metal), Buddie (jazz-gospel). Chaque projet a son **batteur** : sa drum map, sa façon de jouer (vélocités, flas et drags, humanize, Rush / Laid back, densité) et ses **16 chops** sur des pads (un clic = chop inséré au curseur). Les chops ne contiennent que les groupes et le sticking : un coup = un pas de la grille de l'éditeur MIDI. **Editor** : presets de rudiments et de découpages (3+3+2, 5+5+6…), groupes, sticking (R / L / K / fla / drag, accents, ghost notes) et orchestration coup par coup ou par groupe. **Again**, **Vary** (nouvelle orchestration), **Random** (nouveau fill dans le style du batteur), **Display** flottant. Manuel : [FR](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/DrumBuddy/DrumBuddy_manuel_FR.pdf) · [EN](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/DrumBuddy/DrumBuddy_manual_EN.pdf) |
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

### ReNo Mellow - Chord Buddy

- Lancer **ReNo Mellow - Chord Buddy** avec un item MIDI ouvert dans l'éditeur MIDI.
- **Roue** : clic sur une case = accord inséré au curseur d'édition (longueur de la grille, ×2, ×4 ou 1 mesure ; l'item est allongé si besoin), puis le curseur passe à la fin de l'accord. Glisser ou molette sur la roue = la faire tourner : la tonalité en haut devient la tonalité active (couleurs et degrés), **Major / Minor** change les degrés affichés. L'armure de chaque tonalité (1#, 3b…) est écrite dans sa case et au centre.
- **inv** sur chaque case : molette = inversion de −3 à +3 (±4 pour les accords à 4 notes), clic droit = 0. **Auto** choisit l'inversion la plus proche de l'accord précédent.
- **Centre** : octave (molette ou flèches). **Bass** ajoute la fondamentale une octave plus bas ; voicings **Close / Open / Drop 2** ; **Strum** (ms) et **Humanize** (vélocité) ; types **Triad, 7, maj7, 6, sus2, sus4, add9** ; mini clavier avec les notes de l'accord survolé.
- **Display** : petite barre sans titre qui affiche l'accord sous le curseur (suit la lecture), bouton **Open** (ouvre Chord Buddy) et **Export** des accords sélectionnés : clic = modes cochés dans Set up, clic droit = un seul mode. Modes : item vide avec le nom en note d'item sur la piste « Chords » (créée en haut si besoin), take marker, text event, notation event (symbole d'accord de la vue notation). Un export déjà présent au même endroit est remplacé.
- Onglet **Set up** : opacité, tailles, vélocité, remplacement des notes, avancée du curseur, orthographe des notes, numérotation des octaves, modes d'export, nom de la piste Chords, couleurs par degré, Display (ouverture au démarrage de REAPER, taille, opacité).
- Relancer une action ferme sa fenêtre. Nécessite **ReaImGui**.

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ChordBuddy/ChordBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/ChordBuddy/ChordBuddy_manual_EN.pdf)

### ReNo Mellow - Drum Buddy

- Lancer **ReNo Mellow - Drum Buddy** avec un item MIDI de batterie ouvert dans l'éditeur MIDI. Trois batteurs de base sont fournis (drum map General MIDI, 16 chops chacun) : **Charlie** (rock-pop, dont des chops tout au charley), **Mike** (metal : SSKK, SSSSKK, blast, double pédale…) et **Buddie** (jazz et gospel : swing, ghost notes, RLK, rudiments).
- **Un batteur par projet** : il est enregistré dans le projet et revient à l'ouverture de la session. Chaque batteur est un fichier de `Data/ReNo_DrumBuddy/drummers` (drum map, jeu, 16 chops), facile à sauvegarder ou partager.
- Onglet **Drummer** : choix du batteur (New, Duplicate, Delete, **Export** et **Import** d'un batteur dans un fichier) et ses **16 pads** : clic = chop inséré au curseur d'édition, pad vide = enregistrer le fill de l'Editor, clic droit = éditer, remplacer, renommer, vider. **Again** (dernier fill, nouvel humanize), **Vary** (même sticking, nouvelle orchestration), **Random** (nouveau fill dans le style du batteur, longueur 1 temps à 2 mesures).
- Un coup = un pas de la **grille de l'éditeur MIDI** (1/16, 1/32, triolets…) : un chop de 8 coups dure 2 temps en 1/16, 1 temps en 1/32.
- Onglet **Editor** : presets (rudiments et découpages 3+3+2, 5+5+6, Custom), groupes (en-tête : motif suivant, clic droit : taille, couper, fusionner, copier, inverser R/L), **sticking** (clic : normal > accent > ghost > kick > fla ; clic droit : main, drag) et **orchestration** (molette ou clic droit, élément par coup ou par groupe, coup silencieux). Outils **Sticking** (Random, Accent first / odd / even / beat, Ghost odd / even / offbeat) et **Orchestration** (All snare, All HH, Toms down / up, R ride / L HH, MP, Shuffle), Repeat, Insert, Save to a pad.
- Onglet **Profile** : vélocités accent / normal / ghost, flas et drags (ms), humanize, Rush / Laid back, densité (ghost notes et kicks de Random et Vary), fin de fill (kick + crash, china…), remplacement des notes, ouverture du Display au démarrage.
- Onglet **Kit** : drum map du batteur, 29 éléments (6 toms, articulations de caisse claire, charley, ride, crashes, percussions, 2 grosses caisses) : **Detect from note names** (noms de notes chargés dans l'éditeur MIDI), **Load GM**, **Learn** (touche du clavier de l'éditeur MIDI, note sélectionnée ou pad d'un contrôleur).
- **Display** : petite barre sans titre (cachée sans éditeur MIDI) : batteur, chop choisi à la molette (clic = insérer, clic droit = les 16 pads), Again, Vary, Random, Open. Taille du texte, opacité et ouverture au démarrage de REAPER réglables (clic droit sur Open, ou onglet Profile).
- Relancer une action ferme sa fenêtre. Nécessite **ReaImGui**.

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/DrumBuddy/DrumBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/DrumBuddy/DrumBuddy_manual_EN.pdf)

### ReNo Mellow - Grid Buddy

- Lancer **ReNo Mellow - Grid Buddy** : onglet **Grid** pour l'arrangement et l'éditeur MIDI (type, taille, snap, case **Link MIDI editor to the arrange grid**), onglet **Set up** pour le diviseur (2 par défaut : 1/8 → 1/16), les limites (ex. 1/128 et 1), « Preserve grid type per size », les boutons affichés et le Display.
- **Link MIDI editor** active l'option de REAPER « Use the same grid division in arrange view and MIDI editor » : l'éditeur MIDI suit alors la grille de l'arrangement. Sinon, la section MIDI editor règle sa propre grille.
- **Deux Displays indépendants**, petites fenêtres sans titre à placer où l'on veut :
  - **Display** (arrangement, section Main) : molette = taille (au-delà de la plus fine : 1/8T, 1/16T, 1/32T ; au-delà de la plus large : 1/2D, 1/4D, 1/8D, 1/16D, 1/32D), clic = menu (types, swing, Frame, Measure, Hide grid, Link MIDI editor), Alt+clic = swing on/off, Alt+molette = quantité de swing (Ctrl : plus fin), icône aimant = snap (Alt+clic : snap relatif, clic droit : réglages), clic droit = fenêtre Grid Buddy.
  - **Display MIDI** (section MIDI Editor, « Grid Buddy MIDI - Display ») : la grille de l'éditeur MIDI, visible seulement quand un éditeur MIDI est ouvert ; molette = taille (au-delà de la plus fine : 1/8T, 1/16T, 1/32T ; au-delà de la plus large : 1/2D, 1/4D, 1/8D, 1/16D, 1/32D), clic = menu (types, swing, Hide grid, Link MIDI editor, **Sync to arrange view**), aimant = snap MIDI.
  - Chacun garde sa place et sa taille de texte, se rouvre au démarrage de REAPER s'il était ouvert ; relancer son action le ferme.
- **Actions isolées** (section Main, et dans la section MIDI Editor sous le nom « Grid Buddy MIDI ») : Adjust grid (mousewheel), Wider grid, Narrower grid, Toggle swing. L'action « mousewheel » est à associer à une molette (ex. Ctrl+molette) dans la liste d'actions.
- Les réglages d'Adaptive Grid / Gridbox (FeedTheCat) sont repris au premier lancement. Ne pas les faire tourner en même temps que Grid Buddy.
- Nécessite **ReaImGui** ; **js_ReaScriptAPI** est conseillée : sans elle, Alt / Ctrl + molette ou clic sur un Display ne sont vus que si le Display a le focus (cliquer dessus d'abord).

**Manuel d'utilisation :** [français (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/GridBuddy/GridBuddy_manuel_FR.pdf) · [English (PDF)](https://github.com/renothestraws/reno-mellow-manuals/raw/main/scripts/GridBuddy/GridBuddy_manual_EN.pdf)

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
- Onglet **Setup** : une ligne par strip, seul le nom est obligatoire. **Filtre** en haut pour cacher des lignes : un dossier (le même que dans l'onglet Strips) et un texte cherché dans le nom, le nom de piste et les tags. **Multisélection** : clic sur le numéro (#), Ctrl+clic pour ajouter / retirer, Shift+clic pour une plage ; une modification dans une ligne sélectionnée (couleur, normalisation, groupe…) s'applique à toutes les lignes sélectionnées, sauf le nom du strip. Plusieurs pistes sélectionnées avec un nom de piste : numérotation automatique (Tom 1, Tom 2...).
- **Héritage par tag** : la couleur et l'icône données au premier strip d'un tag (ex. Kick pour [KIK]) passent aux autres strips du même tag dans le même dossier, s'ils n'en ont pas encore.
- **Display** (action « ReNo Mellow - Strip Buddy - Display ») : petite barre flottante avec un bouton **Strip Buddy** à l'image de l'icône de barre d'outils (allumé quand la fenêtre est ouverte ; un clic ouvre ou ferme Strip Buddy), Zoom / View / Scroll / Select à gauche et la liste des tags du projet à droite (All + chaque tag, à la couleur de sa première piste). Un clic sur un tag applique les options allumées : View n'affiche que les pistes du tag (dossiers parents gardés), Zoom les agrandit à la hauteur de l'arrangement, Scroll amène la première en haut (TCP) ou à gauche (mixer), Select les sélectionne. Molette sur la liste = tag suivant / précédent. Taille (10 à 36) et opacité du fond (20 à 100 %) réglables par clic droit sur la barre. Onglet **Display** de la fenêtre principale : Display View et Display Scroll (TCP / MCP / Both), taille et opacité du Display et, sous « When REAPER starts », ouverture automatique de la fenêtre Strip Buddy et / ou du Display au démarrage de REAPER. Relancer l'action ferme le Display.
- Normalisation par strip : LUFS-I, RMS, Peak ou True peak, chaque item à la cible ou tous ensemble (gain commun) ; désactivée par défaut (case non cochée), cochée elle propose -15 dBFS Peak, tous ensemble.
- **Strips de base** : 207 strips (batterie, percussions, basse, guitares, claviers, cordes, vents, cuivres, chœur, voix, mix, live, divers…) rangés en 17 dossiers, chacun avec son nom de piste, son tag ([KIK], [SNR], [VOC]…) et le tag de son dossier en tag 2 (Kick in [KIK][DRM]), créés au premier lancement ; le bouton **Load default strips** (onglet Setup) rajoute ceux qui manquent sans toucher aux autres.
- Les strips sont enregistrés dans `Data/ReNo_StripBuddy/strips.lua`.
- **Export / Import** (onglet Setup) : sauver tous les strips ou un seul dossier dans un fichier `.rnstrips` (par défaut dans `Data/ReNo_StripBuddy/Exports`), puis le recharger en ajout (dossiers de même nom fusionnés, doublons ignorés) ou en remplacement. **Clear all strips** efface tous les strips (et, au choix, les dossiers) après confirmation.

**Icônes de piste :** 134 icônes `cs_tags_XXX.png` (le tag en blanc, 128 × 128), une par tag des strips de base, installées dans `Data/track_icons` ; les strips de base créés par Load default strips les utilisent (normalisation désactivée).

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

Le dossier `packages` contient un fichier `.ReaperPkg` par script (ReNo StemSplit, REABACK, MIDI cleaner, Strip Buddy, Tool Buddy, Recording Buddy, Grid Buddy, Chord Buddy, Drum Buddy).
Télécharger le fichier, puis l'ouvrir avec REAPER : les scripts sont installés et ajoutés à la liste d'actions,
et le paquet peut être désinstallé proprement. Pas de mises à jour automatiques : pour cela, préférer ReaPack.

Tool Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Tool_Buddy.ReaperPkg>
(la version éditeur MIDI est ajoutée à la section MIDI Editor au premier lancement de la Toolbox).

Strip Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Strip_Buddy.ReaperPkg>

Recording Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Recording_Buddy.ReaperPkg>

Grid Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Grid_Buddy.ReaperPkg>
(les actions de l'éditeur MIDI sont ajoutées à la section MIDI Editor au premier lancement de Grid Buddy).

Chord Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Chord_Buddy.ReaperPkg>

Drum Buddy en téléchargement direct :
<https://github.com/renothestraws/reno-mellow-script/raw/main/packages/ReNo_Mellow_Drum_Buddy.ReaperPkg>

## Installation manuelle

**REABACK** : télécharger le dossier `REABACK`, puis charger et lancer `REABACK_Install.lua` depuis la liste d'actions
(Actions > Show action list > New action > Load ReaScript) : il copie les scripts, les pages web, le template et les icônes.

**MIDI cleaner** : copier `MIDI/ReNo Mellow - MIDI cleaner.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**Tool Buddy** : copier le dossier `ToolBuddy` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Tool Buddy - Toolbox.lua` : elle ajoute toutes les autres actions (Main et MIDI Editor).

**Recording Buddy** : copier le dossier `RecordingBuddy` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Recording Buddy.lua` : il ajoute les actions Display, Start-Stop et Stop.

**Grid Buddy** : copier le dossier `GridBuddy` dans le dossier `Scripts` de REAPER, puis charger et lancer
`ReNo Mellow - Grid Buddy.lua` : il ajoute les deux Displays et toutes les actions (Main et MIDI Editor).

**Chord Buddy** : copier le dossier `ChordBuddy` dans le dossier `Scripts` de REAPER, puis charger
`ReNo Mellow - Chord Buddy.lua` et `ReNo Mellow - Chord Buddy - Display.lua` dans la liste d'actions.

**Drum Buddy** : copier le dossier `DrumBuddy` dans le dossier `Scripts` de REAPER, puis charger
`ReNo Mellow - Drum Buddy.lua` et `ReNo Mellow - Drum Buddy - Display.lua` dans la liste d'actions.

**Strip Buddy** : copier `StripBuddy/ReNo Mellow - Strip Buddy.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**ReNo StemSplit** : copier le dossier `StemSplit` dans le dossier `Scripts` de REAPER
(Options > Show REAPER resource path), puis charger ses actions dans la liste d'actions
(Actions > Show action list > New action > Load ReaScript).

## Licence

Gratuit pour tout usage, y compris commercial.

**ReNo StemSplit** s'appuie sur [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
Demucs v4 (Meta Research, licence MIT) et le modèle DrumSep MDX23C d'aufr33 et jarredou. Les modèles sont téléchargés
depuis leurs sources d'origine et restent la propriété de leurs auteurs.
**Grid Buddy** reprend du code de Gridbox et d'Adaptive Grid d'Ilias-Timon Poulakis (FeedTheCat), sous licence MIT.

Logic Pro et Stem Splitter sont des marques d'Apple ; ReNo n'est affilié à aucune de ces marques.
