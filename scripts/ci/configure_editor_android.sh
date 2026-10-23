#!/bin/sh
# Renseigne les chemins du SDK Android et de Java dans les réglages d'éditeur (export en ligne de commande).
set -eu
VERSION="${GODOT_VERSION:-4.7.2}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
JAVA="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"
DIR="$HOME/.config/godot"
mkdir -p "$DIR"
cat > "$DIR/editor_settings-${VERSION%.*}.tres" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
EOT
