# Publicités

**Statut (1.3.0)** : l'APK produit par la CI est un build **Gradle + plugin AdMob** (préréglage « Android AdMob ») : il affiche les
**vraies annonces de test de Google**. Le préréglage « Android » (sans Gradle, modèle précompilé) reste disponible en dépannage
(*Run workflow*, case « light ») avec des annonces de test **simulées** (`SimulatedAdProvider`).

## Pourquoi pas de vraies annonces Google sans Gradle

Le SDK Google Mobile Ads est une bibliothèque Android (AAR + ressources + entrées de manifeste). Godot ne l'embarque que dans un
**build Gradle** : sans Gradle, l'export reprend un APK précompilé et ignore les bibliothèques des plugins (vérifié dans le code
source de Godot 4.7.2, `platform/android/export/export_plugin.cpp`). Aucun réglage ne contourne cela proprement ; les annonces
réelles passent donc par le préréglage Gradle.

## Les deux configurations

| | Préréglage « Android AdMob » (CI, défaut) | Préréglage « Android » (dépannage) |
|---|---|---|
| Gradle | oui | non |
| Plugin AdMob | installé (`install_admob.sh --android`) | non installé |
| Annonces | **vraies annonces de test Google** | **simulées** (debug), aucune (release) |
| CI | job `build` (à chaque exécution) | job `build-light` (*Run workflow*, case « light ») |
| Manifeste | fusionné par Gradle (correct) | corrigé par `apk_tool.py fix-authorities` |

Choix du fournisseur (`AppController.choose_ad_backend`, testé) : Android **et** plugin natif AdMob présent dans l'APK
(`Engine.has_singleton("PoingGodotAdMob")`) **et** script du fournisseur présent → vrai AdMob ; sinon build de debug → simulation ;
sinon aucune publicité. Le plugin natif n'existe que si l'APK embarque le SDK : un build sans Gradle ne tente donc jamais d'utiliser
un SDK absent. (Ne pas tester `ResourceLoader.exists("res://addons/admob/plugin.cfg")` : toujours faux, un `.cfg` n'est pas une ressource.)

Annonces simulées : bannière dans la zone réservée, annonce récompensée (compte à rebours de 5 s, +1 indice seulement si on va au
bout), annonce de retour, toutes marquées « annonce de test ». Elles servent à vérifier le parcours complet (indice offert,
annonce de retour, hors ligne) sans SDK ; `test/visual/shot_ads.gd` en produit des captures.

**Reste à vérifier sur appareil** avec l'APK de la CI : consentement UMP, bannière, récompensée, annonce de retour, hors ligne.
Dans `adb logcat` (filtre `godot`), la ligne « Publicités : vraies annonces de test Google (AdMob) » confirme le bon fournisseur.

## Règles

- **Identifiants de test uniquement** (`data/ads_config.json`, éditeur `ca-app-pub-3940256099942544`). `scripts/check_repo.py`
  fait échouer la CI si un identifiant de production apparaît.
- Consentement UMP à chaque lancement (le formulaire n'apparaît que si la région l'exige) ; aucune annonce avant.
- Jamais d'annonce au lancement à froid ni au démarrage d'un niveau. Formats : bannière (zone réservée de 50 dp sous la
  grille), **interstitielle** au passage au niveau suivant (voir ci-dessous), récompensée (1 indice, ou « doubler » une
  récompense, uniquement sur demande du joueur), annonce de retour (`ReturnAdPolicy`).
- Une annonce indisponible, hors ligne ou en erreur ne bloque jamais le jeu : résultat explicite et message court.

## Obtenir l'APK avec les vraies annonces de test Google

- **Par la CI** : chaque exécution du workflow *android* (push, ou *Run workflow*). Le job `build` installe le plugin
  (version 5.1.0 épinglée), le modèle de build Gradle, puis exporte le préréglage « Android AdMob » (artefact
  `mots-meles-debug-apk`) et vérifie l'APK (`scripts/ci/apk_tool.py check --expect-admob`).
- **En local** : `scripts/ci/install_admob.sh --android` (plugin dans `addons/admob`, activé dans `project.godot`, bibliothèques
  Android pour Godot 4.7.2), *Projet > Installer le modèle de build Android*, puis exporter « Android AdMob ».
  L'identifiant d'application de test de Google est celui par défaut du plugin.
- Le job de tests installe toujours le plugin (sans Gradle) pour que `admob_ad_provider.gd` et `admob_consent.gd` soient
  compilés contre la **vraie API** du plugin.

## Système de revenus (1.3.0)

Objectif : **gagner le plus possible avec les publicités sans jamais dégrader le jeu**. Les éditeurs de jeux mobiles (guides
AdMob, Unity, AppLovin, Meta, Pangle, Appodeal…) s'accordent sur les mêmes leviers ; voici comment ils sont appliqués ici.

| Levier | Pourquoi (pratique courante) | Dans le jeu |
|---|---|---|
| **Récompensée d'abord** | Format qui rapporte le plus par vue et le mieux accepté, car le joueur la choisit | Bouton Indice à 0 (pub directe), « Doubler » le cadeau de chapitre (écran de victoire **et** accueil) et les indices du défi du jour |
| **Interstitielle aux pauses naturelles** | Rapporte beaucoup, mais seulement si elle ne coupe jamais l'action | Au toucher de « Niveau suivant » : tirage au hasard, **1 chance sur 3** à chaque passage (`InterstitialPolicy`) |
| **Plafonnement de fréquence** | Les pubs en rafale font fuir les joueurs, donc les revenus futurs | ≥ 90 s entre deux annonces plein écran (toutes sortes), 12 interstitielles/heure au plus |
| **Prise en main sans pub** | La rétention des premières minutes vaut plus que quelques vues | Aucune interstitielle avant 4 niveaux terminés ; jamais pendant les tutoriels |
| **Respect du choix du joueur** | Qui vient de regarder une récompensée ne doit pas enchaîner | Pas d'interstitielle dans les 120 s qui suivent une récompensée ; joueur très « récompensées » (≥ 3 dans l'heure) : probabilité divisée par 2 |
| **Annonce prête = revenu** | Une annonce non chargée au bon moment est un revenu perdu | Préchargement de chaque format ; après un échec, nouvel essai à 4 s, 10 s, 30 s, 1 min puis 2 min (`AdPolicyConfig`) ; une interstitielle périmée (1 h) est renouvelée à 50 min |
| **Jamais d'attente** | Un écran qui attend une pub est pire qu'une pub ratée | Pas d'annonce prête (hors ligne, pas de remplissage) : le niveau suivant démarre tout de suite, la suivante se charge |
| **Public « tout public »** | Le contenu publicitaire doit convenir à tous | `max_ad_content_rating = PG` (réglable) ; aucun marquage « enfants » (voir « Avant publication ») |

Tous les seuils sont dans **`data/ads_policy.json`** (aucun code à toucher ; valeurs bornées au chargement, fichier illisible =
valeurs par défaut sûres). Exemple : passer `probability` à `0.25` ou `min_seconds_between_full_screen_ads` à `120` pour alléger.
L'ordre des essais, les garde-fous et la mémoire d'espacement (`AdPacing`) sont dans `src/domain` (fonctions pures, testées par
`test/domain/ads_and_tutorial_test.gd`). L'interstitielle simulée (build sans plugin) suit exactement les mêmes règles.

**Réglage fin après publication** (c'est là que se gagne le revenu, avec des chiffres réels) : suivre dans AdMob l'eCPM, le taux
de remplissage et la rétention J1/J7 par format ; si la rétention baisse, réduire `probability` ; si elle tient, essayer
`0.4`. Ne changer qu'un seuil à la fois et attendre quelques jours.

**Ce qui se règle dans la console AdMob, pas dans le code** (le plus gros gain, sans mise à jour du jeu) :
1. **Médiation avec enchères** : ajouter d'autres réseaux (AppLovin, Unity Ads, Meta, Pangle, Mintegral, etc.) à chaque bloc ; ils
   se font concurrence en temps réel et le plus offrant gagne l'affichage. Chaque réseau demande son adaptateur Android (dépendance
   Gradle) : à ajouter au préréglage « Android AdMob » le moment venu.
2. **Un bloc d'annonces par emplacement** (déjà le cas : bannière, ouverture, récompensée, interstitielle) pour comparer chaque
   format ; des planchers d'eCPM par pays si certains pays rapportent beaucoup moins.
3. **Rafraîchissement de la bannière** : 30 à 60 s dans la console (le SDK s'en charge).
4. Le revenu dépend beaucoup du pays des joueurs (eCPM bien plus élevés en Amérique du Nord et en Europe qu'ailleurs) : viser
   aussi ces marchés dans la fiche Play Store.

**Pas dans cette version** (volontairement) : configuration à distance (nécessite un service en ligne alors que le jeu est hors
ligne), achats intégrés (aucun dans le jeu), suivi du joueur (aucun).

## Avant publication

Créer dans AdMob les **quatre blocs** (bannière, ouverture, récompensée, **interstitielle**) et remplacer les identifiants de
`data/ads_config.json` par ceux du compte AdMob **hors du dépôt** (variables de build ; la clé `interstitial_unit_id` est nouvelle).
Finaliser `PRIVACY.md` et la déclaration de sécurité des données Google Play.

**Audience** : le jeu est déclaré tout public, sans cibler les moins de 13 ans. Si la fiche Play Console indique que des enfants font
partie du public cible (programme « Famille »), il faut alors marquer les requêtes comme destinées aux enfants
(`tag_for_child_directed_treatment`), n'utiliser que des réseaux certifiés et accepter des revenus nettement plus bas ; ne pas le
faire à la légère.
