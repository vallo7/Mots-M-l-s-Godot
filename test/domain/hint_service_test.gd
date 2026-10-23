class_name HintServiceTest
extends GdUnitTestSuite

var _game: GameState


func before_test() -> void:
	_game = GameEngine.new_game(Fixtures.level({"max_hints": 2}), Language.EN)


func test_hint_reveals_first_cell_of_first_unfound_word_and_costs_one() -> void:
	var r := HintService.use_hint(_game, 2)
	assert_int(r.kind).is_equal(HintOutcome.Kind.REVEALED)
	assert_int(r.hint.word_index).is_equal(0)
	assert_object(r.hint.cell).is_equal(Fixtures.cell(0, 0))
	assert_int(r.new_balance).is_equal(1)
	assert_int(r.state.hints_used()).is_equal(1)


func test_no_balance_means_no_hint_and_no_state_change() -> void:
	assert_int(HintService.use_hint(_game, 0).kind).is_equal(HintOutcome.Kind.NO_BALANCE)


func test_already_hinted_words_are_skipped_then_limit_is_reached() -> void:
	var first := HintService.use_hint(_game, 3)
	var second := HintService.use_hint(first.state, first.new_balance)
	assert_int(second.hint.word_index).is_equal(1)
	assert_int(HintService.use_hint(second.state, second.new_balance).kind).is_equal(HintOutcome.Kind.LIMIT_REACHED)


func test_found_words_are_never_hinted() -> void:
	var found := GameEngine.select(_game, Fixtures.sun()).state
	var r := HintService.use_hint(found, 1)
	assert_int(r.hint.word_index).is_equal(1)


func test_nothing_to_reveal_when_solved_or_all_remaining_words_are_already_hinted() -> void:
	var solved := GameEngine.select(GameEngine.select(_game, Fixtures.sun()).state, Fixtures.sky()).state
	assert_int(HintService.use_hint(solved, 5).kind).is_equal(HintOutcome.Kind.NOTHING_TO_REVEAL)
	var roomy := GameEngine.new_game(Fixtures.level({"max_hints": 5}), Language.EN)
	var a := HintService.use_hint(roomy, 5)
	var b := HintService.use_hint(a.state, a.new_balance)
	assert_int(HintService.use_hint(b.state, b.new_balance).kind).is_equal(HintOutcome.Kind.NOTHING_TO_REVEAL)


func test_limit_per_level_is_enforced_before_balance() -> void:
	var capped := GameEngine.new_game(Fixtures.level({"max_hints": 1}), Language.EN)
	var a := HintService.use_hint(capped, 5)
	assert_int(HintService.use_hint(a.state, a.new_balance).kind).is_equal(HintOutcome.Kind.LIMIT_REACHED)
