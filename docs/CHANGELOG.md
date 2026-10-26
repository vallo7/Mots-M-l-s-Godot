# Journal des modifications

## 1.4.0

**Navigation et fluidité**
- **Défilement des listes** (niveaux, trophées, aide, défi du jour) : nouveau `SmoothScroll` à la place du ScrollContainer. Le contenu suit
  le doigt 1:1 (sans à-coup au démarrage), la vitesse est mesurée sur les ~100 dernières ms, le lancer glisse avec une friction
  exponentielle, les extrémités s'étirent avec une résistance élastique puis reviennent par un ressort amorti qui garde la vitesse du doigt.
  Poser un doigt arrête l'élan. Molette de souris prise en charge.
- **Carrousel de chapitres** (accueil) : même soin. La page suit le doigt sans à-coup, la page visée dépend de la distance ET de la vitesse
  (un petit coup de doigt rapide suffit, jamais plus d'une page à la fois), le ressort de fin repart avec la vitesse du doigt, léger
  « clic » haptique au changement de page, mise en page allégée (les pages ne sont plus redimensionnées à chaque image).
- **Contrôles non recalés sur des pixels entiers** (`gui/common/snap_controls_to_pixels=false`) : sur un écran virtuel de 360 dp un pas
  valait environ 3 pixels réels, d'où des marches d'escalier aux faibles vitesses ; défilements, carrousel et transitions avancent maintenant au pixel près.
- **Transitions de pages** retravaillées : tous les éléments entrent et sortent un à un (l'écran de jeu et l'écran de victoire n'avaient
  aucun groupe), courbes douces à décélération en quart de puissance, **plus aucun rebond**, durée d'image lissée sur 3 images et première
  image (écran tout juste construit) comptée pour 1/60 s, échauffement de 3 images. L'iris (découpe de toute la page à chaque image, coûteux
  sur mobile) est remplacé par une montée (entrée en jeu) et une descente (sortie du jeu) ; `PageTransition.USE_IRIS` permet de le rétablir.
- Aucun fondu ni confetti nulle part : les tutoriels ouvrent/ferment un projecteur (iris du voile) et rétractent le tracé au lieu de s'effacer.

**Tracé des mots**
- Direction et longueur suivent la **position exacte du doigt** (angle par secteurs de 45° avec hystérésis, longueur projetée sur l'axe) au lieu de la
  case sous le doigt : ligne stable, diagonales faciles, plus de sauts d'une direction à l'autre près des frontières.
- **Gamme montante** : chaque lettre ajoutée joue une note plus haute (pentatonique, jusqu'à une octave et demie), la note redescend quand
  on recule ; vibration légère à chaque lettre (inchangée).

**Redémarrage** : le bouton restart fait **pivoter la grille d'un quart de tour, à gauche ou à droite au hasard** : mêmes mots, directions de tracé différentes.
Les lettres glissent comme sur une courroie le long des carrés concentriques de la grille (aucun chevauchement, aucune lettre hors de la grille). L'orientation est
mémorisée avec la partie en cours (reprise après interruption). Les indices visent le début du mot sur la grille tournée.

**Tutoriel** : à la **toute première ouverture**, le gant tape en boucle sur « Jouer » de la bulle du chapitre 1 (depuis l'accueil), puis le tutoriel continue
sur le niveau 1 (inchangé, sans texte) ; il suit la rotation si le joueur redémarre.

**Interface**
- **Liste des niveaux** : plus de bannière sur les illustrations ; le titre du chapitre est écrit **en bas de l'illustration** (blanc cerné de la couleur du chapitre).
- **Bouton Indice** remonté : 22 dp au-dessus de la zone publicitaire, qui suit la vraie hauteur de la bannière adaptative (50 à 90 dp).

**Tests** : 294 tests GdUnit4 (rotation, direction continue, défilement, carrousel, courroie, tutoriel d'accueil, sauvegarde de l'orientation).

## 1.3.0

**Publicités et revenus** (détail : `docs/ADS.md`)
- **Interstitielle au passage au niveau suivant** : une chance sur trois, tirée au hasard à chaque fois. Garde-fous : aucune avant
  4 niveaux terminés, jamais deux annonces plein écran à moins de 90 s, pas juste après une récompensée, probabilité réduite pour
  le joueur qui regarde déjà beaucoup de récompensées, 12 par heure au plus ; pas d'annonce prête = le jeu continue sans attendre.
- **Système de rythme** réglable sans code (`data/ads_policy.json`, `AdPolicyConfig`, `AdPacing`, `InterstitialPolicy`), préchargement de
  l'interstitielle avec nouveaux essais à délais croissants (aussi pour la récompensée et l'annonce d'ouverture), renouvellement avant
  l'expiration d'une heure, contenu publicitaire plafonné à PG (tout public). Identifiant de test `interstitial_unit_id` ajouté.
- **« Doubler la récompense »** (pub récompensée, au choix) : cadeau de chapitre (écran de victoire et accueil) et indices du défi du jour.
- L'annonce de retour respecte aussi l'écart minimal entre annonces plein écran.

**Indices et tutoriels**
- Le joueur commence avec **0 indice** (les sauvegardes existantes gardent leur solde).
- **Tutoriel de prise en main** (niveau 1 du chapitre 1) : après un micro-délai, le gant montre les tracés en boucle, un mot après l'autre
  (le joueur trace, puis on passe au suivant), sans texte. Le gant est celui de l'écran de chargement.
- **Cinématique de l'indice** (première arrivée au niveau 4 du chapitre 1) : écran assombri autour du bouton Indice, gant qui invite à
  le toucher, petite carte explicative, **1 indice offert une seule fois** (mémorisé dans la sauvegarde, sans changer le schéma).

**Trophées** : objectifs multipliés par 2 ou 3 selon le trophée (les plus faciles ×3, les plus rares ×2), « Éclair » en moins de 30 s
au lieu de 40 ; textes FR/EN adaptés. Un objectif ne dépasse jamais le contenu du jeu (10 chapitres, 100 niveaux, 300 étoiles) :
« Maître des mots » reste à 10 chapitres, « Grand voyageur » à 8. Les trophées déjà débloqués le restent.

**Interface**
- Bannières des popups remplacées par les trois images fournies (bleu : réglages, langue, crédits ; jaune : trophées ; rouge :
  victoire et confirmations), titre ajusté à la bande.
- Accueil : plus de bannière sur les bulles de chapitre (« Chapitre N » en simple texte sur la bulle), bulles plus courtes, bulle du défi
  du jour **au-dessus** des bulles de chapitre.
- Les boutons ne touchent plus la zone sûre d'Android : marge minimale de 12 dp (`Wg.EDGE_GAP`, `UiKit.edge`) sur l'accueil, le jeu,
  l'aide, le défi du jour, les niveaux, les trophées (qui n'avait aucune marge) et les popups ; les écrans déjà assez larges sont inchangés.

**Audio** : nouvelle musique de fond (boucle sans couture, normalisée, volume bas), atténuation pendant les voix et jingles, effets
sonores à 60 % par défaut (détail : `docs/AUDIO.md`).

**Tests** : 262 tests GdUnit4 (37 de plus : rythme des pubs, tutoriels, trophées, bannières, marges).

## 1.2.1

**Correctif : l'APK de la CI ne s'installait pas**
- **Signature instable** : chaque exécution du workflow fabriquait une nouvelle clé de debug ; un APK ne pouvait donc jamais
  remplacer le précédent (Android : « application non installée, conflit avec un package existant »). La clé est maintenant
  versionnée (`ci/debug.keystore.b64`, clé de debug sans valeur secrète) et chargée par `scripts/ci/prepare_signing.sh`.
- **Code de version** : `scripts/ci/set_android_version.py` fixe `version/code` à max(dépôt, numéro d'exécution) pour ce build :
  il ne baisse jamais (Android refuse un code inférieur à celui installé).
- **Manifeste de l'export sans Gradle** : Godot 4.7.2 réécrit l'attribut `authorities` de *tous* les `<provider>` du modèle en
  `<package>.fileprovider` (`export_plugin.cpp`) ; le modèle en contient deux (FileProvider, androidx.startup), d'où deux
  fournisseurs de contenu à la même autorité. `scripts/ci/apk_tool.py fix-authorities` rend l'autorité unique (même longueur),
  réaligne et re-signe. Le build Gradle n'est pas concerné (fusion de manifestes d'Android).
- **Contrôle automatique** : `apk_tool.py check` fait échouer la CI si l'APK n'est pas signé (v2/v3), si deux providers partagent une
  autorité, si le package ou le code de version est faux, ou (build AdMob) si le SDK Google, le plugin ou l'identifiant
  d'application de TEST sont absents.

**Correctif : les vraies annonces de test n'étaient jamais choisies**
- `App._create_ads` testait `ResourceLoader.exists("res://addons/admob/plugin.cfg")`, toujours faux (un `.cfg` n'est pas une
  ressource et n'est pas exporté) : même le build Gradle retombait sur les annonces simulées. Le choix repose maintenant sur le plugin
  natif présent dans l'APK (`Engine.has_singleton("PoingGodotAdMob")`), dans une fonction pure testée (`choose_ad_backend`).

**Build**
- Le job `build` de la CI produit désormais l'APK Gradle + AdMob (vraies annonces de test Google) à chaque exécution ; l'APK sans
  Gradle devient un APK de dépannage (*Run workflow*, case « light »).
- Version 1.2.1 (code 4 dans le dépôt, croissant en CI). 225 tests GdUnit4 (6 de plus : choix du fournisseur de publicités).

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
