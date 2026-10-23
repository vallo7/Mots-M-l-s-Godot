# Publicités

**Statut (1.2.1)** : l'APK principal construit par la CI (artefact `mots-meles-debug-apk`) est un build **Gradle + plugin AdMob** :
il affiche les **vraies annonces de test de Google**. La CI le prouve à chaque build (`scripts/ci/verify_apk.sh --ads` : signature
valide, SDK Google Mobile Ads et identifiant d'application de test présents dans l'APK). Le préréglage « Android » (sans Gradle,
export local hors ligne) affiche à la place des annonces de test **simulées** ; l'écran Crédits indique la source active.

## Pourquoi pas de vraies annonces Google sans Gradle

Le SDK Google Mobile Ads est une bibliothèque Android (AAR + ressources + entrées de manifeste). Godot ne l'embarque que dans un
**build Gradle** : sans Gradle, l'export reprend un APK précompilé et ignore les bibliothèques des plugins (vérifié dans le code
source de Godot 4.7.2, `platform/android/export/export_plugin.cpp`). Aucun réglage ne contourne cela proprement ; les annonces
réelles passent donc par le préréglage Gradle.

## Les deux configurations

| | Préréglage « Android » (export local hors ligne) | Préréglage « Android AdMob » (CI, APK principal) |
|---|---|---|
| Gradle | non | oui |
| Plugin AdMob | non installé | installé (`install_admob.sh --android`) |
| Annonces | **simulées** (debug), aucune (release) | **vraies annonces de test Google** |
| CI | job `build-light` (*Run workflow*, case « light ») | job `build` (à chaque push) |
| Caractéristique d'export | — | `admob` (voir ci-dessous) |

Choix du fournisseur (`App._create_ads`) : build Android avec la caractéristique d'export `admob` **et** plugin présent → vrai
AdMob ; sinon build de debug → simulation ; sinon aucune publicité. La caractéristique `admob` évite qu'un build sans Gradle
construit par erreur depuis un dossier contenant le plugin tente d'utiliser un SDK absent de l'APK.

Annonces simulées : bannière dans la zone réservée, annonce récompensée (compte à rebours de 5 s, +1 indice seulement si on va au
bout), annonce de retour, toutes marquées « annonce de test ». Elles servent à vérifier le parcours complet (indice offert,
annonce de retour, hors ligne) sans SDK ; `test/visual/shot_ads.gd` en produit des captures.

**Reste à vérifier sur appareil** avec le build AdMob : consentement UMP, bannière, récompensée, annonce de retour, hors ligne.

## Règles

- **Identifiants de test uniquement** (`data/ads_config.json`, éditeur `ca-app-pub-3940256099942544`). `scripts/check_repo.py`
  fait échouer la CI si un identifiant de production apparaît.
- Consentement UMP à chaque lancement (le formulaire n'apparaît que si la région l'exige) ; aucune annonce avant.
- Jamais d'annonce au lancement à froid ni au démarrage d'un niveau. Formats : bannière (zone réservée de 50 dp sous la
  grille), récompensée (1 indice, uniquement sur demande du joueur), annonce de retour (`ReturnAdPolicy`).
- Une annonce indisponible, hors ligne ou en erreur ne bloque jamais le jeu : résultat explicite et message court.

## Obtenir l'APK avec les vraies annonces de test Google

- **Par la CI** (cas normal) : chaque push, ou *Actions* > *android* > *Run workflow*. Le job `build` installe le plugin (version
  5.1.0 épinglée), le modèle de build Gradle, exporte « Android AdMob » puis vérifie l'APK (artefact `mots-meles-debug-apk`).
  Gradle et ses bibliothèques sont téléchargés **par la CI** : la machine de développement n'a besoin d'aucun accès à internet.
- **En local** : `scripts/ci/install_admob.sh --android` (plugin dans `addons/admob`, activé dans `project.godot`, bibliothèques
  Android pour Godot 4.7.2), *Projet > Installer le modèle de build Android*, puis exporter « Android AdMob ».
  L'identifiant d'application de test de Google est celui par défaut du plugin.
- Vérification vérifiable à la main : écran Crédits > « Source des annonces active : Google AdMob » ; les annonces réelles de test
  portent la mention « Test Ad » de Google (les simulées sont marquées « simulation »).
- Le job de tests installe toujours le plugin (sans Gradle) pour que `admob_ad_provider.gd` et `admob_consent.gd` soient
  compilés contre la **vraie API** du plugin.

## Avant publication

Remplacer les identifiants par ceux du compte AdMob **hors du dépôt** (variables de build), finaliser `PRIVACY.md`
et la déclaration de sécurité des données Google Play.
