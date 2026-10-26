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


## Vrai si la grille est carrée (seules les grilles carrées pivotent : toutes celles du jeu le sont).
func is_square() -> bool:
	for row in grid:
		if row.length() != grid.size():
			return false
	return not grid.is_empty()


## Case (colonne, ligne) d'une grille de côté `n` après `turns` quarts de tour horaires.
static func rotate_cell(cell: Vector2i, n: int, turns: int) -> Vector2i:
	var result := cell
	for _i in range(posmod(turns, 4)):
		result = Vector2i(n - 1 - result.y, result.x)
	return result


## Même grille et mêmes mots après `turns` quarts de tour horaires (négatif = antihoraire) : les lettres changent de place et
## les mots se lisent dans d'autres directions, mais ce sont exactement les mêmes mots. Une grille non carrée est rendue telle quelle.
func rotated(turns: int) -> LevelVariant:
	var t := posmod(turns, 4)
	if t == 0 or not is_square():
		return self
	var n := grid.size()
	var rows: Array = []  # n lignes de n lettres (tableaux : un PackedStringArray extrait d'un tableau serait une copie)
	for _y in n:
		var row: Array = []
		row.resize(n)
		rows.append(row)
	for y in n:
		for x in n:
			var to := rotate_cell(Vector2i(x, y), n, t)
			(rows[to.y] as Array)[to.x] = grid[y][x]
	var new_grid := PackedStringArray()
	for row in rows:
		new_grid.append("".join(PackedStringArray(row as Array)))
	var new_words: Array[TargetWord] = []
	for word in words:
		new_words.append(TargetWord.new(word.display, word.letters, rotate_cell(word.start, n, t), Direction.rotate(word.direction, t)))
	return LevelVariant.new(language, new_grid, new_words)


func in_bounds(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].length()


func letter_at(cell: Vector2i) -> String:
	return grid[cell.y][cell.x]
