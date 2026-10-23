# Architecture

```
          ┌──────────────────────────── src/ui ─────────────────────────────┐
 gestes → │ Main · écrans · composants · LetterGridView · GridFx             │ → pixels
          └───────┬──────────────────────────────────────────────┬───────────┘
                  │ signaux                                       │ autoloads
          ┌───────▼────────┐  GameController          ┌──────────▼─────────┐
          │ src/app        │  (une partie)            │ App · Feedback     │
          └───────┬────────┘                          └──────────┬─────────┘
                  │ appels                                         │
          ┌───────▼───────────────── src/domain ─────────────────▼─────────┐
          │ GameEngine · GameSession · HintService · ProgressRules ·       │
          │ GameUseCases · LevelValidator · Praise* · StarRating · Motion  │
          └───────┬──────────────────────────────────────────────┬─────────┘
                  │ ports (classes de base)                       │
          ┌───────▼────────┐                              ┌──────▼─────────┐
          │ src/data       │ JSON, fichiers atomiques     │ src/platform   │ audio, haptique
          └────────────────┘                              │ src/ads        │ AdMob (optionnel)
                                                          └────────────────┘
```

## Règles de dépendance

- `src/domain` ne dépend de **rien** (ni nœud, ni autoload) : il est testable sans interface et exécutable sur un thread
  de travail (la validation des grilles tourne ainsi pendant l'écran de chargement).
- Les **ports** (`ProgressRepository`, `SettingsRepository`, `LevelRepository`, `AdProvider`, `AudioManager`,
  `HapticsManager`) sont des classes de base surchargées par `src/data`, `src/platform`, `src/ads` ou par des doublures de test.
- `src/ui` ne contient aucune règle de jeu : la victoire est **calculée** par le moteur, jamais déduite de l'affichage.

## Principes conservés de l'application d'origine

1. Victoire vérifiée par le moteur, enregistrée de façon atomique et idempotente.
2. Un indice n'est retiré qu'une fois le solde persisté ; sauvegarde en échec = ni retrait, ni révélation.
3. Récompense publicitaire accordée seulement après confirmation du SDK, un identifiant par diffusion (jamais deux fois).
4. Aucune publicité involontaire : politique de retour (`ReturnAdPolicy`) avec absence minimale, délai de répit, pas
   pendant un geste ni une victoire.
5. Chronomètre : démarre au premier geste, se suspend en arrière-plan, horloge monotone.
6. Persistance versionnée (`schemaVersion`), migration prévue, sauvegarde plus récente refusée plutôt qu'écrasée.

## Cycle de vie

`Main._ready` → `App.start()` : dépôts → réglages (langue appliquée dès le chargement) → `StartupSequence`
(niveaux → validation sur thread → progression → audio, 2 s minimum une seule fois) → accueil. Pause/reprise :
notifications `APPLICATION_PAUSED/RESUMED` → chronomètre, musique, publicité de retour.

## Rendu

Toutes les dimensions sont en dp (fenêtre de référence 360 × 800, `canvas_items`, `expand`). Les éléments animés
utilisent l'*offset transform* des `Control` (transformation visuelle, hors mise en page). La grille est dessinée en
deux couches (bulle statique, effets dynamiques redessinés seulement tant qu'un effet est actif).

## Navigation et popups

`Main` pilote les transitions de page à la main (progression bornée à 1/30 s par image : une image lente fait attendre
l'animation au lieu de lui faire sauter des étapes ; 2 images de « chauffe » avant le départ ; touches bloquées pendant
la transition). Un écran peut définir `on_entered()` : appelé une fois la page en place (la victoire y lance sa séquence).
Le mouvement de chaque changement de page est décrit par `PageTransition` : **aucun fondu**, jamais d'opacité animée.
Quatre styles : `SLIDE` (glissement avec parallaxe : menus, aide, défi), `IRIS` (disque qui s'ouvre depuis le doigt à
l'entrée en jeu, se referme à la sortie ; `IrisWrap` = masque circulaire par `clip_children`), `RISE` (la victoire monte du
bas) et `CURTAIN` (le chargement se lève). Chaque écran peut déclarer des groupes d'éléments (`transition_groups()`) qui
entrent l'un après l'autre avec un petit rebond et repartent plus vite ; il peut aussi définir `on_leaving()` (au départ)
et `on_entered()` (à l'arrivée : la bannière de publicité n'apparaît qu'à ce moment).
`PopupHost` centre la carte dans la zone sûre, la borne à la taille de l'écran et gère le défilement éventuel de son contenu.

## Mode sombre

Les neutres de `Wg` (`BACKGROUND`, `SURFACE`, `INK`, `OUTLINE`, …) sont des variables que `Wg.apply_theme(dark)` remplace ;
`WHITE` et `INK_FIXED` restent constants (texte sur couleur vive). Un changement de thème reconstruit l'interface en place
et `Main` révèle le nouvel écran dans un disque qui grandit depuis l'interrupteur, au-dessus d'une capture de l'ancien.

## Défi du jour

`DailyChallenge` (règles, jours locaux), `DailyLevelFactory` (grille déterministe par jour et par langue : graine FNV-1a,
mots tirés des listes des niveaux, difficulté selon le jour de la semaine, dimanche = 12×12), `ProgressRules.complete_daily`
(une victoire par jour ; +1 indice, +1 avec 3 étoiles, bonus aux séries de 3/7/14/30 jours, une fois par série),
`DailyModel` (affichage). La grille est préparée dans un thread (`App.daily_prepare`) ; `scripts/check_daily.gd` en valide
800 jours dans les deux langues. La sauvegarde passe en schéma 2 (la migration abandonne les parties en cours des anciens
niveaux, conserve étoiles, niveaux terminés et indices).

## Trophées

`Trophy` (identifiant, compteur, objectif, rareté), `TrophyCatalog` (les 20 trophées, dans l'ordre d'affichage = difficulté
croissante), `TrophyRules` (fonctions pures : valeur d'un compteur, déblocage à une heure donnée, trophées « vus », compteurs
mémorisés). Deux familles de compteurs : **dérivés** de la progression (niveaux, étoiles, chapitres, cadeaux, séries du défi du
jour : exacts, donc attribués rétroactivement) et **mémorisés** dans `ProgressState.stats` (indices utilisés, niveaux sans faute,
éclairs, défis du jour, défis finaux sans indice, meilleure série de 3 étoiles). `GameUseCases` les met à jour dans la même
écriture atomique que la victoire, l'indice, le cadeau ou le défi du jour. `App._refresh_progress` compare les trophées connus
et émet `trophy_unlocked` (bandeau `TrophyToast`). Ajouter un trophée : une ligne dans `TrophyCatalog` + deux textes
(`trophy_<id>_name`, `trophy_<id>_desc`) ; ne jamais renommer ni retirer un identifiant déjà publié. Sauvegarde schéma 3.

## Ajouter des chapitres

`scripts/generate_levels.py` est la source éditoriale (mots FR/EN, taille, difficulté). Ajouter un `dict(id="chapter-NN", …)` à
la fin de `CHAPTERS` ne modifie pas les chapitres existants (graine par niveau). Règles : score moyen par chapitre strictement
croissant, score strictement croissant dans le chapitre, défi final ≥ 1,15 × niveau 9, au moins un leurre par niveau (hors
chapitre 1), longueur moyenne des mots croissante, aucun mot contenu (même à l'envers) dans un autre. Ajouter la palette
(`Wg.chapter_theme`) et l'illustration (`assets/illustrations/ill_chapter_<palette>.svg`). Marge restante : tailles jusqu'à 11
(12 pour les finaux), 17 mots, 10 leurres, ambiguïté 1,0.

## Textes

`translations/strings.csv` est importé en `.translation` ; les deux fichiers sont déclarés dans `project.godot`
(`internationalization/locale/translations`). `Strings.ensure_loaded()` est un filet de sécurité : aucune clé brute à l'écran.

## Niveaux : cinq chapitres, leurres, difficulté

`scripts/generate_levels.py` fabrique les 50 niveaux (déterministe) ; `scripts/validate_levels.py` et `LevelValidator`
appliquent les mêmes règles. Tailles : 4×4 et 5×5 réservées au chapitre 1, puis 6 à 11, 12×12 pour le niveau 10 de chaque
chapitre. Chaque niveau peut planter des **leurres** (`decoys` : débuts de mots ou mots « presque justes » cachés dans la
grille, validés par le script Python) ; le score de difficulté en tient compte (+1,5 par leurre). Règles de progression :
score strictement croissant dans un chapitre, score moyen croissant d'un chapitre à l'autre, défi final ≥ 1,15 × niveau 9.

## Niveaux : longueurs de mots

Chaque niveau (dès le 4×4) mêle mots courts et mots longs ; le mélange dépend de la taille de la grille et du palier
(`LENGTH_PROFILE`, `min_longest_word`). Règle appliquée par `scripts/level_tools.py` (génération/CI) et `LevelValidator` (démarrage, tests).
