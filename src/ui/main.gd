class_name Main
extends Control
## Scène racine : affiche chargement, erreur ou navigation. Aucun fondu : tout glisse, s'ouvre en iris, monte ou se lève.
## Les pages de base vivent dans `_pages` ; réglages, crédits et langue sont des popups posés au-dessus (la page de base
## ne bouge pas). Le détail des mouvements de page est dans PageTransition (styles, chorégraphie des éléments) :
## pendant une transition les touches sont bloquées. L'animation ne démarre qu'après quelques images de « chauffe »
## pendant lesquelles le nouvel écran, déjà construit hors champ, calcule sa mise en page.
##
## Changement de thème clair / sombre : une capture de l'ancien écran reste en dessous pendant que l'écran reconstruit
## apparaît dans un disque qui s'agrandit depuis l'interrupteur (aucun fondu).

const WARMUP_FRAMES := 2
const THEME_REVEAL_SECONDS := 0.7
## Un appui plus ancien que cela n'est plus l'origine de l'iris (on retombe sur une origine par défaut).
const PRESS_MEMORY_MS := 1800

var _pages := Control.new()
var _screen: Control
var _screen_key := ""
var _screen_kind := -1  ## -1 = chargement / erreur
var _popup_layer := Control.new()
var _popup: Control
var _popup_kind := -1
var _messages := MessageHost.new()
var _trophy_toast := TrophyToast.new()
var _last_language := -1
var _last_large_text := false
var _last_dark := false

# Transition en cours
var _transition: PageTransition
var _warmup := 0
var _blocker := Control.new()
var _last_press := Vector2.ZERO
var _last_press_at := -100000
var _theme_reveal: _ThemeReveal


## Révélation du nouveau thème : capture de l'ancien écran + disque qui s'agrandit sur l'écran reconstruit.
class _ThemeReveal extends RefCounted:
	var snapshot: TextureRect
	var wrap: IrisWrap
	var ring: PageTransition._Ring
	var origin := Vector2.ZERO
	var t := 0.0


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_pages)
	add_child(_pages)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_popup_layer)
	add_child(_popup_layer)
	add_child(_messages)
	add_child(_trophy_toast)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	UiKit.full_rect(_blocker)
	add_child(_blocker)
	set_process(false)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	App.phase_changed.connect(_on_phase_changed)
	App.stack_changed.connect(_on_stack_changed)
	App.settings_changed.connect(_on_settings_changed)
	_show(LoadingScreen.create(), "loading", true, -1)
	_last_language = App.language
	_last_large_text = App.settings.large_text
	_last_dark = Wg.dark
	App.start()


## Mémorise le dernier appui : c'est de là que s'ouvre (ou vers là que se ferme) l'iris.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_last_press = event.position
		_last_press_at = Time.get_ticks_msec()


func _iris_origin() -> Vector2:
	if Time.get_ticks_msec() - _last_press_at <= PRESS_MEMORY_MS and Rect2(Vector2.ZERO, size).has_point(_last_press):
		return _last_press
	return Vector2(size.x * 0.5, size.y * 0.62)


func _update_insets() -> void:
	App.safe_area_insets = UiKit.safe_insets(get_viewport())


func _on_phase_changed() -> void:
	match App.phase:
		App.Phase.FAILED:
			_show(StartupErrorScreen.create(), "error", true, -1)
		App.Phase.READY:
			_on_stack_changed()


func _on_stack_changed() -> void:
	if App.phase != App.Phase.READY:
		return
	var top := App.current_route()
	var is_popup := ScreenRoute.is_popup_kind(top.kind)
	var base := top
	if is_popup:
		base = _base_route()
	if base.key() != _screen_key:
		var forward := App.direction == App.NavDirection.FORWARD
		var style := PageTransition.style_for(_screen_kind, base.kind, forward)
		_show(_make_screen(base), base.key(), forward, base.kind, style)
	_sync_popup(top.kind if is_popup else -1)


## Dernière route de page pleine de la pile (celle sur laquelle les popups sont posés).
func _base_route() -> ScreenRoute:
	for i in range(App.stack.size() - 1, -1, -1):
		var r := App.stack[i]
		if not ScreenRoute.is_popup_kind(r.kind):
			return r
	return ScreenRoute.home()


func _make_screen(route: ScreenRoute) -> Control:
	match route.kind:
		ScreenRoute.Kind.GAME:
			return GameScreen.create(App.active_game)
		ScreenRoute.Kind.MONUMENT:
			return MonumentScreen.create()
		ScreenRoute.Kind.RESULT:
			return ResultScreen.create(route.result)
		ScreenRoute.Kind.HELP:
			return HelpScreen.create()
		ScreenRoute.Kind.DAILY:
			return DailyScreen.create()
		ScreenRoute.Kind.TROPHIES:
			return TrophiesScreen.create()
		_:
			return HomeScreen.create()


## Remplace l'écran courant : voir PageTransition pour le mouvement choisi. `kind` : type de route du nouvel écran (-1 : chargement / erreur).
func _show(next: Control, key: String, forward: bool, kind: int = -1, style: int = PageTransition.Style.SLIDE) -> void:
	_finish_transition()
	var previous := _screen
	if previous != null and previous.has_method("on_leaving"):
		previous.call("on_leaving")
	_screen = next
	_screen_key = key
	_screen_kind = kind
	_pages.add_child(next)
	UiKit.full_rect(next)
	if previous == null or Wg.reduce_motion:
		if previous != null:
			previous.queue_free()
		_notify_entered(next)
		return
	_transition = PageTransition.new()
	_transition.begin(self, _pages, next, previous, forward, style, _iris_origin())
	_warmup = WARMUP_FRAMES
	_blocker.visible = true
	set_process(true)


func _process(delta: float) -> void:
	if _theme_reveal != null:
		_step_theme_reveal(delta)
		return
	if _transition == null:
		set_process(false)
		return
	if _warmup > 0:
		_warmup -= 1
		return
	if _transition.step(delta):
		_finish_transition()


## Termine tout de suite la transition en cours (état final exact), puis prévient le nouvel écran.
func _finish_transition() -> void:
	if _transition == null:
		return
	var done := _transition
	_transition = null
	done.finish(_pages)
	_blocker.visible = false
	set_process(_theme_reveal != null)
	if is_instance_valid(done.outgoing):
		done.outgoing.queue_free()
	if is_instance_valid(done.incoming):
		_notify_entered(done.incoming)


## L'écran peut démarrer ses animations d'entrée (étoiles, barres…) une fois la page en place : `on_entered()`.
func _notify_entered(screen: Control) -> void:
	if screen.has_method("on_entered"):
		screen.call("on_entered")


func _sync_popup(kind: int) -> void:
	if kind == _popup_kind:
		return
	var replacing := _popup != null and kind != -1
	if _popup != null:
		if _popup is PopupHost:
			if replacing:
				(_popup as PopupHost).close_now()  # popup remplacé par un autre : le voile reste, seules les cartes changent
			else:
				(_popup as PopupHost).close()
		else:
			_popup.queue_free()
		_popup = null
	_popup_kind = kind
	match kind:
		ScreenRoute.Kind.SETTINGS:
			_popup = SettingsPopup.open_settings(_popup_layer)
		ScreenRoute.Kind.CREDITS:
			_popup = CreditsPopup.open(_popup_layer)
		ScreenRoute.Kind.LANGUAGE:
			_popup = LanguagePopup.open_list(_popup_layer)
	if replacing and _popup is PopupHost:
		(_popup as PopupHost).start_with_scrim()


## Un réglage a changé (langue, texte, thème, animations) : on reconstruit les écrans en place, sans animation d'entrée.
func _on_settings_changed() -> void:
	if App.phase != App.Phase.READY or _screen == null:
		return
	_finish_transition()
	var theme_changed := Wg.dark != _last_dark
	var needs_rebuild := App.language != _last_language or App.settings.large_text != _last_large_text or theme_changed
	_last_language = App.language
	_last_large_text = App.settings.large_text
	_last_dark = Wg.dark
	if not needs_rebuild:
		if _popup is SettingsPopup:
			(_popup as SettingsPopup).refresh()
		return
	var reveal: _ThemeReveal = _capture_theme_reveal() if theme_changed and not Wg.reduce_motion else null
	var top := App.current_route()
	var is_popup := ScreenRoute.is_popup_kind(top.kind)
	var base := _base_route()
	Wg.suppress_intro = true
	var fresh := _make_screen(base)
	var old := _screen
	_screen = fresh
	_pages.add_child(fresh)
	UiKit.full_rect(fresh)
	old.queue_free()
	if is_popup and _popup != null:
		var kind := _popup_kind
		_popup_kind = -1
		var stale := _popup
		_popup = null
		stale.queue_free()
		_sync_popup(kind)
	if reveal != null:
		_start_theme_reveal(reveal)
	await get_tree().process_frame
	await get_tree().process_frame
	Wg.suppress_intro = false


# ---- Révélation du thème
func _capture_theme_reveal() -> _ThemeReveal:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var reveal := _ThemeReveal.new()
	reveal.snapshot = TextureRect.new()
	reveal.snapshot.texture = ImageTexture.create_from_image(image)
	reveal.snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reveal.snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	reveal.snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal.origin = _iris_origin()
	return reveal


func _start_theme_reveal(reveal: _ThemeReveal) -> void:
	UiKit.full_rect(reveal.snapshot)
	add_child(reveal.snapshot)
	move_child(reveal.snapshot, 0)
	reveal.wrap = IrisWrap.new(size)
	add_child(reveal.wrap)
	move_child(reveal.wrap, 1)
	remove_child(_pages)
	reveal.wrap.content.add_child(_pages)
	remove_child(_popup_layer)
	reveal.wrap.content.add_child(_popup_layer)
	reveal.ring = PageTransition._Ring.new()
	reveal.ring.size = size
	reveal.ring.color = Wg.YELLOW
	add_child(reveal.ring)
	move_child(reveal.ring, 2)
	reveal.wrap.set_circle(reveal.origin, 0.0)
	_blocker.visible = true
	_theme_reveal = reveal
	set_process(true)


func _step_theme_reveal(delta: float) -> void:
	var reveal := _theme_reveal
	reveal.t = minf(THEME_REVEAL_SECONDS, reveal.t + minf(delta, 1.0 / 30.0))
	var m := reveal.t / THEME_REVEAL_SECONDS
	var e := Motion.ease_in_out_cubic(m)
	var radius := IrisWrap.cover_radius(reveal.origin, size) * e
	reveal.wrap.set_circle(reveal.origin, radius)
	reveal.ring.center = reveal.origin
	reveal.ring.radius = radius
	reveal.ring.width = lerpf(12.0, 1.0, e) if m < 1.0 else 0.0
	reveal.ring.queue_redraw()
	if m >= 1.0:
		_end_theme_reveal()


func _end_theme_reveal() -> void:
	var reveal := _theme_reveal
	_theme_reveal = null
	reveal.wrap.content.remove_child(_pages)
	reveal.wrap.content.remove_child(_popup_layer)
	add_child(_pages)
	move_child(_pages, 0)
	add_child(_popup_layer)
	move_child(_popup_layer, 1)
	reveal.wrap.queue_free()
	reveal.snapshot.queue_free()
	reveal.ring.queue_free()
	_blocker.visible = _transition != null
	set_process(_transition != null)
