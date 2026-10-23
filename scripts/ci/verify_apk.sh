#!/bin/sh
# Vérifie qu'un APK est installable : signature valide, paquet et SDK attendus, architectures.
# Avec « --ads » : vérifie aussi que le VRAI SDK Google Mobile Ads et l'identifiant d'application de test de Google sont
# dans l'APK (sinon le jeu retomberait sur les annonces simulées). Échoue (code != 0) au premier problème.
# Usage : scripts/ci/verify_apk.sh build/mon.apk [--ads]
set -eu
APK="$1"
MODE="${2:-}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -n 1)"
fail() { echo "ÉCHEC : $1" >&2; exit 1; }

echo "== APK : $APK ($(du -h "$APK" | cut -f1))"
echo "== Signature"
"$BT/apksigner" verify --verbose --print-certs "$APK" | grep -E "^(Verifies|Verified using|Signer #1 certificate (DN|SHA-256))" || fail "signature invalide"
echo "== Contenu déclaré (aapt2)"
BADGING="$("$BT/aapt2" dump badging "$APK")"
echo "$BADGING" | grep -E "^(package|sdkVersion|minSdkVersion|targetSdkVersion|native-code)" || true
echo "$BADGING" | grep -q "^package: name='com.motsmeles.game'" || fail "nom de paquet inattendu"
echo "$BADGING" | grep -q "^native-code:" || fail "aucune bibliothèque native dans l'APK"
echo "$BADGING" | grep "^native-code:" | grep -q "arm64-v8a" || fail "arm64-v8a absent"
if [ "$MODE" = "--ads" ]; then
  echo "== SDK Google Mobile Ads"
  MANIFEST="$("$BT/aapt2" dump xmltree --file AndroidManifest.xml "$APK")"
  echo "$MANIFEST" | grep -q "com.google.android.gms.ads.APPLICATION_ID" || fail "meta-data APPLICATION_ID absente du manifeste"
  echo "$MANIFEST" | grep -q "ca-app-pub-3940256099942544~3347511713" || fail "l'identifiant d'application n'est pas celui de test de Google"
  unzip -p "$APK" 'classes*.dex' | grep -a -q "com/google/android/gms/ads/MobileAds" || fail "classes du SDK Google Mobile Ads absentes de l'APK"
  echo "OK : vrai SDK Google Mobile Ads + identifiant de test présents (annonces réelles de test)."
fi
echo "== APK vérifié"
