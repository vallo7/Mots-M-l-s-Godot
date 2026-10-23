# Rapport de portage : Kotlin / Compose → Godot 4.7.2

> Ce document décrit le portage initial (version 1.0). Les évolutions de la 1.1.0 (cinq chapitres, défi du jour, mode sombre, publicités, transitions) sont dans `docs/CHANGELOG.md`.

## 1. Décisions (validées)

| Sujet | Choix |
|---|---|
| Langage | GDScript **typé** (aucun `Variant` implicite dans le domaine) |
| Rendu | **Mobile** (Vulkan) |
| Fidélité visuelle | **Identique** à l'application Kotlin |
| Police | Roboto variable (graisses 700 / 800 / 900), licence OFL |
| Dépôt | nouveau dépôt dédié |
| Pubs | identifiants de test Google uniquement |
| Musique | « C — Music Box Dream » |
| Tests | GdUnit4 6.1.3 |
| Package Android | `com.motsmeles.game` (définitif à la première publication Play) |
| Cible | Android uniquement, 60 fps stables |
| Livraison | projet complet d'un coup |

## 2. Équivalences

| Kotlin | Godot |
|---|---|
| Module `:domain` (JVM pur, 79 tests) | `src/domain` (GDScript pur, mêmes règles, mêmes scénarios de test) |
| Compose (`@Composable`, `Canvas`) | `Control` dessinés en code (`_draw`, `StyleBoxFlat`, `Label`) |
| `graphicsLayer` (échelle, rotation, translation) | « offset transform » des `Control` (nouveauté 4.7 : n'affecte ni la mise en page ni la zone tactile) |
| `spring(...)`, `animate*AsState` | `SpringValue` (intégration pas à pas) et `Motion.spring` (analytique) |
| `GridFx` (Canvas unique) | `GridFx` + `LetterGridView` (2 couches : bulle, effets dynamiques) |
| `HorizontalPager` | `ChapterPager` (glisser, élan, aimantation par ressort, parallaxe) |
| `AppViewModel` + `StateFlow` | autoload `App` + signaux |
| `DataStore` | `FileProgressRepository` / `FileSettingsRepository` (écriture atomique, `.bak`) |
| `SoundPool` / `MediaPlayer` | `AudioStreamPlayer` polyphoniques / lecteur OGG en boucle |
| `Vibrator` | `Input.vibrate_handheld(durée, amplitude)` |
| `strings.xml` (FR/EN, pluriels) | `translations/strings.csv` (`{0}` positionnels, pluriels `_one` / `_other`) |
| VectorDrawable XML | SVG importés (`svg/scale` 4 pour les icônes, 3 pour les illustrations) |
| Google Mobile Ads + UMP | plugin « Godot AdMob » (Poing Studios 5.x), optionnel |
| JUnit | GdUnit4 |

Le domaine n'a pas été « réinventé » : fonctions, noms et règles sont portés un pour un. Les 20 niveaux livrés passent
**toutes** les règles du validateur GDScript (test `LevelAssetsTest`) et celles du validateur Python.

## 3. Ce qui a été vérifié (ici, par exécution)

- **146 tests GdUnit4 passent** (domaine, données, persistance, contrôleur de partie) ; 0 orphelin ; compilation de
  tous les scripts contrôlée (`scripts/check_scripts.gd`).
- Rendu réel de **tous les écrans** avec Godot 4.7.2 (Vulkan logiciel) : chargement, accueil, monument, réglages,
  crédits, jeu (repos, tracé, mot trouvé, erreur, indice), victoire. Captures reproductibles : `test/visual`.
- Démarrage à froid de la vraie scène principale : progression créée (2 indices offerts), aucune erreur.
- Charge de la grille 12×12 dans le pire cas (mélange + mot trouvé) : dessin des effets **< 4 ms** de script.

## 4. Ce qui n'a PAS pu être vérifié ici (à tester sur appareil)

1. **Export APK / AAB** : la CI est écrite d'après le code source de Godot 4.7.2 (options d'export, SDK 36, NDK 29,
   Java 17) mais n'a pas été exécutée ici (pas de SDK Android).
2. **Fluidité réelle sur téléphone** : mesurée seulement côté scripts. À valider sur un appareil d'entrée de gamme
   (voir `docs/PERFORMANCE.md`).
3. **Publicités** : l'intégration suit la documentation officielle du plugin et compile contre une doublure de son API ;
   elle n'a jamais tourné avec le vrai plugin (`docs/ADS.md`).
4. **Gestes tactiles** : carrousel, défilement du monument, tracé sur la grille. Ils utilisent les événements souris
   émulés depuis le tactile (comportement par défaut de Godot) et ont été testés à la souris.
5. **Vibration** : l'amplitude exige Android 8+ (min SDK 26 : ok) ; le réglage système « retour haptique » n'est pas lisible
   depuis Godot (l'app d'origine le respectait).

## 5. Écarts connus par rapport à l'application Kotlin

| Écart | Raison / contournement |
|---|---|
| Mode immersif sur **tous** les écrans (barres système masquées) | c'est une option d'export Android globale (`screen/immersive_mode`) ; l'app d'origine ne le faisait qu'en jeu. À mettre à `false` dans `export_presets.cfg` pour retrouver les barres hors jeu (la zone sûre est déjà gérée). |
| Taille de police système (accessibilité Android) non suivie | Godot n'expose pas le facteur de police système ; le réglage « Texte plus grand » (×1,15) reste disponible. |
| « Animations système désactivées » non détecté | idem ; le réglage « Réduire les animations » de l'app fonctionne. |
| Lecteur d'écran (TalkBack) | les propriétés d'accessibilité Godot sont renseignées mais leur prise en charge sur Android est limitée ; à évaluer. |
| Connectivité | pas d'API directe : « hors ligne » est déduit des erreurs de chargement d'annonce. |
| Reprise de sauvegardes de l'app Kotlin | non prévue (jeu non publié) : même format JSON, mais un fichier Kotlin n'est pas importé. |
| Musique : la version de l'archive (`bgm_main.ogg`) diffère de celle de GitHub | la musique **C** de GitHub est utilisée. |

## 6. Mises à jour utiles

- Changer de niveau d'effets : `src/ui/grid_fx.gd` (constantes en tête de fichier).
- Ajouter une langue : `Language`, colonne dans `strings.csv`, bloc dans les JSON de niveaux, `praise_map.json`.
- Ajouter un chapitre : `scripts/generate_levels.py`, `data/levels/index.json`, palette dans `Wg.chapter_theme`.
