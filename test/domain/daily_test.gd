class_name DailyTest
extends GdUnitTestSuite
## Défi du jour : calendrier, récompenses, série, modèle d'affichage et fabrique de grilles (déterminisme, validité).

var _catalog: LevelCatalog


func before() -> void:
	_catalog = AssetLevelRepository.new().load_catalog()


# --- Calendrier
func test_day_index_follows_the_local_date_not_utc() -> void:
	var noon_utc := 1_700_000_000.0  # 14 nov. 2023, 22:13 UTC
	var utc_day := DailyChallenge.day_index_at(noon_utc, 0)
	assert_int(DailyChallenge.day_index_at(noon_utc, 120)).is_equal(utc_day + 1)  # UTC+2 : déjà le lendemain
	assert_int(DailyChallenge.day_index_at(noon_utc, -300)).is_equal(utc_day)


func test_seconds_until_midnight_are_between_one_and_a_day() -> void:
	var left := DailyChallenge.seconds_until_next_day(1_700_000_000.0, 0)
	assert_int(left).is_between(1, 86400)
	assert_int(DailyChallenge.seconds_until_next_day(DailyChallenge.day_index_at(0.0, 0) * 86400.0 + 86399.0, 0)).is_equal(1)


func test_date_and_month_helpers() -> void:
	var day := DailyChallenge.day_index_of(2026, 10, 21)
	var date := DailyChallenge.date_of(day)
	assert_int(date["year"]).is_equal(2026)
	assert_int(date["month"]).is_equal(10)
	assert_int(date["day"]).is_equal(21)
	assert_int(date["weekday"]).is_equal(3)  # mercredi
	assert_int(DailyChallenge.days_in_month(2026, 10)).is_equal(31)
	assert_int(DailyChallenge.days_in_month(2028, 2)).is_equal(29)
	assert_int(DailyChallenge.days_in_month(2026, 12)).is_equal(31)


# --- Récompenses et série
func test_first_win_gives_one_hint_and_starts_a_streak() -> void:
	var start := ProgressRules.initialize(ProgressState.new())
	var done := ProgressRules.complete_daily(start, 100, 2, 90_000)
	assert_bool(done.already_done).is_false()
	assert_int(done.base_hints).is_equal(1)
	assert_int(done.star_bonus_hints).is_equal(0)
	assert_int(done.milestone_hints).is_equal(0)
	assert_int(done.streak).is_equal(1)
	assert_int(done.state.hint_balance).is_equal(start.hint_balance + 1)
	assert_bool(done.state.daily_results.has(100)).is_true()
	assert_int((done.state.daily_results[100] as LevelResult).stars).is_equal(2)


func test_three_stars_add_one_hint() -> void:
	var done := ProgressRules.complete_daily(ProgressState.new(), 100, 3, 30_000)
	assert_int(done.total_hints()).is_equal(2)
	assert_int(done.state.hint_balance).is_equal(2)


func test_the_same_day_counts_only_once() -> void:
	var first := ProgressRules.complete_daily(ProgressState.new(), 100, 3, 30_000)
	var again := ProgressRules.complete_daily(first.state, 100, 3, 10_000)
	assert_bool(again.already_done).is_true()
	assert_int(again.total_hints()).is_equal(0)
	assert_int(again.state.hint_balance).is_equal(first.state.hint_balance)
	assert_int((again.state.daily_results[100] as LevelResult).elapsed_millis).is_equal(30_000)


func test_consecutive_days_extend_the_streak_and_a_gap_breaks_it() -> void:
	var s := ProgressState.new()
	for day in [100, 101, 102]:
		s = ProgressRules.complete_daily(s, day, 1, 60_000).state
	assert_int(s.daily_streak).is_equal(3)
	assert_int(s.daily_best_streak).is_equal(3)
	var after_gap := ProgressRules.complete_daily(s, 105, 1, 60_000)
	assert_int(after_gap.streak).is_equal(1)
	assert_int(after_gap.state.daily_best_streak).is_equal(3)
	assert_int(DailyChallenge.effective_streak(s, 102)).is_equal(3)
	assert_int(DailyChallenge.effective_streak(s, 103)).is_equal(3)  # hier : la série vit encore
	assert_int(DailyChallenge.effective_streak(s, 104)).is_equal(0)  # rompue


func test_streak_milestones_pay_once_per_streak() -> void:
	var s := ProgressState.new()
	var third: DailyCompletion
	for day in [100, 101, 102]:
		third = ProgressRules.complete_daily(s, day, 1, 60_000)
		s = third.state
	assert_int(third.milestone_hints).is_equal(1)
	assert_int(third.milestone_days).is_equal(3)
	assert_array(s.daily_claimed_milestones).contains_exactly([3])
	# Une nouvelle série qui retombe à 3 jours doit pouvoir re-toucher le palier
	var broken := ProgressRules.complete_daily(s, 110, 1, 60_000).state
	assert_array(broken.daily_claimed_milestones).is_empty()
	var again := broken
	var last: DailyCompletion
	for day in [111, 112]:
		last = ProgressRules.complete_daily(again, day, 1, 60_000)
		again = last.state
	assert_int(last.milestone_hints).is_equal(1)


func test_seven_day_streak_pays_two_hints() -> void:
	var s := ProgressState.new()
	var last: DailyCompletion
	for day in range(200, 207):
		last = ProgressRules.complete_daily(s, day, 1, 60_000)
		s = last.state
	assert_int(last.streak).is_equal(7)
	assert_int(last.milestone_hints).is_equal(2)
	assert_that(DailyChallenge.next_milestone(7)).is_equal(Vector2i(14, 3))
	assert_that(DailyChallenge.next_milestone(30)).is_equal(Vector2i.ZERO)


func test_finishing_a_past_day_gives_hints_but_keeps_the_streak() -> void:
	var s := ProgressRules.complete_daily(ProgressState.new(), 100, 1, 60_000).state
	s = ProgressRules.complete_daily(s, 101, 1, 60_000).state
	var late := ProgressRules.complete_daily(s, 99, 1, 60_000)
	assert_int(late.state.daily_streak).is_equal(2)
	assert_int(late.state.daily_last_day).is_equal(101)
	assert_int(late.base_hints).is_equal(1)
	assert_int(late.milestone_hints).is_equal(0)


func test_winning_the_daily_drops_its_saved_game() -> void:
	var s := ProgressState.new()
	s.in_progress[ProgressRules.snapshot_key("daily-100", Language.FR)] = GameSnapshot.new([] as Array[int], [] as Array[int], 0, 0)
	s.in_progress[ProgressRules.snapshot_key("c1-l01", Language.FR)] = GameSnapshot.new([] as Array[int], [] as Array[int], 0, 0)
	var done := ProgressRules.complete_daily(s, 100, 1, 1000)
	assert_bool(done.state.in_progress.has(ProgressRules.snapshot_key("daily-100", Language.FR))).is_false()
	assert_bool(done.state.in_progress.has(ProgressRules.snapshot_key("c1-l01", Language.FR))).is_true()


# --- Modèle d'affichage
func test_model_reports_status_week_month_and_milestones() -> void:
	var today := DailyChallenge.day_index_of(2026, 10, 21)
	var level := DailyLevelFactory.create(_catalog, today, Language.EN)
	var fresh := DailyModel.build(ProgressState.new(), today, level, false, 5000)
	assert_int(fresh.status).is_equal(DailyModel.Status.AVAILABLE)
	assert_int(DailyModel.build(ProgressState.new(), today, level, true, 5000).status).is_equal(DailyModel.Status.IN_PROGRESS)
	assert_int(DailyModel.build(ProgressState.new(), today, null, false, 5000).status).is_equal(DailyModel.Status.LOADING)
	assert_int(fresh.week.size()).is_equal(7)
	assert_str(fresh.week[6]["state"]).is_equal("today")
	assert_int((fresh.month["days"] as Array).size()).is_equal(31)
	assert_int(fresh.milestones.size()).is_equal(4)
	var won := ProgressRules.complete_daily(ProgressState.new(), today, 3, 40_000).state
	var done := DailyModel.build(won, today, level, false, 5000)
	assert_int(done.status).is_equal(DailyModel.Status.DONE)
	assert_int(done.stars).is_equal(3)
	assert_str(done.week[6]["state"]).is_equal("done")
	assert_int(done.streak).is_equal(1)


# --- Fabrique de grilles
func test_same_day_and_language_give_the_same_grid() -> void:
	for day in [20000, 20001, 20123]:
		var a := DailyLevelFactory.create(_catalog, day, Language.FR)
		var b := DailyLevelFactory.create(_catalog, day, Language.FR)
		assert_array(Array(a.variant(Language.FR).grid)).is_equal(Array(b.variant(Language.FR).grid))
		assert_str(a.id).is_equal("daily-%d" % day)
	assert_bool(DailyLevelFactory.seed_for(5, Language.FR) != DailyLevelFactory.seed_for(5, Language.EN)).is_true()


func test_two_weeks_of_grids_are_valid_in_both_languages() -> void:
	for day in range(21000, 21014):
		for language in [Language.FR, Language.EN]:
			var level := DailyLevelFactory.create(_catalog, day, language)
			assert_object(level).is_not_null()
			assert_bool(level.is_daily()).is_true()
			assert_int(level.daily_day()).is_equal(day)
			var variant := level.variant(language)
			assert_int(variant.grid.size()).is_equal(level.grid_size)
			var lengths: Array[int] = []
			for word in variant.words:
				lengths.append(word.letters.length())
				assert_int(LevelValidator.occurrence_count(variant, word.letters)).is_equal(1)
				for i in word.cells.size():
					assert_str(variant.letter_at(word.cells[i])).is_equal(word.letters[i])
			assert_str(LevelValidator.length_mix_problem(level.grid_size, level.difficulty.tier, lengths)).is_empty()
			assert_int(level.difficulty.score).is_greater(0)


func test_difficulty_follows_the_day_of_the_week() -> void:
	var sunday := DailyLevelFactory.plan_for(DailyChallenge.day_index_of(2026, 10, 18))
	var monday := DailyLevelFactory.plan_for(DailyChallenge.day_index_of(2026, 10, 19))
	assert_int(sunday["size"]).is_equal(12)
	assert_int(monday["size"]).is_less(sunday["size"])
	assert_int(sunday["number"]).is_equal(Level.FINAL_NUMBER)
