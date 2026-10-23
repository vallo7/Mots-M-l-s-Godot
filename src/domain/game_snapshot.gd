class_name GameSnapshot
extends RefCounted
## Partie en cours sauvegardée (reprise après interruption). Les cases d'indice sont déduites des mots indicés.

var found_word_indices: Array[int]
var hinted_word_indices: Array[int]
var wrong_selections: int
var elapsed_millis: int


func _init(p_found: Array[int], p_hinted: Array[int], p_wrong: int, p_elapsed: int) -> void:
	found_word_indices = p_found
	hinted_word_indices = p_hinted
	wrong_selections = p_wrong
	elapsed_millis = p_elapsed
