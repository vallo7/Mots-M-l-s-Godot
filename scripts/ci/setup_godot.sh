#!/bin/sh
# Installe l'éditeur Godot (sans écran) et, si demandé, les modèles d'export. Idempotent.
# Usage : scripts/ci/setup_godot.sh [--templates]
set -eu
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
DEST="${GODOT_HOME:-$HOME/godot}"
mkdir -p "$DEST"
if [ ! -x "$DEST/godot" ]; then
  curl -fsSL -o "$DEST/godot.zip" "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -q -o "$DEST/godot.zip" -d "$DEST"
  mv "$DEST/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$DEST/godot"
  chmod +x "$DEST/godot"
  rm -f "$DEST/godot.zip"
fi
if [ "${1:-}" = "--templates" ]; then
  TPL="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  if [ ! -d "$TPL" ]; then
    curl -fsSL -o "$DEST/templates.tpz" "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
    mkdir -p "$TPL"
    unzip -q -o "$DEST/templates.tpz" -d "$DEST/tpl"
    mv "$DEST"/tpl/templates/* "$TPL/"
    rm -rf "$DEST/tpl" "$DEST/templates.tpz"
  fi
fi
echo "$DEST/godot"
