class_name Chapter
extends RefCounted

var id: String
var index: int
var theme: Dictionary
var palette_key: String
var levels: Array[Level]


func _init(p_id: String, p_index: int, p_theme: Dictionary, p_palette_key: String, p_levels: Array[Level]) -> void:
	id = p_id
	index = p_index
	theme = p_theme
	palette_key = p_palette_key
	levels = p_levels
