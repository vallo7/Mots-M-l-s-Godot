class_name PersistenceJsonTest
extends GdUnitTestSuite


func _rich() -> ProgressState:
	var s := ProgressState.new()
	s.initial_hints_granted = true
	s.hint_balance = 3
	s.completed["c1-l01"] = LevelResult.new(3, 91_000)
	s.completed["c1-l02"] = LevelResult.new(1, 700_000)
	s.claimed_gift_chapters = [1] as Array[int]
	s.granted_reward_ids = ["a", "b"] as Array[String]
	s.last_praise = Praise.AMAZING
	s.perfect_streak = 2
	s.in_progress["c1-l03:fr"] = GameSnapshot.new([0, 2] as Array[int], [1] as Array[int], 4, 33_000)
	return s


func test_daily_challenge_state_survives_a_round_trip() -> void:
	var s := _rich()
	s.daily_results[20_000] = LevelResult.new(3, 41_000)
	s.daily_results[20_001] = LevelResult.new(1, 301_000)
	s.daily_streak = 2
	s.daily_best_streak = 5
	s.daily_last_day = 20_001
	s.daily_claimed_milestones = [3] as Array[int]
	var decoded := ProgressJson.decode(ProgressJson.encode(s))
	assert_bool(decoded.ok).is_true()
	var back: ProgressState = decoded.value
	assert_int((back.daily_results[20_000] as LevelResult).stars).is_equal(3)
	assert_int((back.daily_results[20_001] as LevelResult).elapsed_millis).is_equal(301_000)
	assert_int(back.daily_streak).is_equal(2)
	assert_int(back.daily_best_streak).is_equal(5)
	assert_int(back.daily_last_day).is_equal(20_001)
	assert_array(back.daily_claimed_milestones).contains_exactly([3])
	_same(s, back)


func test_a_version_1_save_is_migrated_and_drops_saved_games_of_the_old_levels() -> void:
	var old := {"schemaVersion": 1, "hintBalance": 5, "initialHintsGranted": true,
		"completed": {"c1-l01": {"stars": 3, "elapsedMillis": 90000}}, "inProgress": {"c1-l03:fr": {"found": [0], "hint": [], "hintsUsed": 1, "elapsedMillis": 5000}}}
	var result := ProgressJson.decode(JSON.stringify(old))
	assert_bool(result.ok).is_true()
	var migrated: ProgressState = result.value
	assert_int(migrated.hint_balance).is_equal(5)
	assert_bool(migrated.completed.has("c1-l01")).is_true()
	assert_bool(migrated.in_progress.is_empty()).is_true()
	assert_int(migrated.daily_last_day).is_equal(-1)
	assert_int(ProgressState.CURRENT_SCHEMA).is_equal(3)
	assert_dict(migrated.trophies).is_empty()
	assert_dict(migrated.stats).is_empty()


func _same(a: ProgressState, b: ProgressState) -> void:
	assert_str(ProgressJson.encode(a)).is_equal(ProgressJson.encode(b))


func test_progress_survives_a_round_trip() -> void:
	var decoded := ProgressJson.decode(ProgressJson.encode(_rich()))
	assert_bool(decoded.ok).is_true()
	_same(_rich(), decoded.value)
	var state: ProgressState = decoded.value
	assert_int((state.completed["c1-l01"] as LevelResult).elapsed_millis).is_equal(91_000)
	assert_int(state.last_praise).is_equal(Praise.AMAZING)
	assert_int((state.in_progress["c1-l03:fr"] as GameSnapshot).wrong_selections).is_equal(4)


func test_empty_default_state_round_trips() -> void:
	var decoded := ProgressJson.decode(ProgressJson.encode(ProgressState.new()))
	assert_bool(decoded.ok).is_true()
	_same(ProgressState.new(), decoded.value)


func test_garbage_and_missing_schema_are_rejected() -> void:
	assert_bool(ProgressJson.decode("not json").ok).is_false()
	assert_bool(ProgressJson.decode("{}").ok).is_false()
	assert_bool(ProgressJson.decode("").ok).is_false()
	assert_bool(ProgressJson.decode("[1, 2]").ok).is_false()


func test_a_save_from_a_newer_version_is_refused_instead_of_overwritten() -> void:
	var json: Dictionary = JSON.parse_string(ProgressJson.encode(_rich()))
	json["schemaVersion"] = 99
	assert_bool(ProgressJson.decode(JSON.stringify(json)).ok).is_false()


func test_older_saves_are_migrated_step_by_step() -> void:
	var old := '{"schemaVersion":1,"hintBalance":4,"initialHintsGranted":true}'
	var migrations := {1: func(json: Dictionary) -> Dictionary:
		json["hintBalance"] = int(json["hintBalance"]) + 10
		return json}
	var decoded := ProgressJson.decode(old, 2, migrations)
	assert_bool(decoded.ok).is_true()
	assert_int((decoded.value as ProgressState).hint_balance).is_equal(14)
	assert_bool(ProgressJson.decode(old, 3, migrations).ok).is_false()


func test_missing_optional_fields_fall_back_to_defaults_and_values_are_clamped() -> void:
	var decoded := ProgressJson.decode('{"schemaVersion":1,"hintBalance":-5,"completed":{"x":{"stars":9,"elapsedMillis":-1}}}')
	assert_bool(decoded.ok).is_true()
	var s: ProgressState = decoded.value
	assert_int(s.hint_balance).is_equal(0)
	assert_int((s.completed["x"] as LevelResult).stars).is_equal(3)
	assert_int((s.completed["x"] as LevelResult).elapsed_millis).is_equal(0)
	assert_int(s.last_praise).is_equal(Praise.NONE)


func test_a_save_written_before_the_interstitial_removal_still_loads() -> void:
	var legacy := '{"schemaVersion":1,"hintBalance":2,"eligibleLevelStarts":7,"lastCountedStart":"c1-l03"}'
	assert_int((ProgressJson.decode(legacy).value as ProgressState).hint_balance).is_equal(2)


func test_settings_saved_before_the_music_option_default_to_music_on() -> void:
	var legacy := '{"schemaVersion":1,"sound":false,"haptics":true,"reduceMotion":false,"largeText":false}'
	var s: AppSettings = SettingsJson.decode(legacy).value
	assert_bool(s.sound_enabled).is_false()
	assert_bool(s.music_enabled).is_true()


func test_sound_effects_volume_round_trips_and_defaults_to_sixty_percent() -> void:
	assert_float(AppSettings.new().sfx_volume).is_equal_approx(0.6, 0.001)
	var custom := AppSettings.new()
	custom.sfx_volume = 0.35
	var back: AppSettings = SettingsJson.decode(SettingsJson.encode(custom)).value
	assert_float(back.sfx_volume).is_equal_approx(0.35, 0.001)
	assert_bool(back.sound_enabled).is_true()
	custom.sfx_volume = 0.0
	assert_bool((SettingsJson.decode(SettingsJson.encode(custom)).value as AppSettings).sound_enabled).is_false()


func test_the_old_sound_switch_becomes_the_volume_and_a_stored_volume_wins() -> void:
	var off: AppSettings = SettingsJson.decode('{"schemaVersion":1,"sound":false}').value
	assert_float(off.sfx_volume).is_equal(0.0)
	var on: AppSettings = SettingsJson.decode('{"schemaVersion":1,"sound":true}').value
	assert_float(on.sfx_volume).is_equal(AppSettings.DEFAULT_SFX_VOLUME)
	var both: AppSettings = SettingsJson.decode('{"schemaVersion":1,"sound":false,"sfxVolume":0.5}').value
	assert_float(both.sfx_volume).is_equal(0.5)
	var wild: AppSettings = SettingsJson.decode('{"schemaVersion":1,"sfxVolume":7}').value
	assert_float(wild.sfx_volume).is_equal(1.0)


func test_switching_sound_back_on_restores_a_usable_volume() -> void:
	var s := AppSettings.new()
	s.sfx_volume = 0.0
	s.sound_enabled = true
	assert_float(s.sfx_volume).is_equal(AppSettings.DEFAULT_SFX_VOLUME)
	s.sound_enabled = false
	assert_float(s.sfx_volume).is_equal(0.0)


func test_sfx_gain_curve_is_quadratic_and_silent_at_zero() -> void:
	assert_float(GodotAudioManager.sfx_gain(1.0)).is_equal(1.0)
	assert_float(GodotAudioManager.sfx_gain(0.5)).is_equal_approx(0.25, 0.0001)
	assert_float(GodotAudioManager.sfx_gain(0.0)).is_equal(0.0)
	assert_float(GodotAudioManager.sfx_gain(3.0)).is_equal(1.0)


func test_settings_round_trip_including_language_none() -> void:
	var custom := AppSettings.new()
	custom.language = Language.FR
	custom.sound_enabled = false
	custom.music_enabled = false
	custom.haptics_enabled = false
	custom.reduce_motion = true
	custom.large_text = true
	var back: AppSettings = SettingsJson.decode(SettingsJson.encode(custom)).value
	assert_str(SettingsJson.encode(back)).is_equal(SettingsJson.encode(custom))
	assert_int(back.language).is_equal(Language.FR)
	var defaults: AppSettings = SettingsJson.decode(SettingsJson.encode(AppSettings.new())).value
	assert_int(defaults.language).is_equal(AppSettings.NONE)


func test_bad_settings_are_rejected() -> void:
	assert_bool(SettingsJson.decode("{}").ok).is_false()
	assert_bool(SettingsJson.decode("[").ok).is_false()
