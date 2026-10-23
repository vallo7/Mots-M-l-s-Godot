class_name MotionTest
extends GdUnitTestSuite


func test_spring_starts_at_zero_and_settles_on_one() -> void:
	assert_float(Motion.spring(0.0)).is_equal_approx(0.0, 0.000001)
	assert_float(Motion.spring(2.0)).is_equal_approx(1.0, 0.01)


func test_a_bouncy_spring_overshoots_one_then_comes_back() -> void:
	var peak := 0.0
	for i in range(1, 201):
		peak = maxf(peak, Motion.spring(i / 100.0, 16.0, 0.4))
	assert_float(peak).is_greater(1.05)
	assert_float(Motion.spring(Motion.spring_settle_seconds(16.0, 0.4) * 1.5, 16.0, 0.4)).is_equal_approx(1.0, 0.02)


func test_a_critically_damped_spring_never_overshoots() -> void:
	var peak := 0.0
	for i in range(1, 301):
		peak = maxf(peak, Motion.spring(i / 100.0, 16.0, 1.0))
	assert_float(peak).is_less_equal(1.0001)


func test_settle_time_is_finite_and_shrinks_with_frequency() -> void:
	assert_float(Motion.spring_settle_seconds(12.0, 0.5)).is_greater(Motion.spring_settle_seconds(24.0, 0.5))
	var default_settle := Motion.spring_settle_seconds()
	assert_bool(default_settle >= 0.1 and default_settle <= 3.0).is_true()


func test_easings_hit_their_endpoints() -> void:
	assert_float(Motion.ease_out_back(0.0)).is_equal_approx(0.0, 0.00001)
	assert_float(Motion.ease_out_back(1.0)).is_equal_approx(1.0, 0.00001)
	assert_float(Motion.ease_in_out_cubic(0.0)).is_equal_approx(0.0, 0.000001)
	assert_float(Motion.ease_in_out_cubic(1.0)).is_equal_approx(1.0, 0.000001)
	assert_float(Motion.ease_out_cubic(1.0)).is_equal_approx(1.0, 0.000001)
	assert_float(Motion.ease_out_back(0.8)).is_greater(1.0)


func test_bump_is_a_0_to_1_to_0_pulse() -> void:
	assert_float(Motion.bump(0.0)).is_equal_approx(0.0, 0.00001)
	assert_float(Motion.bump(0.5)).is_equal_approx(1.0, 0.00001)
	assert_float(Motion.bump(1.0)).is_equal_approx(0.0, 0.00001)


func test_quadratic_arc_passes_through_its_endpoints() -> void:
	assert_float(Motion.quad(10.0, 99.0, 50.0, 0.0)).is_equal_approx(10.0, 0.00001)
	assert_float(Motion.quad(10.0, 99.0, 50.0, 1.0)).is_equal_approx(50.0, 0.00001)
