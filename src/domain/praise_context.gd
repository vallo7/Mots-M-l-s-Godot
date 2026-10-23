class_name PraiseContext
extends RefCounted

var stars: int
var hints_used: int
var wrong_selections: int
var elapsed_millis: int
var is_final_challenge: bool
## Niveaux consécutifs à 3 étoiles *avant* celui-ci.
var perfect_streak_before: int


func _init(
	p_stars: int, p_hints_used: int, p_wrong_selections: int, p_elapsed_millis: int,
	p_is_final_challenge: bool, p_perfect_streak_before: int
) -> void:
	stars = p_stars
	hints_used = p_hints_used
	wrong_selections = p_wrong_selections
	elapsed_millis = p_elapsed_millis
	is_final_challenge = p_is_final_challenge
	perfect_streak_before = p_perfect_streak_before
