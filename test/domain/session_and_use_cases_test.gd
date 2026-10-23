class_name SessionAndUseCasesTest
extends GdUnitTestSuite

var _catalog: LevelCatalog
var _level: Level
var _low := func(from: int, _until: int) -> int: return from
var _high := func(_from: int, until: int) -> int: return until - 1


func before_test() -> void:
	_catalog = Fixtures.stub_catalog()
	_level = _catalog.levels[0]


func _session(clock: Fixtures.FakeClock = null) -> GameSession:
	var c := clock if clock != null else Fixtures.FakeClock.new()
	return GameSession.new(_level, Language.EN, c.callable())


func _progress_with(hint_balance: int = 0) -> MemoryFakes.MemoryProgress:
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state.hint_balance = hint_balance
	return repo


func _use_cases(repo: ProgressRepository, ads: AdProvider, random: Callable) -> GameUseCases:
	return GameUseCases.new(_catalog, repo, ads, random)


func _first_n(path: Array[Vector2i], n: int) -> Array[Vector2i]:
	return Fixtures.cells(path.slice(0, n))


# ---- GameSession
func test_timer_starts_at_first_interaction_not_at_creation() -> void:
	var clock := Fixtures.FakeClock.new()
	clock.now = 0
	var s := _session(clock)
	clock.now += 5_000
	assert_int(s.elapsed_millis()).is_equal(0)
	s.submit(_first_n(Fixtures.sun(), 2))
	clock.now += 2_000
	assert_int(s.elapsed_millis()).is_equal(2_000)


func test_solving_all_words_marks_the_session_solved_and_wrong_tries_are_counted() -> void:
	var s := _session()
	assert_int(s.submit(_first_n(Fixtures.sun(), 2)).kind).is_equal(SessionEvent.Kind.WRONG)
	var first := s.submit(Fixtures.sun())
	assert_int(first.kind).is_equal(SessionEvent.Kind.FOUND)
	assert_int(first.word_index).is_equal(0)
	assert_bool(first.solved).is_false()
	var second := s.submit(Fixtures.sky())
	assert_int(second.word_index).is_equal(1)
	assert_bool(second.solved).is_true()
	assert_bool(s.is_solved()).is_true()
	assert_int(s.state.wrong_selections).is_equal(1)
	assert_int(s.submit(Fixtures.sun()).kind).is_equal(SessionEvent.Kind.IGNORED)


func test_snapshot_and_restore_keep_words_hints_and_elapsed_time() -> void:
	var clock := Fixtures.FakeClock.new()
	var a := _session(clock)
	a.submit(Fixtures.sun())
	clock.now += 4_000
	a.pause()
	var snap := a.snapshot()
	var b := _session(clock)
	b.restore(snap)
	assert_array(b.state.found_word_indices).contains_exactly([0])
	assert_int(b.elapsed_millis()).is_equal(4_000)
	assert_bool(b.is_running()).is_false()
	b.resume()
	clock.now += 1_000
	assert_int(b.elapsed_millis()).is_equal(5_000)


func test_restore_ignores_invalid_indices() -> void:
	var s := _session()
	s.restore(GameSnapshot.new([0, 99] as Array[int], [1, 77] as Array[int], -3, 10))
	assert_array(s.state.found_word_indices).contains_exactly([0])
	assert_int(s.state.hints_used()).is_equal(1)
	assert_int(s.state.wrong_selections).is_equal(0)


func test_restart_resets_grid_and_timer() -> void:
	var clock := Fixtures.FakeClock.new()
	var s := _session(clock)
	s.submit(Fixtures.sun())
	clock.now += 3_000
	s.restart()
	assert_array(s.state.found_word_indices).is_empty()
	assert_bool(s.has_started()).is_false()
	assert_int(s.elapsed_millis()).is_equal(0)


# ---- GridGeometry
func test_cell_at_clamps_to_the_board() -> void:
	assert_object(GridGeometry.cell_at(250.0, 130.0, 100.0, 3)).is_equal(Fixtures.cell(1, 2))
	assert_object(GridGeometry.cell_at(-40.0, -5.0, 100.0, 3)).is_equal(Fixtures.cell(0, 0))
	assert_object(GridGeometry.cell_at(900.0, 900.0, 100.0, 3)).is_equal(Fixtures.cell(2, 2))


func test_snap_path_aligns_on_horizontal_vertical_and_diagonal() -> void:
	assert_array(GridGeometry.snap_path(Fixtures.cell(0, 0), Fixtures.cell(0, 0), 5)).contains_exactly([Fixtures.cell(0, 0)])
	assert_array(GridGeometry.snap_path(Fixtures.cell(2, 0), Fixtures.cell(2, 3), 5)).contains_exactly(
		[Fixtures.cell(2, 0), Fixtures.cell(2, 1), Fixtures.cell(2, 2), Fixtures.cell(2, 3)])
	assert_array(GridGeometry.snap_path(Fixtures.cell(0, 4), Fixtures.cell(3, 4), 5)).contains_exactly(
		[Fixtures.cell(0, 4), Fixtures.cell(1, 4), Fixtures.cell(2, 4), Fixtures.cell(3, 4)])
	assert_array(GridGeometry.snap_path(Fixtures.cell(0, 0), Fixtures.cell(2, 2), 5)).contains_exactly(
		[Fixtures.cell(0, 0), Fixtures.cell(1, 1), Fixtures.cell(2, 2)])
	assert_array(GridGeometry.snap_path(Fixtures.cell(3, 3), Fixtures.cell(1, 1), 5)).contains_exactly(
		[Fixtures.cell(3, 3), Fixtures.cell(2, 2), Fixtures.cell(1, 1)])
	# presque horizontal -> horizontal
	assert_array(GridGeometry.snap_path(Fixtures.cell(0, 0), Fixtures.cell(1, 3), 5)).contains_exactly(
		[Fixtures.cell(0, 0), Fixtures.cell(0, 1), Fixtures.cell(0, 2), Fixtures.cell(0, 3)])


func test_snap_path_never_leaves_the_grid() -> void:
	for c in GridGeometry.snap_path(Fixtures.cell(3, 3), Fixtures.cell(4, 4), 5):
		assert_bool(c.x >= 0 and c.x <= 4 and c.y >= 0 and c.y <= 4).is_true()
	assert_int(GridGeometry.snap_path(Fixtures.cell(4, 4), Fixtures.cell(4, 4), 5).size()).is_equal(1)


func test_time_and_band_formatting() -> void:
	assert_str(TimeFormat.mmss(0)).is_equal("0:00")
	assert_str(TimeFormat.mmss(83_999)).is_equal("1:23")
	assert_str(TimeFormat.mmss(600_000)).is_equal("10:00")
	assert_str(TimeFormat.mmss(-5)).is_equal("0:00")
	assert_int(DifficultyBand.of(3)).is_equal(DifficultyBand.EASY)
	assert_int(DifficultyBand.of(4)).is_equal(DifficultyBand.MEDIUM)
	assert_int(DifficultyBand.of(9)).is_equal(DifficultyBand.HARD)
	assert_int(DifficultyBand.of(10)).is_equal(DifficultyBand.FINAL)


func test_settings_follow_the_system_language_until_chosen() -> void:
	assert_int(AppSettings.new().resolve_language("fr")).is_equal(Language.FR)
	assert_int(AppSettings.new().resolve_language("de")).is_equal(Language.EN)
	var chosen := AppSettings.new()
	chosen.language = Language.EN
	assert_int(chosen.resolve_language("fr")).is_equal(Language.EN)


# ---- Home / Monument
func test_monument_shows_statuses_stars_and_gift_state() -> void:
	var done := ProgressRules.complete_level(ProgressState.new(), "c1-l01", 2, 200_000, Praise.NONE)
	var chapters := MonumentBuilder.build(_catalog, done)
	var first := chapters[0].levels
	assert_int(first[0].status).is_equal(LevelStatus.COMPLETED)
	assert_int(first[0].stars).is_equal(2)
	assert_int(first[1].status).is_equal(LevelStatus.AVAILABLE)
	assert_int(first[2].status).is_equal(LevelStatus.LOCKED)
	assert_bool(first[first.size() - 1].is_final).is_true()
	assert_int(chapters[0].completed_count).is_equal(1)
	assert_bool(chapters[0].gift_claimable).is_false()


func test_home_highlights_the_claimable_gift_before_the_current_chapter() -> void:
	var all1 := ProgressState.new()
	all1.hint_balance = 2
	for n in range(1, 11):
		all1 = ProgressRules.complete_level(all1, "c1-l%02d" % n, 3, 1, Praise.NONE)
	var home := HomeModelBuilder.build(_catalog, all1, Language.EN)
	assert_str(home.current_level.id).is_equal("c2-l01")
	assert_bool(home.gift_claimable).is_true()
	assert_int(home.gift_chapter.index).is_equal(1)
	assert_int(home.hint_balance).is_equal(2)
	assert_int(home.start_page).is_equal(1)
	var everything := all1
	for n in range(1, 11):
		everything = ProgressRules.complete_level(everything, "c2-l%02d" % n, 3, 1, Praise.NONE)
	assert_bool(HomeModelBuilder.build(_catalog, everything, Language.EN).all_completed).is_true()


# ---- GameUseCases
func test_complete_level_gives_stars_from_time_persists_and_is_idempotent() -> void:
	var clock := Fixtures.FakeClock.new()
	var repo := _progress_with()
	var uc := _use_cases(repo, MemoryFakes.FakeAds.new(), _low)
	var s := _session(clock)
	s.submit(Fixtures.sun())
	clock.now += 40_000
	s.submit(Fixtures.sky())
	var r := uc.complete_level(s)
	assert_int(r.stars).is_equal(3)
	assert_str(r.next_level_id).is_equal("c1-l02")
	assert_int(r.chapter_completed_before).is_equal(0)
	assert_int(r.chapter_completed_after).is_equal(1)
	assert_int(r.chapter_total).is_equal(10)
	assert_bool(repo.state.completed.has("c1-l01")).is_true()
	var again := uc.complete_level(s)
	assert_int(again.stars).is_equal(r.stars)
	assert_int(repo.state.completed.size()).is_equal(1)


func test_a_victory_between_one_and_three_minutes_gets_two_stars() -> void:
	var clock := Fixtures.FakeClock.new()
	var uc := _use_cases(_progress_with(), MemoryFakes.FakeAds.new(), _low)
	var s := _session(clock)
	s.submit(Fixtures.sun())
	clock.now += 100_000
	s.submit(Fixtures.sky())
	assert_int(uc.complete_level(s).stars).is_equal(2)


func test_slow_victory_gets_one_star_and_clears_the_saved_game() -> void:
	var clock := Fixtures.FakeClock.new()
	var repo := _progress_with()
	var uc := _use_cases(repo, MemoryFakes.FakeAds.new(), _low)
	var s := _session(clock)
	s.submit(Fixtures.sun())
	uc.save_snapshot(s)
	assert_int(repo.state.in_progress.size()).is_equal(1)
	clock.now += 180_000
	s.submit(Fixtures.sky())
	assert_int(uc.complete_level(s).stars).is_equal(1)
	assert_int(repo.state.in_progress.size()).is_equal(0)


func test_complete_level_refuses_an_unsolved_session() -> void:
	var uc := _use_cases(_progress_with(), MemoryFakes.FakeAds.new(), _low)
	assert_object(uc.complete_level(_session())).is_null()


func test_victory_is_still_reported_when_the_save_fails() -> void:
	var clock := Fixtures.FakeClock.new()
	var repo := _progress_with()
	repo.fail_writes = true
	var uc := _use_cases(repo, MemoryFakes.FakeAds.new(), _low)
	var s := _session(clock)
	s.submit(Fixtures.sun())
	s.submit(Fixtures.sky())
	var r := uc.complete_level(s)
	assert_object(r).is_not_null()
	assert_int(r.stars).is_equal(3)
	assert_int(repo.state.completed.size()).is_equal(0)


func test_hint_costs_one_only_when_revealed() -> void:
	var repo := _progress_with(2)
	var uc := _use_cases(repo, MemoryFakes.FakeAds.new(), _low)
	var s := _session()
	var r := uc.use_hint(s)
	assert_int(r.kind).is_equal(HintUseResult.Kind.USED)
	assert_int(r.new_balance).is_equal(1)
	assert_int(repo.state.hint_balance).is_equal(1)
	assert_int(s.state.hints_used()).is_equal(1)


func test_no_balance_means_no_hint_no_deduction_no_reveal() -> void:
	var repo := _progress_with(0)
	var s := _session()
	assert_int(_use_cases(repo, MemoryFakes.FakeAds.new(), _low).use_hint(s).kind).is_equal(HintUseResult.Kind.NO_BALANCE)
	assert_int(s.state.hints_used()).is_equal(0)


func test_failed_save_neither_deducts_nor_reveals() -> void:
	var repo := _progress_with(2)
	repo.fail_writes = true
	var s := _session()
	assert_int(_use_cases(repo, MemoryFakes.FakeAds.new(), _low).use_hint(s).kind).is_equal(HintUseResult.Kind.FAILED)
	assert_int(repo.state.hint_balance).is_equal(2)
	assert_int(s.state.hints_used()).is_equal(0)


func test_gift_is_granted_once() -> void:
	var done := ProgressState.new()
	for n in range(1, 11):
		done = ProgressRules.complete_level(done, "c1-l%02d" % n, 3, 1, Praise.NONE)
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state = done
	var uc := _use_cases(repo, MemoryFakes.FakeAds.new(), _high)
	assert_int(uc.claim_gift(1)).is_equal(3)
	assert_int(uc.claim_gift(1)).is_equal(0)
	assert_int(repo.state.hint_balance).is_equal(3)
	assert_int(uc.claim_gift(2)).is_equal(0)


func test_gift_is_not_granted_when_the_save_fails() -> void:
	var done := ProgressState.new()
	for n in range(1, 11):
		done = ProgressRules.complete_level(done, "c1-l%02d" % n, 3, 1, Praise.NONE)
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state = done
	repo.fail_writes = true
	assert_int(_use_cases(repo, MemoryFakes.FakeAds.new(), _high).claim_gift(1)).is_equal(0)
	assert_int(repo.state.hint_balance).is_equal(0)


func test_rewarded_ad_grants_one_hint_after_confirmation_and_never_twice() -> void:
	var repo := _progress_with()
	var ads := MemoryFakes.FakeAds.new()
	ads.rewarded = RewardedAdResult.rewarded("show-1")
	var uc := _use_cases(repo, ads, _high)
	var first: RewardOutcome = await uc.watch_rewarded_ad()
	assert_int(first.kind).is_equal(RewardOutcome.Kind.GRANTED)
	assert_int(first.amount).is_equal(1)
	var second: RewardOutcome = await uc.watch_rewarded_ad()
	assert_int(second.kind).is_equal(RewardOutcome.Kind.DUPLICATE)
	assert_int(repo.state.hint_balance).is_equal(1)


func test_unavailable_dismissed_or_failed_ads_change_nothing() -> void:
	var repo := _progress_with(0)
	var ads := MemoryFakes.FakeAds.new()
	ads.reason = UnavailableReason.OFFLINE
	var uc := _use_cases(repo, ads, _high)
	var offline: RewardOutcome = await uc.watch_rewarded_ad()
	assert_int(offline.kind).is_equal(RewardOutcome.Kind.UNAVAILABLE)
	assert_int(offline.reason).is_equal(UnavailableReason.OFFLINE)
	ads.reason = UnavailableReason.NONE
	ads.rewarded = RewardedAdResult.dismissed()
	var dismissed: RewardOutcome = await uc.watch_rewarded_ad()
	assert_int(dismissed.kind).is_equal(RewardOutcome.Kind.DISMISSED)
	ads.rewarded = RewardedAdResult.unavailable(UnavailableReason.NO_FILL)
	var no_fill: RewardOutcome = await uc.watch_rewarded_ad()
	assert_int(no_fill.reason).is_equal(UnavailableReason.NO_FILL)
	assert_int(repo.state.hint_balance).is_equal(0)


func test_timer_restore_is_paused_until_resume() -> void:
	var clock := Fixtures.FakeClock.new()
	var t := GameTimer.new(clock.callable())
	t.restore_elapsed(7_000)
	clock.now += 50_000
	assert_int(t.elapsed_millis()).is_equal(7_000)
	t.resume()
	clock.now += 1_000
	assert_int(t.elapsed_millis()).is_equal(8_000)
