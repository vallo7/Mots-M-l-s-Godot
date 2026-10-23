class_name LevelValidator
extends RefCounted
## Règles de validation du contenu, exécutées au démarrage, en test et (miroir Python) en CI.
## Sans nœud ni scène : peut tourner sur un thread de travail.

const ALLOWED_GRID_SIZES: Array[int] = [4, 5, 6, 7, 8, 9, 10, 11, 12]
const FINAL_MIN_RATIO := 1.15
## Échelle des tailles hors défi final (le 12×12 est réservé au niveau 10, hors règle de saut).
const SIZE_STEPS: Array[int] = [4, 5, 6, 7, 8, 9, 10, 11]
## Profil de longueurs de mots : un niveau mêle toujours des mots COURTS et des mots LONGS, selon la taille de la grille
## et le palier de difficulté. Par taille : [longueur max du mot le plus court, écart minimal plus court / plus long].
## Miroir exact de scripts/level_tools.py.
const LENGTH_PROFILE := {4: [3, 1], 5: [3, 2], 6: [4, 2], 7: [4, 3], 8: [4, 4], 9: [5, 4], 10: [5, 5], 11: [5, 6], 12: [5, 7]}


static func validate_catalog(catalog: LevelCatalog) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	if catalog.chapters.is_empty():
		issues.append(ValidationIssue.new("", "NO_CHAPTER", "aucun chapitre"))
	var counts := {}
	for level in catalog.levels:
		counts[level.id] = int(counts.get(level.id, 0)) + 1
	for id in counts:
		if counts[id] > 1:
			issues.append(ValidationIssue.new(id, "DUPLICATE_ID", "identifiant de niveau en double"))
	var chapters := catalog.chapters_sorted()
	# Difficulté croissante d'un chapitre à l'autre : le score moyen d'un chapitre dépasse celui du précédent.
	var previous_mean := -1.0
	for chapter in chapters:
		var total := 0.0
		for level in chapter.levels:
			total += level.difficulty.score
		var mean := total / maxf(chapter.levels.size(), 1.0)
		if previous_mean >= 0.0 and mean <= previous_mean:
			issues.append(ValidationIssue.new("", "CHAPTER_ORDER", "chapitre %s : score moyen %.1f ≤ chapitre précédent %.1f" % [chapter.id, mean, previous_mean]))
		previous_mean = mean
	for i in chapters.size():
		var chapter := chapters[i]
		if chapter.index != i + 1:
			issues.append(ValidationIssue.new("", "CHAPTER_INDEX", "chapitre %s : index %d, attendu %d" % [chapter.id, chapter.index, i + 1]))
		if String(chapter.theme.get("fr", "")).strip_edges().is_empty() or String(chapter.theme.get("en", "")).strip_edges().is_empty():
			issues.append(ValidationIssue.new("", "CHAPTER_THEME", "chapitre %s : thème manquant" % chapter.id))
		var levels: Array[Level] = chapter.levels.duplicate()
		levels.sort_custom(func(a: Level, b: Level) -> bool: return a.number < b.number)
		var numbers: Array[int] = []
		for level in levels:
			numbers.append(level.number)
		var expected: Array[int] = []
		for n in range(1, Level.LEVELS_PER_CHAPTER + 1):
			expected.append(n)
		if numbers != expected:
			issues.append(ValidationIssue.new("", "CHAPTER_LEVELS", "chapitre %s : les niveaux doivent être numérotés 1..%d" % [chapter.id, Level.LEVELS_PER_CHAPTER]))
		for level in levels:
			if level.chapter_index != chapter.index:
				issues.append(ValidationIssue.new(level.id, "CHAPTER_REF", "chapterIndex %d ≠ %d" % [level.chapter_index, chapter.index]))
		for k in range(1, levels.size()):
			var prev := levels[k - 1]
			var cur := levels[k]
			if cur.difficulty.score <= prev.difficulty.score:
				issues.append(ValidationIssue.new(cur.id, "DIFFICULTY_ORDER", "score %d ≤ score du niveau précédent %d" % [cur.difficulty.score, prev.difficulty.score]))
			if cur.grid_size < prev.grid_size:
				issues.append(ValidationIssue.new(cur.id, "GRID_SHRINK", "la taille de grille ne doit pas diminuer"))
			if not cur.is_final_challenge():
				var a := SIZE_STEPS.find(prev.grid_size)
				var b := SIZE_STEPS.find(cur.grid_size)
				if a >= 0 and b >= 0 and b - a > 1:
					issues.append(ValidationIssue.new(cur.id, "GRID_JUMP", "hausse de taille trop brutale (%d→%d)" % [prev.grid_size, cur.grid_size]))
		var ninth: Level = null
		var tenth: Level = null
		for level in levels:
			if level.number == Level.FINAL_NUMBER - 1:
				ninth = level
			elif level.number == Level.FINAL_NUMBER:
				tenth = level
		if ninth != null and tenth != null and tenth.difficulty.score < ninth.difficulty.score * FINAL_MIN_RATIO:
			issues.append(ValidationIssue.new(tenth.id, "FINAL_NOT_HARD_ENOUGH", "le défi final doit valoir ≥ %s× le niveau 9 (%d vs %d)" % [str(FINAL_MIN_RATIO), tenth.difficulty.score, ninth.difficulty.score]))
		for level in levels:
			issues.append_array(validate_level(level))
	return issues


static func validate_level(level: Level) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var add := func(code: String, message: String) -> void:
		issues.append(ValidationIssue.new(level.id, code, message))

	if level.id.strip_edges().is_empty():
		add.call("ID", "identifiant vide")
	if level.chapter_index < 1:
		add.call("CHAPTER", "chapitre invalide")
	if level.number < 1 or level.number > Level.LEVELS_PER_CHAPTER:
		add.call("NUMBER", "numéro hors 1..%d" % Level.LEVELS_PER_CHAPTER)
	if String(level.theme.get("fr", "")).strip_edges().is_empty() or String(level.theme.get("en", "")).strip_edges().is_empty():
		add.call("THEME", "thème manquant dans une langue")
	if not ALLOWED_GRID_SIZES.has(level.grid_size):
		add.call("GRID_SIZE", "taille %d non autorisée" % level.grid_size)
	if level.grid_size <= 5 and level.chapter_index != 1:
		add.call("GRID_SMALL", "les grilles 4×4 et 5×5 sont réservées au chapitre 1")
	if level.grid_size == 12 and not level.is_final_challenge():
		add.call("GRID_12X12", "12×12 réservé au défi final (niveau 10)")
	if level.is_final_challenge():
		if level.visual_style != VisualStyle.FINAL:
			add.call("STYLE_FINAL", "le niveau 10 doit utiliser le style FINAL")
		if level.grid_size != 12:
			add.call("FINAL_SIZE", "le défi final doit être en 12×12")
	elif level.visual_style == VisualStyle.FINAL:
		add.call("STYLE_FINAL", "le style FINAL est réservé au niveau 10")
	if level.number >= 1 and level.number <= Level.LEVELS_PER_CHAPTER:
		var expected_style := VisualStyle.for_level(level.chapter_index, level.number)
		if level.visual_style != expected_style:
			add.call("STYLE_RULE", "style %s ≠ %s attendu" % [VisualStyle.NAMES[level.visual_style], VisualStyle.NAMES[expected_style]])
	if level.difficulty.tier < 1 or level.difficulty.tier > 4:
		add.call("TIER", "palier %d hors 1..4" % level.difficulty.tier)
	if level.difficulty.ambiguity < 0.0 or level.difficulty.ambiguity > 1.0:
		add.call("AMBIGUITY", "ambiguïté hors 0..1")
	if level.hints_max_per_level < 1:
		add.call("HINTS", "maxPerLevel doit être ≥ 1")
	var missing := false
	for language in Language.ALL:
		if not level.variants.has(language):
			missing = true
			add.call("VARIANT_MISSING", "variante %s absente" % Language.code(language))
	var word_counts := {}
	for language in level.variants:
		word_counts[level.variants[language].words.size()] = true
	if word_counts.size() > 1:
		add.call("WORD_COUNT", "nombre de mots différent entre langues")
	if not missing and not level.variants.is_empty():
		var expected_score := DifficultyScore.compute(level)
		if expected_score != level.difficulty.score:
			add.call("SCORE", "score %d ≠ calculé %d" % [level.difficulty.score, expected_score])
	for language in level.variants:
		issues.append_array(_validate_variant(level, level.variants[language]))
	return issues


static func _validate_variant(level: Level, variant: LevelVariant) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var tag := Language.code(variant.language)
	var add := func(code: String, message: String) -> void:
		issues.append(ValidationIssue.new(level.id, code, "[%s] %s" % [tag, message]))

	var n := level.grid_size
	var shape_ok := variant.grid.size() == n
	if shape_ok:
		for row in variant.grid:
			if row.length() != n:
				shape_ok = false
	if not shape_ok:
		add.call("GRID_SHAPE", "la grille doit être %d×%d" % [n, n])
		return issues
	var chars_ok := true
	for row in variant.grid:
		for ch in row:
			if not (ch >= "A" and ch <= "Z" and ch.length() == 1):
				chars_ok = false
	if not chars_ok:
		add.call("GRID_CHARS", "la grille ne doit contenir que A-Z")
	if variant.words.is_empty():
		add.call("NO_WORDS", "aucun mot cible")

	var letters_seen := {}
	var allowed := level.difficulty.allowed_directions()
	var geometry_broken := not chars_ok
	for i in variant.words.size():
		var w := variant.words[i]
		if w.letters != TextNormalizer.to_grid_letters(w.display):
			add.call("WORD_LETTERS", "mot #%d « %s » : letters « %s » incohérent" % [i, w.display, w.letters])
		if w.length() < 2:
			add.call("WORD_LENGTH", "mot #%d trop court" % i)
		if letters_seen.has(w.letters):
			add.call("WORD_DUPLICATE", "mot en double « %s »" % w.letters)
		letters_seen[w.letters] = true
		if not allowed.has(w.direction):
			add.call("DIRECTION", "mot « %s » : direction %s interdite au palier %d" % [w.letters, Direction.NAMES[w.direction], level.difficulty.tier])
		var out_of_bounds := false
		for cell in w.cells:
			if not variant.in_bounds(cell):
				out_of_bounds = true
		if out_of_bounds:
			add.call("OUT_OF_BOUNDS", "mot « %s » sort de la grille" % w.letters)
			geometry_broken = true
		else:
			for k in w.cells.size():
				if variant.letter_at(w.cells[k]) != w.letters[k]:
					add.call("GRID_MISMATCH", "mot « %s » ne correspond pas aux lettres de la grille" % w.letters)
					geometry_broken = true
					break
	# Un mot ne doit pas contenir un autre mot (sens normal ou inverse) : sinon ambiguïté.
	for a in variant.words:
		for b in variant.words:
			if a != b and (a.letters.contains(b.letters) or a.letters.contains(_reversed(b.letters))):
				add.call("WORD_CONTAINED", "« %s » est contenu dans « %s »" % [b.letters, a.letters])
	var lengths: Array[int] = []
	for w in variant.words:
		lengths.append(w.letters.length())
	var mix_problem := length_mix_problem(n, level.difficulty.tier, lengths)
	if not mix_problem.is_empty():
		add.call("LENGTH_MIX", mix_problem)
	if geometry_broken:
		return issues

	# Unicité : chaque mot n'apparaît qu'une fois dans la grille, dans les 8 directions.
	for w in variant.words:
		var count := occurrence_count(variant, w.letters)
		if count != 1:
			add.call("AMBIGUOUS_WORD", "« %s » apparaît %d fois dans la grille" % [w.letters, count])
	# Résolubilité : on rejoue la solution avec le vrai moteur.
	if issues.is_empty():
		var state := GameEngine.new_game(level, variant.language)
		for i in variant.words.size():
			var w := variant.words[i]
			var result := GameEngine.select(state, w.cells)
			if result.kind != SelectionResult.Kind.FOUND or result.word_index != i:
				add.call("UNSOLVABLE", "le moteur n'accepte pas le mot « %s »" % w.letters)
			state = result.state
		if not state.is_solved():
			add.call("UNSOLVABLE", "niveau non résolu après avoir joué tous les mots")
	return issues


## Nombre d'ensembles de cases distincts où `letters` apparaît (un palindrome ne compte qu'une fois).
## Longueur minimale du mot le plus long : presque toute la grille dans les petites tailles ; plus le palier est
## élevé, plus le mot le plus long se rapproche de la largeur de la grille.
static func min_longest_word(grid_size: int, tier: int) -> int:
	if grid_size <= 7:
		return grid_size - 1
	return grid_size - 1 if tier >= 4 else grid_size - 2


## Message décrivant l'insuffisance du mélange de longueurs, ou "" si le profil est respecté.
static func length_mix_problem(grid_size: int, tier: int, lengths: Array[int]) -> String:
	if not LENGTH_PROFILE.has(grid_size) or lengths.is_empty():
		return ""
	var profile: Array = LENGTH_PROFILE[grid_size]
	var shortest: int = lengths.min()
	var longest: int = lengths.max()
	if shortest > int(profile[0]):
		return "aucun mot court : le plus court fait %d lettres (max %d en %d×%d)" % [shortest, profile[0], grid_size, grid_size]
	var need_long := min_longest_word(grid_size, tier)
	if longest < need_long:
		return "aucun mot long : le plus long fait %d lettres (min %d en %d×%d, palier %d)" % [longest, need_long, grid_size, grid_size, tier]
	if longest - shortest < int(profile[1]):
		return "longueurs trop uniformes : écart %d (min %d)" % [longest - shortest, profile[1]]
	return ""


static func occurrence_count(variant: LevelVariant, letters: String) -> int:
	var found := {}
	var n := variant.grid.size()
	var length := letters.length()
	var first := letters[0]
	for r in n:
		for c in n:
			if variant.grid[r][c] != first:
				continue
			for d in Direction.ALL:
				var step := Direction.vector(d)
				var end := Vector2i(c, r) + step * (length - 1)
				if end.x < 0 or end.x >= n or end.y < 0 or end.y >= n:
					continue
				var matches := true
				var cells: Array[int] = []
				for k in length:
					var cc := c + step.x * k
					var rr := r + step.y * k
					if variant.grid[rr][cc] != letters[k]:
						matches = false
						break
					cells.append(rr * n + cc)
				if matches:
					cells.sort()
					found[cells] = true
	return found.size()


static func _reversed(text: String) -> String:
	var out := ""
	for i in range(text.length() - 1, -1, -1):
		out += text[i]
	return out
