class_name AdMobAdProvider
extends AdProvider
## Google Mobile Ads via le plugin « Godot AdMob » de Poing Studios (5.x) — IDENTIFIANTS DE TEST UNIQUEMENT.
## Ne bloque jamais le jeu : toute indisponibilité (hors ligne, pas d'annonce, erreur, consentement refusé) devient
## un résultat explicite, sans exception. Ce fichier n'est chargé que si le plugin est installé (voir App.create_ads).
## L'API (consentement UMP, MobileAds.initialize, chargeurs, AdView) a été relue contre le code source du plugin v5.1.0.
## Reste à vérifier sur appareil (voir docs/ADS.md) : le build Gradle avec le plugin installé par scripts/ci/install_admob.sh.

signal _rewarded_finished(result: RewardedAdResult)
signal _return_finished(shown: bool)
signal _sdk_ready()

## Une annonce d'ouverture expire au bout de 4 h : on ne l'affiche jamais périmée.
const APP_OPEN_TTL_MS := 4 * 60 * 60 * 1000

var _banner_id: String
var _app_open_id: String
var _rewarded_id: String
var _consent := AdMobConsent.new()
var _tree: SceneTree
var _rewarded: RewardedAd
var _app_open: AppOpenAd
var _app_open_loaded_at: int = 0
var _loading_rewarded := false
var _loading_app_open := false
var _initialized := false
var _can_request_ads := false
var _full_screen_showing := false
var _rewarded_error: int = UnavailableReason.NOT_LOADED
var _banner: AdView


func _init(tree: SceneTree) -> void:
	_tree = tree
	var config: Variant = JsonUtil.parse_object(FileAccess.get_file_as_string("res://data/ads_config.json"))
	var cfg: Dictionary = config if config != null else {}
	_banner_id = JsonUtil.get_string(cfg, "banner_unit_id")
	_app_open_id = JsonUtil.get_string(cfg, "app_open_unit_id")
	_rewarded_id = JsonUtil.get_string(cfg, "rewarded_unit_id")


## Consentement puis initialisation du SDK. Asynchrone. Renvoie true si les annonces sont autorisées.
func start() -> bool:
	_can_request_ads = await _consent.request_consent(_tree)
	if _can_request_ads and not _initialized:
		_initialized = true
		await _initialize_sdk()
		prefetch()
	return _can_request_ads


## Initialise le SDK et attend qu'il ait fini : les demandes d'annonces envoyées avant la fin échoueraient.
## Garde-fou : on n'attend jamais plus de 10 s (le jeu ne dépend pas des annonces).
func _initialize_sdk() -> void:
	var done := [false]
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		if not done[0]:
			done[0] = true
			_sdk_ready.emit()
	MobileAds.initialize(listener)
	var timer := _tree.create_timer(10.0)
	timer.timeout.connect(func() -> void:
		if not done[0]:
			done[0] = true
			_sdk_ready.emit())
	if not done[0]:
		await _sdk_ready


## Précharge (prefetch) les annonces plein écran (au démarrage et après chaque affichage).
func prefetch() -> void:
	if not _initialized or not _can_request_ads:
		return
	_load_rewarded()
	_load_app_open()


func _load_rewarded() -> void:
	if _rewarded != null or _loading_rewarded:
		return
	_loading_rewarded = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		_loading_rewarded = false
		_rewarded_error = UnavailableReason.NONE
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_rewarded = null
		_loading_rewarded = false
		_rewarded_error = _classify(error)
	RewardedAdLoader.new().load(_rewarded_id, AdRequest.new(), callback)


func _load_app_open() -> void:
	if _loading_app_open or (_app_open != null and not _is_app_open_expired()):
		return
	_loading_app_open = true
	var callback := AppOpenAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: AppOpenAd) -> void:
		_app_open = ad
		_app_open_loaded_at = Time.get_ticks_msec()
		_loading_app_open = false
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_app_open = null
		_loading_app_open = false
	AppOpenAdLoader.new().load(_app_open_id, AdRequest.new(), callback)


func _is_app_open_expired() -> bool:
	return Time.get_ticks_msec() - _app_open_loaded_at >= APP_OPEN_TTL_MS


## Hors ligne (réseau), pas d'annonce disponible (« no fill »), ou erreur générique.
func _classify(error: LoadAdError) -> int:
	var message := str(error.message).to_lower()
	if "network" in message or "internet" in message or "offline" in message:
		return UnavailableReason.OFFLINE
	if "no fill" in message or "no ad" in message:
		return UnavailableReason.NO_FILL
	return UnavailableReason.ERROR


func rewarded_unavailable_reason() -> int:
	if not _can_request_ads:
		return UnavailableReason.ERROR
	if _rewarded == null:
		prefetch()
		return _rewarded_error if _rewarded_error != UnavailableReason.NONE else UnavailableReason.NOT_LOADED
	return UnavailableReason.NONE


func show_rewarded() -> RewardedAdResult:
	var ad := _rewarded
	if ad == null:
		return RewardedAdResult.unavailable(UnavailableReason.NOT_LOADED)
	_rewarded = null
	var earned := [false]
	var reward_id := "%d-%d" % [Time.get_ticks_usec(), randi()]  # identifiant unique de CETTE diffusion
	var finish := func(result: RewardedAdResult) -> void:
		_full_screen_showing = false
		ad.destroy()
		prefetch()  # avant l'émission : l'appelant reprend la main dès `emit`
		_rewarded_finished.emit(result)
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = func() -> void:
		finish.call(RewardedAdResult.rewarded(reward_id) if earned[0] else RewardedAdResult.dismissed())
	content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		finish.call(RewardedAdResult.unavailable(UnavailableReason.ERROR))
	ad.full_screen_content_callback = content
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	_full_screen_showing = true
	ad.show(listener)
	return await _rewarded_finished


func show_return_ad_if_ready() -> bool:
	var ad := _app_open
	if ad == null or _is_app_open_expired() or _full_screen_showing:
		prefetch()
		return false
	_app_open = null
	var finish := func(shown: bool) -> void:
		_full_screen_showing = false
		ad.destroy()
		prefetch()
		_return_finished.emit(shown)
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = func() -> void: finish.call(true)
	content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: finish.call(false)
	ad.full_screen_content_callback = content
	_full_screen_showing = true
	ad.show()
	return await _return_finished


func is_full_screen_ad_showing() -> bool:
	return _full_screen_showing


func set_banner_visible(is_visible: bool) -> void:
	if is_visible and _banner == null and _can_request_ads and _initialized:
		var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(_banner_id, size, AdPosition.BOTTOM)
		_banner.load_ad(AdRequest.new())
	elif not is_visible and _banner != null:
		_banner.destroy()
		_banner = null


func privacy_options_required() -> bool:
	return _can_request_ads and _consent.privacy_options_required()


func show_privacy_options() -> void:
	_consent.show_privacy_options()
