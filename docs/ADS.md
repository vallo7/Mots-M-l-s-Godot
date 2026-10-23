# Publicités

**Statut (1.2.1)** : l'APK produit par la CI est un build **Gradle + plugin AdMob** (préréglage « Android AdMob ») : il affiche les
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
  grille), récompensée (1 indice, uniquement sur demande du joueur), annonce de retour (`ReturnAdPolicy`).
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

## Avant publication

Remplacer les identifiants par ceux du compte AdMob **hors du dépôt** (variables de build), finaliser `PRIVACY.md`
et la déclaration de sécurité des données Google Play.
