class_name GameEngineTest
extends GdUnitTestSuite

var _start: GameState


func before_test() -> void:
	_start = GameEngine.new_game(Fixtures.level(), Language.EN)


func test_selecting_a_target_word_finds_it() -> void:
	var r := GameEngine.select(_start, Fixtures.sun())
	assert_int(r.kind).is_equal(SelectionResult.Kind.FOUND)
	assert_array(r.state.found_word_indices).contains_exactly([0])
	assert_bool(r.state.is_solved()).is_false()


func test_reverse_drag_also_finds_the_word() -> void:
	var reversed := Fixtures.sun()
	reversed.reverse()
	assert_int(GameEngine.select(_start, reversed).kind).is_equal(SelectionResult.Kind.FOUND)


func test_partial_selection_is_wrong_and_counted() -> void:
	var partial := Fixtures.sun().slice(0, 2)
	var r := GameEngine.select(_start, Fixtures.cells(partial))
	assert_int(r.kind).is_equal(SelectionResult.Kind.WRONG)
	assert_int(r.state.wrong_selections).is_equal(1)
	assert_array(r.state.found_word_indices).is_empty()


func test_non_straight_path_is_wrong() -> void:
	var r := GameEngine.select(_start, Fixtures.cells([Fixtures.cell(0, 0), Fixtures.cell(0, 1), Fixtures.cell(1, 1)]))
	assert_int(r.kind).is_equal(SelectionResult.Kind.WRONG)


func test_out_of_bounds_path_is_wrong() -> void:
	var r := GameEngine.select(_start, Fixtures.cells([Fixtures.cell(0, 2), Fixtures.cell(0, 3)]))
	assert_int(r.kind).is_equal(SelectionResult.Kind.WRONG)


func test_single_tap_is_ignored_and_not_an_error() -> void:
	var r := GameEngine.select(_start, Fixtures.cells([Fixtures.cell(1, 1)]))
	assert_int(r.kind).is_equal(SelectionResult.Kind.IGNORED)
	assert_int(r.state.wrong_selections).is_equal(0)


func test_already_found_word_does_not_count_as_error() -> void:
	var once := GameEngine.select(_start, Fixtures.sun()).state
	var again := GameEngine.select(once, Fixtures.sun())
	assert_int(again.kind).is_equal(SelectionResult.Kind.ALREADY_FOUND)
	assert_int(again.state.wrong_selections).is_equal(0)


func test_level_is_solved_only_when_every_word_is_found() -> void:
	var s1 := GameEngine.select(_start, Fixtures.sun()).state
	assert_bool(s1.is_solved()).is_false()
	var s2 := GameEngine.select(s1, Fixtures.sky()).state
	assert_bool(s2.is_solved()).is_true()


func test_french_variant_uses_its_own_grid() -> void:
	var fr := GameEngine.new_game(Fixtures.level(), Language.FR)
	var r := GameEngine.select(fr, Fixtures.cells([Fixtures.cell(2, 0), Fixtures.cell(2, 1), Fixtures.cell(2, 2)]))
	assert_int(r.kind).is_equal(SelectionResult.Kind.FOUND)
	assert_int(r.word_index).is_equal(1)


func test_states_are_immutable_between_transitions() -> void:
	var r := GameEngine.select(_start, Fixtures.sun())
	assert_array(_start.found_word_indices).is_empty()
	assert_array(r.state.found_word_indices).has_size(1)


func test_snap_path_follows_the_eight_directions_and_stays_inside() -> void:
	var horizontal := GridGeometry.snap_path(Vector2i(0, 0), Vector2i(3, 0), 4)
	assert_array(horizontal).contains_exactly([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	var diagonal := GridGeometry.snap_path(Vector2i(0, 0), Vector2i(2, 3), 4)
	assert_array(diagonal).contains_exactly([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)])
	assert_array(GridGeometry.snap_path(Vector2i(1, 1), Vector2i(1, 1), 4)).contains_exactly([Vector2i(1, 1)])
	assert_object(GridGeometry.cell_at(-50.0, 999.0, 40.0, 5)).is_equal(Vector2i(0, 4))
