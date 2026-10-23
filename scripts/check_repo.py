#!/usr/bin/env python3
"""Contrôles de dépôt (CI) : identifiants publicitaires de test uniquement, textes traduits complets,
clés de traduction utilisées dans le code, aucun fichier temporaire. Code de sortie 1 en cas d'écart."""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST_PUBLISHER = "ca-app-pub-3940256099942544"
errors = []

# 1) Identifiants AdMob : uniquement l'éditeur de test de Google
for path in list(ROOT.glob("data/*.json")) + list(ROOT.glob("src/**/*.gd")) + list(ROOT.glob("*.cfg")) + [ROOT / "project.godot"]:
    if not path.exists():
        continue
    for ident in re.findall(r"ca-app-pub-\d+", path.read_text(encoding="utf-8", errors="ignore")):
        if ident != TEST_PUBLISHER:
            errors.append(f"{path.relative_to(ROOT)} : identifiant AdMob de production interdit ({ident})")

# 2) Traductions : chaque clé a un texte en/fr non vide, mêmes {placeholders}
rows = list(csv.DictReader(open(ROOT / "translations" / "strings.csv", encoding="utf-8")))
keys = set()
for r in rows:
    keys.add(r["keys"])
    for lang in ("en", "fr"):
        if not r[lang].strip():
            errors.append(f"translations : {r['keys']} vide en {lang}")
    if sorted(re.findall(r"\{\d+\}", r["en"])) != sorted(re.findall(r"\{\d+\}", r["fr"])):
        errors.append(f"translations : {r['keys']} placeholders différents entre en et fr")

# 3) Toute clé utilisée dans le code existe
used = set()
for path in ROOT.glob("src/**/*.gd"):
    text = path.read_text(encoding="utf-8")
    used.update(re.findall(r'Strings\.(?:t|n)\(\s*"([a-z0-9_]+)"', text))
    used.update(re.findall(r'"((?:praise|band|monument|home|game|settings|credits|dialog|rewarded|result|loading|msg|cd|hints|stars|language)_[a-z0-9_]+)"', text))
for key in sorted(used):
    if key.endswith("_unit_id"):
        continue
    if key not in keys and f"{key}_one" not in keys and not key.endswith("_"):
        errors.append(f"code : clé de traduction inconnue « {key} »")

# 4) Pas de reliquats
for pattern in ("**/*.tmp", "**/.DS_Store", "**/Thumbs.db"):
    for path in ROOT.glob(pattern):
        if ".godot" not in path.parts:
            errors.append(f"fichier parasite : {path.relative_to(ROOT)}")

if errors:
    print("\n".join(f"ERREUR {e}" for e in errors))
    sys.exit(1)
print(f"OK : {len(rows)} textes traduits, {len(used)} clés utilisées vérifiées, identifiants de test uniquement.")
