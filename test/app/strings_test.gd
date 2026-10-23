class_name StringsTest
extends GdUnitTestSuite
## Les textes de l'interface ne doivent jamais s'afficher sous forme de clé brute (« home_play », « settings_title »…).

const SAMPLE_KEYS: Array[String] = [
	"home_play", "home_resume", "dialog_quit_title", "dialog_quit_body", "settings_title", "settings_language",
	"result_title", "praise_amazing", "game_hint_more", "band_medium", "home_chapter_level",
]


func after_test() -> void:
	Strings.set_language(Language.EN)


func test_translation_files_are_declared_in_the_project_settings() -> void:
	var declared: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for path in Strings.TRANSLATION_FILES:
		assert_bool(declared.has(path)).is_true()


func test_every_sample_key_is_translated_in_both_languages() -> void:
	for language in [Language.EN, Language.FR]:
		Strings.set_language(language)
		for key in SAMPLE_KEYS:
			assert_str(Strings.t(key)).is_not_equal(key)


func test_arguments_are_substituted() -> void:
	Strings.set_language(Language.EN)
	assert_str(Strings.t("home_chapter_level", [1, 5])).contains("5")
