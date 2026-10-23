class_name LevelResult
extends RefCounted

var stars: int
var elapsed_millis: int


func _init(p_stars: int, p_elapsed_millis: int) -> void:
	stars = p_stars
	elapsed_millis = p_elapsed_millis
