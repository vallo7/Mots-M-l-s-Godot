#!/bin/sh
# Importe le projet, vérifie la compilation de tous les scripts, puis lance les tests GdUnit4 (sans écran).
set -eu
GODOT="${GODOT:-$HOME/godot/godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://scripts/check_scripts.gd
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test
