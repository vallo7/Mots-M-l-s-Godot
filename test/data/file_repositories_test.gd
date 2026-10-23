class_name FileRepositoriesTest
extends GdUnitTestSuite
## Dépôts de persistance : écriture atomique, copie de secours, fichier corrompu.

const DIR := "user://test_repos"
var _progress_path: String
var _settings_path: String


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_progress_path = DIR + "/progress.json"
	_settings_path = DIR + "/settings.json"
	_clean()


func after_test() -> void:
	_clean()


func _clean() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func test_progress_is_persisted_and_reloaded() -> void:
	var repo := FileProgressRepository.new(_progress_path)
	repo.update(func(s: ProgressState) -> ProgressState: return ProgressRules.initialize(s))
	repo.update(func(s: ProgressState) -> ProgressState: return ProgressRules.complete_level(s, "c1-l01", 3, 42_000, Praise.GREAT))
	var reloaded := FileProgressRepository.new(_progress_path)
	assert_int(reloaded.read().hint_balance).is_equal(2)
	assert_int((reloaded.read().completed["c1-l01"] as LevelResult).elapsed_millis).is_equal(42_000)
	assert_bool(FileAccess.file_exists(_progress_path + ".bak")).is_true()


func test_a_fresh_repository_starts_from_the_initial_state() -> void:
	var repo := FileProgressRepository.new(_progress_path)
	assert_int(repo.read().hint_balance).is_equal(0)
	assert_int(repo.read().completed.size()).is_equal(0)


func test_a_corrupt_file_is_kept_aside_and_the_backup_is_restored() -> void:
	var repo := FileProgressRepository.new(_progress_path)
	repo.update(func(s: ProgressState) -> ProgressState: return ProgressRules.initialize(s))
	var file := FileAccess.open(_progress_path, FileAccess.WRITE)
	file.store_string("{ceci n'est pas du json")
	file.close()
	var reloaded := FileProgressRepository.new(_progress_path)
	assert_int(reloaded.read().hint_balance).is_equal(2)
	assert_bool(FileAccess.file_exists(_progress_path + ".corrupt")).is_true()


func test_a_corrupt_file_without_backup_falls_back_to_the_initial_state() -> void:
	var file := FileAccess.open(_progress_path, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	var repo := FileProgressRepository.new(_progress_path)
	assert_int(repo.read().hint_balance).is_equal(0)
	assert_bool(FileAccess.file_exists(_progress_path + ".corrupt")).is_true()


func test_an_unchanged_update_does_not_rewrite_the_file() -> void:
	var repo := FileProgressRepository.new(_progress_path)
	repo.update(func(s: ProgressState) -> ProgressState: return s)
	assert_bool(FileAccess.file_exists(_progress_path)).is_false()


func test_a_failed_write_leaves_the_state_unchanged_and_reports_null() -> void:
	var repo := FileProgressRepository.new("user://dossier_inexistant/progress.json")
	var result := repo.update(func(s: ProgressState) -> ProgressState: return ProgressRules.initialize(s))
	assert_object(result).is_null()
	assert_int(repo.read().hint_balance).is_equal(0)


func test_music_volume_and_dark_mode_are_persisted() -> void:
	var repo := FileSettingsRepository.new(_settings_path)
	repo.update(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.music_volume = 0.35
		n.dark_mode = true
		return n)
	var reloaded := FileSettingsRepository.new(_settings_path).read()
	assert_float(reloaded.music_volume).is_equal_approx(0.35, 0.001)
	assert_bool(reloaded.dark_mode).is_true()
	assert_bool(reloaded.music_enabled).is_true()


func test_legacy_music_switch_becomes_a_volume() -> void:
	assert_float((SettingsJson.decode("{\"schemaVersion\": 1, \"music\": false}").value as AppSettings).music_volume).is_equal(0.0)
	assert_float((SettingsJson.decode("{\"schemaVersion\": 1, \"music\": true}").value as AppSettings).music_volume).is_equal_approx(AppSettings.DEFAULT_MUSIC_VOLUME, 0.001)
	var s := AppSettings.new()
	s.music_enabled = false
	assert_float(s.music_volume).is_equal(0.0)
	s.music_enabled = true
	assert_float(s.music_volume).is_equal_approx(AppSettings.DEFAULT_MUSIC_VOLUME, 0.001)


func test_the_volume_curve_is_silent_at_zero_and_monotonic() -> void:
	assert_float(GodotAudioManager.music_gain(0.0)).is_equal(0.0)
	assert_float(GodotAudioManager.music_gain(0.6)).is_between(0.28, 0.36)
	assert_float(GodotAudioManager.music_gain(1.0)).is_greater(GodotAudioManager.music_gain(0.6))


func test_settings_are_persisted_and_a_garbage_file_gives_defaults() -> void:
	var repo := FileSettingsRepository.new(_settings_path)
	repo.update(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.language = Language.FR
		n.music_enabled = false
		return n)
	var reloaded := FileSettingsRepository.new(_settings_path)
	assert_int(reloaded.read().language).is_equal(Language.FR)
	assert_bool(reloaded.read().music_enabled).is_false()
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	assert_int(FileSettingsRepository.new(_settings_path).read().language).is_equal(AppSettings.NONE)
