class_name PraiseAndSoundsTest
extends GdUnitTestSuite
## Vérifie que les audios fournis sont réellement déclarés et présents dans le projet.

var _map: PraiseMap


func before() -> void:
	_map = PraiseMap.parse(FileAccess.get_file_as_string(PraiseMap.FILE))


func test_praise_map_parses() -> void:
	assert_object(_map).is_not_null()


func test_ladder_in_the_map_matches_the_praise_order() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PraiseMap.FILE))
	assert_array(root["ladder"]).contains_exactly(Praise.KEYS)


func test_every_praise_resolves_to_an_existing_non_empty_file_in_both_languages() -> void:
	for praise in range(Praise.KEYS.size()):
		for language in Language.ALL:
			var voice := _map.resolve(praise, language)
			assert_object(voice).is_not_null()
			assert_bool(FileAccess.file_exists(voice.asset_path)).is_true()
			assert_bool(FileAccess.open(voice.asset_path, FileAccess.READ).get_length() > 0).is_true()
			assert_bool(voice.volume >= 0.1 and voice.volume <= 1.0).is_true()


func test_file_names_follow_the_stable_lowercase_mp3_convention() -> void:
	for praise in range(Praise.KEYS.size()):
		assert_str(_map.resolve(praise, Language.EN).asset_path.get_file()).is_equal(Praise.key_of(praise) + ".mp3")


func test_an_unknown_praise_language_entry_falls_back_to_no_voice() -> void:
	var empty := PraiseMap.parse('{"voices":{"en":{}}}')
	for praise in range(Praise.KEYS.size()):
		assert_object(empty.resolve(praise, Language.FR)).is_null()
	assert_object(PraiseMap.parse("garbage")).is_null()


func test_every_declared_file_exists() -> void:
	for path in _map.all_asset_paths():
		assert_bool(FileAccess.file_exists(path)).is_true()


func test_every_ui_sound_has_an_existing_wav_file() -> void:
	for sound in UiSounds.all_sounds():
		var path := UiSounds.asset_path(sound)
		var file := FileAccess.open(path, FileAccess.READ)
		assert_object(file).is_not_null()
		assert_bool(file.get_length() > 1000).is_true()
		assert_str(file.get_buffer(4).get_string_from_ascii()).is_equal("RIFF")
		file.seek(8)
		assert_str(file.get_buffer(4).get_string_from_ascii()).is_equal("WAVE")


func test_volumes_are_moderate_and_the_file_names_are_unique() -> void:
	var names := {}
	for sound in UiSounds.all_sounds():
		names[UiSounds.file_for(sound)] = true
		assert_bool(UiSounds.volume_for(sound) >= 0.3 and UiSounds.volume_for(sound) <= 0.95).is_true()
	assert_int(names.size()).is_equal(UiSounds.all_sounds().size())


func test_ui_sounds_stay_short_enough_to_be_preloaded_in_memory() -> void:
	for sound in UiSounds.all_sounds():
		assert_bool(FileAccess.open(UiSounds.asset_path(sound), FileAccess.READ).get_length() < 200_000).is_true()
