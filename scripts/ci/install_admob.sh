#!/bin/sh
# Installe le plugin « Godot AdMob » (Poing Studios, version épinglée) dans addons/admob et l'active dans project.godot.
# Idempotent. Sans option : seulement le code GDScript du plugin (suffit pour vérifier que le fournisseur de publicités
# compile contre sa vraie API). Avec --android : télécharge aussi les bibliothèques Android du plugin (indispensables pour
# exporter un APK avec de vraies annonces ; l'export doit alors être un build Gradle, voir docs/ADS.md).
set -eu
ADMOB_VERSION="${ADMOB_VERSION:-5.1.0}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
BASE="https://github.com/poingstudios/godot-admob-plugin/releases/download/v${ADMOB_VERSION}"
if [ ! -f addons/admob/plugin.cfg ]; then
  curl -fsSL -o /tmp/admob-plugin.zip "${BASE}/poing-godot-admob-v${ADMOB_VERSION}.zip"
  rm -rf /tmp/admob-plugin
  unzip -q -o /tmp/admob-plugin.zip -d /tmp/admob-plugin
  mkdir -p addons
  cp -r "$(find /tmp/admob-plugin -type d -path '*/addons/admob' | head -n 1)" addons/
fi
if [ "${1:-}" = "--android" ] && [ ! -f addons/admob/android/bin/package.gd ]; then
  curl -fsSL -o /tmp/admob-android.zip "${BASE}/android-template-v${GODOT_VERSION}.zip"
  mkdir -p addons/admob/android/bin
  unzip -q -o /tmp/admob-android.zip -d addons/admob/android/bin
fi
python3 "$(dirname "$0")/enable_plugin.py" "res://addons/admob/plugin.cfg"
echo "AdMob ${ADMOB_VERSION} installé"
