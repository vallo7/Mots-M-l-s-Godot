# Mots Mêlés — version Godot 4.7

Jeu de mots mêlés hors ligne (FR / EN), Android, portrait. Portage du projet Kotlin / Jetpack Compose vers
**Godot 4.7.2** : GDScript typé, rendu **Mobile (Vulkan)**, objectif **60 fps stables**, rendu visuel **identique**
à l'application d'origine.

- 10 chapitres × 10 niveaux (de 4×4 jusqu'aux défis finaux 12×12), chaque niveau en français et en anglais, avec des leurres
  cachés dans les grilles et une difficulté qui monte d'un chapitre à l'autre (Nature, Voyage, Espace, Légendes, Sciences,
  Histoire, Arts, Sports, Gastronomie, Métiers). La montée est volontairement douce après le chapitre 5 : il reste de la marge
  pour de futurs chapitres (voir `docs/ARCHITECTURE.md`, « Ajouter des chapitres »).
- **20 trophées** (accomplissements) en six raretés, menu en grille de 3 colonnes sous les bulles de chapitre de l'accueil ;
  chaque chapitre terminé offre en plus un **cadeau** d'indices.
- Défi du jour : une grille par jour (la même pour tous), série de jours, indices en récompense.
- Mode sombre, volume des **effets sonores** et de la musique réglables, page d'aide, transitions sans aucun fondu.
- Aucun compte, aucun réseau pour jouer. Publicités : identifiants de **test** uniquement (vraies annonces de test Google dans l'APK de la CI, simulées dans l'APK léger de dépannage ; voir `docs/ADS.md`).
- Détail du portage, équivalences et limites connues : **`docs/MIGRATION.md`** (à lire en premier).

## Démarrer

1. Ouvrir le dossier avec Godot **4.7.2** (rendu *Mobile*). La première ouverture importe les ressources.
2. Lancer (F5) : la scène principale est `scenes/main.tscn`. Sur ordinateur, la fenêtre peut être redimensionnée ;
   la mise en page de référence est 360 × 800 dp.
3. Export Android : *Projet > Exporter* avec le préréglage « Android » (déjà configuré : `com.motsmeles.game`,
   arm64-v8a, version 1.4.0 / code 6, écran de démarrage Android blanc). Il faut que les modèles d'export de Godot 4.7.2, le SDK
   Android (platform-tools, build-tools), le JDK et la clé de debug soient configurés dans les *Paramètres de l'éditeur*.
   - **Préréglage « Android AdMob »** (Gradle + plugin, **vraies annonces de test Google**) : celui de la CI ; voir `docs/ADS.md`.
   - **Préréglage « Android »** (sans Gradle, modèle précompilé) : publicités de test **simulées** en debug, aucune en release.
     Attention : l'export Godot 4.7.2 sans Gradle produit un manifeste à deux autorités de provider identiques ; il faut passer
     `python3 scripts/ci/apk_tool.py fix-authorities <apk>` avant d'installer (voir `docs/CHANGELOG.md`, 1.2.1).
   Ou laisser la CI faire tout cela (ci-dessous).

## Tests et contrôles

```sh
scripts/ci/setup_godot.sh                 # télécharge Godot 4.7.2 (sans écran) dans ~/godot
scripts/ci/install_gdunit4.sh             # installe GdUnit4 6.1.3 (non versionné) et l'active
scripts/ci/install_admob.sh               # installe le plugin AdMob 5.1.0 (non versionné) : le fournisseur de publicités est alors compilé
scripts/ci/run_tests.sh                   # compile tous les scripts + 225 tests GdUnit4
godot --headless --path . -s res://scripts/check_daily.gd -- --days=800   # valide 800 jours de défis du jour (2 langues)
python3 scripts/check_repo.py             # identifiants de test, traductions, clés utilisées
python3 scripts/validate_levels.py        # validation des niveaux (miroir Python du validateur)
```

La CI (`.github/workflows/android.yml`) enchaîne : contrôles Python → tests → **APK de debug Gradle + AdMob** (vraies annonces de
test Google), vérifié (signature, manifeste, version, SDK AdMob présent) puis publié comme artefact `mots-meles-debug-apk`.
Un lancement manuel (*Run workflow*, case « light ») produit en plus l'APK léger sans Gradle (artefact `mots-meles-light-debug-apk`).

**Installer l'APK** : télécharger l'artefact (un zip), le dézipper, installer le `.apk`. Tous les APK de la CI sont signés avec la
même clé de debug (`ci/debug.keystore.b64`, SHA-256 `FF:8C:B0:A1:…:38:F5`) : un nouvel APK s'installe par-dessus le précédent.
Seule exception : si une ancienne version signée avec une autre clé est installée, la désinstaller une fois.
Note : `generate_levels.py --check` régénère les 100 niveaux (plusieurs minutes) pour prouver que les JSON viennent du générateur.

## Organisation

| Dossier | Rôle |
|---|---|
| `src/domain` | Règles pures (moteur, indices, étoiles, praise, progression, trophées, validation, cas d'usage). Aucun nœud, aucune scène : testé sans interface, exécutable sur un thread. |
| `src/data` | Lecture/écriture JSON versionnée, dépôts fichiers atomiques (`.bak`, `.corrupt`), sons et praises. |
| `src/platform` | Audio (lecteurs polyphoniques, musique en boucle), haptique. |
| `src/app` | Autoloads `App` (navigation, progression, réglages, cycle de vie) et `Feedback`, contrôleur de partie, démarrage. |
| `src/ui` | Écrans et composants (100 % code, dessinés avec `_draw`), moteur d'effets de la grille. |
| `src/ads` | Intégration AdMob (chargée seulement si le plugin natif est dans l'APK) et annonces simulées. |
| `ci` | Clé de signature de debug stable (`debug.keystore.b64`) ; exclue de l'export. |
| `data/levels` | Niveaux JSON (inchangés par rapport à l'app d'origine). |
| `translations` | `strings.csv` (EN/FR) importé par Godot. |
| `test` | 225 tests GdUnit4 + captures d'écran automatisées (`test/visual`). |
| `docs` | Architecture, design system, migration, publicité, performance, QA. |

## Licences

Voir `LICENSES.md` (Godot MIT, Roboto OFL, GdUnit4 MIT, sons et icônes du projet). Confidentialité : `PRIVACY.md` (brouillon).
