class_name LetterGridView
extends Control
## Grille de lettres : point focal de l'écran de jeu. Le joueur trace avec le doigt une ligne droite (8 directions) ;
## le tracé est aligné par GridGeometry. La grille ne décide jamais de la victoire : elle remonte le tracé au moteur.
##
## Deux couches : la bulle (une grande forme arrondie simple, sans contour ni bulles individuelles, dessinée une seule
## fois) et les effets dynamiques (capsules, lettres animées, indices ; redessinés seulement tant qu'un effet est actif).
## Aucun fondu, aucune particule. La grille occupe le plus grand carré possible, centré dans la place disponible.

signal selection_started(cell: Vector2i)
signal selection_changed(path: Array[Vector2i])
signal selection_ended()

## Marge entre le bord de la bulle et les lettres (en dp).
const PAD := 8.0
const CARD_RADIUS := 30.0

var grid: PackedStringArray = PackedStringArray()
var found: Array[FoundHighlight] = []
var hint_cells: Array[Vector2i] = []
var selection: Array[Vector2i] = []
var selection_color: Color = Wg.trace_tint(Wg.PURPLE)
var input_enabled := true
## Durée (µs) du dernier dessin de la couche dynamique : instrumentation de performance (voir test/visual/bench_grid.gd).
var last_paint_usec := 0

var _fx: GridFx
var _card := _Layer.new()
var _dynamic := _Layer.new()
var _n := 0
var _cell_size := 0.0
var _side := 0.0
var _shake := SpringValue.new(650.0, 0.2, 0.0)
var _pointer_down := false
var _gesture_start := Vector2i.ZERO
var _gesture_path: Array[Vector2i] = []
var _gesture_direction := -1
var _restart_count := 0


## Couche de dessin déléguant à la vue.
class _Layer extends Control:
	var painter: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card.painter = _paint_card
	_dynamic.painter = _paint_dynamic
	add_child(_card)
	add_child(_dynamic)
	resized.connect(_relayout)
	set_process(false)


func _ready() -> void:
	_relayout()


## Charge une nouvelle grille. `hints` : indices déjà présents (partie reprise, aucun effet de révélation).
## `p_selection_color` : teinte du tracé en direct (adoucie ici : plus claire, moins saturée, translucide).
func setup(p_grid: PackedStringArray, p_selection_color: Color, hints: Array[Vector2i]) -> void:
	grid = p_grid
	_n = grid.size()
	selection_color = Wg.trace_tint(p_selection_color)
	found = []
	selection = []
	hint_cells = hints
	_fx = GridFx.new(_n, Wg.reduce_motion)
	_fx.set_trace_color(selection_color)
	_fx.woke.connect(_wake)
	_fx.prime_hints(hints)
	_relayout()
	_wake()


## Côté du carré occupé par la bulle (en dp).
func bubble_side() -> float:
	return _side


## Centre d'une case (colonne, ligne) dans le repère de la grille : le gant des tutoriels vise ces points.
func cell_center(cell: Vector2i) -> Vector2:
	return _dynamic.position + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


## Côté d'une case (en dp).
func cell_extent() -> float:
	return _cell_size


func _relayout() -> void:
	_side = minf(size.x, size.y)
	var inner := _side - PAD * 2.0
	_cell_size = inner / maxf(_n, 1)
	var origin := Vector2((size.x - _side) * 0.5, (size.y - _side) * 0.5)
	_card.position = origin
	_card.size = Vector2(_side, _side)
	_dynamic.position = origin + Vector2(PAD, PAD)
	_dynamic.size = Vector2(inner, inner)
	_card.queue_redraw()
	_dynamic.queue_redraw()


# ---- Mises à jour d'état (appelées par l'écran de jeu)
func update_found(new_found: Array[FoundHighlight]) -> void:
	if _fx == null:
		return
	if new_found.is_empty() and not found.is_empty():
		_fx.on_found_cleared(found)
	_fx.on_found_changed(new_found)
	found = new_found
	_dynamic.queue_redraw()


func update_selection(new_selection: Array[Vector2i]) -> void:
	if _fx == null:
		return
	selection = new_selection
	_fx.on_selection_changed(new_selection)
	_dynamic.queue_redraw()


func update_hints(cells: Array[Vector2i]) -> void:
	if _fx == null:
		return
	hint_cells = cells
	_fx.on_hint_cells(cells)
	_wake()


func play_wrong() -> void:
	if _fx == null:
		return
	_fx.on_wrong()
	if not Wg.reduce_motion:
		_shake.value = 9.0
		_shake.target = 0.0
		_wake()


## Redémarrage : la grille affichée devient `new_grid` (les mêmes lettres tournées de `turns` quarts de tour horaires) et les
## lettres tournent jusqu'à leurs nouvelles cases.
func play_restart(new_grid: PackedStringArray, turns: int) -> void:
	if _fx == null:
		return
	grid = new_grid
	selection = []
	_restart_count += 1
	_fx.input_locked_until = Time.get_ticks_msec() + (0 if Wg.reduce_motion else GridFx.SHUFFLE_TOTAL_MS)
	_fx.on_restart(turns, _restart_count)
	_dynamic.queue_redraw()
	_wake()


func _wake() -> void:
	set_process(true)


# ---- Boucle d'images : tourne uniquement tant qu'un effet est actif (ou qu'un indice bat)
func _process(delta: float) -> void:
	if _fx == null:
		set_process(false)
		return
	var now := Time.get_ticks_msec()
	_fx.reduce_motion = Wg.reduce_motion
	_fx.tick(now)
	_shake.step(delta)
	if _shake.value != 0.0 or _shake.target != 0.0 or not is_zero_approx(offset_transform_position.x):
		offset_transform_enabled = true
		offset_transform_visual_only = true
		offset_transform_position = Vector2(_shake.value, 0.0)
	_dynamic.queue_redraw()
	if hint_cells.is_empty() and not _fx.has_work(now) and _shake.is_settled():
		offset_transform_position = Vector2.ZERO
		set_process(false)


# ---- Dessin
## La bulle : un grand rectangle arrondi plat, sans contour, sans ombre, sans reflet.
func _paint_card(layer: Control) -> void:
	Wg.rrect(layer, Rect2(Vector2.ZERO, Vector2(_side, _side)), Wg.GRID_BUBBLE, CARD_RADIUS)


func _paint_dynamic(layer: Control) -> void:
	if _fx == null or _n == 0:
		return
	var started := Time.get_ticks_usec()
	_fx.draw(layer, grid, found, selection, selection_color, hint_cells, Wg.font(Wg.Weight.BLACK), _cell_size * 0.56, Wg.INK, _cell_size)
	last_paint_usec = Time.get_ticks_usec() - started


# ---- Gestes
func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - _dynamic.position
	return GridGeometry.cell_at(local.x, local.y, _cell_size, _n)


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or _n == 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _fx != null and Time.get_ticks_msec() < _fx.input_locked_until:
				return
			_pointer_down = true
			_gesture_start = _cell_at(event.position)
			_gesture_path = [_gesture_start] as Array[Vector2i]
			_gesture_direction = -1
			selection_started.emit(_gesture_start)
			accept_event()
		elif _pointer_down:
			_pointer_down = false
			selection_ended.emit()
			accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		# Tracé « continu » : la direction et la longueur suivent la position exacte du doigt (angle par secteurs de 45° avec
		# hystérésis, longueur projetée sur l'axe), pas la case sous le doigt : ligne stable, diagonales faciles, aucun saut.
		var pointer := ((event as InputEventMouseMotion).position - _dynamic.position) / maxf(_cell_size, 1.0)
		_gesture_direction = GridGeometry.direction_for(_gesture_start, pointer, _gesture_direction)
		var length := GridGeometry.length_for(_gesture_start, pointer, _gesture_direction, _n) if _gesture_direction >= 0 else 0
		var next := GridGeometry.path_along(_gesture_start, _gesture_direction, length, _n)
		if next != _gesture_path:
			_gesture_path = next
			selection_changed.emit(next)
		accept_event()
