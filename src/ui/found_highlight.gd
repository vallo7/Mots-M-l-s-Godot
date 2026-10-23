class_name FoundHighlight
extends RefCounted
## Mot trouvé à afficher : cases + couleur de capsule.

var cells: Array[Vector2i]
var color: Color


func _init(p_cells: Array[Vector2i], p_color: Color) -> void:
	cells = p_cells
	color = p_color
