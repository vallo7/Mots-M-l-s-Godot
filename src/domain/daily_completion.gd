class_name DailyCompletion
extends RefCounted
## Résultat d'une victoire au défi du jour : nouvel état de progression et détail des récompenses.

var state: ProgressState
var already_done := false
var base_hints := 0
var star_bonus_hints := 0
var milestone_hints := 0
var streak := 0
var best_streak := 0
var new_best := false
## Palier de série atteint par cette victoire (0 si aucun).
var milestone_days := 0


func _init(p_state: ProgressState) -> void:
	state = p_state


func total_hints() -> int:
	return base_hints + star_bonus_hints + milestone_hints
