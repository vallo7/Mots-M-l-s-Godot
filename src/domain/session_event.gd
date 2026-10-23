class_name SessionEvent
extends RefCounted

enum Kind { FOUND, ALREADY_FOUND, WRONG, IGNORED }

var kind: int
var word_index: int
var solved: bool


func _init(p_kind: int, p_word_index: int = -1, p_solved: bool = false) -> void:
	kind = p_kind
	word_index = p_word_index
	solved = p_solved
