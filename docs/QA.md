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
