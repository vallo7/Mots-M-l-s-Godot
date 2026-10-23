class_name LevelVariant
extends RefCounted
## Grille et mots d'un niveau dans une langue.

var language: int
var grid: PackedStringArray
var words: Array[TargetWord]


func _init(p_language: int, p_grid: PackedStringArray, p_words: Array[TargetWord]) -> void:
	language = p_language
	grid = p_grid
	words = p_words


func in_bounds(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].length()


func letter_at(cell: Vector2i) -> String:
	return grid[cell.y][cell.x]
