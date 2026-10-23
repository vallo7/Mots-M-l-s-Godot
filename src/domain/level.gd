class_name Level
extends RefCounted
## Un niveau : thème, style visuel, taille, difficulté, indices, variantes par langue.

const LEVELS_PER_CHAPTER := 10
const FINAL_NUMBER := 10

var id: String
var chapter_index: int
var number: int
var theme: Dictionary
var visual_style: int
var grid_size: int
var difficulty: DifficultyProfile
var hints_max_per_level: int
var variants: Dictionary  ## langue (int) -> LevelVariant


func _init(
	p_id: String, p_chapter_index: int, p_number: int, p_theme: Dictionary, p_visual_style: int,
	p_grid_size: int, p_difficulty: DifficultyProfile, p_hints_max_per_level: int, p_variants: Dictionary
) -> void:
	id = p_id
	chapter_index = p_chapter_index
	number = p_number
	theme = p_theme
	visual_style = p_visual_style
	grid_size = p_grid_size
	difficulty = p_difficulty
	hints_max_per_level = p_hints_max_per_level
	variants = p_variants


func is_final_challenge() -> bool:
	return number == FINAL_NUMBER


## Défi du jour : chapitre 0, identifiant « daily-<jour> » (voir DailyLevelFactory).
func is_daily() -> bool:
	return chapter_index == 0 and id.begins_with("daily-")


## Jour (entier) d'un défi du jour ; -1 pour un niveau ordinaire.
func daily_day() -> int:
	return int(id.substr(6)) if is_daily() else -1


func variant(language: int) -> LevelVariant:
	return variants[language]
