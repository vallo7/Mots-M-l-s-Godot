class_name JuicyPressable
extends Control
## Base de tout élément cliquable : pression « gelée ». La progression d'appui `press` vaut 0 au repos et 1
## à fond ; au relâchement le ressort sous-amorti la fait passer sous 0 (l'élément s'étire un instant) avant
## de se poser. Son et haptique immédiats, action après un micro-délai, garde anti double-clic, focus visible.
## Les événements ne sont jamais consommés : un défilement parent peut prendre le geste (zone de tolérance).

signal activated()

const TOUCH_SLOP := 10.0

var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_pointer_down = false
			_press_spring.target = 0.0
		_wake()
		_state_changed()
		queue_redraw()
## Son et haptique joués à l'activation ; -1 : aucun.
var sound: int = Sound.CLICK
var haptic: int = HapticEffect.SELECTION
## Intensité de l'écrasement (1 = bouton, 0,45 = ligne de réglage).
var squash := 1.0
var description := "":
	set(value):
		description = value
		set("accessibility_name", value)

var _press_spring := SpringValue.new(620.0, 0.36)
var _pointer_down := false
var _dragged := false
var _down_position := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	set_process(false)


## Progression d'appui courante (peut être légèrement négative : étirement au relâchement).
func press() -> float:
	return _press_spring.value


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down = true
			_dragged = false
			_down_position = event.position
			_press_spring.target = 1.0
			_wake()
		elif _pointer_down:
			var inside := Rect2(Vector2.ZERO, size).grow(TOUCH_SLOP).has_point(event.position)
			_pointer_down = false
			_press_spring.target = 0.0
			_wake()
			if inside and not _dragged:
				_activate()
	elif event is InputEventMouseMotion and _pointer_down:
		var motion := event as InputEventMouseMotion
		var moved := (motion.position - _down_position).length() > TOUCH_SLOP
		if moved:
			_dragged = true  # le geste est un glissement (défilement parent) : ce n'est plus un tap
		if moved and not Rect2(Vector2.ZERO, size).has_point(motion.position):
			_pointer_down = false  # le doigt a quitté l'élément : appui annulé
			_press_spring.target = 0.0
			_wake()
	elif event.is_action_pressed(&"ui_accept") and has_focus():
		_press_spring.value = 0.6
		_wake()
		_activate()
		accept_event()


func _activate() -> void:
	if not Feedback.try_acquire_click():
		return
	if sound >= 0:
		Feedback.play(sound)
	if haptic >= 0:
		Feedback.perform(haptic)
	await get_tree().create_timer(Wg.PRESS_DELAY).timeout
	if is_inside_tree() and enabled:
		activated.emit()


func _wake() -> void:
	if is_inside_tree():
		set_process(true)


func _process(delta: float) -> void:
	_press_spring.step(delta)
	var p := _press_spring.value
	UiKit.jelly(self, 1.0 + 0.07 * squash * p, 1.0 - 0.11 * squash * p)
	_on_press_changed()
	queue_redraw()
	if _press_spring.is_settled() and not _pointer_down:
		set_process(false)


## Point d'extension : appelé quand `enabled` change.
func _state_changed() -> void:
	pass


## Point d'extension : appelé à chaque image où la progression d'appui change.
func _on_press_changed() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


## Anneau de focus visible (clavier / manette), dessiné par les sous-classes en dernier.
func _draw_focus_ring(rect: Rect2, radius: float) -> void:
	if has_focus():
		Wg.outline(self, rect.grow(2.0), Wg.INK, radius + 2.0, 2.0)
