# Performance (objectif : 60 fps stables partout)

## Choix qui servent l'objectif

- **Rendu Mobile (Vulkan)**, mais jeu 2D simple : aucune lumière, aucune ombre dynamique, aucun post-traitement.
- `run/max_fps=60` : pas de gaspillage de batterie au-delà de la cible.
- **Boucle d'images à la demande** : la grille ne redessine que tant qu'un effet est actif ; le fond animé n'anime que des
  transformations (GPU), il n'est dessiné qu'une fois.
- **La grille n'a plus qu'une bulle** (plus de tuiles par lettre) : un seul rectangle arrondi statique ; chaque capsule est une seule forme.
- Effets calculés à partir du temps (ressorts analytiques) : aucun état par case, aucune allocation par image dans le tracé.
- Validation des grilles sur un **thread de travail** pendant le chargement (l'écran reste animé).
- Aucune écriture disque dans les images de jeu : sauvegarde à chaque mot trouvé / indice / pause (fichiers de quelques Ko, atomiques).
- Icônes SVG importées à la résolution utile (×4) avec mipmaps : nettes sans retex à chaud.

## Mesure

`test/visual/bench_grid.gd` mesure le dessin des effets sur la grille 12×12 (pire cas) : < 4 ms de script, ~110 appels.
Le rendu logiciel de la machine de test ne mesure pas le GPU d'un téléphone.

## À faire sur appareil

1. Activer *Developer options > Profile GPU rendering* ou `adb shell dumpsys gfxinfo com.motsmeles.game framestats`.
2. Parcourir : accueil (glisser), niveau 10 (mélange, mot trouvé), victoire, monument (défilement).
3. Si des à-coups apparaissent au premier effet : activer `shader_baker/enabled=true` dans le préréglage (export sur une
   machine disposant d'un GPU) pour précompiler les shaders.
4. Test conseillé : appareil d'entrée de gamme (Android 8–10, 3 Go de RAM).
