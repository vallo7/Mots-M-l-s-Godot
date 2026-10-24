# Recette sur appareil

Automatisé (CI) : plus de 200 tests, compilation de tous les scripts, validation des niveaux, traductions, identifiants de test.
À valider **à la main** (ce qu'aucune machine sans téléphone ne peut prouver) :

- [ ] Installation de l'APK de debug (artefact CI), icône adaptative et monochrome, **écran de démarrage Android entièrement blanc (aucun logo)**, sur Android 12+ et sur une version plus ancienne.
- [ ] Chargement (2 s), accueil, glisser entre chapitres (élan, aimantation, parallaxe, son + vibration).
- [ ] Tracé sur toutes les tailles (4×4 → 12×12) : horizontal, vertical, diagonales ; doigt qui sort de la grille ; deux doigts.
- [ ] Mot trouvé (capsule douce, vague, son, vibration) ; les lettres ne bougent jamais de leur case dès le début d'un tracé, mauvais mot (secousse), mot déjà trouvé.
- [ ] Indice : solde, limite par niveau, solde à zéro = publicité lancée directement (micro-délai + animation, sans confirmation), retrait seulement si révélé.
- [ ] Redémarrage (mélange 1,3 s, verrou de saisie), retour avec confirmation, reprise après fermeture de l'appli.
- [ ] Victoire : étoiles selon le temps (< 1 min : 3, < 3 min : 2), praise voix FR/EN, progression de chapitre, cadeau, bandeau « Trophée débloqué » éventuel.
- [ ] Trophées : bouton sous les bulles de chapitre (pastille « nouveau »), grille de 3 colonnes, fiche au toucher (verrouillé : avancement ; débloqué : date), étiquettes « Nouveau », bandeau en jeu, trophées rétroactifs après mise à jour.
- [ ] Écran de chargement : aucun conseil, barre en bas, mention « Développé par Vallo Game » discrète.
- [ ] Navigation : transitions de page fluides (accueil ↔ jeu ↔ victoire ↔ niveaux) ; popups centrés et complets (réglages visibles en entier).
- [ ] Monument : barre du haut = progression du chapitre en cours, défilement, niveaux terminés / disponible / verrouillés, messages.
- [ ] Réglages : liste de langues (Automatique / Français / English) sans perte de page, curseur de volume des effets sonores (clic témoin au relâchement) et de la musique
      (écoute en direct, valeurs conservées), vibration, mode sombre (révélation circulaire, tous les écrans lisibles), animations
      réduites, texte plus grand. Pas de bouton « restaurer ».
- [ ] Chargement : démonstration du gant (3 scénarios au hasard), commentaire aléatoire, durée ≥ 2,8 s.
- [ ] Transitions : aucun fondu ; iris à l'entrée et à la sortie d'un niveau, montée à la victoire, glissement ailleurs.
- [ ] Accueil : bulles plus courtes, pourcentage d'étoiles, bouton d'aide, bannière du défi du jour. Liste des niveaux : défile
      jusqu'au niveau en cours.
- [ ] Défi du jour : grille du jour, reprise, victoire (indices, série), passage de minuit, changement de langue.
- [ ] Publicités de test : bannière, récompensée (+1 indice seulement après le compte à rebours), annonce de retour.
- [ ] Appel entrant / verrouillage pendant une partie : chronomètre suspendu, reprise exacte.
- [ ] Mode avion, rotation (verrouillée en portrait), encoche / geste de retour, 120 Hz (fluidité plafonnée à 60).
- [ ] Publicités (si plugin) : consentement, bannière, récompensée, retour — identifiants de test.
- [ ] 1.3.0 — Niveau 1 : le gant montre le premier tracé en boucle (après ≈ 1 s), s'efface quand on trace, passe au mot suivant une fois trouvé, aucun texte.
- [ ] 1.3.0 — Nouvelle installation : 0 indice ; première arrivée au niveau 4 du chapitre 1 : écran assombri, gant sur Indice, carte, 1 indice offert ; la cinématique ne revient jamais.
- [ ] 1.3.0 — « Niveau suivant » : ≈ 1 fois sur 3 une interstitielle, jamais avant 4 niveaux, jamais deux pubs à moins de 90 s ; hors ligne : le niveau démarre sans attente.
- [ ] 1.3.0 — « Doubler » : cadeau de chapitre (victoire et accueil) et défi du jour ; pub fermée trop tôt = rien, le bouton reste.
- [ ] 1.3.0 — Bannières : bleue (réglages, langue, crédits), jaune (trophée), rouge (victoire, confirmation) ; titres lisibles en FR/EN et en « texte plus grand ».
- [ ] 1.3.0 — Accueil : défi du jour au-dessus des chapitres, « Chapitre N » en texte sur la bulle, bulles plus courtes ; aucun bouton collé à la zone sûre (encoche, barre de gestes, rotation).
- [ ] 1.3.0 — Musique : ambiance discrète, boucle sans coupure, baisse pendant les voix de félicitation ; effets à 60 % par défaut.
- [ ] 1.3.0 — Trophées : nouveaux objectifs (ex. « Premiers pas » = 3 niveaux, « Étoiles » = 150), textes corrects dans les deux langues.
