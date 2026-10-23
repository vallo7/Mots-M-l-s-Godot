"""Outils partagés pour les niveaux : normalisation, score, validation.

Miroir Python des règles de `domain/.../content/LevelValidator.kt` : il permet à la CI de valider
`data/levels/*.json` sans Android. Toute règle modifiée ici doit l'être aussi côté Kotlin.
"""
import json
import math
import unicodedata
from pathlib import Path

DIRS = {
    "E": (0, 1), "S": (1, 0), "SE": (1, 1), "W": (0, -1),
    "N": (-1, 0), "SW": (1, -1), "NW": (-1, -1), "NE": (-1, 1),
}
OPPOSITE = {"E": "W", "W": "E", "S": "N", "N": "S", "SE": "NW", "NW": "SE", "SW": "NE", "NE": "SW"}
TIER_DIRS = {
    1: ["E", "S"],
    2: ["E", "S", "SE"],
    3: ["E", "S", "SE", "W", "N"],
    4: list(DIRS),
}
LANGS = ("fr", "en")
ALLOWED_SIZES = {4, 5, 6, 7, 8, 9, 10, 11, 12}
SIZE_STEPS = [4, 5, 6, 7, 8, 9, 10, 11]  # 12 est réservé au défi final (hors règle de saut)
LEVELS_PER_CHAPTER = 10
# Profil de longueurs de mots : un niveau mêle toujours des mots COURTS et des mots LONGS, et ce mélange dépend de
# la taille de la grille et du palier de difficulté. Par taille : (longueur max du mot le plus court, écart minimal
# entre le mot le plus court et le plus long).
LENGTH_PROFILE = {4: (3, 1), 5: (3, 2), 6: (4, 2), 7: (4, 3), 8: (4, 4), 9: (5, 4), 10: (5, 5), 11: (5, 6), 12: (5, 7)}
FINAL_MIN_RATIO = 1.15
SCHEMA_VERSION = 1


def tier_directions(tier):
    return TIER_DIRS[min(max(tier, 1), 4)]


def to_letters(display):
    decomposed = unicodedata.normalize("NFD", display).upper()
    return "".join(ch for ch in decomposed if "A" <= ch <= "Z")


def style_for(chapter, number):
    if number == LEVELS_PER_CHAPTER:
        return "FINAL"
    band = (number - 1) // 3
    return ["STYLE_1", "STYLE_2", "STYLE_3"][(band + chapter - 1) % 3]


def jround(x):
    """Équivalent de Math.round (arrondi au supérieur sur .5)."""
    return int(math.floor(x + 0.5))


def difficulty_score(grid_size, word_count, avg_len, tier, ambiguity, decoys=0):
    return jround(grid_size * 2.0 + word_count * 3.0 + avg_len * 1.5 + tier * 6.0 + ambiguity * 20.0 + decoys * 1.5)


def level_score(level):
    variants = [level["variants"][lang] for lang in LANGS]
    word_count = sum(len(v["words"]) for v in variants) / len(variants)
    lengths = [len(w["letters"]) for v in variants for w in v["words"]]
    avg = sum(lengths) / len(lengths)
    d = level["difficulty"]
    return difficulty_score(level["gridSize"], word_count, avg, d["tier"], d["ambiguity"], d.get("decoys", 0))


def min_longest_word(grid_size, tier):
    """Longueur minimale du mot le plus long : presque toute la grille dans les petites tailles ; plus le palier
    est élevé, plus le mot le plus long se rapproche de la largeur de la grille."""
    if grid_size <= 7:
        return grid_size - 1  # 4×4 : 3 ; 5×5 : 4 ; 6×6 : 5 ; 7×7 : 6
    return grid_size - 1 if tier >= 4 else grid_size - 2


def length_mix_problem(grid_size, tier, lengths):
    """Renvoie un message si le mélange de longueurs est insuffisant, sinon None."""
    profile = LENGTH_PROFILE.get(grid_size)
    if profile is None or not lengths:
        return None
    max_shortest, min_spread = profile
    shortest, longest = min(lengths), max(lengths)
    if shortest > max_shortest:
        return f"aucun mot court : le plus court fait {shortest} lettres (max {max_shortest} en {grid_size}x{grid_size})"
    need_long = min_longest_word(grid_size, tier)
    if longest < need_long:
        return f"aucun mot long : le plus long fait {longest} lettres (min {need_long} en {grid_size}x{grid_size}, palier {tier})"
    if longest - shortest < min_spread:
        return f"longueurs trop uniformes : écart {longest - shortest} (min {min_spread})"
    return None


def word_cells(word):
    dr, dc = DIRS[word["direction"]]
    return [(word["row"] + dr * i, word["col"] + dc * i) for i in range(len(word["letters"]))]


def occurrences(grid, letters):
    n = len(grid)
    found = set()
    for r in range(n):
        for c in range(n):
            for dr, dc in DIRS.values():
                er, ec = r + dr * (len(letters) - 1), c + dc * (len(letters) - 1)
                if not (0 <= er < n and 0 <= ec < n):
                    continue
                cells = [(r + dr * i, c + dc * i) for i in range(len(letters))]
                if all(grid[y][x] == letters[i] for i, (y, x) in enumerate(cells)):
                    found.add(frozenset(cells))
    return found


def validate_variant(level, lang, variant):
    issues = []
    lid = level["id"]

    def add(code, msg):
        issues.append((lid, code, f"[{lang}] {msg}"))

    n = level["gridSize"]
    grid = variant["grid"]
    if len(grid) != n or any(len(row) != n for row in grid):
        add("GRID_SHAPE", f"la grille doit être {n}x{n}")
        return issues
    if any(ch < "A" or ch > "Z" for row in grid for ch in row):
        add("GRID_CHARS", "la grille ne doit contenir que A-Z")
    words = variant["words"]
    if not words:
        add("NO_WORDS", "aucun mot cible")
    allowed = set(tier_directions(level["difficulty"]["tier"]))
    seen = set()
    for i, w in enumerate(words):
        if w["letters"] != to_letters(w["display"]):
            add("WORD_LETTERS", f"mot #{i} {w['display']!r} : letters incohérent")
        if len(w["letters"]) < 2:
            add("WORD_LENGTH", f"mot #{i} trop court")
        if w["letters"] in seen:
            add("WORD_DUPLICATE", f"mot en double {w['letters']}")
        seen.add(w["letters"])
        if w["direction"] not in allowed:
            add("DIRECTION", f"{w['letters']} : direction {w['direction']} interdite au palier {level['difficulty']['tier']}")
        cells = word_cells(w)
        if any(not (0 <= y < n and 0 <= x < n) for y, x in cells):
            add("OUT_OF_BOUNDS", f"{w['letters']} sort de la grille")
        elif any(grid[y][x] != w["letters"][i2] for i2, (y, x) in enumerate(cells)):
            add("GRID_MISMATCH", f"{w['letters']} ne correspond pas à la grille")
    for j, dcy in enumerate(variant.get("decoys", [])):
        cells = word_cells(dcy)
        if len(dcy["letters"]) < 3:
            add("DECOY_LENGTH", f"leurre #{j} trop court")
        if dcy["direction"] not in allowed:
            add("DECOY_DIRECTION", f"leurre {dcy['letters']} : direction {dcy['direction']} interdite")
        if any(not (0 <= y < n and 0 <= x < n) for y, x in cells):
            add("DECOY_BOUNDS", f"leurre {dcy['letters']} sort de la grille")
        elif any(grid[y][x] != dcy["letters"][i2] for i2, (y, x) in enumerate(cells)):
            add("DECOY_MISMATCH", f"leurre {dcy['letters']} ne correspond pas à la grille")
        if dcy["letters"] in seen:
            add("DECOY_IS_WORD", f"le leurre {dcy['letters']} est un mot cible")
    for a in words:
        for b in words:
            if a is not b and (b["letters"] in a["letters"] or b["letters"][::-1] in a["letters"]):
                add("WORD_CONTAINED", f"{b['letters']} est contenu dans {a['letters']}")
    problem = length_mix_problem(n, level["difficulty"]["tier"], [len(w["letters"]) for w in words])
    if problem:
        add("LENGTH_MIX", problem)
    if any(code in ("OUT_OF_BOUNDS", "GRID_MISMATCH", "GRID_CHARS") for _, code, _ in issues):
        return issues
    for w in words:
        count = len(occurrences(grid, w["letters"]))
        if count != 1:
            add("AMBIGUOUS_WORD", f"{w['letters']} apparaît {count} fois dans la grille")
    if not issues:
        placed = {frozenset(word_cells(w)) for w in words}
        if len(placed) != len(words):
            add("UNSOLVABLE", "deux mots occupent les mêmes cases")
    return issues


def validate_level(level):
    issues = []
    lid = level["id"]

    def add(code, msg):
        issues.append((lid, code, msg))

    chapter, number, size = level["chapter"], level["number"], level["gridSize"]
    if not lid:
        add("ID", "identifiant vide")
    if not 1 <= number <= LEVELS_PER_CHAPTER:
        add("NUMBER", "numéro hors 1..10")
    if not all(level["theme"].get(lang) for lang in LANGS):
        add("THEME", "thème manquant dans une langue")
    if size not in ALLOWED_SIZES:
        add("GRID_SIZE", f"taille {size} non autorisée")
    if size <= 5 and chapter != 1:
        add("GRID_SMALL", "les grilles 4x4 et 5x5 sont réservées au chapitre 1")
    if size == 12 and number != LEVELS_PER_CHAPTER:
        add("GRID_12X12", "12x12 réservé au défi final (niveau 10)")
    final = number == LEVELS_PER_CHAPTER
    if final:
        if level["visualStyle"] != "FINAL":
            add("STYLE_FINAL", "le niveau 10 doit utiliser le style FINAL")
        if size != 12:
            add("FINAL_SIZE", "le défi final doit être en 12x12")
    elif level["visualStyle"] == "FINAL":
        add("STYLE_FINAL", "le style FINAL est réservé au niveau 10")
    if 1 <= number <= LEVELS_PER_CHAPTER and level["visualStyle"] != style_for(chapter, number):
        add("STYLE_RULE", f"style {level['visualStyle']} attendu {style_for(chapter, number)}")
    d = level["difficulty"]
    if not 1 <= d["tier"] <= 4:
        add("TIER", "palier hors 1..4")
    if not 0.0 <= d["ambiguity"] <= 1.0:
        add("AMBIGUITY", "ambiguïté hors 0..1")
    if level["hints"]["maxPerLevel"] < 1:
        add("HINTS", "maxPerLevel doit être >= 1")
    missing = [lang for lang in LANGS if lang not in level["variants"]]
    for lang in missing:
        add("VARIANT_MISSING", f"variante {lang} absente")
    if missing:
        return issues
    counts = {len(level["variants"][lang]["words"]) for lang in LANGS}
    if len(counts) > 1:
        add("WORD_COUNT", "nombre de mots différent entre langues")
    wanted = d.get("decoys", 0)
    for lang in LANGS:
        have = len(level["variants"][lang].get("decoys", []))
        if have != wanted:
            add("DECOY_COUNT", f"[{lang}] {have} leurres pour {wanted} annoncés")
    expected = level_score(level)
    if expected != d["score"]:
        add("SCORE", f"score {d['score']} != calculé {expected}")
    for lang in LANGS:
        issues += validate_variant(level, lang, level["variants"][lang])
    return issues


def validate_chapters(chapters):
    issues = []
    ids = [lv["id"] for ch in chapters for lv in ch["levels"]]
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        issues.append((dup, "DUPLICATE_ID", "identifiant de niveau en double"))
    ordered = sorted(chapters, key=lambda c: c["index"])
    means = [sum(lv["difficulty"]["score"] for lv in c["levels"]) / max(len(c["levels"]), 1) for c in ordered]
    for k in range(1, len(ordered)):
        if means[k] <= means[k - 1]:
            issues.append((None, "CHAPTER_ORDER", f"{ordered[k]['id']} : score moyen {means[k]:.1f} <= chapitre précédent {means[k - 1]:.1f}"))
    for i, chapter in enumerate(ordered):
        if chapter["index"] != i + 1:
            issues.append((None, "CHAPTER_INDEX", f"{chapter['id']} : index {chapter['index']} attendu {i + 1}"))
        if not all(chapter["theme"].get(lang) for lang in LANGS):
            issues.append((None, "CHAPTER_THEME", f"{chapter['id']} : thème manquant"))
        levels = sorted(chapter["levels"], key=lambda lv: lv["number"])
        if [lv["number"] for lv in levels] != list(range(1, LEVELS_PER_CHAPTER + 1)):
            issues.append((None, "CHAPTER_LEVELS", f"{chapter['id']} : niveaux 1..10 attendus"))
        for lv in levels:
            if lv["chapter"] != chapter["index"]:
                issues.append((lv["id"], "CHAPTER_REF", "chapter != index du chapitre"))
        for prev, cur in zip(levels, levels[1:]):
            if cur["difficulty"]["score"] <= prev["difficulty"]["score"]:
                issues.append((cur["id"], "DIFFICULTY_ORDER", f"score {cur['difficulty']['score']} <= précédent {prev['difficulty']['score']}"))
            if cur["gridSize"] < prev["gridSize"]:
                issues.append((cur["id"], "GRID_SHRINK", "la taille de grille ne doit pas diminuer"))
            if cur["number"] != LEVELS_PER_CHAPTER and prev["gridSize"] in SIZE_STEPS and cur["gridSize"] in SIZE_STEPS:
                if SIZE_STEPS.index(cur["gridSize"]) - SIZE_STEPS.index(prev["gridSize"]) > 1:
                    issues.append((cur["id"], "GRID_JUMP", "hausse de taille trop brutale"))
        if len(levels) >= LEVELS_PER_CHAPTER:
            ninth, tenth = levels[8], levels[9]
            if tenth["difficulty"]["score"] < ninth["difficulty"]["score"] * FINAL_MIN_RATIO:
                issues.append((tenth["id"], "FINAL_NOT_HARD_ENOUGH", f"{tenth['difficulty']['score']} < {FINAL_MIN_RATIO} x {ninth['difficulty']['score']}"))
        for lv in levels:
            issues += validate_level(lv)
    return issues


def load_chapters(levels_dir):
    levels_dir = Path(levels_dir)
    index = json.loads((levels_dir / "index.json").read_text(encoding="utf-8"))
    chapters = []
    for name in index["chapters"]:
        chapter = json.loads((levels_dir / name).read_text(encoding="utf-8"))
        for lv in chapter["levels"]:
            lv.setdefault("chapter", chapter["index"])
        chapters.append(chapter)
    return index, chapters
