class_name ChapterPager
extends Control
## Carrousel horizontal de pages qu'on fait glisser : décalage de 44 dp sur les bords (la carte voisine dépasse),
## 4 dp entre les pages. La page suit le doigt 1:1 (sans à-coup au démarrage : la distance de tolérance est déduite), avec une
## résistance élastique aux extrémités. Au relâchement, la page visée dépend de la distance parcourue ET de la vitesse mesurée
## sur les ~100 dernières ms (un petit coup de doigt rapide suffit), jamais plus d'une page à la fois ; le ressort amorti qui
## termine le mouvement repart avec la vitesse du doigt, donc le geste se prolonge sans rupture. Poser un doigt pendant le
## mouvement le rattrape. Chaque page reçoit son décalage fractionnaire (`(page courante − page) + fraction`) pour la
## parallaxe et l'inclinaison. Aucun fondu.

signal page_changed(page: int)

const SIDE_PADDING := 44.0
const SPACING := 4.0
## Distance parcourue (en pages) à partir de laquelle on change de page même sans vitesse.
const COMMIT_DISTANCE := 0.28
## Vitesse (pages/s) à partir de laquelle un geste rapide change de page même s'il est court.
const FLING_PAGES_PER_S := 0.85
const MAX_FLING_PAGES_PER_S := 9.0
const RUBBER := 0.35
## Ressort de fin de mouvement : quasi critique (un dépassement imperceptible), repart avec la vitesse du doigt.
const SETTLE_STIFFNESS := 250.0
const SETTLE_DAMPING := 0.94
const VELOCITY_WINDOW_MS := 100

var _pages: Array[Control] = []
var _position := 0.0  ## en pages (0 = première)
var _spring := SpringValue.new(SETTLE_STIFFNESS, SETTLE_DAMPING, 0.0)
var _pressed := false
var _dragging := false
var _press_x := 0.0
var _drag_start_position := 0.0
var _start_page := 0
var _samples: Array[Vector2] = []  ## (ms, x du doigt)
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


## Vrai tant que le carrousel bouge (doigt posé ou ressort en cours) : les tutoriels attendent qu'il soit posé.
func is_moving() -> bool:
	return _dragging or is_processing()


func _page_width() -> float:
	return maxf(size.x - SIDE_PADDING * 2.0, 1.0)


func _layout() -> void:
	var width := _page_width()
	var page_size := Vector2(width, size.y)
	for i in _pages.size():
		var p := _pages[i]
		if not p.size.is_equal_approx(page_size):
			p.size = page_size  # inutile à chaque image : cela relancerait toute la mise en page de la carte
		p.position = Vector2(SIDE_PADDING + (i - _position) * (width + SPACING), 0.0)
		if on_offsets.is_valid():
			on_offsets.call(i, _position - i)


func _process(delta: float) -> void:
	if _dragging:
		return
	_spring.step(delta)
	_position = _spring.value
	_layout()
	if _spring.is_settled():
		_position = _spring.target
		_layout()
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if _pages.size() <= 1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_x = event.position.x
			_start_page = clampi(roundi(_position), 0, _pages.size() - 1)  # on rattrape une page encore en mouvement
			_samples.clear()
			_samples.append(Vector2(Time.get_ticks_msec(), event.position.x))
			if is_processing():
				_drag_start_position = _position
				set_process(false)
		elif _pressed:
			_pressed = false
			if _dragging:
				_dragging = false
				_settle()
			elif absf(_position - roundf(_position)) > 0.001:
				_settle()  # un simple toucher sur une page encore en mouvement : on la laisse finir
	elif event is InputEventMouseMotion and _pressed:
		var motion := event as InputEventMouseMotion
		var dx := motion.position.x - _press_x
		if not _dragging:
			if absf(dx) <= JuicyPressable.TOUCH_SLOP:
				return
			_dragging = true
			_drag_start_position = _position
			set_process(false)
		# Distance de tolérance déduite : la page part de zéro sous le doigt, sans saut.
		var effective := dx - signf(dx) * JuicyPressable.TOUCH_SLOP
		_position = _rubber(_drag_start_position - effective / (_page_width() + SPACING))
		_layout()
		var now := Time.get_ticks_msec()
		_samples.append(Vector2(now, motion.position.x))
		while _samples.size() > 2 and now - _samples[0].x > VELOCITY_WINDOW_MS * 2:
			_samples.remove_at(0)
		var nearest := clampi(roundi(_position), 0, _pages.size() - 1)
		if nearest != _current:
			_set_current(nearest)
		accept_event()


## Résistance élastique au-delà des extrémités.
func _rubber(raw: float) -> float:
	var max_page := float(_pages.size() - 1)
	if raw < 0.0:
		return raw * RUBBER
	if raw > max_page:
		return max_page + (raw - max_page) * RUBBER
	return raw


## Vitesse des pages (pages/s, positif = vers la page suivante) d'après les derniers relevés du doigt.
func _fling_pages_per_second() -> float:
	if _samples.size() < 2:
		return 0.0
	var last := _samples[_samples.size() - 1]
	if Time.get_ticks_msec() - last.x > 80.0:
		return 0.0  # le doigt s'est arrêté avant de se lever : pas d'élan
	var first := last
	for i in range(_samples.size() - 1, -1, -1):
		if last.x - _samples[i].x > VELOCITY_WINDOW_MS:
			break
		first = _samples[i]
	var seconds := (last.x - first.x) / 1000.0
	if seconds < 0.012:
		return 0.0
	var pixels_per_second := (last.x - first.x) / seconds
	return clampf(-pixels_per_second / (_page_width() + SPACING), -MAX_FLING_PAGES_PER_S, MAX_FLING_PAGES_PER_S)


## Page visée au relâchement : jamais plus d'une page de celle où le geste a commencé ; une distance suffisante OU une vitesse
## suffisante change de page. Fonction pure (testée).
static func target_page(start_page: int, position: float, velocity_pages_per_s: float, page_count: int) -> int:
	var moved := position - float(start_page)
	var step := 0
	if absf(velocity_pages_per_s) >= FLING_PAGES_PER_S and (signf(velocity_pages_per_s) == signf(moved) or absf(moved) < 0.12):
		step = int(signf(velocity_pages_per_s))
	elif absf(moved) >= COMMIT_DISTANCE:
		step = int(signf(moved))
	return clampi(start_page + step, 0, maxi(page_count - 1, 0))


func _settle() -> void:
	var velocity := _fling_pages_per_second()
	var target := target_page(_start_page, _position, velocity, _pages.size())
	if target != _current:
		_set_current(target)
		Feedback.perform(HapticEffect.SELECTION)  # un léger « clic » quand la page change
	_spring.value = _position
	_spring.velocity = velocity
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
	set_process(false)
	_layout()
