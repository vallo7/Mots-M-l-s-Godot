#!/usr/bin/env python3
"""Ajoute un plugin d'éditeur à `[editor_plugins] enabled` de project.godot (idempotent, conserve les plugins déjà actifs).
Usage : scripts/ci/enable_plugin.py res://addons/xxx/plugin.cfg"""
import re
import sys

plugin = sys.argv[1]
path = "project.godot"
text = open(path, encoding="utf-8").read()
match = re.search(r"^enabled=PackedStringArray\((.*)\)\s*$", text, re.M)
if match:
    items = re.findall(r'"([^"]+)"', match.group(1))
    if plugin in items:
        sys.exit(0)
    items.append(plugin)
    line = "enabled=PackedStringArray(%s)" % ", ".join('"%s"' % i for i in items)
    text = text[: match.start()] + line + text[match.end():]
else:
    text = text.rstrip("\n") + '\n\n[editor_plugins]\n\nenabled=PackedStringArray("%s")\n' % plugin
open(path, "w", encoding="utf-8").write(text)
