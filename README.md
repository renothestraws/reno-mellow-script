# ReNo Mellow Scripts – scripts Lua gratuits pour REAPER

Les plug-ins JSFX **ReNo Mellow** (compresseurs, EQ, couleur, instruments) sont dans un dépôt séparé :
<https://github.com/renothestraws/reno-mellow>

## Scripts

| Script | Description |
|---|---|
| **REABACK** | Lancement des backing tracks sur scène : setlist de régions (une chanson = une région mère), transport, Live loop, contrôle à distance depuis un téléphone et prompteur de paroles / accords pour tablette. Fournit 8 actions, 2 pages web, un project template et des icônes de barre d'outils |
| **ReNo Mellow - MIDI cleaner** | Nettoie les items MIDI sélectionnés : supprime SysEx, Program Change, pitch bend et tous les CC sauf CC4, CC11 et CC64, passe tout sur le canal 1 et règle le timebase sur Beats (position, length, rate) |
| **ReNo StemSplit** | Séparation de stems par IA, en local (esprit Stem Splitter de Logic Pro). Trois actions : **Stems** (voix, batterie, basse, guitare, piano, autres – 6 ou 4 stems), **Drums** (kick, snare, toms, cymbales – 4, 5 ou 6 pièces, depuis un mix complet ou une piste de batterie seule) et **Install** (installation / réparation du moteur) |

### ReNo StemSplit

Option **Quality** : *Standard* (Demucs pour tout, le plus rapide) ou *Vocals HQ* (voix séparée par BS-RoFormer, de meilleure qualité, puis le reste par Demucs ; environ deux fois plus lent).

Les stems arrivent sur de nouvelles pistes sous la piste d'origine (dossier optionnel), alignés et colorés ;
l'item d'origine peut être muté. Les WAV sont enregistrés dans le dossier `Stems` du dossier média du projet.

**Moteur (installation unique) :** nécessite **Python 3.10 à 3.13** (3.12 conseillé).
- Windows : `py install 3.12` (Python install manager) ou `winget install Python.Python.3.12`
- macOS : installateur python.org ou `brew install python@3.12`

Au premier lancement, le bouton **Install engine** installe tout dans `Data/ReNo_StemSplit` (environ 1,5 Go,
4,5 Go avec la version GPU NVIDIA, détectée et testée automatiquement ; Apple Silicon utilisé automatiquement ; les Mac Intel ne sont pas pris en charge).
Ensuite, tout fonctionne hors ligne. Pour profiter des nouveaux modèles et corrections de la bibliothèque : action **Install** > **Update engine** (Internet nécessaire). Supprimer `Data/ReNo_StemSplit` désinstalle le moteur.
En cas d'erreur : bouton **Open log** (journaux `install.log` et `last_run.log`).

Durée pour un morceau de 4 min : 20 s à 1 min avec une carte NVIDIA ou un Mac Apple Silicon, 2 à 6 min sur processeur seul.

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

## Installation manuelle

**REABACK** : télécharger le dossier `REABACK`, puis charger et lancer `REABACK_Install.lua` depuis la liste d'actions
(Actions > Show action list > New action > Load ReaScript) : il copie les scripts, les pages web, le template et les icônes.

**MIDI cleaner** : copier `MIDI/ReNo Mellow - MIDI cleaner.lua` dans le dossier `Scripts` de REAPER, puis le charger dans la liste d'actions.

**ReNo StemSplit** : copier le dossier `StemSplit` dans le dossier `Scripts` de REAPER
(Options > Show REAPER resource path), puis charger ses actions dans la liste d'actions
(Actions > Show action list > New action > Load ReaScript).

## Licence

Gratuit pour tout usage, y compris commercial.

**ReNo StemSplit** s'appuie sur [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
Demucs v4 (Meta Research, licence MIT) et le modèle DrumSep MDX23C d'aufr33 et jarredou. Les modèles sont téléchargés
depuis leurs sources d'origine et restent la propriété de leurs auteurs.
Logic Pro et Stem Splitter sont des marques d'Apple ; ReNo n'est affilié à aucune de ces marques.
