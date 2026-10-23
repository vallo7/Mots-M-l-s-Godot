class_name LevelValidatorTest
extends GdUnitTestSuite


func _codes(level: Level) -> Array[String]:
	var result: Array[String] = []
	for issue in LevelValidator.validate_level(level):
		result.append(issue.code)
	return result


func _with_en(variant: LevelVariant) -> Dictionary:
	return {Language.EN: variant, Language.FR: Fixtures.fr_variant()}


func test_reference_level_is_valid() -> void:
	var messages: Array[String] = []
	for issue in LevelValidator.validate_level(Fixtures.level_4x4()):
		messages.append(str(issue))
	assert_array(messages).is_empty()


func test_normalizer_strips_accents_and_non_letters() -> void:
	assert_str(TextNormalizer.to_grid_letters("Île")).is_equal("ILE")
	assert_str(TextNormalizer.to_grid_letters("été")).is_equal("ETE")
	assert_str(TextNormalizer.to_grid_letters("arc-en-ciel")).is_equal("ARCENCIEL")
	assert_str(TextNormalizer.to_grid_letters("Çà et là")).is_equal("CAETLA")


func test_grid_mismatch_is_detected() -> void:
	var bad := LevelVariant.new(Language.EN, PackedStringArray(["SXN", "KQZ", "YWV"]), Fixtures.en_variant().words)
	assert_array(_codes(Fixtures.level({"variants": _with_en(bad)}))).contains(["GRID_MISMATCH"])


func test_word_leaving_the_grid_is_detected() -> void:
	var words := Fixtures.words([
		TargetWord.new("SUN", "SUN", Fixtures.cell(0, 1), Direction.E), Fixtures.en_variant().words[1]])
	var bad := LevelVariant.new(Language.EN, Fixtures.en_variant().grid, words)
	assert_array(_codes(Fixtures.level({"variants": _with_en(bad)}))).contains(["OUT_OF_BOUNDS"])


func test_direction_forbidden_by_tier_is_detected() -> void:
	var words := Fixtures.words([
		TargetWord.new("SUN", "SUN", Fixtures.cell(0, 2), Direction.W),
		TargetWord.new("SKY", "SKY", Fixtures.cell(0, 0), Direction.S)])
	var reversed := LevelVariant.new(Language.EN, PackedStringArray(["NUS", "KQZ", "YWV"]), words)
	assert_array(_codes(Fixtures.level({"variants": _with_en(reversed)}))).contains(["DIRECTION"])


func test_word_appearing_twice_is_ambiguous() -> void:
	var words := Fixtures.words([
		TargetWord.new("SUN", "SUN", Fixtures.cell(0, 0), Direction.E),
		TargetWord.new("SK", "SK", Fixtures.cell(0, 0), Direction.S)])
	var twice := LevelVariant.new(Language.EN, PackedStringArray(["SUN", "KQZ", "SUN"]), words)
	assert_array(_codes(Fixtures.level({"variants": _with_en(twice)}))).contains(["AMBIGUOUS_WORD"])


func test_word_contained_in_another_is_detected() -> void:
	var words := Fixtures.words([
		TargetWord.new("SUNS", "SUNS", Fixtures.cell(0, 0), Direction.E),
		TargetWord.new("UN", "UN", Fixtures.cell(0, 1), Direction.E)])
	var v := LevelVariant.new(Language.EN, PackedStringArray(["SUNS", "KQZW", "YWVX", "ABCD"]), words)
	var level := Fixtures.level({"grid_size": 4, "number": 3, "variants": _with_en(v)})
	assert_array(_codes(level)).contains(["WORD_CONTAINED"])


func test_3x3_grid_is_no_longer_allowed_anywhere() -> void:
	assert_array(_codes(Fixtures.level({"id": "c1-l01", "chapter": 1, "number": 1}))).contains(["GRID_SIZE"])
	assert_array(_codes(Fixtures.level({"id": "c2-l01", "chapter": 2, "number": 1}))).contains(["GRID_SIZE"])


func test_4x4_and_5x5_grids_are_refused_outside_chapter_1() -> void:
	assert_array(_codes(Fixtures.level_4x4({"id": "c2-l02", "chapter": 2, "number": 2}))).contains(["GRID_SMALL"])
	assert_array(_codes(Fixtures.level({"id": "c3-l02", "chapter": 3, "number": 2, "grid_size": 5}))).contains(["GRID_SMALL"])
	assert_array(_codes(Fixtures.level_4x4({"id": "c1-l03", "chapter": 1, "number": 3}))).not_contains(["GRID_SMALL"])
	assert_array(_codes(Fixtures.level({"id": "c1-l03", "chapter": 1, "number": 3, "grid_size": 5}))).not_contains(["GRID_SMALL"])


func test_12x12_is_reserved_to_the_final_challenge_and_the_size_ladder_runs_from_4_to_12() -> void:
	assert_array(_codes(Fixtures.level({"id": "c2-l05", "chapter": 2, "number": 5, "grid_size": 12}))).contains(["GRID_12X12"])
	assert_array(_codes(Fixtures.level({"id": "c2-l05", "chapter": 2, "number": 5, "grid_size": 3}))).contains(["GRID_SIZE"])
	assert_array(LevelValidator.ALLOWED_GRID_SIZES).contains_exactly([4, 5, 6, 7, 8, 9, 10, 11, 12])


func test_final_challenge_must_be_12x12() -> void:
	assert_array(_codes(Fixtures.level({"id": "c1-l10", "number": 10, "grid_size": 10}))).contains(["FINAL_SIZE"])


func test_wrong_score_and_wrong_style_are_detected() -> void:
	assert_array(_codes(Fixtures.level({"score": 999}))).contains(["SCORE"])
	assert_array(_codes(Fixtures.level({"style": VisualStyle.STYLE_3}))).contains(["STYLE_RULE"])


func test_missing_language_variant_is_detected() -> void:
	assert_array(_codes(Fixtures.level({"variants": {Language.EN: Fixtures.en_variant()}}))).contains(["VARIANT_MISSING"])


func test_final_level_must_be_12x12_with_final_style() -> void:
	assert_array(_codes(Fixtures.level({"id": "c1-l10", "number": 10}))).contains(["FINAL_SIZE"])
	assert_array(_codes(Fixtures.level({"id": "c1-l10", "number": 10, "style": VisualStyle.STYLE_1}))).contains(["STYLE_FINAL"])
	assert_array(_codes(Fixtures.level({"id": "c1-l02", "number": 2, "style": VisualStyle.FINAL}))).contains(["STYLE_FINAL"])


func test_style_rotation_depends_on_chapter_and_band() -> void:
	assert_int(VisualStyle.for_level(1, 1)).is_equal(VisualStyle.STYLE_1)
	assert_int(VisualStyle.for_level(1, 4)).is_equal(VisualStyle.STYLE_2)
	assert_int(VisualStyle.for_level(1, 9)).is_equal(VisualStyle.STYLE_3)
	assert_int(VisualStyle.for_level(2, 1)).is_equal(VisualStyle.STYLE_2)
	assert_int(VisualStyle.for_level(2, 10)).is_equal(VisualStyle.FINAL)


func test_catalog_checks_ordering_of_difficulty_and_chapter_shape() -> void:
	var codes: Array[String] = []
	for issue in LevelValidator.validate_catalog(Fixtures.stub_catalog(1)):
		codes.append(issue.code)
	assert_array(codes).contains(["DIFFICULTY_ORDER"])  # niveaux factices identiques


func test_length_mix_accepts_a_level_with_short_and_long_words() -> void:
	assert_str(LevelValidator.length_mix_problem(8, 3, [8, 7, 6, 4])).is_empty()
	assert_str(LevelValidator.length_mix_problem(12, 4, [12, 10, 8, 5, 4])).is_empty()
	assert_str(LevelValidator.length_mix_problem(4, 1, [4, 3, 3])).is_empty()


func test_length_mix_rejects_levels_without_a_short_word() -> void:
	assert_str(LevelValidator.length_mix_problem(8, 3, [8, 7, 6, 5])).contains("aucun mot court")


func test_length_mix_rejects_levels_without_a_long_word_and_wants_longer_words_at_higher_tiers() -> void:
	assert_str(LevelValidator.length_mix_problem(8, 3, [5, 4, 4, 3])).contains("aucun mot long")
	assert_str(LevelValidator.length_mix_problem(8, 3, [6, 4, 2])).is_empty()  # palier 3 : 6 lettres suffisent en 8×8
	assert_str(LevelValidator.length_mix_problem(8, 4, [6, 4, 2])).contains("aucun mot long")  # palier 4 : 7 minimum


func test_length_mix_rejects_uniform_lengths() -> void:
	assert_str(LevelValidator.length_mix_problem(10, 3, [8, 7, 6, 5])).contains("trop uniformes")


func test_length_mix_covers_the_new_sizes() -> void:
	assert_str(LevelValidator.length_mix_problem(5, 1, [5, 4, 3])).is_empty()
	assert_str(LevelValidator.length_mix_problem(9, 4, [9, 8, 4])).is_empty()
	assert_str(LevelValidator.length_mix_problem(11, 4, [11, 9, 5, 4])).is_empty()
	assert_str(LevelValidator.length_mix_problem(11, 4, [8, 7, 6, 5])).contains("aucun mot long")


func test_chapters_must_get_harder_from_one_to_the_next() -> void:
	var codes: Array[String] = []
	for issue in LevelValidator.validate_catalog(Fixtures.stub_catalog(2)):
		codes.append(issue.code)
	assert_array(codes).contains(["CHAPTER_ORDER"])  # chapitres factices identiques
