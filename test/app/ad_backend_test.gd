class_name AdBackendTest
extends GdUnitTestSuite
## Choix du fournisseur de publicités (AppController.choose_ad_backend) : le vrai AdMob dès que le plugin natif est dans l'APK,
## les annonces simulées seulement en debug sans plugin, rien en release sans plugin.


func test_real_admob_when_the_native_plugin_is_in_the_apk() -> void:
	assert_int(AppController.choose_ad_backend(true, true, true, true)).is_equal(AppController.AdBackend.ADMOB)
	assert_int(AppController.choose_ad_backend(true, true, true, false)).is_equal(AppController.AdBackend.ADMOB)


func test_simulated_ads_in_a_debug_build_without_the_plugin() -> void:
	assert_int(AppController.choose_ad_backend(true, false, true, true)).is_equal(AppController.AdBackend.SIMULATED)
	assert_int(AppController.choose_ad_backend(false, false, true, true)).is_equal(AppController.AdBackend.SIMULATED)


func test_no_ads_in_a_release_build_without_the_plugin() -> void:
	assert_int(AppController.choose_ad_backend(true, false, true, false)).is_equal(AppController.AdBackend.NONE)


func test_native_plugin_alone_is_not_enough_without_the_provider_script() -> void:
	assert_int(AppController.choose_ad_backend(true, true, false, true)).is_equal(AppController.AdBackend.SIMULATED)


func test_never_real_admob_outside_android() -> void:
	assert_int(AppController.choose_ad_backend(false, true, true, true)).is_equal(AppController.AdBackend.SIMULATED)
	assert_int(AppController.choose_ad_backend(false, true, true, false)).is_equal(AppController.AdBackend.NONE)


func test_resource_loader_cannot_detect_the_plugin_config_file() -> void:
	# Garde-fou documentaire : c'était l'ancien test de présence du plugin ; un .cfg n'est pas une ressource.
	assert_bool(ResourceLoader.exists("res://project.godot")).is_false()
	assert_bool(ResourceLoader.exists(AppController.ADMOB_PROVIDER_SCRIPT)).is_true()
