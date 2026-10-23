class_name PopupHost
extends Control
## Voile + conteneur de popup. Le voile s'ouvre depuis le centre en cercle grandissant (aucun fondu) ; il intercepte
## tous les gestes pour que rien ne se déclenche derrière. `dismissed` : tap en dehors de la carte.
##
## Mise en page : la carte est TOUJOURS centrée dans la zone sûre de l'écran, jamais plus large que l'écran moins ses
## marges (plafonnée à MAX_CARD_WIDTH sur tablette) et jamais plus haute que lui. Si un contenu exigeait malgré tout
## plus de place (texte agrandi, petit écran), la carte entière est réduite pour tenir plutôt que de déborder.
## Un défilement vertical peut être confié à l'hôte (`set_scroll_region`) : il prend alors toute la hauteur utile.
##
## Entrée : la carte monte et grandit avec un ressort doux ; sortie : elle rétrécit et le voile se referme en cercle.

signal dismissed()
signal closed()

const SIDE_MARGIN := 20.0
const VERTICAL_MARGIN := 16.0
const MAX_CARD_WIDTH := 420.0
const INTRO_SCALE := 0.86
const INTRO_RISE := 28.0
const REVEAL_SECONDS := 0.28
const OUTRO_SECONDS := 0.18

var _reveal := 0.0
var _closing := false
var _ready_to_show := false
var _stage := Control.new()
var _card: Control
var _fit_scale := 1.0
var _anim := 1.0  ## 0 = carte rentrée, 1 = carte en place (entrée / sortie)
var _anim_tween: Tween
var _scroll: ScrollContainer
var _scroll_list: Control
var _scroll_chrome := 0.0
var _scrim_instant := false


## Ouvre un popup sur `parent` (la couche de superposition). `card` : carte à afficher. Renvoie l'hôte.
static func open(parent: Node, card: Control, dismissable: bool = true, instance: PopupHost = null) -> PopupHost:
	var host := instance if instance != null else PopupHost.new()
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host._stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._stage.visible = false
	host._card = card
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host._stage.add_child(card)
	host.add_child(host._stage)
	if dismissable:
		host.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				host.dismissed.emit())
	card.minimum_size_changed.connect(host._layout_card)
	host.resized.connect(host._layout_card)
	parent.add_child(host)
	return host


## Confie à l'hôte un `ScrollContainer` : sa hauteur suit celle de son contenu (`list`) sans dépasser la place
## disponible une fois retirée la hauteur fixe de la carte (`chrome`).
func set_scroll_region(scroll: ScrollContainer, list: Control, chrome: float) -> void:
	_scroll = scroll
	_scroll_list = list
	_scroll_chrome = chrome
	list.minimum_size_changed.connect(_layout_card)


func _ready() -> void:
	_layout_card()
	# Deux images pour que les textes à retour à la ligne trouvent leur largeur, puis on affiche la carte : jamais de saut visible.
	await get_tree().process_frame
	_layout_card()
	await get_tree().process_frame
	if _closing:
		return
	_layout_card()
	_stage.visible = true
	_ready_to_show = true
	if Wg.reduce_motion or Wg.suppress_intro:
		_reveal = 1.0
		_set_anim(1.0)
		queue_redraw()
		return
	_set_anim(0.0)
	if _scrim_instant:
		_reveal = 1.0
		queue_redraw()
	else:
		var reveal := create_tween()
		reveal.tween_method(func(v: float) -> void:
			_reveal = v
			queue_redraw(), 0.0, 1.0, REVEAL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animate_anim(1.0)


func _available() -> Rect2:
	var insets := App.safe_area_insets
	var origin := Vector2(insets.x + SIDE_MARGIN, insets.y + VERTICAL_MARGIN)
	var extent := Vector2(size.x - insets.x - insets.z - SIDE_MARGIN * 2.0, size.y - insets.y - insets.w - VERTICAL_MARGIN * 2.0)
	return Rect2(origin, extent.max(Vector2(40.0, 40.0)))


func _layout_card() -> void:
	if _card == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var area := _available()
	if _scroll != null and is_instance_valid(_scroll_list):
		var wanted := _scroll_list.get_combined_minimum_size().y
		var room := area.size.y - _scroll_chrome
		_scroll.custom_minimum_size.y = clampf(wanted, minf(120.0, room), maxf(room, 120.0))
	var width := minf(area.size.x, MAX_CARD_WIDTH)
	var needed := _card.get_combined_minimum_size()
	var card_size := Vector2(maxf(width, needed.x), needed.y)
	_fit_scale = minf(1.0, minf(area.size.x / card_size.x, area.size.y / card_size.y))
	_stage.size = card_size
	_stage.position = area.position + (area.size - card_size) * 0.5
	_set_anim(_anim)


## Applique l'état d'entrée / sortie (0 = rentrée, 1 = en place) en plus de l'échelle d'ajustement.
func _set_anim(value: float) -> void:
	_anim = value
	var scale := _fit_scale * lerpf(INTRO_SCALE, 1.0, minf(value, 1.0))
	var rise := (1.0 - minf(value, 1.0)) * INTRO_RISE
	UiKit.jelly(_stage, scale, scale, rise)


func _animate_anim(target: float) -> void:
	if _anim_tween != null:
		_anim_tween.kill()
	_anim_tween = create_tween()
	if target >= 1.0:
		var omega := sqrt(380.0)
		var duration := Motion.spring_settle_seconds(omega, 0.72, 0.003)
		var from := _anim
		_anim_tween.tween_method(func(t: float) -> void:
			_set_anim(from + (1.0 - from) * Motion.spring(t, omega, 0.72)), 0.0, duration, duration)
		_anim_tween.tween_callback(func() -> void: _set_anim(1.0))
	else:
		_anim_tween.tween_method(_set_anim, _anim, 0.0, OUTRO_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _draw() -> void:
	var max_r := size.length()
	if _reveal >= 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Wg.SCRIM)
	elif _reveal > 0.0:
		draw_circle(size * 0.5, max_r * _reveal, Wg.SCRIM)


## Ce popup en remplace un autre : le voile est déjà plein (aucune ouverture en cercle), seule la carte entre.
func start_with_scrim() -> void:
	_scrim_instant = true
	_reveal = 1.0
	queue_redraw()


## Fermeture immédiate, sans animation (le popup suivant garde le voile).
func close_now() -> void:
	if _closing:
		return
	_closing = true
	_finish()


func close() -> void:
	if _closing:
		return
	_closing = true
	if Wg.reduce_motion or not _ready_to_show:
		_finish()
		return
	_animate_anim(0.0)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_reveal = v
		queue_redraw(), _reveal, 0.0, OUTRO_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish)


func _finish() -> void:
	closed.emit()
	queue_free()
