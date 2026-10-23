class_name TrophyTest
extends GdUnitTestSuite
## Trophées : catalogue (20, du plus simple au plus rare), compteurs, déblocage, sauvegarde et intégration aux victoires.

const _NOW := 1_700_000_000

var _catalog: LevelCatalog
var _low := func(from: int, _until: int) -> int: return from


func before_test() -> void:
	_catalog = Fixtures.stub_catalog(10)


func _complete(state: ProgressState, level_id: String, stars: int = 3) -> ProgressState:
	return ProgressRules.complete_level(state, level_id, stars, 30_000, Praise.NONE)


func _all_levels_of_chapters(state: ProgressState, chapter_count: int, stars: int = 3) -> ProgressState:
	var next := state
	for c in range(1, chapter_count + 1):
		for n in range(1, 11):
			next = _complete(next, "c%d-l%02d" % [c, n], stars)
	return next


# ---- Catalogue
func test_the_catalog_has_twenty_trophies_with_unique_ids() -> void:
	assert_int(TrophyCatalog.all().size()).is_equal(20)
	var ids := {}
	for trophy in TrophyCatalog.all():
		ids[trophy.id] = true
		assert_int(trophy.target).is_greater(0)
	assert_int(ids.size()).is_equal(20)


func test_rarity_never_goes_down_and_the_first_two_trophies_are_the_easy_ones() -> void:
	var previous := -1
	for trophy in TrophyCatalog.all():
		assert_int(trophy.tier).is_greater_equal(previous)
		previous = trophy.tier
	assert_int(TrophyCatalog.all()[0].tier).is_equal(Trophy.Tier.BRONZE)
	assert_int(TrophyCatalog.all()[1].tier).is_equal(Trophy.Tier.BRONZE)
	assert_int(TrophyCatalog.all()[2].tier).is_greater(Trophy.Tier.BRONZE)
	assert_int(TrophyCatalog.all()[19].tier).is_equal(Trophy.Tier.AMETHYST)


func test_every_trophy_has_a_name_and_a_description_in_both_languages_and_its_icon() -> void:
	for language in [Language.EN, Language.FR]:
		Strings.set_language(language)
		for trophy in TrophyCatalog.all():
			assert_str(Strings.t(trophy.name_key())).is_not_equal(trophy.name_key())
			assert_str(Strings.t(trophy.description_key(), [trophy.target])).is_not_equal(trophy.description_key())
			assert_bool(Strings.t(trophy.description_key(), [trophy.target]).contains("{0}")).is_false()
	for trophy in TrophyCatalog.all():
		assert_bool(ResourceLoader.exists("res://assets/icons/%s.png" % trophy.icon_name())).is_true()
	assert_bool(ResourceLoader.exists("res://assets/icons/%s.png" % Trophy.LOCKED_ICON)).is_true()
	for tier in range(6):
		assert_str(Strings.t(Trophy.tier_key(tier))).is_not_equal(Trophy.tier_key(tier))


func test_a_trophy_can_be_found_by_its_id() -> void:
	assert_str(TrophyCatalog.by_id("first_steps").id).is_equal("first_steps")
	assert_object(TrophyCatalog.by_id("nope")).is_null()


# ---- Règles
func test_a_fresh_save_unlocks_nothing() -> void:
	var state := ProgressState.new()
	assert_bool(TrophyRules.evaluate(_catalog, state, _NOW) == state).is_true()
	assert_int(TrophyRules.unlocked_count(state)).is_equal(0)


func test_first_level_unlocks_first_steps_and_a_three_star_level_unlocks_rising_star() -> void:
	var state := _complete(ProgressState.new(), "c1-l01", 2)
	var next := TrophyRules.evaluate(_catalog, state, _NOW)
	assert_bool(next.trophies.has("first_steps")).is_true()
	assert_bool(next.trophies.has("rising_star")).is_false()
	assert_int(int(next.trophies["first_steps"])).is_equal(_NOW)
	next = TrophyRules.evaluate(_catalog, _complete(next, "c1-l02", 3), _NOW + 5)
	assert_bool(next.trophies.has("rising_star")).is_true()
	assert_int(int(next.trophies["first_steps"])).is_equal(_NOW)  # une date de déblocage ne change jamais


func test_evaluate_does_not_touch_the_state_it_receives_and_is_idempotent() -> void:
	var state := _complete(ProgressState.new(), "c1-l01")
	var next := TrophyRules.evaluate(_catalog, state, _NOW)
	assert_bool(state.trophies.is_empty()).is_true()
	assert_bool(TrophyRules.evaluate(_catalog, next, _NOW + 99) == next).is_true()


func test_counters_derived_from_the_progression() -> void:
	var state := _all_levels_of_chapters(ProgressState.new(), 2, 2)
	state.claimed_gift_chapters = [1]
	assert_int(TrophyRules.metric_value(TrophyRules.LEVELS, _catalog, state)).is_equal(20)
	assert_int(TrophyRules.metric_value(TrophyRules.STARS, _catalog, state)).is_equal(40)
	assert_int(TrophyRules.metric_value(TrophyRules.CHAPTERS, _catalog, state)).is_equal(2)
	assert_int(TrophyRules.metric_value(TrophyRules.GIFTS, _catalog, state)).is_equal(1)
	assert_int(TrophyRules.metric_value(TrophyRules.THREE_STAR_LEVELS, _catalog, state)).is_equal(0)


func test_existing_players_get_their_trophies_retroactively() -> void:
	var state := _all_levels_of_chapters(ProgressState.new(), 4, 3)
	var next := TrophyRules.evaluate(_catalog, state, _NOW)
	for id in ["first_steps", "rising_star", "five_levels", "chapter_one", "fifty_stars", "perfect_five", "hundred_stars"]:
		assert_bool(next.trophies.has(id)).is_true()
	assert_bool(next.trophies.has("five_chapters")).is_false()
	assert_array(TrophyRules.newly_unlocked(state, next)).contains(["first_steps", "chapter_one"])


func test_progress_is_capped_at_the_target() -> void:
	var state := _all_levels_of_chapters(ProgressState.new(), 1)
	var five := TrophyCatalog.by_id("five_levels")
	assert_int(TrophyRules.progress_of(five, _catalog, state)).is_equal(5)
	var chapters := TrophyCatalog.by_id("five_chapters")
	assert_int(TrophyRules.progress_of(chapters, _catalog, state)).is_equal(1)


func test_recording_a_flawless_level_a_lightning_level_and_a_final_without_hint() -> void:
	var state := TrophyRules.record_level(ProgressState.new(), 9, 30_000, 0, 0, true)
	assert_int(TrophyRules.metric_value(TrophyRules.FLAWLESS_LEVELS, null, state)).is_equal(1)
	assert_int(TrophyRules.metric_value(TrophyRules.LIGHTNING_LEVELS, null, state)).is_equal(1)
	assert_int(TrophyRules.metric_value(TrophyRules.FINAL_NO_HINT, null, state)).is_equal(1)
	# Un indice ou une erreur : pas sans faute ; trop lent ou petite grille : pas d'éclair ; indice : pas de défi sans indice
	var worse := TrophyRules.record_level(ProgressState.new(), 6, 30_000, 1, 2, true)
	assert_int(TrophyRules.metric_value(TrophyRules.FLAWLESS_LEVELS, null, worse)).is_equal(0)
	assert_int(TrophyRules.metric_value(TrophyRules.LIGHTNING_LEVELS, null, worse)).is_equal(0)
	assert_int(TrophyRules.metric_value(TrophyRules.FINAL_NO_HINT, null, worse)).is_equal(0)
	var slow := TrophyRules.record_level(ProgressState.new(), 10, 40_000, 0, 0)
	assert_int(TrophyRules.metric_value(TrophyRules.LIGHTNING_LEVELS, null, slow)).is_equal(0)


func test_best_perfect_streak_is_remembered_after_the_current_streak_resets() -> void:
	var state := ProgressState.new()
	state.perfect_streak = 6
	var recorded := TrophyRules.record_level(state, 5, 90_000, 0, 0)
	recorded.perfect_streak = 0
	assert_int(TrophyRules.metric_value(TrophyRules.BEST_PERFECT_STREAK, null, recorded)).is_equal(6)


func test_unseen_trophies_are_listed_until_marked_seen() -> void:
	var state := TrophyRules.evaluate(_catalog, _complete(ProgressState.new(), "c1-l01"), _NOW)
	assert_array(TrophyRules.unseen_ids(state)).contains_exactly(["first_steps", "rising_star"])
	var seen := TrophyRules.mark_all_seen(state)
	assert_array(TrophyRules.unseen_ids(seen)).is_empty()
	assert_array(TrophyRules.unseen_ids(state)).is_not_empty()  # l'état d'origine n'est pas modifié
	assert_bool(TrophyRules.mark_all_seen(seen) == seen).is_true()


# ---- Sauvegarde
func test_trophies_stats_and_seen_ids_survive_a_save_and_reload() -> void:
	var state := TrophyRules.evaluate(_catalog, _complete(ProgressState.new(), "c1-l01"), _NOW)
	state = TrophyRules.record_hint(state)
	state = TrophyRules.mark_all_seen(state)
	var back := ProgressJson.decode(ProgressJson.encode(state)).value as ProgressState
	assert_dict(back.trophies).is_equal(state.trophies)
	assert_dict(back.stats).is_equal(state.stats)
	assert_array(back.trophies_seen).contains_exactly_in_any_order(state.trophies_seen)
	assert_int(TrophyRules.metric_value(TrophyRules.HINTS_USED, _catalog, back)).is_equal(1)


func test_unknown_trophy_ids_and_garbage_are_ignored_on_load() -> void:
	var text := JSON.stringify({
		"schemaVersion": 3, "hintBalance": 3, "completed": {}, "inProgress": {}, "claimedGiftChapters": [],
		"stats": {"hint_uses": 4, "bad": -9}, "trophies": {"first_steps": 123, "from_the_future": 5}, "trophiesSeen": ["first_steps", "ghost"],
	})
	var back := ProgressJson.decode(text).value as ProgressState
	assert_dict(back.trophies).is_equal({"first_steps": 123})
	assert_array(back.trophies_seen).contains_exactly(["first_steps"])
	assert_int(int(back.stats["hint_uses"])).is_equal(4)
	assert_int(int(back.stats["bad"])).is_equal(0)


# ---- Cas d'usage
func test_completing_a_level_unlocks_trophies_and_persists_them() -> void:
	var clock := Fixtures.FakeClock.new()
	var repo := MemoryFakes.MemoryProgress.new()
	var uc := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low, func() -> int: return _NOW)
	var session := GameSession.new(_catalog.levels[0], Language.EN, clock.callable())
	session.submit(Fixtures.sun())
	clock.now += 20_000
	session.submit(Fixtures.sky())
	var before := repo.state
	uc.complete_level(session)
	assert_bool(repo.state.trophies.has("first_steps")).is_true()
	assert_bool(repo.state.trophies.has("rising_star")).is_true()
	assert_int(int(repo.state.trophies["first_steps"])).is_equal(_NOW)
	assert_array(TrophyRules.newly_unlocked(before, repo.state)).contains(["first_steps", "rising_star"])
	assert_int(TrophyRules.metric_value(TrophyRules.FLAWLESS_LEVELS, _catalog, repo.state)).is_equal(1)
	# Rejouer la même victoire ne recompte rien
	uc.complete_level(session)
	assert_int(TrophyRules.metric_value(TrophyRules.FLAWLESS_LEVELS, _catalog, repo.state)).is_equal(1)


func test_a_wrong_selection_means_the_level_is_not_flawless() -> void:
	var clock := Fixtures.FakeClock.new()
	var repo := MemoryFakes.MemoryProgress.new()
	var uc := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low)
	var session := GameSession.new(_catalog.levels[0], Language.EN, clock.callable())
	session.submit(Fixtures.cells([Fixtures.cell(0, 0), Fixtures.cell(0, 1)]))  # mauvaise sélection
	session.submit(Fixtures.sun())
	session.submit(Fixtures.sky())
	uc.complete_level(session)
	assert_int(TrophyRules.metric_value(TrophyRules.FLAWLESS_LEVELS, _catalog, repo.state)).is_equal(0)


func test_using_a_hint_counts_and_unlocks_helping_hand() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state.hint_balance = 2
	var uc := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low, func() -> int: return _NOW)
	var session := GameSession.new(_catalog.levels[0], Language.EN, Fixtures.FakeClock.new().callable())
	uc.use_hint(session)
	assert_bool(repo.state.trophies.has("helping_hand")).is_true()
	assert_int(TrophyRules.metric_value(TrophyRules.HINTS_USED, _catalog, repo.state)).is_equal(1)


func test_sync_unlocks_what_the_progression_already_earned_without_changing_dates() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state = _all_levels_of_chapters(ProgressState.new(), 1)
	var uc := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low, func() -> int: return _NOW)
	uc.sync_trophies()
	assert_bool(repo.state.trophies.has("chapter_one")).is_true()
	var count := repo.state.trophies.size()
	var later := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low, func() -> int: return _NOW + 500)
	later.sync_trophies()
	assert_int(repo.state.trophies.size()).is_equal(count)
	assert_int(int(repo.state.trophies["first_steps"])).is_equal(_NOW)


func test_marking_trophies_seen_persists() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	repo.state = TrophyRules.evaluate(_catalog, _complete(ProgressState.new(), "c1-l01"), _NOW)
	var uc := GameUseCases.new(_catalog, repo, MemoryFakes.FakeAds.new(), _low)
	uc.mark_trophies_seen()
	assert_array(TrophyRules.unseen_ids(repo.state)).is_empty()
