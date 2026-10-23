class_name AppController
extends Node
## Source de vérité de l'application (autoload `App`) : navigation, progression, réglages, lancement des
## parties, publicités de retour. Les règles de jeu vivent dans src/domain ; ce nœud ne fait que les orchestrer.

enum Phase { LOADING, FAILED, READY }
enum NavDirection { FORWARD, BACK }

const MESSAGE_SECONDS := 2.3
## Durée minimale de l'écran de chargement (modifiable pour les tests).
var startup_minimum_ms := StartupSequence.MIN_DURATION_MS
const PROGRESS_PATH := "user://progress.json"
const SETTINGS_PATH := "user://settings.json"

signal phase_changed()
signal loading_progressed(progress: float, label_key: String)
signal progress_changed()
signal settings_changed()
signal stack_changed()
signal message_changed()
signal game_started(controller: GameController)
## Le défi du jour est prêt, ou son état a changé (nouveau jour, nouvelle langue, victoire).
signal daily_changed()
## Un trophée vient d'être débloqué (annoncé une seule fois par trophée et par lancement) : bandeau « Trophée débloqué ».
signal trophy_unlocked(trophy_id: String)

var phase: int = Phase.LOADING
var loading_progress := 0.0
var loading_label_key := "loading_step_read"
var startup_issues: Array[ValidationIssue] = []
var catalog: LevelCatalog
var progress := ProgressState.new()
var settings := AppSettings.new()
var language: int = Language.EN
var stack: Array[ScreenRoute] = [ScreenRoute.home()]
var direction: int = NavDirection.FORWARD
var message_text := ""
var message_id := 0
var ads_enabled := false
## Vrai quand le formulaire de consentement impose d'offrir l'accès aux choix de confidentialité (règlement européen).
var privacy_options_required := false
var busy := false
var active_game: GameController
var safe_area_insets := Vector4.ZERO  ## gauche, haut, droite, bas (en unités de la fenêtre de référence)

var level_repository: LevelRepository = AssetLevelRepository.new()
var progress_repository: ProgressRepository
var settings_repository: SettingsRepository
var ads: AdProvider = AdProvider.new()
var audio: GodotAudioManager
var haptics: GodotHapticsManager

## Défi du jour : grille de la langue courante pour `daily_today`, préparée dans un thread (voir daily_prepare).
var daily_level: Level
var daily_today := -1
var daily_preparing := false
var _daily_thread: Thread
var _daily_retry_after := 0

var _use_cases: GameUseCases
var _announced_trophies: Dictionary = {}  ## id -> true : trophées déjà connus du joueur (ou annoncés)
var _rng := RandomNumberGenerator.new()
var _game_token := 0
var _started := false
# Publicité de retour dans l'appli (horloge monotone : jamais l'heure civile du téléphone).
var _stopped_at: int = -1
var _last_return_ad_at: int = -1
var _stopped_while_ad_showing := false
var _session_started := false


func _ready() -> void:
	_rng.randomize()
	get_tree().quit_on_go_back = false
	process_mode = Node.PROCESS_MODE_ALWAYS


## Démarrage à froid (appelé une fois par la scène principale). Asynchrone : `await` possible.
func start() -> void:
	if _started:
		return
	_started = true
	progress_repository = FileProgressRepository.new(PROGRESS_PATH)
	settings_repository = FileSettingsRepository.new(SETTINGS_PATH)
	audio = GodotAudioManager.new()
	haptics = GodotHapticsManager.new()
	Feedback.set_managers(audio, haptics)
	_apply_settings(settings_repository.read())  # langue et options appliquées dès l'écran de chargement
	Icons.preload_all()

	var sequence := StartupSequence.new(
		get_tree(), level_repository,
		func() -> void:
			progress_repository.update(func(s: ProgressState) -> ProgressState: return ProgressRules.initialize(s)),  # 2 indices offerts, une seule fois
		func() -> void: audio.preload_all(),
		startup_minimum_ms
	)
	sequence.progressed.connect(func(value: float, step: int) -> void:
		loading_progress = value
		loading_label_key = ["loading_step_read", "loading_step_check", "loading_step_progress", "loading_step_audio", "loading_step_ready"][step]
		loading_progressed.emit(value, loading_label_key))
	ads = _create_ads()
	var ok: bool = await sequence.run()
	if not ok:
		push_error("Démarrage impossible : %s" % sequence.error)
		for issue in sequence.issues:
			push_error(str(issue))
		startup_issues = sequence.issues
		phase = Phase.FAILED
		phase_changed.emit()
		return
	_finish_startup(sequence.catalog)


## Choix du fournisseur de publicités :
##  1. build Android « AdMob » (Gradle + plugin, caractéristique d'export `admob`) : vraies annonces de TEST de Google ;
##  2. sinon, build de debug (éditeur, APK sans Gradle — la configuration par défaut) : annonces de test SIMULÉES, pour que
##     tout le parcours (bannière, récompense d'un indice, annonce de retour) fonctionne et se teste sans SDK ;
##  3. sinon (build de release sans plugin) : aucune publicité.
## Le SDK Google est une bibliothèque Android que Godot n'embarque que dans un build Gradle : sans Gradle, aucune vraie
## annonce n'est possible (voir docs/ADS.md).
func _create_ads() -> AdProvider:
	var real_ads := OS.get_name() == "Android" and OS.has_feature("admob") \
		and ResourceLoader.exists("res://addons/admob/plugin.cfg") and ResourceLoader.exists("res://src/ads/admob_ad_provider.gd")
	if real_ads:
		var script: GDScript = load("res://src/ads/admob_ad_provider.gd")
		return script.new(get_tree())
	if OS.is_debug_build():
		return SimulatedAdProvider.new(get_tree())
	return AdProvider.new()


## Consentement puis initialisation des annonces ; n'arrête jamais le jeu (en arrière-plan de l'écran d'accueil).
func _start_ads() -> void:
	if not ads.has_method("start"):
		return
	var allowed: bool = await ads.start()
	ads_enabled = allowed
	privacy_options_required = ads.privacy_options_required()
	progress_changed.emit()


func _finish_startup(loaded: LevelCatalog) -> void:
	catalog = loaded
	progress = progress_repository.read()
	var current_settings := settings_repository.read()
	_apply_settings(current_settings)
	_use_cases = GameUseCases.new(catalog, progress_repository, ads, func(from: int, until: int) -> int: return _rng.randi_range(from, until - 1))
	# Trophées déjà mérités (mise à jour d'une sauvegarde existante) : attribués en silence, signalés dans le menu (« Nouveau »).
	_use_cases.sync_trophies()
	progress = progress_repository.read()
	for id in progress.trophies:
		_announced_trophies[id] = true
	stack = [ScreenRoute.home()]
	phase = Phase.READY
	phase_changed.emit()
	_session_started = true
	_start_ads()
	daily_prepare()


func _system_language_code() -> String:
	return OS.get_locale_language()


func _apply_settings(new_settings: AppSettings) -> void:
	settings = new_settings
	language = settings.resolve_language(_system_language_code())
	Strings.set_language(language)
	Wg.reduce_motion = settings.reduce_motion or _system_animations_disabled()
	Wg.text_scale = 1.15 if settings.large_text else 1.0
	Wg.apply_theme(settings.dark_mode)
	if catalog != null and daily_level != null and not daily_level.variants.has(language):
		daily_prepare.call_deferred()  # la grille du jour existe par langue : on prépare celle de la nouvelle langue
	if audio != null:
		audio.set_sfx_volume(settings.sfx_volume)
		audio.set_music_volume(settings.music_volume)
	if haptics != null:
		haptics.set_enabled(settings.haptics_enabled)


## Vrai si l'utilisateur a supprimé les animations dans les réglages système (non exposé par Godot : faux).
func _system_animations_disabled() -> bool:
	return false


# ---- Défi du jour
## Prépare (hors du fil principal) la grille du jour pour la langue courante. Sans effet si elle est déjà prête.
func daily_prepare() -> void:
	if catalog == null or daily_preparing:
		return
	var day := DailyChallenge.today_index()
	if daily_level != null and daily_today == day and daily_level.variants.has(language):
		return
	daily_preparing = true
	daily_changed.emit()
	_daily_thread = Thread.new()
	_daily_thread.start(_generate_daily.bind(day, language))


func _generate_daily(day: int, for_language: int) -> void:
	var level := DailyLevelFactory.create(catalog, day, for_language)
	_on_daily_generated.call_deferred(day, for_language, level)


func _on_daily_generated(day: int, for_language: int, level: Level) -> void:
	if _daily_thread != null:
		_daily_thread.wait_to_finish()
		_daily_thread = null
	daily_preparing = false
	if day != DailyChallenge.today_index() or for_language != language:
		daily_prepare()  # le jour ou la langue a changé pendant la préparation
	elif level != null:
		daily_level = level
		daily_today = day
		daily_changed.emit()
	else:
		# Ne devrait jamais arriver (vérifié sur 800 jours) : on réessaiera dans 30 s au plus tôt, sans boucler.
		push_warning("Défi du jour %d : grille non fabriquée" % day)
		_daily_retry_after = Time.get_ticks_msec() + 30_000
		daily_changed.emit()


## Appelé régulièrement par les écrans qui affichent le défi : minuit passé -> nouveau défi.
func check_day_rollover() -> void:
	if catalog != null and DailyChallenge.today_index() != daily_today and Time.get_ticks_msec() >= _daily_retry_after:
		daily_prepare()
		daily_changed.emit()


func daily_model() -> DailyModel:
	var today := DailyChallenge.today_index()
	var ready_level: Level = daily_level if (daily_level != null and daily_today == today and daily_level.variants.has(language)) else null
	var resumable := false
	if ready_level != null:
		resumable = progress.in_progress.has(ProgressRules.snapshot_key(ready_level.id, language))
	return DailyModel.build(progress, today, ready_level, resumable, DailyChallenge.seconds_until_tomorrow())


## Tap sur « Jouer » : lance (ou reprend) le défi du jour.
func play_daily() -> void:
	var model := daily_model()
	match model.status:
		DailyModel.Status.DONE:
			show_message("msg_daily_done")
		DailyModel.Status.LOADING:
			show_message("msg_daily_loading")
			daily_prepare()
		_:
			_launch_level(daily_level)


func go_daily() -> void:
	_close_game()
	_refresh_progress()
	stack = [ScreenRoute.home(), ScreenRoute.daily()]
	direction = NavDirection.BACK
	stack_changed.emit()


func home_model() -> HomeModel:
	return HomeModelBuilder.build(catalog, progress, language) if catalog != null else null


func _refresh_progress() -> void:
	progress = progress_repository.read()
	_announce_new_trophies()
	progress_changed.emit()


## Annonce chaque trophée débloqué depuis la dernière lecture (victoire, indice, cadeau, défi du jour).
func _announce_new_trophies() -> void:
	for trophy in TrophyCatalog.all():
		if progress.trophies.has(trophy.id) and not _announced_trophies.has(trophy.id):
			_announced_trophies[trophy.id] = true
			trophy_unlocked.emit(trophy.id)


# ---- Réglages
func update_settings(transform: Callable) -> void:
	var updated := settings_repository.update(transform)
	if updated == null:
		show_message("msg_error_generic")
		return
	_apply_settings(updated)
	settings_changed.emit()


## Choix de la langue : `Language.FR`, `Language.EN` ou `AppSettings.NONE` (langue du téléphone).
func set_language_choice(choice: int) -> void:
	update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.language = choice
		return n)


## Volume de la musique pendant que le curseur est tiré : appliqué tout de suite au son, écrit une seule fois au relâchement.
func preview_music_volume(volume: float) -> void:
	if audio != null:
		audio.set_music_volume(volume)


func commit_music_volume(volume: float) -> void:
	update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.music_volume = clampf(volume, 0.0, 1.0)
		return n)


## Volume des effets sonores : appliqué tout de suite pendant que le curseur est tiré, écrit une seule fois au relâchement
## (un clic de contrôle se fait alors entendre au nouveau niveau).
func preview_sfx_volume(volume: float) -> void:
	if audio != null:
		audio.set_sfx_volume(volume)


func commit_sfx_volume(volume: float) -> void:
	update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.sfx_volume = clampf(volume, 0.0, 1.0)
		return n)
	if audio != null:
		audio.play(Sound.CLICK)


# ---- Navigation
func _push(route: ScreenRoute) -> void:
	stack.append(route)
	direction = NavDirection.FORWARD
	stack_changed.emit()


func _pop() -> void:
	if stack.size() > 1:
		stack.pop_back()
		direction = NavDirection.BACK
		stack_changed.emit()


func current_route() -> ScreenRoute:
	return stack[stack.size() - 1]


func open_settings() -> void:
	_push(ScreenRoute.settings())


func open_monument() -> void:
	_push(ScreenRoute.monument())


func open_credits() -> void:
	_push(ScreenRoute.credits())


func open_language() -> void:
	_push(ScreenRoute.language())


func open_help() -> void:
	_push(ScreenRoute.help())


func open_trophies() -> void:
	_push(ScreenRoute.trophies())


## Le menu des trophées a été ouvert : tout ce qui est débloqué est « vu » (éteint la pastille de l'accueil).
func mark_trophies_seen() -> void:
	if _use_cases == null:
		return
	_use_cases.mark_trophies_seen()
	progress = progress_repository.read()


func open_daily() -> void:
	_push(ScreenRoute.daily())


## Rouvre le formulaire de consentement (nécessite la brique publicitaire ; sans effet sinon).
func open_privacy_options() -> void:
	ads.show_privacy_options()


func go_home() -> void:
	_close_game()
	_refresh_progress()
	stack = [ScreenRoute.home()]
	direction = NavDirection.BACK
	stack_changed.emit()


## Bouton Retour (physique, gestuel ou à l'écran) : ferme le menu courant ; le jeu gère sa propre confirmation.
func on_back() -> void:
	match current_route().kind:
		ScreenRoute.Kind.GAME:
			if active_game != null:
				active_game.on_back_requested()
		ScreenRoute.Kind.RESULT:
			go_home()
		ScreenRoute.Kind.HOME:
			pass
		_:
			_pop()


# ---- Lancement des parties
func play_current() -> void:
	if catalog == null:
		return
	var level := ProgressRules.current_level(catalog, progress)
	if level != null:
		_launch_level(level)


## Tap sur un chapitre du carrousel d'accueil : le chapitre en cours ouvre son niveau en cours ;
## un chapitre terminé ou verrouillé répond par un court message (jamais de niveau gagné rejoué).
func open_chapter(chapter_index: int) -> void:
	var home := home_model()
	if home == null:
		return
	for card in home.chapters:
		if card.index == chapter_index:
			match card.status:
				ChapterStatus.CURRENT:
					if card.current_level != null:
						_launch_level(card.current_level)
				ChapterStatus.COMPLETED:
					show_message("msg_chapter_completed")
				_:
					show_message("msg_chapter_locked")
			return


## Tap sur un niveau du monument : seul le niveau disponible se lance.
func open_level(level_id: String) -> void:
	if catalog == null:
		return
	var level := catalog.level_by_id(level_id)
	if level == null:
		return
	match ProgressRules.status_of(catalog, progress, level_id):
		LevelStatus.AVAILABLE:
			_launch_level(level)
		LevelStatus.COMPLETED:
			show_message("msg_level_completed")
		_:
			show_message("msg_level_locked")


func play_next_after(result: VictoryResult) -> void:
	var next := catalog.level_by_id(result.next_level_id) if not result.next_level_id.is_empty() else null
	if next != null:
		_launch_level(next)
	else:
		go_home()


func _launch_level(level: Level) -> void:
	if _use_cases == null or busy:
		return
	busy = true
	_close_game()
	_game_token += 1
	var controller := GameController.new(level, language, _use_cases, func() -> int: return progress_repository.read().hint_balance)
	controller.victory.connect(_on_victory)
	controller.leave_requested.connect(go_daily if level.is_daily() else go_home)
	controller.progress_changed.connect(_refresh_progress)
	controller.message_requested.connect(func(key: String, quantity: int, plural: bool) -> void: show_message(key, quantity, plural))
	active_game = controller
	add_child(controller)
	progress = progress_repository.read()
	var route_stack: Array[ScreenRoute] = [ScreenRoute.home()]
	if level.is_daily():
		route_stack.append(ScreenRoute.daily())  # quitter la partie ramène à la page du défi
	route_stack.append(ScreenRoute.game(level.id, _game_token))
	stack = route_stack
	direction = NavDirection.FORWARD
	game_started.emit(controller)
	stack_changed.emit()
	busy = false


func _on_victory(result: VictoryResult) -> void:
	_close_game()
	_refresh_progress()
	stack = [ScreenRoute.home(), ScreenRoute.result_of(result)]
	direction = NavDirection.FORWARD
	stack_changed.emit()


func _close_game() -> void:
	if active_game != null:
		active_game.close()
		active_game = null


# ---- Trophée de chapitre
func claim_gift(chapter_index: int) -> void:
	if _use_cases == null:
		return
	var amount := _use_cases.claim_gift(chapter_index)
	if amount > 0:
		audio.play(Sound.GIFT)
		haptics.perform(HapticEffect.SUCCESS)
		show_message("msg_gift_earned", amount, true)
	_refresh_progress()


# ---- Messages
## `plural` : `key` désigne un pluriel (`<clé>_one` / `<clé>_other`) dont `quantity` est la quantité.
func show_message(key: String, quantity: int = 0, plural: bool = false) -> void:
	message_text = Strings.n(key, quantity) if plural else Strings.t(key)
	message_id += 1
	var id := message_id
	message_changed.emit()
	await get_tree().create_timer(MESSAGE_SECONDS).timeout
	if message_id == id:
		message_text = ""
		message_changed.emit()


# ---- Publicités / cycle de vie
func on_consent_result(can_request_ads: bool) -> void:
	ads_enabled = can_request_ads


func on_app_started() -> void:
	check_day_rollover()
	if audio != null:
		audio.on_app_started()
	if active_game != null:
		active_game.on_resume()
	if _stopped_at < 0:
		return
	var stopped_at := _stopped_at
	_stopped_at = -1
	var now := Time.get_ticks_msec()
	var moment := AdMoment.new()
	moment.is_first_render = phase != Phase.READY
	moment.is_grid_being_touched = active_game != null and active_game.is_grid_being_touched()
	moment.is_resolving_win = current_route().kind == ScreenRoute.Kind.RESULT
	moment.is_sensitive_action_pending = busy
	var since_last := ReturnAdPolicy.NEVER if _last_return_ad_at < 0 else now - _last_return_ad_at
	var show := ads_enabled and ReturnAdPolicy.should_show(
		now - stopped_at, since_last, _stopped_while_ad_showing, _session_started, moment
	)
	_stopped_while_ad_showing = false
	if not show:
		return
	# Une publicité qui échoue, n'est pas prête ou est hors ligne ne bloque jamais le jeu.
	@warning_ignore("redundant_await")  # AdProvider est l'interface : l'implémentation AdMob est asynchrone
	var shown: bool = await ads.show_return_ad_if_ready()
	if shown:
		_last_return_ad_at = Time.get_ticks_msec()


func on_app_stopped() -> void:
	if audio != null:
		audio.on_app_stopped()
	if active_game != null:
		active_game.on_pause()
	_stopped_at = Time.get_ticks_msec()
	_stopped_while_ad_showing = ads.is_full_screen_ad_showing()


func _exit_tree() -> void:
	if _daily_thread != null:
		_daily_thread.wait_to_finish()
		_daily_thread = null
	Wg.clear_caches()
	Icons.clear_cache()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _started:
				on_app_stopped()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _started:
				on_app_started()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back()
