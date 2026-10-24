class_name AdsAndTutorialTest
extends GdUnitTestSuite
## Système publicitaire (rythme des interstitielles, configuration, espacement) et tutoriels (indice offert une seule fois).

const _SEC := 1000

var _config := AdPolicyConfig.defaults()
var _pacing: AdPacing


func before_test() -> void:
	_config = AdPolicyConfig.defaults()
	_pacing = AdPacing.new()


# ---- Configuration
func test_the_shipped_policy_file_is_valid_and_matches_the_agreed_defaults() -> void:
	var shipped := AdPolicyConfig.load_file()
	assert_bool(shipped.interstitial_enabled).is_true()
	assert_float(shipped.interstitial_probability).is_equal_approx(1.0 / 3.0, 0.001)
	assert_int(shipped.min_levels_completed).is_equal(4)
	assert_int(shipped.min_seconds_between_full_screen_ads).is_equal(90)
	assert_str(shipped.max_ad_content_rating).is_equal("PG")
	assert_array(shipped.retry_delays_seconds).is_not_empty()


func test_a_broken_or_wild_policy_file_falls_back_to_safe_values() -> void:
	var broken := AdPolicyConfig.parse("pas du json")
	assert_float(broken.interstitial_probability).is_equal_approx(1.0 / 3.0, 0.001)
	var wild := AdPolicyConfig.parse('{"interstitial": {"probability": 9, "min_seconds_between_full_screen_ads": 0, "min_levels_completed": -4}, "content": {"max_ad_content_rating": "XXX"}, "loading": {"retry_delays_seconds": []}}')
	assert_float(wild.interstitial_probability).is_equal(1.0)  # borné
	assert_int(wild.min_seconds_between_full_screen_ads).is_equal(15)  # jamais de pub en rafale à cause d'un 0
	assert_int(wild.min_levels_completed).is_equal(0)
	assert_str(wild.max_ad_content_rating).is_equal("PG")  # valeur inconnue ignorée
	assert_array(wild.retry_delays_seconds).is_not_empty()


func test_retry_delays_grow_then_repeat_the_last_one() -> void:
	assert_float(_config.retry_delay(1)).is_equal(4.0)
	assert_float(_config.retry_delay(2)).is_equal(10.0)
	assert_float(_config.retry_delay(5)).is_equal(120.0)
	assert_float(_config.retry_delay(50)).is_equal(120.0)


# ---- Interstitielle : une chance sur trois, avec garde-fous
func test_one_chance_in_three_is_drawn_at_each_passage_once_the_player_is_past_the_start() -> void:
	var now := 10 * 60 * _SEC
	assert_float(InterstitialPolicy.probability(_config, _pacing, 5, now)).is_equal_approx(1.0 / 3.0, 0.001)
	assert_bool(InterstitialPolicy.should_show(_config, _pacing, 5, now, 0.10)).is_true()
	assert_bool(InterstitialPolicy.should_show(_config, _pacing, 5, now, 0.50)).is_false()


func test_over_many_passages_about_one_in_three_shows_an_ad() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var shown := 0
	var trials := 6000
	for i in range(trials):
		if InterstitialPolicy.should_show(_config, AdPacing.new(), 10, 0, rng.randf()):
			shown += 1
	assert_float(float(shown) / trials).is_between(0.31, 0.355)


func test_no_ad_during_the_first_levels() -> void:
	for completed in range(0, 4):
		assert_float(InterstitialPolicy.probability(_config, _pacing, completed, 0)).is_equal(0.0)
	assert_float(InterstitialPolicy.probability(_config, _pacing, 4, 0)).is_greater(0.0)


func test_never_two_full_screen_ads_in_a_row() -> void:
	_pacing.record(AdPacing.Kind.INTERSTITIAL, 100 * _SEC)
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, 150 * _SEC)).is_equal(0.0)  # 50 s après
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, 191 * _SEC)).is_greater(0.0)  # 91 s après
	var other := AdPacing.new()
	other.record(AdPacing.Kind.RETURN, 100 * _SEC)  # une annonce de retour compte aussi
	assert_float(InterstitialPolicy.probability(_config, other, 9, 120 * _SEC)).is_equal(0.0)


func test_no_interstitial_right_after_a_rewarded_ad_the_player_chose() -> void:
	_pacing.record(AdPacing.Kind.REWARDED, 100 * _SEC)
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, 195 * _SEC)).is_equal(0.0)  # < 120 s
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, 221 * _SEC)).is_greater(0.0)


func test_a_player_who_watches_many_rewarded_ads_sees_fewer_interstitials() -> void:
	for i in range(3):
		_pacing.record(AdPacing.Kind.REWARDED, (100 + i * 200) * _SEC)
	var chance := InterstitialPolicy.probability(_config, _pacing, 9, 1500 * _SEC)
	assert_float(chance).is_equal_approx(1.0 / 6.0, 0.001)


func test_the_hourly_cap_is_enforced_and_expires() -> void:
	for i in range(_config.max_interstitials_per_hour):
		_pacing.record(AdPacing.Kind.INTERSTITIAL, (i * 200) * _SEC)
	var last := ((_config.max_interstitials_per_hour - 1) * 200) * _SEC
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, last + 100 * _SEC)).is_equal(0.0)
	assert_float(InterstitialPolicy.probability(_config, _pacing, 9, last + 2 * AdPacing.HOUR_MS)).is_greater(0.0)


func test_the_switch_turns_interstitials_off() -> void:
	_config.interstitial_enabled = false
	assert_float(InterstitialPolicy.probability(_config, _pacing, 50, 0)).is_equal(0.0)


func test_pacing_memory_reports_what_was_seen() -> void:
	assert_int(_pacing.since_last_full_screen(5000)).is_equal(AdPacing.NEVER)
	_pacing.record(AdPacing.Kind.INTERSTITIAL, 1000)
	_pacing.record(AdPacing.Kind.REWARDED, 3000)
	assert_int(_pacing.since_last_full_screen(8000)).is_equal(5000)
	assert_int(_pacing.since_last_rewarded(8000)).is_equal(5000)
	assert_int(_pacing.interstitials_in_last_hour(8000)).is_equal(1)
	assert_int(_pacing.rewarded_in_last_hour(8000)).is_equal(1)


# ---- Tutoriels
func _level(chapter: int, number: int) -> Level:
	return Fixtures.level({"id": "c%d-l%02d" % [chapter, number], "chapter": chapter, "number": number})


func test_the_tutorials_target_levels_1_and_4_of_chapter_1_only() -> void:
	assert_bool(TutorialRules.is_first_level(_level(1, 1))).is_true()
	assert_bool(TutorialRules.is_first_level(_level(1, 2))).is_false()
	assert_bool(TutorialRules.is_first_level(_level(2, 1))).is_false()
	assert_bool(TutorialRules.is_hint_intro_level(_level(1, 4))).is_true()
	assert_bool(TutorialRules.is_hint_intro_level(_level(1, 3))).is_false()
	assert_bool(TutorialRules.is_hint_intro_level(_level(2, 4))).is_false()


func test_the_hint_intro_gives_one_hint_once_and_never_again() -> void:
	var level := _level(1, 4)
	var fresh := ProgressState.new()
	assert_bool(TutorialRules.hint_intro_due(fresh, level)).is_true()
	var after := TutorialRules.begin_hint_intro(fresh)
	assert_int(after.hint_balance).is_equal(1)
	assert_bool(TutorialRules.hint_intro_due(after, level)).is_false()
	assert_bool(TutorialRules.begin_hint_intro(after) == after).is_true()  # rien de plus
	assert_int(fresh.hint_balance).is_equal(0)  # l'état d'origine n'est pas modifié


func test_the_hint_intro_is_skipped_for_a_player_who_already_won_level_4() -> void:
	var state := ProgressRules.complete_level(ProgressState.new(), "c1-l04", 3, 1, Praise.NONE)
	assert_bool(TutorialRules.hint_intro_due(state, _level(1, 4))).is_false()


func test_the_hint_intro_flag_survives_a_save_and_reload() -> void:
	var state := TutorialRules.begin_hint_intro(ProgressState.new())
	var back := ProgressJson.decode(ProgressJson.encode(state)).value as ProgressState
	assert_bool(TutorialRules.hint_intro_due(back, _level(1, 4))).is_false()
	assert_int(back.hint_balance).is_equal(1)


func test_use_case_offers_the_intro_hint_atomically_and_only_once() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	var uc := GameUseCases.new(Fixtures.stub_catalog(), repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	assert_bool(uc.begin_hint_intro(_level(1, 3))).is_false()  # pas le bon niveau
	assert_bool(uc.begin_hint_intro(_level(1, 4))).is_true()
	assert_int(repo.state.hint_balance).is_equal(1)
	assert_bool(uc.begin_hint_intro(_level(1, 4))).is_false()
	assert_int(repo.state.hint_balance).is_equal(1)


func test_a_failed_save_offers_nothing_and_shows_nothing() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	repo.fail_writes = true
	var uc := GameUseCases.new(Fixtures.stub_catalog(), repo, MemoryFakes.FakeAds.new(), func(from: int, _until: int) -> int: return from)
	assert_bool(uc.begin_hint_intro(_level(1, 4))).is_false()
	assert_int(repo.state.hint_balance).is_equal(0)


# ---- « Doubler la récompense »
func test_doubling_a_reward_grants_the_bonus_after_the_ad_and_counts_in_the_pacing() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	var ads := MemoryFakes.FakeAds.new()
	var pacing := AdPacing.new()
	var uc := GameUseCases.new(Fixtures.stub_catalog(), repo, ads, func(from: int, _until: int) -> int: return from, Callable(), pacing)
	var outcome: RewardOutcome = await uc.watch_rewarded_bonus(3)
	assert_int(outcome.kind).is_equal(RewardOutcome.Kind.GRANTED)
	assert_int(outcome.amount).is_equal(3)
	assert_int(repo.state.hint_balance).is_equal(3)
	assert_int(pacing.rewarded_in_last_hour(Time.get_ticks_msec())).is_equal(1)


func test_doubling_grants_nothing_when_the_ad_is_closed_early_or_unavailable() -> void:
	var repo := MemoryFakes.MemoryProgress.new()
	var ads := MemoryFakes.FakeAds.new()
	ads.rewarded = RewardedAdResult.dismissed()
	var uc := GameUseCases.new(Fixtures.stub_catalog(), repo, ads, func(from: int, _until: int) -> int: return from)
	var closed: RewardOutcome = await uc.watch_rewarded_bonus(2)
	assert_int(closed.kind).is_equal(RewardOutcome.Kind.DISMISSED)
	ads.reason = UnavailableReason.OFFLINE
	var offline: RewardOutcome = await uc.watch_rewarded_bonus(2)
	assert_int(offline.kind).is_equal(RewardOutcome.Kind.UNAVAILABLE)
	assert_int(repo.state.hint_balance).is_equal(0)
