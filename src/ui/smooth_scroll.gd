class_name SmoothScroll
extends Control
## Défilement vertical « de téléphone moderne », à la place du ScrollContainer : le contenu suit le doigt 1:1 (sans à-coup au
## démarrage : la distance de tolérance est déduite), la vitesse est mesurée sur les ~100 dernières millisecondes, le lancer glisse
## avec une friction exponentielle, et aux extrémités le contenu s'étire (résistance élastique) puis revient par un ressort
## amorti avec la vitesse qu'il avait. Poser un doigt arrête l'élan. Molette de souris prise en charge (poste de développement).
## Aucun fondu. Le contenu est le premier enfant : il prend la largeur du défilement et sa hauteur minimale.

signal scroll_started()

## Distance (dp) avant qu'un toucher devienne un défilement ; moins que celle des boutons : le défilement reprend la main.
const SLOP := 9.0
## Friction du lancer (1/s) : la vitesse est multipliée par exp(-FRICTION × dt).
const FRICTION := 3.1
const STOP_SPEED := 14.0
const MAX_FLING_SPEED := 7000.0
## Ressort de retour des extrémités (critique : revient sans rebondir).
const SPRING_STIFFNESS := 240.0
## Résistance quand on tire au-delà d'une extrémité (formule des listes tactiles : plus on tire, moins ça suit).
const RUBBER := 0.55
const VELOCITY_WINDOW_MS := 100
const WHEEL_STEP := 110.0

var _content: Control
var _offset := 0.0
var _velocity := 0.0  ## px/s, positif = le contenu monte (on descend dans la liste)
var _pressed := false
var _dragging := false
var _press_y := 0.0
var _drag_start_offset := 0.0
var _samples: Array[Vector2] = []  ## (ms, y du doigt)
var _wheel_target := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	child_entered_tree.connect(_on_child_entered)
	resized.connect(_relayout)
	set_process(false)


func _on_child_entered(child: Node) -> void:
	if _content != null or not child is Control:
		return
	_content = child
	_content.minimum_size_changed.connect(_relayout)
	_content.resized.connect(_apply_offset)
	_relayout.call_deferred()


## Position de défilement (px, décimale) : c'est elle que l'on anime pour un défilement programmé.
var scroll_position: float:
	get:
		return _offset
	set(value):
		_stop_motion()
		_offset = clampf(value, 0.0, max_scroll())
		_apply_offset()


## Compatible avec ScrollContainer (entier).
var scroll_vertical: int:
	get:
		return roundi(_offset)
	set(value):
		scroll_position = float(value)


func max_scroll() -> float:
	if _content == null:
		return 0.0
	return maxf(_content.size.y - size.y, 0.0)


func is_moving() -> bool:
	return _dragging or absf(_velocity) > STOP_SPEED or _offset < 0.0 or _offset > max_scroll() or _wheel_target >= 0.0


func _relayout() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	var wanted := _content.get_combined_minimum_size().y
	if _content.size_flags_vertical & Control.SIZE_EXPAND:
		wanted = maxf(wanted, size.y)
	var target := Vector2(size.x, wanted)
	if not _content.size.is_equal_approx(target):
		_content.size = target
	_content.position.x = 0.0
	if not _dragging and absf(_velocity) < STOP_SPEED and _wheel_target < 0.0:
		_offset = clampf(_offset, 0.0, max_scroll())  # le contenu a changé de taille : on reste dans les limites
	_apply_offset()


func _apply_offset() -> void:
	if _content != null and is_instance_valid(_content):
		_content.position.y = -_offset


func _stop_motion() -> void:
	_velocity = 0.0
	_wheel_target = -1.0
	set_process(false)


# ---- Élasticité aux extrémités
## Décalage affiché pour un tirage brut `raw` : 1:1 dans la liste, de plus en plus résistant au-delà des extrémités.
func rubber_offset(raw: float) -> float:
	var top := 0.0
	var bottom := max_scroll()
	var view := maxf(size.y, 1.0)
	if raw < top:
		return top - _stretch(top - raw, view)
	if raw > bottom:
		return bottom + _stretch(raw - bottom, view)
	return raw


static func _stretch(excess: float, view: float) -> float:
	return (1.0 - 1.0 / (excess * RUBBER / view + 1.0)) * view


# ---- Gestes
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_on_press(button.position)
				else:
					_on_release()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					var direction := -1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					var base := _wheel_target if _wheel_target >= 0.0 else _offset
					_wheel_target = clampf(base + direction * WHEEL_STEP, 0.0, max_scroll())
					_velocity = 0.0
					scroll_started.emit()
					set_process(true)
					accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_on_motion((event as InputEventMouseMotion).position)


func _on_press(position_value: Vector2) -> void:
	var was_moving := is_moving()
	_stop_motion()
	_pressed = true
	_dragging = false
	_press_y = position_value.y
	_samples.clear()
	_samples.append(Vector2(Time.get_ticks_msec(), position_value.y))
	if was_moving:
		scroll_started.emit()


func _on_motion(position_value: Vector2) -> void:
	var dy := position_value.y - _press_y
	if not _dragging:
		if absf(dy) <= SLOP:
			return
		_dragging = true
		_drag_start_offset = _offset
		scroll_started.emit()
	# Distance de tolérance déduite : le contenu part de zéro sous le doigt, sans saut.
	var effective := dy - signf(dy) * SLOP
	_offset = rubber_offset(_drag_start_offset - effective)
	_apply_offset()
	var now := Time.get_ticks_msec()
	_samples.append(Vector2(now, position_value.y))
	while _samples.size() > 2 and now - _samples[0].x > VELOCITY_WINDOW_MS * 2:
		_samples.remove_at(0)
	accept_event()


func _on_release() -> void:
	if not _pressed:
		return
	_pressed = false
	if not _dragging:
		return
	_dragging = false
	_velocity = clampf(fling_velocity(_samples, Time.get_ticks_msec()), -MAX_FLING_SPEED, MAX_FLING_SPEED)
	set_process(true)
	accept_event()


## Vitesse du contenu (px/s, positif = il monte) d'après les derniers relevés du doigt (ms, y). Un doigt immobile avant le
## relâchement donne 0 : on ne lance pas ce que le joueur a arrêté.
static func fling_velocity(samples: Array[Vector2], now_ms: int) -> float:
	if samples.size() < 2:
		return 0.0
	var last := samples[samples.size() - 1]
	if now_ms - last.x > 80.0:
		return 0.0
	var first := last
	for i in range(samples.size() - 1, -1, -1):
		if last.x - samples[i].x > VELOCITY_WINDOW_MS:
			break
		first = samples[i]
	var seconds := (last.x - first.x) / 1000.0
	if seconds < 0.012:
		return 0.0
	return -(last.y - first.y) / seconds


func _process(delta: float) -> void:
	if _dragging:
		return
	var dt := minf(delta, 1.0 / 20.0)
	if _wheel_target >= 0.0:
		_offset += (_wheel_target - _offset) * (1.0 - exp(-16.0 * dt))
		if absf(_wheel_target - _offset) < 0.4:
			_offset = _wheel_target
			_wheel_target = -1.0
			set_process(false)
		_apply_offset()
		return
	var top := 0.0
	var bottom := max_scroll()
	if _offset < top or _offset > bottom:
		# Hors des extrémités : ressort critique vers la borne, avec la vitesse que le contenu avait.
		var bound := top if _offset < top else bottom
		var omega := sqrt(SPRING_STIFFNESS)
		var remaining := dt
		while remaining > 0.0:
			var step := minf(remaining, 1.0 / 240.0)
			var accel := -SPRING_STIFFNESS * (_offset - bound) - 2.0 * omega * _velocity
			_velocity += accel * step
			_offset += _velocity * step
			remaining -= step
		if absf(_offset - bound) < 0.2 and absf(_velocity) < 8.0:
			_offset = bound
			_velocity = 0.0
			set_process(false)
	else:
		_offset += _velocity * dt
		_velocity *= exp(-FRICTION * dt)
		if absf(_velocity) < STOP_SPEED:
			_velocity = 0.0
			set_process(false)
	_apply_offset()
