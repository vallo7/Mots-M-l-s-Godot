extends SceneTree
## Vérifie que les défis quotidiens sont toujours valides : génère `--days=N` jours consécutifs (400 par défaut) dans
## les deux langues, contrôle chaque grille (mots à leur place, une seule occurrence, mélange de longueurs, directions du
## palier), la stabilité (même jour = même grille) et affiche les durées. Sortie non nulle au moindre problème.
## Usage : godot --headless --path . -s res://scripts/check_daily.gd -- --days=400 --from=20000


func _init() -> void:
	var days := 400
	var from_day := int(Time.get_unix_time_from_system() / 86400.0)
	var verbose := OS.get_cmdline_user_args().has("--verbose")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--days="):
			days = int(argument.get_slice("=", 1))
		if argument.begins_with("--from="):
			from_day = int(argument.get_slice("=", 1))
	var catalog := AssetLevelRepository.new().load_catalog()
	if catalog == null:
		push_error("catalogue illisible")
		quit(1)
		return
	var failures := 0
	var slowest := 0
	var slow_count := 0
	var total := 0
	for offset in days:
		for language in Language.ALL:
			var day := from_day + offset
			if verbose:
				print("... jour %d %s" % [day, Language.code(language)])
			var started := Time.get_ticks_msec()
			var level := DailyLevelFactory.create(catalog, day, language)
			var elapsed := Time.get_ticks_msec() - started
			slowest = maxi(slowest, elapsed)
			if elapsed > 250:
				slow_count += 1
				if slow_count <= 6:
					print("   lent : jour %d %s %d ms (jour de semaine %d)" % [day, Language.code(language), elapsed, DailyLevelFactory.weekday_of(day)])
			total += elapsed
			var problems := _problems(level, day, language)
			if offset < 3 or problems.size() > 0:
				var variant_words := level.variant(language).words.size() if level != null else 0
				print("jour %d %s : %s %d×%d %d mots (%d ms)%s" % [day, Language.code(language), level.id if level != null else "AUCUN", level.grid_size if level != null else 0, level.grid_size if level != null else 0, variant_words, elapsed, "" if problems.is_empty() else "  -> " + "; ".join(problems)])
			failures += 1 if problems.size() > 0 else 0
	print("%d grilles, %d en échec, moyenne %d ms, plus lente %d ms, %d de plus de 250 ms" % [days * Language.ALL.size(), failures, total / maxi(days * Language.ALL.size(), 1), slowest, slow_count])
	quit(1 if failures > 0 else 0)


func _problems(level: Level, day: int, language: int) -> Array[String]:
	var problems: Array[String] = []
	if level == null:
		problems.append("niveau absent")
		return problems
	var variant := level.variant(language)
	var n := level.grid_size
	if variant.grid.size() != n:
		problems.append("taille de grille incohérente")
		return problems
	var tier_directions := Direction.for_tier(level.difficulty.tier)
	var lengths: Array[int] = []
	for word in variant.words:
		lengths.append(word.letters.length())
		if not tier_directions.has(word.direction):
			problems.append("direction interdite pour %s" % word.letters)
		for i in word.cells.size():
			var cell: Vector2i = word.cells[i]
			if not variant.in_bounds(cell) or variant.letter_at(cell) != word.letters[i]:
				problems.append("%s ne correspond pas à la grille" % word.letters)
				break
		if LevelValidator.occurrence_count(variant, word.letters) != 1:
			problems.append("%s apparaît %d fois" % [word.letters, LevelValidator.occurrence_count(variant, word.letters)])
	var mix := LevelValidator.length_mix_problem(n, level.difficulty.tier, lengths)
	if mix != "":
		problems.append(mix)
	var again := DailyLevelFactory.create(AssetLevelRepository.new().load_catalog(), day, language) if day % 97 == 0 else null
	if again != null and again.variant(language).grid != variant.grid:
		problems.append("grille non reproductible")
	return problems
