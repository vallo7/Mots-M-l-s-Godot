#!/usr/bin/env python3
"""Valide data/levels/*.json (utilisé en CI). Code de sortie 1 si une règle est violée."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from level_tools import SCHEMA_VERSION, load_chapters, validate_chapters  # noqa: E402


def main():
    levels_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "data" / "levels"
    index, chapters = load_chapters(levels_dir)
    issues = []
    if index.get("schemaVersion") != SCHEMA_VERSION:
        issues.append((None, "SCHEMA", f"schemaVersion {index.get('schemaVersion')} != {SCHEMA_VERSION}"))
    issues += validate_chapters(chapters)
    total = sum(len(ch["levels"]) for ch in chapters)
    if issues:
        for lid, code, msg in issues:
            print(f"ERREUR [{lid or 'catalogue'}] {code} : {msg}")
        print(f"\n{len(issues)} problème(s) dans {total} niveaux.")
        sys.exit(1)
    print(f"OK : {len(chapters)} chapitres, {total} niveaux valides (FR + EN).")


if __name__ == "__main__":
    main()
