# Journal des modifications

## 1.2.0

**Contenu**
- **5 chapitres de plus** (6 à 10 : Histoire, Arts, Sports, Gastronomie, Métiers) : 100 niveaux au total, chacun en FR et EN, avec
  leurs illustrations et palettes. Scores moyens par chapitre 117,4 / 117,7 / 118,6 / 119,3 / 120,1 (chapitre 5 : 115,9) : jamais
  plus facile que le chapitre précédent, mais une montée douce qui laisse de la marge (finaux à 145-146, 10 leurres au plus).
  Les anciens chapitres sont inchangés (le générateur est déterministe).
- **Système de trophées** : 20 accomplissements en six raretés (commun, peu commun, rare, épique, légendaire, mythique), deux
  faciles pour démarrer puis de plus en plus durs. Menu en **grille de 3 colonnes** (bouton sous les bulles de chapitre, à la
  place des points de pagination, supprimés), fiche de détail au toucher (rareté, description, avancement ou date de
  déblocage), étiquette « Nouveau » et pastille de l'accueil, bandeau « Trophée débloqué » en jeu. Les joueurs existants
  reçoivent leurs trophées rétroactivement. Sauvegarde en schéma 3 (champs additifs).

**Interface**
- Nouvelles images : étoile, trophée (en teintes de rareté, gris quand il est verrouillé), **cadeau** (à la place du trophée dans
  les bulles de chapitre, la victoire et le monument), **pièce-couronne** (à la place de la flamme de la série).
- Réglages : **curseur de volume des effets sonores** (appliqué en direct, clic témoin au relâchement) à la place de l'interrupteur.
- Écran de chargement : plus aucun conseil ; barre tout en bas de l'écran ; mention discrète « Développé par Vallo Game ».
- Crédits : section « Développeur » (Vallo Game).
- Splash Android : **page blanche** (icône de démarrage transparente ; fonctionne sans Gradle).

**Publicités et build**
- Export **sans Gradle** par défaut, avec annonces de test simulées ; vraies annonces de test Google dans le préréglage
  « Android AdMob » (job CI optionnel). Voir `docs/ADS.md` pour le pourquoi.

**Technique**
- Version 1.2.0 (code 3). 219 tests GdUnit4. Vocabulaire : le « trophée » de fin de chapitre s'appelle désormais « cadeau »
  (`GiftBadge`), « trophée » désigne les accomplissements (`Trophy`, `TrophyRules`, `TrophyCatalog`).

## 1.1.0

**Contenu et difficulté**
- 5 chapitres de 10 niveaux (Nature, Voyage, **Espace, Légendes, Sciences**) au lieu de 2 : 50 niveaux, chacun en FR et EN.
- Difficulté relevée partout : grilles plus grandes et plus tôt (de 4×4 à 11×11, 12×12 en final), plus de mots, mots plus longs,
  directions complètes plus tôt, grilles remplies avec les lettres des mots, et **leurres** (débuts de mots cachés).
  Règles de validation étendues (tailles 4 à 12, profils de longueurs, score moyen croissant par chapitre, défi final ≥ 1,15 × niveau 9
  au lieu de 1,25) en Python et en GDScript.
- **Défi du jour** complet : grille par jour (la même pour tous), difficulté selon le jour, série, calendrier, récompenses.
- Nouvelle page **Aide** (bouton à côté des réglages) : comment jouer, étoiles, indices, récompenses.

**Interface**
- Transitions refaites, sans aucun fondu : glissement avec parallaxe, iris depuis le doigt en entrée/sortie de niveau, montée à
  la victoire, rideau au démarrage ; les éléments entrent et sortent en cascade.
- Écran de chargement : plus de logo ; le gant joue en boucle une démonstration (3 scénarios au hasard), 10 commentaires au hasard,
  durée minimale de 2,8 s.
- Accueil : bulles de chapitre plus courtes avec pourcentage d'étoiles, illustrations propres à chaque thème, filigrane dézoomé,
  bannière du défi du jour. Liste des niveaux : défilement animé jusqu'au niveau en cours.
- Réglages : **mode sombre**, **curseur de volume** de la musique, langue dans une **liste dédiée**, « restaurer les paramètres » retiré.

**Publicités**
- Cause du dysfonctionnement corrigée : plugin AdMob installé par la CI, export Gradle activé, initialisation du SDK attendue ;
  annonces de test simulées en debug sans plugin (voir `docs/ADS.md`).

**Technique**
- Version 1.1.0 (code 2). Sauvegarde en schéma 2 (migration : parties en cours abandonnées, progression conservée).
- 195 tests GdUnit4 ; `scripts/check_daily.gd` ; `scripts/ci/install_admob.sh`.
- Correctifs : un écran de jeu reconstruit en place (langue, thème) ne met plus la partie en pause ni ne retire la bannière.

## 1.0.0-rc2
**Corrections**
- Textes de l'interface affichés sous forme de clés brutes (`home_play`, `settings_title`…) : les traductions n'étaient pas
  déclarées dans `project.godot`. Elles le sont maintenant, avec un filet de sécurité dans `Strings`. C'était aussi la cause des
  popups et cartes qui débordaient de l'écran (les clés brutes sont bien plus longues que les textes).
- Lettres de la grille qui se décalaient au début d'un tracé : la transformation de dessin d'une lettre animée restait active
  pour toutes les lettres suivantes (`GridFx.draw`).
- Popups : toujours centrés dans la zone sûre, jamais plus larges ni plus hauts que l'écran ; réglages : tous les éléments visibles.
- Boutons à libellé et libellés de victoire : le texte rétrécit pour tenir, il ne fait plus déborder son conteneur.

**Navigation**
- Transitions de page en « push » avec parallaxe et ombre de bord, pilotées à la main (aucune saccade si une image est lente).
- Popups : voile en cercle (sans fondu), entrée à ressort doux, sortie animée.
- La victoire lance sa séquence une fois la page en place ; plus d'entrées en cascade pendant le glissement.

**Modifications**
- Indice sans solde : la publicité se lance directement (micro-délai + animation du bouton), plus de popup de confirmation.
- Grille : une seule grande bulle sans contour, sans bulles par lettre, agrandie au maximum (6 dp de marge) ; lettres foncées.
- Tracés : capsules plates, moins saturées et plus transparentes ; plus de reflet blanc sur les tracés.
- Tous les boutons d'action au design à contour blanc de l'écran de victoire, sans reflet.
- Plus aucune particule (étincelles, traînées) ni onde de choc sur la grille.
- Niveaux : mots courts et longs mélangés, selon la taille de la grille et le palier (règle `LENGTH_MIX` vérifiée en CI et au démarrage).
- Barre du haut du monument : progression du chapitre en cours.
- Retire `RewardedOfferPopup` et les textes `rewarded_*`.

## 1.0.0-rc1 (portage Godot)
- Portage complet de l'application Kotlin / Compose vers Godot 4.7.2 (GDScript typé, rendu Mobile).
- Domaine porté un pour un ; 146 tests GdUnit4 ; niveaux et validations inchangés.
- Interface identique : accueil à carrousel, jeu, victoire, monument, réglages, crédits.
- Moteur d'effets de grille regroupé en trois couches, tuiles en un seul lot de dessin.
- CI GitHub Actions : contrôles, tests, APK de debug.
- Intégration AdMob optionnelle (non testée sur appareil).
- Export Android sans Gradle (hors ligne) : `gradle_build/use_gradle_build=false` ; correction des 19 avertissements de l'analyseur GDScript.
