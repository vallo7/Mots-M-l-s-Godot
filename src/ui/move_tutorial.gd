class_name MoveTutorial
extends Control
## Tutoriel de prise en main : le niveau 1 du chapitre 1 sert de tutoriel. Après un micro-délai, le gant montre le tracé du
## premier mot, en boucle (il entre, pose le doigt sur la première lettre, glisse jusqu'à la dernière, relâche, repart),
## sans aucun texte. Dès que le joueur trouve ce mot, on passe au tracé suivant, un par un, jusqu'à la fin du niveau.
## Pendant que le joueur trace lui-même, le gant disparaît ; il reprend si le mot n'est pas encore trouvé.
## Posé en enfant de la grille (même repère), il ne capte jamais le toucher.

const START_DELAY := 0.85  ## micro-délai avant la première démonstration
const NEXT_WORD_DELAY := 0.9  ## laisse jouer l'animation du mot trouvé avant de montrer le suivant
const RESUME_DELAY := 0.8  ## après un geste du joueur qui n'a pas trouvé le mot
const ENTER_OFFSET := Vector2(64.0, 76.0)
const APPROACH := 0.6
const PRESS := 0.28
const HOLD := 0.3
const RELEASE := 0.22
const REST := 0.95
const EXIT := 0.4

var _grid: LetterGridView
var _controller: GameController
var _words: Array[TargetWord] = []
var _orientation := 0  ## orientation de la grille : un redémarrage la fait pivoter, le gant reprend après l'animation
var _target := -1
var _time := 0.0
var _wait := START_DELAY


## Crée le tutoriel comme enfant de `grid`.
static func attach(grid: LetterGridView, controller: GameController, words: Array[TargetWord], delay: float = START_DELAY) -> MoveTutorial:
	var tutorial := MoveTutorial.new()
	tutorial._grid = grid
	tutorial._controller = controller
	tutorial._words = words
	tutorial._orientation = controller.state().orientation
	tutorial._wait = delay
	tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_child(tutorial)
	return tutorial


## Mot à montrer maintenant : le premier mot de la liste pas encore trouvé (-1 = niveau terminé). Fonction pure, testée.
static func next_target(found: Array[int], word_count: int) -> int:
	for i in range(word_count):
		if not found.has(i):
			return i
	return -1


## Durée de la boucle de démonstration d'un mot de `cell_count` lettres (secondes).
static func period_for(cell_count: int) -> float:
	return APPROACH + PRESS + drag_seconds(cell_count) + HOLD + RELEASE + REST + EXIT


static func drag_seconds(cell_count: int) -> float:
	return clampf(0.3 * float(cell_count - 1), 0.8, 2.2)


## Contour d'une capsule (stade) de rayon `radius` entre `a` et `b` : une seule forme convexe, donc une transparence uniforme
## (pas de zones plus foncées là où une ligne et des disques se chevaucheraient).
static func capsule_polygon(a: Vector2, b: Vector2, radius: float, steps: int = 10) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle := 0.0 if a.is_equal_approx(b) else (b - a).angle()
	for i in range(steps + 1):  # demi-cercle autour de b
		points.append(b + Vector2.from_angle(angle - PI * 0.5 + PI * float(i) / steps) * radius)
	for i in range(steps + 1):  # demi-cercle autour de a
		points.append(a + Vector2.from_angle(angle + PI * 0.5 + PI * float(i) / steps) * radius)
	return points


func _process(delta: float) -> void:
	if not is_instance_valid(_controller) or _controller.solved:
		queue_free()
		return
	if _controller.state().orientation != _orientation:
		# Redémarrage : la grille a tourné, les tracés à montrer ont changé de place. On repart après l'animation des lettres.
		_orientation = _controller.state().orientation
		_words = _controller.variant().words
		_target = -1
		_time = 0.0
		_wait = float(GridFx.SHUFFLE_TOTAL_MS) / 1000.0 + RESUME_DELAY
	var target := next_target(_controller.found_word_indices, _words.size())
	if target < 0:
		queue_free()
		return
	if target != _target:
		if _target >= 0:
			_wait = NEXT_WORD_DELAY  # un mot vient d'être trouvé : on passe au tracé suivant
		_target = target
		_time = 0.0
	if not _controller.selection.is_empty() or not _controller.can_interact():
		_time = 0.0
		_wait = maxf(_wait, RESUME_DELAY)  # le joueur trace : le gant s'efface, puis revient si le mot reste à trouver
	elif _wait > 0.0:
		_wait -= delta
	else:
		_time += delta
		if _time >= period_for(_words[_target].cells.size()):
			_time = 0.0
	queue_redraw()


## État du gant à l'instant `t` de la boucle : {tip, press, shown, trail_to (Vector2 ou null), retract (0..1)}.
func pose(t: float, from_cell: Vector2, to_cell: Vector2, cell_count: int) -> Dictionary:
	var drag := drag_seconds(cell_count)
	var t_press := APPROACH
	var t_drag := t_press + PRESS
	var t_hold := t_drag + drag
	var t_release := t_hold + HOLD
	var t_rest := t_release + RELEASE
	var t_exit := t_rest + REST
	var result := {"tip": from_cell, "press": 0.0, "shown": true, "trail_to": null, "retract": 0.0}
	if t < t_press:
		var u := Motion.ease_out_cubic(t / APPROACH)
		result["tip"] = (from_cell + ENTER_OFFSET).lerp(from_cell, u) + Vector2(0.0, -14.0 * Motion.bump(u))  # petit arc
	elif t < t_drag:
		result["press"] = Motion.ease_out_cubic((t - t_press) / PRESS)
		result["trail_to"] = from_cell
	elif t < t_hold:
		var u := Motion.ease_in_out_cubic((t - t_drag) / drag)
		result["tip"] = from_cell.lerp(to_cell, u)
		result["press"] = 1.0
		result["trail_to"] = result["tip"]
	elif t < t_release:
		result["tip"] = to_cell
		result["press"] = 1.0
		result["trail_to"] = to_cell
	elif t < t_rest:
		result["tip"] = to_cell
		result["press"] = 1.0 - Motion.ease_out_cubic((t - t_release) / RELEASE)
		result["trail_to"] = to_cell
	elif t < t_exit:
		result["tip"] = to_cell
		result["trail_to"] = to_cell
		# Le tracé se rétracte vers la dernière lettre en s'amincissant (jamais de fondu).
		result["retract"] = Motion.ease_in_out_cubic(clampf((t - (t_exit - 0.4)) / 0.4, 0.0, 1.0))
	else:
		var u := Motion.ease_in_out_cubic((t - t_exit) / EXIT)
		result["tip"] = to_cell.lerp(to_cell + ENTER_OFFSET, u)
	return result


func _draw() -> void:
	if _target < 0 or _wait > 0.0 or _grid == null:
		return
	var word := _words[_target]
	var count := word.cells.size()
	if count < 2:
		return
	var from_cell := _grid.cell_center(word.cells[0])
	var to_cell := _grid.cell_center(word.cells[count - 1])
	var width := clampf(_grid.cell_extent() * 2.2, 78.0, 104.0)
	var state: Dictionary
	if Wg.reduce_motion:
		# Animations réduites : image fixe (le doigt posé sur la première lettre, le tracé complet dessiné).
		state = {"tip": from_cell, "press": 0.6, "shown": true, "trail_to": to_cell, "retract": 0.0}
	else:
		state = pose(_time, from_cell, to_cell, count)
	var trail: Variant = state["trail_to"]
	if trail != null:
		var color := _grid.selection_color
		color.a = clampf(color.a * 1.25, 0.0, 0.85)
		var retract := float(state["retract"])
		var tail := from_cell.lerp(trail as Vector2, retract)
		draw_colored_polygon(capsule_polygon(tail, trail as Vector2, _grid.cell_extent() * 0.39 * (1.0 - 0.85 * retract)), color)
	TutorialHand.draw_touch(self, state["tip"], float(state["press"]), _grid.cell_extent() * 0.55)
	TutorialHand.draw(self, state["tip"], float(state["press"]), width)
