class_name PraiseSelectorTest
extends GdUnitTestSuite

var _weak := PraiseContext.new(1, 2, 4, 700_000, false, 0)
var _perfect := PraiseContext.new(3, 0, 0, 40_000, true, 5)
var _average := PraiseContext.new(2, 1, 2, 300_000, false, 0)


func test_trivial_performance_never_gets_more_than_nice() -> void:
	assert_int(PraiseSelector.points(_weak)).is_equal(0)
	for seed_value in range(0, 51):
		assert_int(PraiseSelector.select(_weak, Praise.NONE, seed_value)).is_equal(Praise.NICE)


func test_perfect_final_challenge_reaches_the_top_of_the_ladder() -> void:
	assert_int(PraiseSelector.points(_perfect)).is_equal(7)
	var picks := {}
	for seed_value in range(0, 61):
		picks[PraiseSelector.select(_perfect, Praise.NONE, seed_value)] = true
	for pick in picks:
		assert_bool(pick == Praise.DIVINE or pick == Praise.LEGENDARY).is_true()
	assert_bool(picks.has(Praise.LEGENDARY)).is_true()


func test_average_performance_stays_in_the_low_middle_range() -> void:
	var cap := PraiseSelector.points(_average)
	for seed_value in range(0, 61):
		assert_int(PraiseSelector.select(_average, Praise.NONE, seed_value)).is_less_equal(cap)


func test_selection_is_deterministic_for_a_given_seed() -> void:
	assert_int(PraiseSelector.select(_perfect, Praise.NONE, 42)).is_equal(PraiseSelector.select(_perfect, Praise.NONE, 42))


func test_previous_praise_is_not_repeated_when_an_alternative_exists() -> void:
	for seed_value in range(0, 61):
		assert_int(PraiseSelector.select(_perfect, Praise.LEGENDARY, seed_value)).is_not_equal(Praise.LEGENDARY)
		assert_int(PraiseSelector.select(_perfect, Praise.DIVINE, seed_value)).is_not_equal(Praise.DIVINE)


func test_file_names_follow_stable_keys() -> void:
	assert_array(Praise.KEYS).contains_exactly(["nice", "great", "awesome", "amazing", "insane", "unreal", "divine", "legendary"])


func test_string_hash_matches_java_hashcode() -> void:
	# Valeurs de référence calculées avec String.hashCode() de Java/Kotlin (entier 32 bits signé).
	assert_int(PraiseSelector.string_hash("")).is_equal(0)
	assert_int(PraiseSelector.string_hash("a")).is_equal(97)
	assert_int(PraiseSelector.string_hash("hello")).is_equal(99162322)
	assert_int(PraiseSelector.string_hash("c1-l01")).is_equal(-1413982898)
	assert_int(PraiseSelector.string_hash("Hello, World!")).is_equal(1498789909)
