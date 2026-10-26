class_name GameControllerTest
extends GdUnitTestSuite
## Orchestration d'une partie : gestes -> moteur -> sauvegarde, indices, dialogues, victoire.

var _catalog: LevelCatalog
var _repo: MemoryFakes.MemoryProgress
var _controller: GameController
var _events: Dictionary


func before_test() -> void:
	_catalog = Fixtures.stub_catalog()
	_repo = MemoryFakes.MemoryProgress.new()
	_repo.state.hint_balance = 2
	_events = {"found": [], "wrong": 0, "hint": [], "restarted": 0, "turns": 0, "victory": [], "leave": 0, "messages": []}
	_controller = _make_controller()


func _make_controller() -> GameController:
	var use_cases := GameUseCases.new(_catalog, _repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	var c := GameController.new(_catalog.levels[0], Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	c.found.connect(func(i: int) -> void: _events["found"].append(i))
	c.wrong.connect(func() -> void: _events["wrong"] += 1)
	c.hint_revealed.connect(func(cell: Vector2i) -> void: _events["hint"].append(cell))
	c.restarted.connect(func(turns: int) -> void:
		_events["restarted"] += 1
		_events["turns"] = turns)
	c.victory.connect(func(r: VictoryResult) -> void: _events["victory"].append(r))
	c.leave_requested.connect(func() -> void: _events["leave"] += 1)
	c.message_requested.connect(func(key: String, _q: int, _p: bool) -> void: _events["messages"].append(key))
	add_child(c)
	return c


func _trace(path: Array[Vector2i]) -> void:
	_controller.on_selection_start(path[0])
	_controller.on_selection_change(path)
	_controller.on_selection_end()


func after_test() -> void:
	if is_instance_valid(_controller):
		_controller.free()


func test_controller_is_ready_with_the_balance_and_no_progress() -> void:
	assert_bool(_controller.ready_to_play).is_true()
	assert_int(_controller.hint_balance).is_equal(2)
	assert_array(_controller.found_word_indices).is_empty()
	assert_int(_controller.hints_left_on_level).is_equal(3)


func test_a_correct_trace_finds_the_word_and_notifies() -> void:
	_trace(Fixtures.sun())
	assert_array(_controller.found_word_indices).contains_exactly([0])
	assert_array(_events["found"]).contains_exactly([0])
	assert_bool(_controller.solved).is_false()
	assert_array(_controller.selection).is_empty()


func test_a_wrong_trace_notifies_and_changes_nothing() -> void:
	_trace(Fixtures.cells([Fixtures.cell(0, 0), Fixtures.cell(0, 1)]))
	assert_int(_events["wrong"]).is_equal(1)
	assert_array(_controller.found_word_indices).is_empty()


func test_a_single_tap_is_ignored() -> void:
	_controller.on_selection_start(Fixtures.cell(1, 1))
	_controller.on_selection_end()
	assert_int(_events["wrong"]).is_equal(0)
	assert_array(_events["found"]).is_empty()


func test_progress_is_saved_after_each_word_and_restored_by_a_new_controller() -> void:
	_trace(Fixtures.sun())
	assert_int(_repo.state.in_progress.size()).is_equal(1)
	_controller.free()
	_controller = _make_controller()
	assert_array(_controller.found_word_indices).contains_exactly([0])


func test_a_hint_costs_one_and_reveals_the_first_cell() -> void:
	_controller.on_hint_requested()
	assert_int(_controller.hint_balance).is_equal(1)
	assert_array(_events["hint"]).contains_exactly([Fixtures.cell(0, 0)])
	assert_array(_controller.hint_cells).contains_exactly([Fixtures.cell(0, 0)])
	assert_int(_controller.hints_left_on_level).is_equal(2)


func test_without_balance_the_ad_starts_directly_without_any_confirmation_dialog() -> void:
	_repo.state.hint_balance = 0
	_controller.hint_balance = 0
	var launches := [0]
	_controller.ad_launching.connect(func() -> void: launches[0] += 1)
	_controller.on_hint_requested()
	assert_int(launches[0]).is_equal(1)  # animation du bouton immédiate
	assert_int(_controller.dialog).is_equal(GameController.Dialog.NONE)  # aucun popup de confirmation
	await await_millis(int(GameController.AD_LAUNCH_DELAY_SECONDS * 1000.0) + 300)
	assert_int(_controller.hint_balance).is_equal(1)  # la publicité (simulée) a accordé un indice
	assert_array(_events["messages"]).contains(["msg_hints_earned"])


func test_an_unavailable_ad_never_blocks_the_game() -> void:
	_repo.state.hint_balance = 0
	_controller.hint_balance = 0
	var ads := MemoryFakes.FakeAds.new()
	ads.reason = UnavailableReason.OFFLINE
	var use_cases := GameUseCases.new(_catalog, _repo, ads, func(from: int, _until: int) -> int: return from)
	var offline := GameController.new(_catalog.levels[0], Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	var messages: Array[String] = []
	offline.message_requested.connect(func(key: String, _q: int, _p: bool) -> void: messages.append(key))
	add_child(offline)
	offline.on_hint_requested()
	await await_millis(int(GameController.AD_LAUNCH_DELAY_SECONDS * 1000.0) + 300)
	assert_array(messages).contains(["msg_ad_offline"])
	assert_bool(offline.can_interact()).is_true()
	offline.free()


func test_the_hint_limit_per_level_is_explained() -> void:
	_repo.state.hint_balance = 9
	var use_cases := GameUseCases.new(_catalog, _repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	var capped := GameController.new(Fixtures.level({"max_hints": 1}), Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	var messages: Array[String] = []
	capped.message_requested.connect(func(key: String, _q: int, _p: bool) -> void: messages.append(key))
	add_child(capped)
	capped.on_hint_requested()
	capped.on_hint_requested()
	assert_array(messages).contains(["msg_hint_limit"])
	capped.free()


func test_when_every_remaining_word_is_hinted_nothing_is_left_to_reveal() -> void:
	_repo.state.hint_balance = 9
	_controller.on_hint_requested()
	_controller.on_hint_requested()
	_controller.on_hint_requested()
	assert_array(_events["messages"]).contains(["msg_hint_nothing"])


func test_back_before_playing_leaves_and_back_during_play_asks_for_confirmation() -> void:
	_controller.on_back_requested()
	assert_int(_events["leave"]).is_equal(1)
	_trace(Fixtures.sun())
	_controller.on_back_requested()
	assert_int(_controller.dialog).is_equal(GameController.Dialog.CONFIRM_QUIT)
	_controller.confirm_quit()
	assert_int(_events["leave"]).is_equal(2)


func test_interaction_is_blocked_while_a_dialog_is_open() -> void:
	_trace(Fixtures.sun())
	_controller.on_back_requested()
	assert_bool(_controller.can_interact()).is_false()
	_trace(Fixtures.sky())
	assert_array(_controller.found_word_indices).contains_exactly([0])


func test_restart_clears_the_grid_and_the_saved_game_and_is_locked_briefly() -> void:
	_trace(Fixtures.sun())
	_controller.on_restart_requested()
	assert_array(_controller.found_word_indices).is_empty()
	assert_int(_events["restarted"]).is_equal(1)
	assert_int(_repo.state.in_progress.size()).is_equal(0)
	_controller.on_restart_requested()  # double déclenchement immédiat : refusé
	assert_int(_events["restarted"]).is_equal(1)


func test_solving_every_word_ends_in_a_victory_with_stars_and_saved_progress() -> void:
	_trace(Fixtures.sun())
	_trace(Fixtures.sky())
	assert_bool(_controller.solved).is_true()
	await await_millis(700)
	assert_int(_events["victory"].size()).is_equal(1)
	var result: VictoryResult = _events["victory"][0]
	assert_int(result.stars).is_equal(3)
	assert_bool(_repo.state.completed.has("c1-l01")).is_true()
	assert_int(_repo.state.in_progress.size()).is_equal(0)


# ---- Tutoriels
func test_the_first_level_of_chapter_one_asks_for_the_hand_tutorial_until_it_is_solved() -> void:
	assert_bool(_controller.wants_move_tutorial()).is_true()
	assert_array(_controller.remaining_word_indices(2)).contains_exactly([0, 1])
	_trace(Fixtures.sun())
	assert_array(_controller.remaining_word_indices(2)).contains_exactly([1])  # on passe au tracé suivant
	_trace(Fixtures.sky())
	assert_bool(_controller.wants_move_tutorial()).is_false()


func test_other_levels_have_no_hand_tutorial_and_no_hint_intro() -> void:
	var use_cases := GameUseCases.new(_catalog, _repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	var second := GameController.new(_catalog.levels[1], Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	add_child(second)
	assert_bool(second.wants_move_tutorial()).is_false()
	assert_bool(second.begin_hint_intro()).is_false()
	second.free()


func test_arriving_at_level_four_for_the_first_time_offers_one_hint_once() -> void:
	_repo.state.hint_balance = 0
	var use_cases := GameUseCases.new(_catalog, _repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	var fourth := GameController.new(_catalog.levels[3], Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	add_child(fourth)
	assert_bool(fourth.begin_hint_intro()).is_true()
	assert_int(fourth.hint_balance).is_equal(1)
	assert_int(_repo.state.hint_balance).is_equal(1)
	assert_bool(fourth.begin_hint_intro()).is_false()  # une seule fois par partie…
	fourth.free()
	var again := GameController.new(_catalog.levels[3], Language.EN, use_cases, func() -> int: return _repo.read().hint_balance)
	add_child(again)
	assert_bool(again.begin_hint_intro()).is_false()  # …et jamais plus (mémorisé dans la sauvegarde)
	assert_int(_repo.state.hint_balance).is_equal(1)
	again.free()


# ---- Redémarrage : la grille pivote
func test_restart_turns_the_grid_a_quarter_turn_left_or_right_and_the_same_words_are_still_findable() -> void:
	_controller.turn_picker = func() -> int: return 1
	var before := _controller.variant()
	_controller.on_restart_requested()
	assert_int(_events["turns"]).is_equal(1)
	assert_int(_controller.state().orientation).is_equal(1)
	var after := _controller.variant()
	assert_array(Array(after.grid)).is_not_equal(Array(before.grid))
	# Les mêmes mots, dans d'autres directions : on les trace sur la grille tournée.
	for word in after.words:
		_trace(word.cells)
	assert_bool(_controller.state().is_solved()).is_true()


func test_restart_picks_left_or_right_at_random_and_orientations_accumulate() -> void:
	var picks: Array[int] = [1, 1, -1, -1, -1]
	_controller.turn_picker = func() -> int: return picks.pop_front()
	var seen: Array[int] = []
	for i in picks.size():
		_controller._last_restart_at = -1_000_000  # lève le verrou entre deux essais
		_controller.on_restart_requested()
		seen.append(_controller.state().orientation)
	assert_array(seen).contains_exactly([1, 2, 1, 0, 3])


func test_the_default_picker_only_ever_returns_a_left_or_right_turn() -> void:
	var left := 0
	var right := 0
	for i in range(200):
		var turn: int = _controller.turn_picker.call()
		assert_bool(turn == 1 or turn == -1).is_true()
		if turn == 1:
			right += 1
		else:
			left += 1
	assert_int(left).is_greater(40)
	assert_int(right).is_greater(40)
