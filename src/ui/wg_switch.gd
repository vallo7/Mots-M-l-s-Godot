class_name WgSwitch
extends Control
## Interrupteur de la maquette (piste grise, pouce blanc, jaune une fois activé). Le pouce glisse avec un
## rebond. Purement visuel : la zone tactile est la ligne entière (voir les réglages).

var _checked := false
var _thumb := SpringValue.new(520.0, 0.42, 3.0)


static func create(checked: bool) -> WgSwitch:
	var s := WgSwitch.new()
	s.custom_minimum_size = Vector2(56.0, 32.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s._checked = checked
	s._thumb.snap_to(25.0 if checked else 3.0)
	return s


func set_checked(checked: bool) -> void:
	_checked = checked
	_thumb.target = 25.0 if checked else 3.0
	set_process(true)


func _process(delta: float) -> void:
	_thumb.step(delta)
	queue_redraw()
	if _thumb.is_settled():
		set_process(false)


func _draw() -> void:
	Wg.rrect(self, Rect2(Vector2.ZERO, Vector2(56.0, 32.0)), Wg.YELLOW if _checked else Wg.LOCKED, Wg.R_PILL)
	Wg.rrect(self, Rect2(Vector2(_thumb.value, 3.0), Vector2(26.0, 26.0)), Wg.WHITE, Wg.R_PILL)
