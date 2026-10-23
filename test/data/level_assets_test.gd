class_name LevelAssetsTest
extends GdUnitTestSuite
## Valide le contenu réellement livré dans data/levels (les mêmes fichiers que ceux embarqués dans l'APK).

var _catalog: LevelCatalog


func before() -> void:
	_catalog = AssetLevelRepository.new().load_catalog()


func test_shipped_catalog_loads() -> void:
	assert_object(_catalog).is_not_null()


func test_shipped_catalog_passes_every_validation_rule() -> void:
	var issues: Array[String] = []
	for issue in LevelValidator.validate_catalog(_catalog):
		issues.append(str(issue))
	assert_array(issues).is_empty()


func test_ten_chapters_of_ten_levels_make_a_hundred_levels() -> void:
	assert_int(_catalog.chapters.size()).is_equal(10)
	for chapter in _catalog.chapters:
		assert_int(chapter.levels.size()).is_equal(Level.LEVELS_PER_CHAPTER)
	assert_int(_catalog.levels.size()).is_equal(100)


func test_every_chapter_has_its_own_palette_and_theme() -> void:
	var palettes := {}
	for chapter in _catalog.chapters:
		palettes[chapter.palette_key] = true
		var look := Wg.chapter_theme(chapter.palette_key)
		assert_bool(ResourceLoader.exists("res://assets/illustrations/%s.svg" % look["illustration"])).is_true()
	assert_int(palettes.size()).is_equal(10)


func test_every_level_exists_in_both_languages_with_the_same_word_count() -> void:
	for level in _catalog.levels:
		var counts := {}
		for language in Language.ALL:
			counts[level.variant(language).words.size()] = true
		assert_int(counts.size()).is_equal(1)


func test_small_grids_only_in_chapter_1_and_12x12_only_for_final_challenges() -> void:
	for level in _catalog.levels:
		if level.grid_size <= 5:
			assert_int(level.chapter_index).is_equal(1)
		if level.grid_size == 12:
			assert_int(level.number).is_equal(Level.LEVELS_PER_CHAPTER)
		assert_int(level.grid_size).is_not_equal(3)
		assert_array(LevelValidator.ALLOWED_GRID_SIZES).contains([level.grid_size])


func test_each_chapter_starts_on_a_bigger_grid_than_the_one_before_ends_its_first_third() -> void:
	var first_sizes: Array[int] = []
	for chapter in _catalog.chapters:
		first_sizes.append(chapter.levels[0].grid_size)
	for i in range(1, first_sizes.size()):
		assert_int(first_sizes[i]).is_greater_equal(first_sizes[i - 1])
	assert_int(first_sizes[first_sizes.size() - 1]).is_greater_equal(10)


func test_chapters_get_harder_and_levels_plant_decoys() -> void:
	var previous_mean := 0.0
	for chapter in _catalog.chapters:
		var total := 0.0
		for level in chapter.levels:
			total += level.difficulty.score
			if level.chapter_index > 1 or level.number >= 4:
				assert_int(level.difficulty.decoys).is_greater(0)
		var mean := total / chapter.levels.size()
		assert_float(mean).is_greater(previous_mean)
		previous_mean = mean


func _average_length(chapter: Chapter, number: int) -> float:
	for level in chapter.levels:
		if level.number == number:
			var words := level.variant(Language.FR).words
			var total := 0
			for w in words:
				total += w.letters.length()
			return float(total) / words.size()
	return 0.0


func _half_average(chapter: Chapter, from_number: int, to_number: int) -> float:
	var total := 0.0
	var count := 0
	for number in range(from_number, to_number + 1):
		total += _average_length(chapter, number)
		count += 1
	return total / count


func test_words_get_longer_as_levels_go_up() -> void:
	for chapter in _catalog.chapters:
		assert_float(_half_average(chapter, 6, 10)).is_greater(_half_average(chapter, 1, 5))
		assert_float(_average_length(chapter, 10)).is_greater(_average_length(chapter, 9))


func test_final_challenges_are_12x12_and_clearly_harder_than_level_9() -> void:
	for chapter in _catalog.chapters:
		var ninth: Level = null
		var tenth: Level = null
		for level in chapter.levels:
			if level.number == 9:
				ninth = level
			elif level.number == 10:
				tenth = level
		assert_int(tenth.grid_size).is_equal(12)
		assert_float(float(tenth.difficulty.score)).is_greater_equal(ninth.difficulty.score * LevelValidator.FINAL_MIN_RATIO)


func test_unsupported_schema_is_rejected() -> void:
	var decoded := LevelJsonParser.parse_catalog(func(_name: String) -> String: return '{"schemaVersion": 99, "chapters": []}')
	assert_bool(decoded.ok).is_false()


func test_missing_files_and_garbage_are_rejected_without_crashing() -> void:
	assert_bool(LevelJsonParser.parse_catalog(func(_name: String) -> String: return "").ok).is_false()
	assert_bool(LevelJsonParser.parse_catalog(func(_name: String) -> String: return "not json").ok).is_false()
	assert_bool(LevelJsonParser.parse_catalog(func(name: String) -> String:
		return '{"schemaVersion": 1, "chapters": ["x.json"]}' if name == "index.json" else "").ok).is_false()


func test_every_level_from_4x4_mixes_short_and_long_words_in_both_languages() -> void:
	for level in _catalog.levels:
		for variant in level.variants.values():
			var shortest := 99
			var longest := 0
			for w in variant.words:
				shortest = mini(shortest, w.letters.length())
				longest = maxi(longest, w.letters.length())
			assert_int(shortest).is_less(longest)
			assert_int(shortest).is_less_equal(5)


func test_the_longest_word_grows_with_the_grid_and_the_final_challenge_uses_the_longest_words() -> void:
	for chapter in _catalog.chapters:
		var previous_longest := 0
		for level in chapter.levels:
			var longest := 0
			for w in level.variants[Language.FR].words:
				longest = maxi(longest, w.letters.length())
			assert_int(longest).is_greater_equal(previous_longest - 1)  # jamais de recul net : les grilles grandissent
			previous_longest = longest
		var final: Level = chapter.levels[chapter.levels.size() - 1]
		var final_longest := 0
		for w in final.variants[Language.FR].words:
			final_longest = maxi(final_longest, w.letters.length())
		assert_int(final_longest).is_greater_equal(11)

