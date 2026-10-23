class_name TargetWord
extends RefCounted
## Mot à trouver. `display` : texte affiché (accents autorisés), `letters` : suite A-Z présente
## dans la grille, `start` : première case (x = colonne, y = ligne), `direction` : sens de pose.

var display: String
var letters: String
var start: Vector2i
var direction: int
var cells: Array[Vector2i] = []


func _init(p_display: String, p_letters: String, p_start: Vector2i, p_direction: int) -> void:
	display = p_display
	letters = p_letters
	start = p_start
	direction = p_direction
	var step := Direction.vector(direction)
	for i in letters.length():
		cells.append(start + step * i)


func length() -> int:
	return letters.length()


func end_cell() -> Vector2i:
	return cells[cells.size() - 1]
