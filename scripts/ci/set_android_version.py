#!/usr/bin/env python3
"""Fixe le code de version Android (`version/code`) des préréglages d'export pour CE build seulement (rien n'est commité).

Valeur retenue : max(valeur du dépôt, numéro d'exécution du workflow). Android refuse d'installer un APK dont le code de
version est INFÉRIEUR à celui déjà installé ; un code qui croît à chaque exécution évite cet échec.
Usage : scripts/ci/set_android_version.py [numéro]   (par défaut : variable d'environnement GITHUB_RUN_NUMBER)
"""
import os
import re
import sys

PATH = "export_presets.cfg"
run_number = int(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GITHUB_RUN_NUMBER", "0") or 0)
text = open(PATH, encoding="utf-8").read()
codes = [int(c) for c in re.findall(r"^version/code=(\d+)$", text, re.M)]
if not codes:
    sys.exit("version/code introuvable dans " + PATH)
chosen = max(max(codes), run_number)
text = re.sub(r"^version/code=\d+$", "version/code=%d" % chosen, text, flags=re.M)
open(PATH, "w", encoding="utf-8").write(text)
print("version/code = %d (dépôt : %d, exécution : %d)" % (chosen, max(codes), run_number))
