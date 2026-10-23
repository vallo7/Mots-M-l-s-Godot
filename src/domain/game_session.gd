class_name GameSession
extends RefCounted
## Partie en cours : moteur de règles + chronomètre. Sans nœud, sans scène : testable en pur GDScript.
## Le chronomètre démarre à la première interaction avec la grille.

var level: Level
var language: int
var state: GameState
var _timer: GameTimer


func _init(p_level: Level, p_language: int, clock: Callable) -> void:
	level = p_level
	language = p_language
	_timer = GameTimer.new(clock)
	state = GameEngine.new_game(level, language)


func is_solved() -> bool:
	return state.is_solved()


func has_started() -> bool:
	return _timer.has_started()


func is_running() -> bool:
	return _timer.is_running()


func elapsed_millis() -> int:
	return _timer.elapsed_millis()


func begin_interaction() -> void:
	if not is_solved():
		_timer.start_if_needed()


func submit(path: Array[Vector2i]) -> SessionEvent:
	if is_solved():
		return SessionEvent.new(SessionEvent.Kind.IGNORED)
	begin_interaction()
	var result := GameEngine.select(state, path)
	state = result.state
	match result.kind:
		SelectionResult.Kind.FOUND:
			return SessionEvent.new(SessionEvent.Kind.FOUND, result.word_index, state.is_solved())
		SelectionResult.Kind.ALREADY_FOUND:
			return SessionEvent.new(SessionEvent.Kind.ALREADY_FOUND, result.word_index)
		SelectionResult.Kind.WRONG:
			return SessionEvent.new(SessionEvent.Kind.WRONG)
		_:
			return SessionEvent.new(SessionEvent.Kind.IGNORED)


func apply_hint(outcome: HintOutcome) -> void:
	state = outcome.state


func pause() -> void:
	_timer.pause()


func resume() -> void:
	if not is_solved():
		_timer.resume()


## Fige le chronomètre et renvoie le temps final.
func finish() -> int:
	return _timer.stop()


func restart() -> void:
	state = GameEngine.new_game(level, language)
	_timer.reset()


func snapshot() -> GameSnapshot:
	var hinted: Array[int] = []
	for hint in state.revealed_hints:
		hinted.append(hint.word_index)
	return GameSnapshot.new(state.found_word_indices.duplicate(), hinted, state.wrong_selections, _timer.elapsed_millis())


## Restaure une sauvegarde ; ignore les indices invalides (sauvegarde d'une autre version du niveau).
func restore(snapshot_value: GameSnapshot) -> void:
	var words := state.variant().words
	var restored := GameState.new(level, language)
	for index in snapshot_value.found_word_indices:
		if index >= 0 and index < words.size() and not restored.found_word_indices.has(index):
			restored.found_word_indices.append(index)
	for index in snapshot_value.hinted_word_indices:
		if index >= 0 and index < words.size():
			var already := false
			for hint in restored.revealed_hints:
				if hint.word_index == index:
					already = true
			if not already:
				restored.revealed_hints.append(RevealedHint.new(index, words[index].start))
	restored.wrong_selections = maxi(0, snapshot_value.wrong_selections)
	state = restored
	_timer.restore_elapsed(snapshot_value.elapsed_millis)
