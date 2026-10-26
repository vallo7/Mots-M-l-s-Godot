class_name GameState
extends RefCounted
## État d'une partie. La résolution est *calculée* ici, jamais déduite de l'interface.
## Traité comme immuable : les transitions passent par `copy()`.

var level: Level
var language: int
var found_word_indices: Array[int] = []
var revealed_hints: Array[RevealedHint] = []
var wrong_selections: int = 0
## Quarts de tour horaires appliqués à la grille depuis le début du niveau (chaque redémarrage la fait pivoter, 0..3).
var orientation: int = 0


func _init(p_level: Level, p_language: int) -> void:
	level = p_level
	language = p_language


func copy() -> GameState:
	var c := GameState.new(level, language)
	c.found_word_indices = found_word_indices.duplicate()
	c.revealed_hints = revealed_hints.duplicate()
	c.wrong_selections = wrong_selections
	c.orientation = orientation
	return c


## Grille et mots dans leur orientation actuelle (les indices des mots ne changent jamais, seules les positions).
func variant() -> LevelVariant:
	return level.oriented_variant(language, orientation)


func hints_used() -> int:
	return revealed_hints.size()


func has_found(word_index: int) -> bool:
	return found_word_indices.has(word_index)


func is_solved() -> bool:
	var count := variant().words.size()
	for i in count:
		if not found_word_indices.has(i):
			return false
	return true


## Cases couvertes par les mots trouvés (sans doublon).
func found_cells() -> Array[Vector2i]:
	var seen := {}
	var result: Array[Vector2i] = []
	var words := variant().words
	for index in found_word_indices:
		for cell in words[index].cells:
			if not seen.has(cell):
				seen[cell] = true
				result.append(cell)
	return result
