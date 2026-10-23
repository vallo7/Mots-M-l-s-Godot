class_name ValidationIssue
extends RefCounted

var level_id: String  ## "" = problème de catalogue
var code: String
var message: String


func _init(p_level_id: String, p_code: String, p_message: String) -> void:
	level_id = p_level_id
	code = p_code
	message = p_message


func _to_string() -> String:
	return "[%s] %s : %s" % [level_id if not level_id.is_empty() else "catalogue", code, message]
