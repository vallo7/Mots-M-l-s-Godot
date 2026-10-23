class_name RevealedHint
extends RefCounted

var word_index: int
var cell: Vector2i


func _init(p_word_index: int, p_cell: Vector2i) -> void:
	word_index = p_word_index
	cell = p_cell
