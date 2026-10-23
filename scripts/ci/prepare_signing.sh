#!/bin/sh
# Prépare la clé de signature de DEBUG, la MÊME à chaque build.
# Pourquoi : Android n'installe une mise à jour par-dessus une version déjà présente que si les deux APK portent la même
# signature. Avant, chaque exécution du workflow fabriquait une clé neuve : le 2e APK installé échouait donc toujours
# (« application non installée : conflit avec un package existant »). La clé est versionnée (ci/debug.keystore.b64, en base64) ;
# c'est une clé de DEBUG sans valeur secrète. Ne JAMAIS l'utiliser pour une version publiée (clé de release à part, en secret).
# Exporte GODOT_ANDROID_KEYSTORE_DEBUG_PATH / _USER / _PASSWORD pour les étapes suivantes (variables d'environnement lues par Godot).
set -eu
SRC="ci/debug.keystore.b64"
DEST="${RUNNER_TEMP:-/tmp}/mots-meles-debug.keystore"
if [ ! -f "$SRC" ]; then
  echo "::error::$SRC introuvable : sans clé stable, chaque APK aurait une signature différente et ne pourrait pas remplacer le précédent."
  exit 1
fi
base64 -d "$SRC" > "$DEST"
keytool -list -keystore "$DEST" -storepass android -alias androiddebugkey | grep -E "androiddebugkey|SHA-256" || {
  echo "::error::clé de debug illisible (alias androiddebugkey, mot de passe android attendus)"
  exit 1
}
if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$DEST"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
  } >> "$GITHUB_ENV"
else
  echo "export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$DEST GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
fi
