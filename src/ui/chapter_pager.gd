class_name ChapterPager
extends Control
## Carrousel horizontal de pages qu'on fait glisser : décalage de 44 dp sur les bords (la carte voisine dépasse),
## 4 dp entre les pages, aimantation sur la page la plus proche (ressort), élan du geste pris en compte.
## Chaque page reçoit son décalage fractionnaire (`(page courante − page) + fraction`) pour la parallaxe et l'inclinaison.

signal page_changed(page: int)

const SIDE_PADDING := 44.0
const SPACING := 4.0
const FLING_PX_PER_S := 420.0

var _pages: Array[Control] = []
var _position := 0.0  ## en pages (0 = première)
var _spring := SpringValue.new(260.0, 1.0, 0.0)
var _dragging := false
var _drag_origin := Vector2.ZERO
var _drag_start_position := 0.0
var _last_x := 0.0
var _velocity := 0.0
var _last_time := 0
var _moved_far := false
var _current := 0
var on_offsets: Callable  ## (page_index, offset) -> void : appelé à chaque image pour chaque page


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	resized.connect(_layout)


func set_pages(pages: Array[Control], start_page: int) -> void:
	for p in _pages:
		p.queue_free()
	_pages = pages
	for p in _pages:
		add_child(p)
	_current = clampi(start_page, 0, maxi(_pages.size() - 1, 0))
	_position = float(_current)
	_spring.snap_to(_position)
	_layout()


func current_page() -> int:
	return _current


func _page_width() -> float:
	return maxf(size.x - SIDE_PADDING * 2.0, 1.0)


func _layout() -> void:
	var width := _page_width()
	for i in _pages.size():
		var p := _pages[i]
		p.size = Vector2(width, size.y)
		p.position = Vector2(SIDE_PADDING + (i - _position) * (width + SPACING), 0.0)
		if on_offsets.is_valid():
			on_offsets.call(i, _position - i)


func _process(delta: float) -> void:
	if not _dragging:
		_spring.step(delta)
		_position = _spring.value
		_layout()
		if _spring.is_settled():
			set_process(false)


func _gui_input(event: InputEvent) -> void:
	if _pages.size() <= 1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_moved_far = false
			_drag_origin = event.position
			_drag_start_position = _position
			_last_x = event.position.x
			_velocity = 0.0
			_last_time = Time.get_ticks_msec()
			set_process(false)
		elif _dragging:
			_dragging = false
			_settle()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var dx := motion.position.x - _drag_origin.x
		if absf(dx) > JuicyPressable.TOUCH_SLOP:
			_moved_far = true
		if _moved_far:
			var now := Time.get_ticks_msec()
			var dt := maxf((now - _last_time) / 1000.0, 0.001)
			_velocity = lerpf(_velocity, (motion.position.x - _last_x) / dt, 0.4)
			_last_x = motion.position.x
			_last_time = now
			var raw := _drag_start_position - dx / (_page_width() + SPACING)
			# Résistance élastique au-delà des extrémités.
			var max_page := float(_pages.size() - 1)
			if raw < 0.0:
				raw *= 0.35
			elif raw > max_page:
				raw = max_page + (raw - max_page) * 0.35
			_position = raw
			_layout()
			var nearest := clampi(roundi(_position), 0, _pages.size() - 1)
			if nearest != _current:
				_set_current(nearest)
			accept_event()


func _settle() -> void:
	var target := _current
	if absf(_velocity) > FLING_PX_PER_S:
		target = _current - signi(int(_velocity))
	else:
		target = roundi(_position)
	target = clampi(target, 0, _pages.size() - 1)
	_set_current(target)
	_spring.value = _position
	_spring.velocity = 0.0
	_spring.target = float(target)
	set_process(true)


func _set_current(page: int) -> void:
	if page == _current:
		return
	_current = page
	page_changed.emit(page)


## Aller à une page sans geste (ex. reconstruction de l'écran).
func go_to(page: int) -> void:
	_current = clampi(page, 0, maxi(_pages.size() - 1, 0))
	_position = float(_current)
	_spring.snap_to(_position)
	_layout()
