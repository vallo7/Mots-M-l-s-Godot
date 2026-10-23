class_name TimerAndStarsTest
extends GdUnitTestSuite

var _clock: Fixtures.FakeClock
var _timer: GameTimer


func before_test() -> void:
	_clock = Fixtures.FakeClock.new()
	_timer = GameTimer.new(_clock.callable())


func test_timer_does_not_run_before_first_interaction() -> void:
	_clock.now += 5_000
	assert_int(_timer.elapsed_millis()).is_equal(0)
	assert_bool(_timer.has_started()).is_false()


func test_timer_counts_from_first_interaction_and_ignores_pauses() -> void:
	_timer.start_if_needed()
	_clock.now += 2_000
	_timer.pause()
	_clock.now += 60_000  # application en arrière-plan
	assert_int(_timer.elapsed_millis()).is_equal(2_000)
	_timer.resume()
	_clock.now += 1_500
	assert_int(_timer.elapsed_millis()).is_equal(3_500)


func test_resume_without_start_does_nothing_and_start_if_needed_is_idempotent() -> void:
	_timer.resume()
	assert_bool(_timer.is_running()).is_false()
	_timer.start_if_needed()
	_clock.now += 1_000
	_timer.start_if_needed()
	_clock.now += 1_000
	assert_int(_timer.elapsed_millis()).is_equal(2_000)


func test_stop_freezes_the_time() -> void:
	_timer.start_if_needed()
	_clock.now += 4_000
	assert_int(_timer.stop()).is_equal(4_000)
	_clock.now += 10_000
	_timer.resume()
	assert_int(_timer.elapsed_millis()).is_equal(4_000)


func test_reset_restores_the_initial_state() -> void:
	_timer.start_if_needed()
	_clock.now += 4_000
	_timer.reset()
	assert_int(_timer.elapsed_millis()).is_equal(0)
	assert_bool(_timer.has_started()).is_false()
	_timer.start_if_needed()
	assert_bool(_timer.is_running()).is_true()


func test_star_thresholds_are_exact_including_3_minutes() -> void:
	assert_int(StarRating.stars_for(0)).is_equal(3)
	assert_int(StarRating.stars_for(59_999)).is_equal(3)
	assert_int(StarRating.stars_for(60_000)).is_equal(2)
	assert_int(StarRating.stars_for(179_999)).is_equal(2)
	assert_int(StarRating.stars_for(180_000)).is_equal(1)
	assert_int(StarRating.stars_for(3_600_000)).is_equal(1)
