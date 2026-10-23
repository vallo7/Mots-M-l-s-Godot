class_name DifficultyProfile
extends RefCounted
## Profil de difficulté éditorial. Le score est vérifié par DifficultyScore.

var tier: int
var ambiguity: float
var score: int
## Nombre de leurres plantés dans chaque grille (débuts de mots ou mots « presque justes »). 0 si absent des données.
var decoys: int


func _init(p_tier: int, p_ambiguity: float, p_score: int, p_decoys: int = 0) -> void:
	tier = p_tier
	ambiguity = p_ambiguity
	score = p_score
	decoys = p_decoys


func allowed_directions() -> Array[int]:
	return Direction.for_tier(tier)
