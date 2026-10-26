class_name RotationTest
extends GdUnitTestSuite
## Rotation de la grille au redémarrage : mêmes mots, directions différentes, jamais de mot perdu ni de case hors grille.


func _letters_along(variant: LevelVariant, word: TargetWord) -> String:
	var text := ""
	for cell in word.cells:
		text += variant.letter_at(cell)
	return text


func test_a_quarter_turn_clockwise_sends_east_to_south_and_four_turns_come_back() -> void:
	assert_int(Direction.rotate(Direction.E, 1)).is_equal(Direction.S)
	assert_int(Direction.rotate(Direction.S, 1)).is_equal(Direction.W)
	assert_int(Direction.rotate(Direction.W, 1)).is_equal(Direction.N)
	assert_int(Direction.rotate(Direction.N, 1)).is_equal(Direction.E)
	assert_int(Direction.rotate(Direction.SE, 1)).is_equal(Direction.SW)
	assert_int(Direction.rotate(Direction.E, -1)).is_equal(Direction.N)  # antihoraire
	for direction in Direction.ALL:
		assert_int(Direction.rotate(direction, 4)).is_equal(direction)
		assert_int(Direction.rotate(Direction.rotate(direction, 1), -1)).is_equal(direction)


func test_cells_rotate_inside_the_grid() -> void:
	assert_vector(LevelVariant.rotate_cell(Vector2i(0, 0), 3, 1)).is_equal(Vector2i(2, 0))  # coin haut-gauche -> haut-droite
	assert_vector(LevelVariant.rotate_cell(Vector2i(2, 0), 3, 1)).is_equal(Vector2i(2, 2))
	assert_vector(LevelVariant.rotate_cell(Vector2i(1, 1), 3, 1)).is_equal(Vector2i(1, 1))  # le centre ne bouge pas
	assert_vector(LevelVariant.rotate_cell(Vector2i(0, 0), 3, -1)).is_equal(Vector2i(0, 2))
	for x in range(4):
		for y in range(4):
			var cell := Vector2i(x, y)
			assert_vector(LevelVariant.rotate_cell(cell, 4, 4)).is_equal(cell)
			assert_vector(LevelVariant.rotate_cell(LevelVariant.rotate_cell(cell, 4, 1), 4, -1)).is_equal(cell)


func test_the_rotated_grid_has_the_same_letters_and_four_turns_give_the_original() -> void:
	var original := Fixtures.en_variant_4()
	var turned := original.rotated(1)
	assert_array(Array(turned.grid)).is_not_equal(Array(original.grid))
	var a: Array = []
	var b: Array = []
	for row in original.grid:
		a.append_array(row.split(""))
	for row in turned.grid:
		b.append_array(row.split(""))
	a.sort()
	b.sort()
	assert_int(a.size()).is_equal(16)
	assert_array(b).is_equal(a)  # exactement les mêmes lettres
	assert_array(Array(original.rotated(4).grid)).is_equal(Array(original.grid))
	assert_array(Array(original.rotated(1).rotated(3).grid)).is_equal(Array(original.grid))
	assert_array(Array(original.rotated(-1).grid)).is_equal(Array(original.rotated(3).grid))


func test_every_word_reads_the_same_along_its_rotated_cells() -> void:
	for turns in [1, 2, 3, -1]:
		var rotated := Fixtures.en_variant_4().rotated(turns)
		for word in rotated.words:
			assert_str(_letters_along(rotated, word)).is_equal(word.letters)


func test_a_horizontal_word_becomes_vertical_after_a_quarter_turn() -> void:
	var rotated := Fixtures.en_variant_4().rotated(1)
	assert_int(rotated.words[0].direction).is_equal(Direction.S)  # SAND : E -> S (tour à droite)
	assert_int(Fixtures.en_variant_4().rotated(-1).words[0].direction).is_equal(Direction.N)  # tour à gauche


func test_a_non_square_grid_is_left_alone() -> void:
	var flat := LevelVariant.new(Language.EN, PackedStringArray(["ABC", "DEF"]), Fixtures.words([TargetWord.new("ABC", "ABC", Vector2i(0, 0), Direction.E)]))
	assert_bool(flat.is_square()).is_false()
	assert_bool(flat.rotated(1) == flat).is_true()


func test_the_level_caches_its_rotated_variants() -> void:
	var level := Fixtures.level_4x4()
	assert_bool(level.oriented_variant(Language.EN, 0) == level.variant(Language.EN)).is_true()
	var first := level.oriented_variant(Language.EN, 1)
	assert_bool(level.oriented_variant(Language.EN, 1) == first).is_true()
	assert_bool(level.oriented_variant(Language.EN, 5) == first).is_true()  # 5 tours = 1 tour
	assert_bool(level.oriented_variant(Language.FR, 1) == first).is_false()


func test_the_shipped_levels_stay_valid_after_any_rotation() -> void:
	var catalog := AssetLevelRepository.new().load_catalog()
	var checked := 0
	for level in catalog.levels:
		for language in [Language.EN, Language.FR]:
			for turns in [1, 2, 3]:
				var rotated := level.oriented_variant(language, turns)
				for word in rotated.words:
					for cell in word.cells:
						assert_bool(rotated.in_bounds(cell)).is_true()
					assert_str(_letters_along(rotated, word)).is_equal(word.letters)
				checked += 1
	assert_int(checked).is_equal(100 * 2 * 3)


func test_session_restart_rotates_clears_progress_and_stays_solvable() -> void:
	var clock := Fixtures.FakeClock.new()
	var session := GameSession.new(Fixtures.level_4x4(), Language.EN, clock.callable())
	session.submit(Fixtures.cells([Fixtures.cell(0, 0), Fixtures.cell(0, 1), Fixtures.cell(0, 2), Fixtures.cell(0, 3)]))
	assert_int(session.state.found_word_indices.size()).is_equal(1)
	session.restart(1)
	assert_int(session.state.orientation).is_equal(1)
	assert_array(session.state.found_word_indices).is_empty()
	for word in session.state.variant().words:
		assert_int(session.submit(word.cells).kind).is_equal(SessionEvent.Kind.FOUND)
	assert_bool(session.is_solved()).is_true()
	session.restart(-1)  # une seconde fois dans l'autre sens : retour à l'orientation d'origine
	assert_int(session.state.orientation).is_equal(0)


func test_hints_point_at_the_start_of_the_word_on_the_rotated_grid() -> void:
	var clock := Fixtures.FakeClock.new()
	var session := GameSession.new(Fixtures.level_4x4(), Language.EN, clock.callable())
	session.restart(1)
	var words := session.state.variant().words
	var hint := RevealedHint.new(0, words[0].start)
	assert_str(session.state.variant().letter_at(hint.cell)).is_equal(words[0].letters[0])


func test_the_orientation_survives_an_interruption_and_a_reload() -> void:
	var clock := Fixtures.FakeClock.new()
	var session := GameSession.new(Fixtures.level_4x4(), Language.EN, clock.callable())
	session.restart(-1)
	var word := session.state.variant().words[0]
	session.submit(word.cells)
	var snapshot := session.snapshot()
	assert_int(snapshot.orientation).is_equal(3)
	var state := ProgressState.new()
	var key := ProgressRules.snapshot_key("c1-l01", Language.EN)
	state.in_progress[key] = snapshot
	var back := ProgressJson.decode(ProgressJson.encode(state)).value as ProgressState
	var restored_snapshot: GameSnapshot = back.in_progress[key]
	assert_int(restored_snapshot.orientation).is_equal(3)
	var resumed := GameSession.new(Fixtures.level_4x4(), Language.EN, clock.callable())
	resumed.restore(restored_snapshot)
	assert_int(resumed.state.orientation).is_equal(3)
	assert_array(resumed.state.found_word_indices).contains_exactly([0])
	assert_array(resumed.state.found_cells()).contains_exactly_in_any_order(word.cells)


func test_an_old_save_without_orientation_loads_unrotated() -> void:
	var key := ProgressRules.snapshot_key("c1-l01", Language.EN)
	var legacy := '{"schemaVersion": %d, "inProgress": {"%s": {"found": [0], "hinted": [], "wrong": 1, "elapsedMillis": 5000}}}' % [ProgressState.CURRENT_SCHEMA, key]
	var decoded := ProgressJson.decode(legacy)
	var back := decoded.value as ProgressState
	var snapshot: GameSnapshot = back.in_progress[key]
	assert_int(snapshot.orientation).is_equal(0)
	assert_array(snapshot.found_word_indices).contains_exactly([0])
