class_name GameEngine
extends RefCounted
## Règles de sélection : le tracé du joueur est comparé au placement des mots cibles.


static func new_game(level: Level, language: int) -> GameState:
	return GameState.new(level, language)


## Évalue le tracé du joueur (`path`, dans l'ordre du doigt). Le sens importe peu : on compare
## l'ensemble de cases au placement des mots cibles (unicité garantie par le validateur).
static func select(state: GameState, path: Array[Vector2i]) -> SelectionResult:
	if path.size() < 2:
		return SelectionResult.new(SelectionResult.Kind.IGNORED, state)
	if not is_straight_line(state.variant(), path):
		return _wrong(state)
	var index := _find_word_with_cells(state.variant(), path)
	if index < 0:
		return _wrong(state)
	if state.has_found(index):
		return SelectionResult.new(SelectionResult.Kind.ALREADY_FOUND, state, index)
	var next := state.copy()
	next.found_word_indices.append(index)
	return SelectionResult.new(SelectionResult.Kind.FOUND, next, index)


static func is_straight_line(variant: LevelVariant, path: Array[Vector2i]) -> bool:
	if path.size() < 2:
		return false
	for cell in path:
		if not variant.in_bounds(cell):
			return false
	var direction := Direction.step_between(path[0], path[1])
	if direction < 0:
		return false
	for i in range(1, path.size()):
		if Direction.step_between(path[i - 1], path[i]) != direction:
			return false
	return true


static func _wrong(state: GameState) -> SelectionResult:
	var next := state.copy()
	next.wrong_selections += 1
	return SelectionResult.new(SelectionResult.Kind.WRONG, next)


## Index du mot dont l'ensemble de cases est exactement celui du tracé, ou -1.
static func _find_word_with_cells(variant: LevelVariant, path: Array[Vector2i]) -> int:
	var selected := {}
	for cell in path:
		selected[cell] = true
	if selected.size() != path.size():
		return -1
	for i in variant.words.size():
		var cells := variant.words[i].cells
		if cells.size() != selected.size():
			continue
		var same := true
		for cell in cells:
			if not selected.has(cell):
				same = false
				break
		if same:
			return i
	return -1
