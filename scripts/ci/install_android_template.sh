#!/bin/sh
# Installe le modèle de projet Gradle Android (équivalent de « Projet > Installer le modèle de build Android »).
set -eu
VERSION="${GODOT_VERSION:-4.7.2}"
TPL="$HOME/.local/share/godot/export_templates/${VERSION}.stable/android_source.zip"
mkdir -p android/build
unzip -q -o "$TPL" -d android/build
printf '%s.stable' "$VERSION" > android/.build_version
touch android/build/.gdignore
