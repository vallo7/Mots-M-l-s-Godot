class_name WgSlider
extends Control
## Curseur « bulle » : piste, remplissage jaune à lèvre, pouce rond qui grossit quand on le tient. Se règle en tapant
## sur la piste ou en la faisant glisser ; clavier / manette : gauche et droite. `value_changed` est émis pendant le
## geste (aperçu en direct), `drag_ended` une seule fois au relâchement (c'est là qu'on enregistre).

signal value_changed(value: float)
signal drag_ended(value: float)

const TRACK_HEIGHT := 14.0
const THUMB_RADIUS := 15.0
const HEIGHT := 40.0
const KEY_STEP := 0.05
## Un retour haptique léger à chaque dixième franchi.
const TICKS := 10

var value := 0.5:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

var _dragging := false
var _grab := SpringValue.new(520.0, 0.42, 0.0)
var _last_tick := -1


static func create(initial: float, description_text: String = "") -> WgSlider:
	var slider := WgSlider.new()
	slider.value = initial
	slider.description_text = description_text
	slider._last_tick = int(round(initial * TICKS))
	return slider


var description_text := "":
	set(v):
		description_text = v
		set("accessibility_name", v)


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(false)


func is_dragging() -> bool:
	return _dragging


## Positionne le curseur sans émettre de signal (rafraîchissement depuis les réglages).
func set_value_silently(v: float) -> void:
	if _dragging:
		return
	value = v
	_last_tick = int(round(value * TICKS))


func _track_left() -> float:
	return THUMB_RADIUS


func _track_width() -> float:
	return maxf(size.x - THUMB_RADIUS * 2.0, 1.0)


func _value_at(x: float) -> float:
	return clampf((x - _track_left()) / _track_width(), 0.0, 1.0)


func _apply(x: float) -> void:
	var v := _value_at(x)
	if is_equal_approx(v, value):
		return
	value = v
	var tick := int(round(v * TICKS))
	if tick != _last_tick:
		_last_tick = tick
		Feedback.perform(HapticEffect.SELECTION)
	value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_grab.target = 1.0
			set_process(true)
			_apply(event.position.x)
			accept_event()
		elif _dragging:
			_dragging = false
			_grab.target = 0.0
			set_process(true)
			Feedback.play(Sound.CLICK)
			drag_ended.emit(value)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_apply((event as InputEventMouseMotion).position.x)
		accept_event()
	elif has_focus() and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
		var direction := -1.0 if event.is_action_pressed(&"ui_left") else 1.0
		value = clampf(value + direction * KEY_STEP, 0.0, 1.0)
		value_changed.emit(value)
		drag_ended.emit(value)
		accept_event()


func _process(delta: float) -> void:
	_grab.step(delta)
	queue_redraw()
	if _grab.is_settled() and not _dragging:
		set_process(false)


func _draw() -> void:
	var cy := size.y * 0.5
	var left := _track_left()
	var width := _track_width()
	var top := cy - TRACK_HEIGHT * 0.5
	Wg.rrect(self, Rect2(left - THUMB_RADIUS * 0.5, top, width + THUMB_RADIUS, TRACK_HEIGHT), Wg.TRACK, TRACK_HEIGHT * 0.5)
	var x := left + width * value
	if value > 0.001:
		var fill_w := maxf(x - left + THUMB_RADIUS * 0.5, TRACK_HEIGHT)
		Wg.rrect(self, Rect2(left - THUMB_RADIUS * 0.5, top + 1.5, fill_w, TRACK_HEIGHT - 1.5), Wg.YELLOW_DARK, TRACK_HEIGHT * 0.5)
		Wg.rrect(self, Rect2(left - THUMB_RADIUS * 0.5, top, fill_w, TRACK_HEIGHT - 1.5), Wg.YELLOW, TRACK_HEIGHT * 0.5)
	var grow := 1.0 + 0.16 * clampf(_grab.value, 0.0, 1.2)
	var r := THUMB_RADIUS * grow
	for i in range(4):
		draw_circle(Vector2(x, cy + 2.5 + i * 0.5), r + 3.0 - i * 0.8, Color(Wg.SHADOW, Wg.SHADOW.a * 0.2), true, -1.0, true)
	draw_circle(Vector2(x, cy), r, Wg.SURFACE, true, -1.0, true)
	draw_circle(Vector2(x, cy), r * 0.5, Wg.YELLOW, true, -1.0, true)
	if has_focus():
		draw_arc(Vector2(x, cy), r + 3.0, 0.0, TAU, 32, Wg.INK, 2.0, true)
