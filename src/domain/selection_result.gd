class_name SelectionResult
extends RefCounted

enum Kind { FOUND, ALREADY_FOUND, WRONG, IGNORED }

var kind: int
var word_index: int
var state: GameState


func _init(p_kind: int, p_state: GameState, p_word_index: int = -1) -> void:
	kind = p_kind
	state = p_state
	word_index = p_word_index
