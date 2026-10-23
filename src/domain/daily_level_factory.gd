class_name DailyLevelFactory
extends RefCounted
## Fabrique la grille du défi du jour, déterministe : le même jour et la même langue donnent la même grille sur tous les
## appareils (graine = FNV-1a de « jour/langue », générateur PCG de Godot). Le thème et les mots sont tirés des listes
## éditoriales des niveaux du jeu ; la difficulté suit le jour de la semaine (lundi doux, dimanche = grand 12×12).
##
## Même méthode que scripts/generate_levels.py : placement « mots croisés » des mots, leurres (débuts de mots cachés),
## remplissage avec les lettres des mots eux-mêmes (`ambiguity`) puis correction des occurrences parasites jusqu'à ce que
## chaque mot n'apparaisse qu'une fois. La grille est vérifiée avant d'être rendue ; en cas d'échec on retente avec un
## autre tirage (jamais de grille invalide, jamais d'échec visible).

## Plan par jour de la semaine (0 = dimanche … 6 = samedi, comme `Time.get_date_dict_from_unix_time`).
## `number` règle le badge de difficulté et le style visuel ; 10 = style « final ».
const PLAN := [
	{"number": 10, "size": 12, "tier": 4, "words": 15, "ambiguity": 0.95, "decoys": 6, "hints": 5},
	{"number": 3, "size": 7, "tier": 3, "words": 8, "ambiguity": 0.6, "decoys": 2, "hints": 3},
	{"number": 4, "size": 8, "tier": 3, "words": 9, "ambiguity": 0.65, "decoys": 2, "hints": 3},
	{"number": 5, "size": 8, "tier": 4, "words": 10, "ambiguity": 0.7, "decoys": 3, "hints": 4},
	{"number": 6, "size": 9, "tier": 4, "words": 11, "ambiguity": 0.75, "decoys": 3, "hints": 4},
	{"number": 7, "size": 10, "tier": 4, "words": 12, "ambiguity": 0.8, "decoys": 4, "hints": 4},
	{"number": 8, "size": 10, "tier": 4, "words": 13, "ambiguity": 0.85, "decoys": 5, "hints": 4},
]

const FR_ALPHABET := "EEEEEEEEEEEEAAAAAAAIIIIIIINNNNNNOOOOOORRRRRRSSSSSSTTTTTTUUUUUULLLLLDDDCCMMPPVFBGHQXYZJKW"
const EN_ALPHABET := "EEEEEEEEEEEEAAAAAAAAIIIIIIIOOOOOOONNNNNNRRRRRRTTTTTTSSSSSLLLLCCCDDDUUMMPPHHGGBFYWKVXZJQ"

## Plafonds d'effort (en tirages, jamais en temps : le résultat doit être identique sur tous les appareils).
## Compteurs de diagnostic (scripts/check_daily.gd).
static var stats := {"themes": 0, "places": 0, "fills": 0, "rounds": 0}

const MIN_WORD_LENGTH := 4
const MAX_THEME_TRIES := 40
const MAX_PLACE_TRIES := 8
## Budget de placements pour un nombre de mots donné ; au-delà on retente avec un mot de moins (rare).
const MAX_TOTAL_PLACES := 30
const MAX_FILL_ROUNDS := 160


static func weekday_of(day_index: int) -> int:
	return int(Time.get_date_dict_from_unix_time(day_index * 86400)["weekday"])


static func plan_for(day_index: int) -> Dictionary:
	return PLAN[weekday_of(day_index)]


## Graine stable (FNV-1a 32 bits) : ne dépend ni de la plateforme ni de `String.hash()`.
static func seed_for(day_index: int, language: int) -> int:
	var h := 2166136261
	for byte in ("daily/%d/%s" % [day_index, Language.code(language)]).to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h


## Le défi du jour pour `language`. Ne renvoie jamais null si le catalogue contient au moins un niveau.
static func create(catalog: LevelCatalog, day_index: int, language: int) -> Level:
	var plan := plan_for(day_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(day_index, language)
	var words_wanted: int = plan["words"]
	# Sécurité : si les listes sont plus courtes que prévu on réduit le nombre de mots, jamais la validité.
	while words_wanted >= 4:
		var places_before: int = stats["places"]
		var pool: Array[Level] = []
		for level in catalog.levels:
			if level.variants.has(language) and level.variant(language).words.size() >= words_wanted:
				pool.append(level)
		if not pool.is_empty():
			for _try in MAX_THEME_TRIES:
				if int(stats["places"]) - places_before > MAX_TOTAL_PLACES:
					break
				stats["themes"] += 1
				var source: Level = pool[rng.randi_range(0, pool.size() - 1)]
				var picked := _pick_words(rng, source.variant(language).words, words_wanted)
				var size := _size_for(int(plan["size"]), picked)
				if size < 0:
					continue
				var lengths: Array[int] = []
				for w in picked:
					lengths.append(w.letters.length())
				if LevelValidator.length_mix_problem(size, int(plan["tier"]), lengths) != "":
					continue
				# Si les premiers thèmes résistent, on desserre peu à peu l'ambiguïté (jamais en dessous de 0,4).
				var ambiguity := maxf(float(plan["ambiguity"]) - 0.08 * float(_try / 12), 0.4)
				var variant := _build_variant(rng, size, int(plan["tier"]), ambiguity, int(plan["decoys"]), picked, language)
				if variant != null:
					return _make_level(day_index, plan, source, size, variant, language)
		words_wanted -= 1
	return null


static func _make_level(day_index: int, plan: Dictionary, source: Level, size: int, variant: LevelVariant, language: int) -> Level:
	var number: int = plan["number"]
	var level := Level.new(
		"daily-%d" % day_index, 0, number, source.theme.duplicate(),
		VisualStyle.for_level(1, number), size,
		DifficultyProfile.new(int(plan["tier"]), float(plan["ambiguity"]), 0, int(plan["decoys"])),
		int(plan["hints"]), {language: variant}
	)
	level.difficulty.score = DifficultyScore.compute(level)
	return level


## Sous-ensemble de `count` mots de la liste, tirés au hasard avec une préférence pour les mots courts (les grilles du
## début de semaine restent aérées) ; les mots longs et courts restent mêlés.
static func _pick_words(rng: RandomNumberGenerator, words: Array[TargetWord], count: int) -> Array[TargetWord]:
	# Les mots de 3 lettres ou moins surgissent par hasard dans une petite grille dense : on les évite si possible.
	var remaining: Array[TargetWord] = []
	for w in words:
		if w.letters.length() >= MIN_WORD_LENGTH:
			remaining.append(w)
	if remaining.size() < count:
		remaining = words.duplicate()
	var picked: Array[TargetWord] = []
	while picked.size() < count and not remaining.is_empty():
		var total := 0.0
		for w in remaining:
			total += 1.0 / pow(w.letters.length(), 1.5)
		var roll := rng.randf() * total
		var chosen := remaining.size() - 1
		for i in remaining.size():
			roll -= 1.0 / pow(remaining[i].letters.length(), 1.5)
			if roll <= 0.0:
				chosen = i
				break
		picked.append(remaining[chosen])
		remaining.remove_at(chosen)
	return picked


## Taille de grille : celle du jour, agrandie d'un cran au plus si les mots tirés sont trop serrés pour y tenir ;
## -1 si le tirage est trop dense (on en tire un autre).
static func _size_for(planned: int, words: Array[TargetWord]) -> int:
	var letters := 0
	var longest := 0
	for w in words:
		letters += w.letters.length()
		longest = maxi(longest, w.letters.length())
	var size := maxi(planned, longest)
	while size < 12 and size <= planned and letters > int(size * size * 0.68):
		size += 1
	if size > planned + 1 or letters > int(size * size * 0.74):
		return -1
	return mini(size, 12)


# ---- Placement
static func _axis_bit(direction: int) -> int:
	match direction:
		Direction.E, Direction.W:
			return 1
		Direction.S, Direction.N:
			return 2
		Direction.SE, Direction.NW:
			return 4
		_:
			return 8


## Positions où `w` tient : cases vides ou lettres identiques, jamais deux mots sur le même axe d'une case.
static func _candidates(grid: Array, axes: Array, n: int, w: String, dirs: Array[int]) -> Array:
	var result: Array = []
	var first := w[0]
	var last_index := w.length() - 1
	for d in dirs:
		var step := Direction.vector(d)
		var bit := _axis_bit(d)
		for y in n:
			for x in n:
				var ex := x + step.x * last_index
				var ey := y + step.y * last_index
				if ex < 0 or ex >= n or ey < 0 or ey >= n:
					continue
				var g: String = grid[y][x]
				if g != "" and g != first:
					continue
				var overlap := 0
				var ok := true
				for t in w.length():
					var cx := x + step.x * t
					var cy := y + step.y * t
					var cell: String = grid[cy][cx]
					if cell == "":
						continue
					if cell != w[t] or (axes[cy][cx] & bit) != 0:
						ok = false
						break
					overlap += 1
				if ok:
					result.append([x, y, d, overlap])
	return result


static func _put(grid: Array, axes: Array, w: String, x: int, y: int, d: int) -> void:
	var step := Direction.vector(d)
	var bit := _axis_bit(d)
	for t in w.length():
		grid[y + step.y * t][x + step.x * t] = w[t]
		axes[y + step.y * t][x + step.x * t] |= bit


static func _cells_key(w: String, x: int, y: int, d: int) -> Array[int]:
	var step := Direction.vector(d)
	var keys: Array[int] = []
	for t in w.length():
		keys.append((y + step.y * t) * 64 + (x + step.x * t))
	keys.sort()
	return keys


static func _one_decoy(rng: RandomNumberGenerator, words: Array[String], alphabet: String) -> String:
	var pool: Array[String] = []
	for w in words:
		if w.length() >= 4:
			pool.append(w)
	if pool.is_empty():
		return ""
	var base := pool[rng.randi_range(0, pool.size() - 1)]
	var low := 4 if base.length() >= 6 else 3
	var s := ""
	if rng.randf() < 0.55:
		s = base.substr(0, rng.randi_range(mini(low, base.length() - 1), base.length() - 1))
	else:
		var k := rng.randi_range(1, 2)
		s = base.substr(0, base.length() - k)
		for _i in k:
			s += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	if s.length() < 3 or s == base or words.has(s):
		return ""
	return s


## Tente de poser tous les mots et leurs leurres ; renvoie {grid, axes, pos, fixed} ou null.
static func _try_place(rng: RandomNumberGenerator, n: int, letters: Array[String], dirs: Array[int], min_cross: int, decoys_wanted: int, alphabet: String) -> Variant:
	var grid: Array = []
	var axes: Array = []
	for _y in n:
		var row: Array = []
		var axis_row: Array = []
		for _x in n:
			row.append("")
			axis_row.append(0)
		grid.append(row)
		axes.append(axis_row)
	var order: Array[int] = []
	for i in letters.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return letters[a].length() > letters[b].length() or (letters[a].length() == letters[b].length() and a < b))
	var pos: Array = []
	pos.resize(letters.size())
	var cross := 0
	var word_cells: Array = []
	word_cells.resize(letters.size())
	for k in order.size():
		var i := order[k]
		var w := letters[i]
		var cands := _candidates(grid, axes, n, w, dirs)
		if cands.is_empty():
			return null
		var best := 0
		for c in cands:
			best = maxi(best, int(c[3]))
		var pool: Array = []
		if k > 0 and best > 0 and (cross < min_cross or rng.randf() < 0.8):
			var floor_value := maxi(best - (1 if rng.randf() < 0.33 else 0), 1)
			for c in cands:
				if int(c[3]) >= floor_value:
					pool.append(c)
		else:
			pool = cands
		var chosen: Array = pool[rng.randi_range(0, pool.size() - 1)]
		_put(grid, axes, w, chosen[0], chosen[1], chosen[2])
		pos[i] = [chosen[0], chosen[1], chosen[2]]
		word_cells[i] = _cells_key(w, chosen[0], chosen[1], chosen[2])
		cross += int(chosen[3])
	var fixed: Dictionary = {}
	for y in n:
		for x in n:
			if grid[y][x] != "":
				fixed[y * 64 + x] = true
	# Pour écarter vite les positions qui retomberaient « dans » un vrai mot : un ensemble de cases et un axe par mot.
	var word_sets: Array = []
	var word_axes: Array = []
	for i in letters.size():
		var set: Dictionary = {}
		for key in word_cells[i]:
			set[key] = true
		word_sets.append(set)
		word_axes.append(_axis_bit(pos[i][2]))
	var decoys := 0
	var attempts := 0
	var word_list: Array[String] = letters.duplicate()
	while decoys < decoys_wanted and attempts < 50:
		attempts += 1
		var s := _one_decoy(rng, word_list, alphabet)
		if s == "":
			continue
		var cands := _candidates(grid, axes, n, s, dirs)
		var usable: Array = []
		for c in cands:
			var inside := false
			var start_key: int = int(c[1]) * 64 + int(c[0])
			var bit := _axis_bit(c[2])
			for wi in word_sets.size():
				if word_axes[wi] == bit and word_sets[wi].has(start_key) and _within(s, c, word_sets[wi]):
					inside = true
					break
			if not inside:
				usable.append(c)
		if usable.is_empty():
			continue
		var crossing: Array = []
		for c in usable:
			if int(c[3]) > 0:
				crossing.append(c)
		var source: Array = crossing if (not crossing.is_empty() and rng.randf() < 0.7) else usable
		var pick: Array = source[rng.randi_range(0, source.size() - 1)]
		_put(grid, axes, s, pick[0], pick[1], pick[2])
		for key in _cells_key(s, pick[0], pick[1], pick[2]):
			fixed[key] = true
		decoys += 1
	if decoys < decoys_wanted or cross < min_cross:
		return null
	return {"grid": grid, "pos": pos, "word_cells": word_cells, "fixed": fixed}


## Toutes les cases du mot `w` posé en `c` ([x, y, direction, …]) sont-elles dans l'ensemble de cases `set` ?
static func _within(w: String, c: Array, set: Dictionary) -> bool:
	var step := Direction.vector(c[2])
	for t in w.length():
		if not set.has((int(c[1]) + step.y * t) * 64 + int(c[0]) + step.x * t):
			return false
	return true


# ---- Remplissage
## Occurrences (en ensembles de cases triés) du mot `w` dans `rows`, dans les 8 directions.
static func _occurrences(rows: Array, by_letter: Dictionary, n: int, w: String) -> Array:
	var found: Array = []
	var starts: Array = by_letter.get(w[0], [])
	var last_index := w.length() - 1
	for start in starts:
		for d in Direction.ALL:
			var step := Direction.vector(d)
			var ex: int = start.x + step.x * last_index
			var ey: int = start.y + step.y * last_index
			if ex < 0 or ex >= n or ey < 0 or ey >= n:
				continue
			var ok := true
			for t in range(1, w.length()):
				if rows[start.y + step.y * t][start.x + step.x * t] != w[t]:
					ok = false
					break
			if ok:
				found.append(_cells_key(w, start.x, start.y, d))
	return found


static func _fill_unique(rng: RandomNumberGenerator, placed: Dictionary, n: int, letters: Array[String], alphabet: String, ambiguity: float) -> Variant:
	var pool := "".join(letters)
	var rows: Array = placed["grid"].duplicate(true)
	var fixed: Dictionary = placed["fixed"]
	for y in n:
		for x in n:
			if rows[y][x] == "":
				rows[y][x] = _random_letter(rng, pool, alphabet, ambiguity)
	for _round in MAX_FILL_ROUNDS:
		stats["rounds"] += 1
		var by_letter: Dictionary = {}
		for y in n:
			for x in n:
				var ch: String = rows[y][x]
				if not by_letter.has(ch):
					by_letter[ch] = []
				by_letter[ch].append(Vector2i(x, y))
		var clean := true
		for i in letters.size():
			var found := _occurrences(rows, by_letter, n, letters[i])
			var own: Array = placed["word_cells"][i]
			if found.size() == 1 and found[0] == own:
				continue
			clean = false
			var own_present := false
			for occurrence in found:
				if occurrence == own:
					own_present = true
			if not own_present:
				return null  # un leurre ou un autre mot a recouvert celui-ci : on repart d'un autre placement
			for occurrence in found:
				if occurrence == own:
					continue
				var free: Array[int] = []
				for key in occurrence:
					if not fixed.has(key):
						free.append(key)
				if free.is_empty():
					return null
				var key: int = free[rng.randi_range(0, free.size() - 1)]
				var old: String = rows[key >> 6][key & 63]
				var replacement := _random_letter(rng, pool, alphabet, ambiguity * 0.5)  # on s'éloigne des lettres des mots
				for _i in 4:
					if replacement != old:
						break
					replacement = _random_letter(rng, pool, alphabet, ambiguity * 0.5)
				rows[key >> 6][key & 63] = replacement
		if clean:
			return rows
	return null


static func _random_letter(rng: RandomNumberGenerator, pool: String, alphabet: String, ambiguity: float) -> String:
	if rng.randf() < ambiguity:
		return pool[rng.randi_range(0, pool.length() - 1)]
	return alphabet[rng.randi_range(0, alphabet.length() - 1)]


static func _build_variant(rng: RandomNumberGenerator, n: int, tier: int, ambiguity: float, decoys: int, words: Array[TargetWord], language: int) -> LevelVariant:
	var letters: Array[String] = []
	for w in words:
		letters.append(w.letters)
	var alphabet := FR_ALPHABET if language == Language.FR else EN_ALPHABET
	var dirs := Direction.for_tier(tier)
	var min_cross := int(round(words.size() * 0.55))
	for _try in MAX_PLACE_TRIES:
		stats["places"] += 1
		var placed: Variant = _try_place(rng, n, letters, dirs, min_cross, decoys, alphabet)
		if placed == null:
			continue
		for _fill in 3:
			stats["fills"] += 1
			var rows: Variant = _fill_unique(rng, placed, n, letters, alphabet, ambiguity)
			if rows == null:
				continue
			var grid := PackedStringArray()
			for row in rows:
				grid.append("".join(row))
			var targets: Array[TargetWord] = []
			for i in words.size():
				var p: Array = placed["pos"][i]
				targets.append(TargetWord.new(words[i].display, letters[i], Vector2i(p[0], p[1]), p[2]))
			var variant := LevelVariant.new(language, grid, targets)
			var valid := true
			for target in targets:
				if LevelValidator.occurrence_count(variant, target.letters) != 1:
					valid = false
					break
			if valid:
				return variant
	return null
