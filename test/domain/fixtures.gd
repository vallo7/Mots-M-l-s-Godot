class_name Fixtures
extends RefCounted
## Jeux de données de test. Une case se note `cell(ligne, colonne)` comme dans l'app Kotlin d'origine ;
## en interne c'est un Vector2i (x = colonne, y = ligne).


static func cell(row: int, col: int) -> Vector2i:
	return Vector2i(col, row)


static func words(list: Array) -> Array[TargetWord]:
	var typed: Array[TargetWord] = []
	for w in list:
		typed.append(w)
	return typed


static func cells(list: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for c in list:
		typed.append(c)
	return typed


static func en_variant() -> LevelVariant:
	return LevelVariant.new(Language.EN, PackedStringArray(["SUN", "KQZ", "YWV"]), words([
		TargetWord.new("SUN", "SUN", cell(0, 0), Direction.E),
		TargetWord.new("SKY", "SKY", cell(0, 0), Direction.S),
	]))


static func fr_variant() -> LevelVariant:
	return LevelVariant.new(Language.FR, PackedStringArray(["MER", "TOK", "ILE"]), words([
		TargetWord.new("MER", "MER", cell(0, 0), Direction.E),
		TargetWord.new("Île", "ILE", cell(2, 0), Direction.E),
	]))


static func both_variants() -> Dictionary:
	return {Language.EN: en_variant(), Language.FR: fr_variant()}


static func en_variant_4() -> LevelVariant:
	return LevelVariant.new(Language.EN, PackedStringArray(["SAND", "UQZW", "NWVX", "ZXCV"]), words([
		TargetWord.new("SAND", "SAND", cell(0, 0), Direction.E),
		TargetWord.new("SUN", "SUN", cell(0, 0), Direction.S),
	]))


static func fr_variant_4() -> LevelVariant:
	return LevelVariant.new(Language.FR, PackedStringArray(["MERQ", "TOKX", "ILES", "ZVWY"]), words([
		TargetWord.new("MER", "MER", cell(0, 0), Direction.E),
		TargetWord.new("Îles", "ILES", cell(2, 0), Direction.E),
	]))


## Niveau 4×4 valide (chapitre 1, niveau 1) : la plus petite grille autorisée. Même options que `level`.
static func level_4x4(o: Dictionary = {}) -> Level:
	var merged := o.duplicate()
	merged["grid_size"] = 4
	merged["variants"] = o.get("variants", {Language.EN: en_variant_4(), Language.FR: fr_variant_4()})
	return level(merged)


## Niveau 3×3 (chapitre 1, niveau 1) : pratique pour les tests du moteur, mais plus autorisé par le validateur. Options : id, chapter, number, grid_size, tier, ambiguity,
## max_hints, variants, style, score.
static func level(o: Dictionary = {}) -> Level:
	var chapter: int = o.get("chapter", 1)
	var number: int = o.get("number", 1)
	var draft := Level.new(
		o.get("id", "c1-l01"), chapter, number, {"fr": "Plage", "en": "Beach"},
		o.get("style", VisualStyle.for_level(chapter, number)), o.get("grid_size", 3),
		DifficultyProfile.new(o.get("tier", 1), o.get("ambiguity", 0.0), 0),
		o.get("max_hints", 3), o.get("variants", both_variants())
	)
	draft.difficulty.score = o.get("score", DifficultyScore.compute(draft))
	return draft


## Catalogue factice (niveaux sans contenu valide) pour tester la progression.
static func stub_catalog(chapter_count: int = 2) -> LevelCatalog:
	var chapters: Array[Chapter] = []
	for c in range(1, chapter_count + 1):
		var levels: Array[Level] = []
		for n in range(1, 11):
			levels.append(level({"id": "c%d-l%02d" % [c, n], "chapter": c, "number": n}))
		chapters.append(Chapter.new("chapter-0%d" % c, c, {"fr": "Chapitre %d" % c, "en": "Chapter %d" % c}, "palette%d" % c, levels))
	return LevelCatalog.new(chapters)


static func sun() -> Array[Vector2i]:
	return cells([cell(0, 0), cell(0, 1), cell(0, 2)])


static func sky() -> Array[Vector2i]:
	return cells([cell(0, 0), cell(1, 0), cell(2, 0)])


## Horloge simulée : `clock.callable()` s'injecte dans GameTimer / GameSession.
class FakeClock extends RefCounted:
	var now: int = 1_000

	func callable() -> Callable:
		return func() -> int: return now
