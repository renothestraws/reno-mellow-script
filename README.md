# ReNo Mellow Scripts – scripts Lua gratuits pour REAPER

Les plug-ins JSFX **ReNo Mellow** (compresseurs, EQ, couleur, instruments) sont dans un dépôt séparé :
<https://github.com/renothestraws/reno-mellow>

## Scripts

| Script | Description |
|---|---|
| **ReNo StemSplit** | Séparation de stems par IA, en local (esprit Stem Splitter de Logic Pro). Trois actions : **Stems** (voix, batterie, basse, guitare, piano, autres – 6 ou 4 stems), **Drums** (kick, snare, toms, cymbales – 4, 5 ou 6 pièces, depuis un mix complet ou une piste de batterie seule) et **Install** (installation / réparation du moteur) |

### ReNo StemSplit

Les stems arrivent sur de nouvelles pistes sous la piste d'origine (dossier optionnel), alignés et colorés ;
l'item d'origine peut être muté. Les WAV sont enregistrés dans le dossier `Stems` du dossier média du projet.

**Moteur (installation unique) :** nécessite **Python 3.10 à 3.13** (3.12 conseillé).
- Windows : `py install 3.12` (Python install manager) ou `winget install Python.Python.3.12`
- macOS : installateur python.org ou `brew install python@3.12`

Au premier lancement, le bouton **Install engine** installe tout dans `Data/ReNo_StemSplit` (environ 1,5 Go,
4,5 Go avec la version GPU NVIDIA, détectée et testée automatiquement ; Apple Silicon utilisé automatiquement).
Ensuite, tout fonctionne hors ligne. Supprimer `Data/ReNo_StemSplit` désinstalle le moteur.
En cas d'erreur : bouton **Open log** (journaux `install.log` et `last_run.log`).

Durée pour un morceau de 4 min : 20 s à 1 min avec une carte NVIDIA ou un Mac Apple Silicon, 2 à 6 min sur processeur seul.

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

Copier le dossier d'un script (par ex. `StemSplit`) dans le dossier `Scripts` de REAPER
(Options > Show REAPER resource path), puis charger ses actions dans la liste d'actions
(Actions > Show action list > New action > Load ReaScript).

## Licence

Gratuit pour tout usage, y compris commercial.

**ReNo StemSplit** s'appuie sur [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
Demucs v4 (Meta Research, licence MIT) et le modèle DrumSep MDX23C d'aufr33 et jarredou. Les modèles sont téléchargés
depuis leurs sources d'origine et restent la propriété de leurs auteurs.
Logic Pro et Stem Splitter sont des marques d'Apple ; ReNo n'est affilié à aucune de ces marques.
