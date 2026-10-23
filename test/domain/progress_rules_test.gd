class_name ProgressRulesTest
extends GdUnitTestSuite

var _catalog: LevelCatalog
var _low := func(from: int, _until: int) -> int: return from
var _high := func(_from: int, until: int) -> int: return until - 1


func before_test() -> void:
	_catalog = Fixtures.stub_catalog()


func _complete_chapter(state: ProgressState, chapter: int, stars: int = 3) -> ProgressState:
	var s := state
	for n in range(1, 11):
		s = ProgressRules.complete_level(s, "c%d-l%02d" % [chapter, n], stars, 60_000, Praise.NICE)
	return s


func _same(a: ProgressState, b: ProgressState) -> void:
	assert_str(ProgressJson.encode(a)).is_equal(ProgressJson.encode(b))


# --- indices initiaux
func test_first_launch_grants_exactly_two_hints_once() -> void:
	var once := ProgressRules.initialize(ProgressState.new())
	assert_int(once.hint_balance).is_equal(2)
	assert_bool(once.initial_hints_granted).is_true()
	_same(once, ProgressRules.initialize(once))
	assert_int(ProgressRules.initialize(ProgressRules.initialize(once)).hint_balance).is_equal(2)


func test_hint_spend_never_goes_below_zero() -> void:
	assert_object(ProgressRules.spend_hint(ProgressState.new())).is_null()
	var two := ProgressState.new()
	two.hint_balance = 2
	assert_int(ProgressRules.spend_hint(two).hint_balance).is_equal(1)


# --- progression et verrouillage
func test_only_the_first_uncompleted_level_is_available() -> void:
	var s := ProgressState.new()
	assert_int(ProgressRules.status_of(_catalog, s, "c1-l01")).is_equal(LevelStatus.AVAILABLE)
	assert_int(ProgressRules.status_of(_catalog, s, "c1-l02")).is_equal(LevelStatus.LOCKED)
	var next := ProgressRules.complete_level(s, "c1-l01", 3, 1000, Praise.NICE)
	assert_int(ProgressRules.status_of(_catalog, next, "c1-l01")).is_equal(LevelStatus.COMPLETED)
	assert_int(ProgressRules.status_of(_catalog, next, "c1-l02")).is_equal(LevelStatus.AVAILABLE)
	assert_str(ProgressRules.current_level(_catalog, next).id).is_equal("c1-l02")


func test_completing_a_level_twice_changes_nothing() -> void:
	var once := ProgressRules.complete_level(ProgressState.new(), "c1-l01", 3, 1000, Praise.GREAT)
	var twice := ProgressRules.complete_level(once, "c1-l01", 1, 999_000, Praise.LEGENDARY)
	_same(once, twice)
	assert_int((twice.completed["c1-l01"] as LevelResult).stars).is_equal(3)


func test_current_level_moves_to_next_chapter_and_ends_with_null() -> void:
	var ch1 := _complete_chapter(ProgressState.new(), 1)
	assert_str(ProgressRules.current_level(_catalog, ch1).id).is_equal("c2-l01")
	assert_object(ProgressRules.current_level(_catalog, _complete_chapter(ch1, 2))).is_null()


func test_perfect_streak_counts_consecutive_three_star_levels() -> void:
	var s := ProgressRules.complete_level(ProgressState.new(), "c1-l01", 3, 1, Praise.NONE)
	s = ProgressRules.complete_level(s, "c1-l02", 3, 1, Praise.NONE)
	assert_int(s.perfect_streak).is_equal(2)
	s = ProgressRules.complete_level(s, "c1-l03", 2, 1, Praise.NONE)
	assert_int(s.perfect_streak).is_equal(0)


func test_completion_clears_the_in_progress_snapshots_of_that_level() -> void:
	var snapshot := GameSnapshot.new([0] as Array[int], [] as Array[int], 1, 5_000)
	var s := ProgressRules.save_snapshot(ProgressState.new(), "c1-l01", Language.FR, snapshot)
	s = ProgressRules.save_snapshot(s, "c1-l01", Language.EN, snapshot)
	assert_int(s.in_progress.size()).is_equal(2)
	var done := ProgressRules.complete_level(s, "c1-l01", 3, 1, Praise.NICE)
	assert_int(done.in_progress.size()).is_equal(0)
	# Une sauvegarde sur un niveau terminé est ignorée.
	assert_int(ProgressRules.save_snapshot(done, "c1-l01", Language.FR, snapshot).in_progress.size()).is_equal(0)


func test_rules_never_mutate_the_state_they_receive() -> void:
	var before := ProgressState.new()
	ProgressRules.initialize(before)
	ProgressRules.complete_level(before, "c1-l01", 3, 1, Praise.NICE)
	assert_int(before.hint_balance).is_equal(0)
	assert_int(before.completed.size()).is_equal(0)


# --- cadeau de chapitre
func test_gift_is_not_claimable_before_the_chapter_is_complete() -> void:
	var partial := ProgressRules.complete_level(ProgressState.new(), "c1-l01", 3, 1, Praise.NONE)
	assert_bool(ProgressRules.is_gift_claimable(_catalog, partial, 1)).is_false()
	assert_object(ProgressRules.claim_gift(_catalog, partial, 1, _low)).is_null()
	assert_int(ProgressRules.chapter_completed_count(_catalog, partial, 1)).is_equal(1)


func test_gift_gives_one_to_three_hints_and_only_once_per_chapter() -> void:
	var done := _complete_chapter(ProgressState.new(), 1)
	assert_bool(ProgressRules.is_gift_claimable(_catalog, done, 1)).is_true()
	var claim := ProgressRules.claim_gift(_catalog, done, 1, _high)
	assert_int(claim.amount).is_equal(3)
	assert_int(claim.state.hint_balance).is_equal(3)
	assert_object(ProgressRules.claim_gift(_catalog, claim.state, 1, _high)).is_null()
	assert_int(ProgressRules.claim_gift(_catalog, done, 1, _low).amount).is_equal(1)
	assert_bool(ProgressRules.is_gift_claimable(_catalog, done, 2)).is_false()


# --- publicité récompensée
func test_rewarded_ad_grants_exactly_one_hint_whatever_the_random_source() -> void:
	assert_int(ProgressRules.grant_rewarded_hints(ProgressState.new(), "ad-1", _low).amount).is_equal(1)
	assert_int(ProgressRules.grant_rewarded_hints(ProgressState.new(), "ad-1", _high).amount).is_equal(1)
	var four := ProgressState.new()
	four.hint_balance = 4
	assert_int(ProgressRules.grant_rewarded_hints(four, "ad-9", _high).state.hint_balance - 4).is_equal(1)


func test_same_reward_id_is_never_granted_twice() -> void:
	var first := ProgressRules.grant_rewarded_hints(ProgressState.new(), "ad-1", _high)
	assert_object(ProgressRules.grant_rewarded_hints(first.state, "ad-1", _high)).is_null()
	assert_object(ProgressRules.grant_rewarded_hints(first.state, "ad-2", _high)).is_not_null()


func test_blank_reward_id_is_refused_and_random_is_not_drawn() -> void:
	var draws := [0]
	var counting := func(from: int, _until: int) -> int:
		draws[0] += 1
		return from
	assert_object(ProgressRules.grant_rewarded_hints(ProgressState.new(), " ", counting)).is_null()
	var granted := ProgressRules.grant_rewarded_hints(ProgressState.new(), "x", _low)
	assert_object(ProgressRules.grant_rewarded_hints(granted.state, "x", counting)).is_null()
	assert_int(draws[0]).is_equal(0)


func test_remembered_reward_ids_are_bounded() -> void:
	var s := ProgressState.new()
	for i in range(1, 101):
		s = ProgressRules.grant_rewarded_hints(s, "ad-%d" % i, _low).state
	assert_int(s.granted_reward_ids.size()).is_equal(ProgressRules.REMEMBERED_REWARD_IDS)
	assert_str(s.granted_reward_ids[s.granted_reward_ids.size() - 1]).is_equal("ad-100")


# --- publicité de retour dans l'application
func _moment(first_render := false, touched := false, resolving := false, sensitive := false) -> AdMoment:
	var m := AdMoment.new()
	m.is_first_render = first_render
	m.is_grid_being_touched = touched
	m.is_resolving_win = resolving
	m.is_sensitive_action_pending = sensitive
	return m


func test_return_ad_is_shown_after_a_long_enough_absence() -> void:
	assert_bool(ReturnAdPolicy.should_show(30_000, ReturnAdPolicy.NEVER, false, true, _moment())).is_true()


func test_return_ad_is_never_shown_for_a_very_short_absence() -> void:
	assert_bool(ReturnAdPolicy.should_show(ReturnAdPolicy.MIN_AWAY_MS - 1, ReturnAdPolicy.NEVER, false, true, _moment())).is_false()
	assert_bool(ReturnAdPolicy.should_show(ReturnAdPolicy.MIN_AWAY_MS, ReturnAdPolicy.NEVER, false, true, _moment())).is_true()


func test_return_ad_respects_the_cooldown() -> void:
	assert_bool(ReturnAdPolicy.should_show(60_000, ReturnAdPolicy.COOLDOWN_MS - 1, false, true, _moment())).is_false()
	assert_bool(ReturnAdPolicy.should_show(60_000, ReturnAdPolicy.COOLDOWN_MS, false, true, _moment())).is_true()


func test_return_ad_is_never_shown_after_a_cold_start_or_when_coming_back_from_another_ad() -> void:
	assert_bool(ReturnAdPolicy.should_show(60_000, ReturnAdPolicy.NEVER, false, false, _moment())).is_false()
	assert_bool(ReturnAdPolicy.should_show(60_000, ReturnAdPolicy.NEVER, true, true, _moment())).is_false()


func test_return_ad_is_blocked_at_sensitive_moments() -> void:
	assert_bool(ReturnAdPolicy.can_show_now(_moment())).is_true()
	assert_bool(ReturnAdPolicy.can_show_now(_moment(true))).is_false()
	assert_bool(ReturnAdPolicy.can_show_now(_moment(false, true))).is_false()
	assert_bool(ReturnAdPolicy.can_show_now(_moment(false, false, true))).is_false()
	assert_bool(ReturnAdPolicy.can_show_now(_moment(false, false, false, true))).is_false()
	assert_bool(ReturnAdPolicy.should_show(60_000, ReturnAdPolicy.NEVER, false, true, _moment(false, false, true))).is_false()
