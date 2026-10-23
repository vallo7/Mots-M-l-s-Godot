#!/bin/sh
# Installe GdUnit4 (version épinglée) dans addons/ et l'active dans project.godot. Idempotent.
set -eu
GDUNIT_VERSION="${GDUNIT_VERSION:-6.1.3}"
if [ ! -f addons/gdUnit4/plugin.cfg ]; then
  curl -fsSL -o /tmp/gdunit4.zip "https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v${GDUNIT_VERSION}.zip"
  unzip -q -o /tmp/gdunit4.zip -d /tmp/gdunit4
  mkdir -p addons
  cp -r "/tmp/gdunit4/gdUnit4-${GDUNIT_VERSION}/addons/gdUnit4" addons/
fi
python3 "$(dirname "$0")/enable_plugin.py" "res://addons/gdUnit4/plugin.cfg"
