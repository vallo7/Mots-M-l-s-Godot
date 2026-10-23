class_name UiFeaturesTest
extends GdUnitTestSuite
## Mode sombre, écran de chargement (commentaires, durée), transitions (jamais de fondu), publicités de test simulées,
## pourcentage des chapitres, chaînes de traduction.


func after_test() -> void:
	Wg.apply_theme(false)
	Strings.set_language(Language.EN)


# --- Mode sombre
func test_dark_mode_swaps_the_neutral_palette_and_back() -> void:
	var light_ink := Wg.INK
	var light_surface := Wg.SURFACE
	Wg.apply_theme(true)
	assert_bool(Wg.dark).is_true()
	assert_bool(Wg.INK != light_ink).is_true()
	assert_bool(Wg.SURFACE != light_surface).is_true()
	assert_float(Wg.BACKGROUND.get_luminance()).is_less(0.2)
	assert_float(Wg.INK.get_luminance()).is_greater(0.7)
	Wg.apply_theme(false)
	assert_that(Wg.INK).is_equal(light_ink)
	assert_that(Wg.BACKGROUND).is_equal(Color8(0xFF, 0xFF, 0xFF))


func test_new_labels_use_the_current_theme_colours() -> void:
	Wg.apply_theme(true)
	var label := Wg.label("x", 16.0)
	assert_that(label.get_theme_color("font_color")).is_equal(Wg.INK)
	label.free()


func test_text_on_bright_colours_keeps_a_fixed_dark_ink_in_both_themes() -> void:
	var fixed := Wg.INK_FIXED
	Wg.apply_theme(true)
	assert_that(Wg.INK_FIXED).is_equal(fixed)
	assert_float(Wg.INK_FIXED.get_luminance()).is_less(0.2)


# --- Chapitres
func test_every_palette_has_an_illustration_and_a_ribbon() -> void:
	for key in ["meadow", "voyage", "cosmos", "legend", "lab", "dusk", "history", "arts", "arena", "kitchen", "workshop"]:
		var theme := Wg.chapter_theme(key)
		assert_bool(ResourceLoader.exists("res://assets/illustrations/%s.svg" % theme["illustration"])).is_true()
		assert_bool(RibbonBanner.COLORS.has(theme["ribbon"])).is_true()


func test_chapter_percent_is_the_share_of_stars_earned() -> void:
	var card := ChapterCard.new()
	card.stars_max = 30
	card.stars_earned = 0
	assert_int(card.percent()).is_equal(0)
	card.stars_earned = 12
	assert_int(card.percent()).is_equal(40)
	card.stars_earned = 30
	assert_int(card.percent()).is_equal(100)
	card.stars_max = 0
	assert_int(card.percent()).is_equal(0)


# --- Chargement
func test_loading_lasts_between_two_and_three_seconds_at_least() -> void:
	assert_int(StartupSequence.MIN_DURATION_MS).is_between(2000, 3000)


func test_loading_screen_has_no_tip_texts_and_credits_the_studio() -> void:
	for language in [Language.EN, Language.FR]:
		Strings.set_language(language)
		assert_str(Strings.t("loading_studio")).is_not_equal("loading_studio")
		assert_str(Strings.t("loading_studio")).contains("Vallo Game")
		# Les anciens conseils de jeu ont disparu du jeu
		assert_str(Strings.t("loading_tip_1")).is_equal("loading_tip_1")


func test_three_glove_demos_with_grids_in_both_languages() -> void:
	assert_int(LoadingDemo.SCENARIO_COUNT).is_equal(3)
	for code in ["fr", "en"]:
		for scenario in range(3):
			var grid: Array = LoadingDemo.GRIDS[code][scenario]
			assert_int(grid.size()).is_equal(LoadingDemo.GRID_N)
			for row in grid:
				assert_int(String(row).length()).is_equal(LoadingDemo.GRID_N)
			var steps: Array = LoadingDemo.STEPS[scenario]
			if code == "en" and LoadingDemo.EN_STEPS_OVERRIDE.has(scenario):
				steps = LoadingDemo.EN_STEPS_OVERRIDE[scenario]
			for step in steps:
				if step[0] != "swipe":
					continue
				var word := ""
				var dx := signi(step[3] - step[1])
				var dy := signi(step[4] - step[2])
				var n := maxi(absi(step[3] - step[1]), absi(step[4] - step[2]))
				for k in range(n + 1):
					word += String(grid[step[2] + dy * k])[step[1] + dx * k]
				assert_bool(LoadingDemo.WORDS[code][scenario].has(word) or LoadingDemo.WORDS[code][scenario].has(word.reverse())).is_true()


func test_the_hand_image_is_imported() -> void:
	assert_bool(ResourceLoader.exists(LoadingDemo.HAND_TEXTURE)).is_true()
	assert_object(load(LoadingDemo.HAND_TEXTURE)).is_not_null()


# --- Transitions
func test_transition_styles_match_the_pages() -> void:
	var K := ScreenRoute.Kind
	assert_int(PageTransition.style_for(-1, K.HOME, true)).is_equal(PageTransition.Style.CURTAIN)
	assert_int(PageTransition.style_for(K.HOME, K.GAME, true)).is_equal(PageTransition.Style.IRIS)
	assert_int(PageTransition.style_for(K.GAME, K.HOME, false)).is_equal(PageTransition.Style.IRIS)
	assert_int(PageTransition.style_for(K.GAME, K.RESULT, true)).is_equal(PageTransition.Style.RISE)
	assert_int(PageTransition.style_for(K.HOME, K.MONUMENT, true)).is_equal(PageTransition.Style.SLIDE)
	assert_int(PageTransition.style_for(K.HOME, K.HELP, true)).is_equal(PageTransition.Style.SLIDE)
	assert_int(PageTransition.style_for(K.HOME, K.DAILY, true)).is_equal(PageTransition.Style.SLIDE)


func test_popups_are_not_pages() -> void:
	for kind in [ScreenRoute.Kind.SETTINGS, ScreenRoute.Kind.CREDITS, ScreenRoute.Kind.LANGUAGE]:
		assert_bool(ScreenRoute.is_popup_kind(kind)).is_true()
	for kind in [ScreenRoute.Kind.HOME, ScreenRoute.Kind.GAME, ScreenRoute.Kind.MONUMENT, ScreenRoute.Kind.RESULT, ScreenRoute.Kind.HELP, ScreenRoute.Kind.DAILY]:
		assert_bool(ScreenRoute.is_popup_kind(kind)).is_false()


func test_no_page_transition_fades_anything() -> void:
	# Garde-fou de conception : aucune opacité animée dans les fichiers de transition et de popup.
	for path in ["res://src/ui/page_transition.gd", "res://src/ui/iris_wrap.gd", "res://src/ui/main.gd"]:
		var code := FileAccess.get_file_as_string(path)
		assert_bool(code.contains("modulate:a") or code.contains("modulate.a") or code.contains("\"modulate\"")).is_false()


# --- Publicités de test simulées
func test_each_ad_provider_announces_its_source_and_the_credits_can_say_so() -> void:
	assert_str(AdProvider.new().provider_id()).is_equal("none")
	assert_str(SimulatedAdProvider.new(get_tree()).provider_id()).is_equal("simulated")
	for language in [Language.EN, Language.FR]:
		Strings.set_language(language)
		for id in ["none", "simulated", "admob"]:
			assert_str(Strings.t("credits_ads_source_%s" % id)).is_not_equal("credits_ads_source_%s" % id)


func test_simulated_ads_are_always_available_and_the_reward_needs_the_full_view() -> void:
	var provider := SimulatedAdProvider.new(get_tree())
	assert_bool(await provider.start()).is_true()
	assert_int(provider.rewarded_unavailable_reason()).is_equal(UnavailableReason.NONE)
	var out: Array = [null]
	var runner := func() -> void: out[0] = await provider.show_rewarded()
	runner.call()
	await await_millis(150)
	assert_bool(provider.is_full_screen_ad_showing()).is_true()
	var overlay := _find_overlay()
	assert_object(overlay).is_not_null()
	overlay._finish(true)
	await await_millis(150)
	assert_bool(provider.is_full_screen_ad_showing()).is_false()
	assert_int((out[0] as RewardedAdResult).kind).is_equal(RewardedAdResult.Kind.REWARDED)
	assert_str((out[0] as RewardedAdResult).reward_id).is_not_empty()


func test_closing_a_simulated_rewarded_ad_early_gives_no_reward() -> void:
	var provider := SimulatedAdProvider.new(get_tree())
	var out: Array = [null]
	var runner := func() -> void: out[0] = await provider.show_rewarded()
	runner.call()
	await await_millis(150)
	_find_overlay()._finish(false)
	await await_millis(150)
	assert_int((out[0] as RewardedAdResult).kind).is_equal(RewardedAdResult.Kind.DISMISSED)


func _find_overlay() -> Control:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 100 and child.get_child_count() > 0:
			return child.get_child(0)
	return null


# --- Chaînes de traduction
func test_every_translation_row_has_both_languages_and_no_duplicate_key() -> void:
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	var header := file.get_csv_line()
	assert_int(header.size()).is_equal(3)
	var keys := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		assert_bool(keys.has(row[0])).is_false()
		keys[row[0]] = true
		assert_str(row[1]).is_not_empty()
		assert_str(row[2]).is_not_empty()
	assert_bool(keys.has("settings_restore")).is_false()  # le bouton « restaurer » a disparu
