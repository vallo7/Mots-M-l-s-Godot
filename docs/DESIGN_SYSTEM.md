# Design system (identique à l'application d'origine)

Source unique : `src/ui/wg.gd` (jetons) — palette vive sur fond blanc, relief 3D par « lèvre » foncée, **aucun fondu**.

- **Couleurs** : encre `#2A2750`, violet `#7B5CFF`, bleu `#2EB8FF`, vert `#5CD62F`, jaune `#FFC81E`, orange `#FF8A1F`,
  rose `#FF3D8B`, rouge `#FF4B55`, turquoise `#14D1B8` ; chacune a sa variante foncée (lèvre).
- **Dimensions** (dp) : espacements 4 / 8 / 16 / 24 / 32, rayons 10 / 18 / 28, zone tactile ≥ 48, bouton 46 + lèvre 4.
- **Typographie** : Roboto variable — 700 (texte), 800 (libellés), 900 (titres). Ombre dure (0, 3 dp) sur les boutons.
- **Mouvement** : tout rebondit (ressorts), grandit, glisse ou rétrécit ; pression « gelée » (échelle 1,07 × 0,89 au maximum,
  étirement au relâchement). « Réduire les animations » : tout passe en échelon.
- **Boutons d'action** : tous cerclés de blanc (anneau 4 dp + ombre douce) sur une bulle colorée à lèvre foncée, **sans reflet** :
  `RingButton` (rond : retour, recommencer, réglages, fermer, niveaux, accueil, suivant), `HintButton`, pastille « Jouer » et
  boutons d'action des cartes (`WgButton` avec `with_ring`). Les boutons de popup restent à lèvre simple, sans reflet non plus.
- **Grille** : une seule grande bulle plate (`Wg.GRID_BUBBLE`), sans contour, sans bulles par lettre ; lettres toujours foncées ;
  tracés = capsules plates claires et translucides (`Wg.trace_tint` : saturation × 0,55, opacité 0,52), une seule forme chacune.
- **Pas de particules, pas de fondu** : aucun effet ne change d'opacité dans le temps (le voile des popups s'ouvre en cercle).
- **Navigation** : pages en « push » (la nouvelle glisse, l'ancienne recule de 28 % : parallaxe, ombre de bord, 0,42 s, courbe
  quartique) ; popups centrés dans la zone sûre, jamais plus larges que l'écran (`PopupHost` réduit la carte en dernier recours) ;
  entrée à ressort doux (échelle 0,86 → 1 + montée de 28 dp), sortie rapide.
- **Composants** : `BubbleButton`, `WgButton`, `RingButton`, `ChunkyProgressBar`, `RibbonBanner`,
  `PopupHost` / `PopupCard`, `HintChip`, `StarsRow`, `GiftBadge`, `WgSwitch`, `LevelPill`, `ChapterCardView`.
- **Styles de difficulté** : turquoise (niveaux 1–3), jaune (4–6), rose (7–9), violet (niveau final).
