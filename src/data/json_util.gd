class_name JsonUtil
extends RefCounted
## Petits utilitaires pour lire du JSON de façon typée (Godot parse tous les nombres en float).


static func to_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


static func get_int(obj: Dictionary, key: String, fallback: int = 0) -> int:
	return to_int(obj.get(key, fallback), fallback)


static func get_bool(obj: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = obj.get(key, fallback)
	return v if v is bool else fallback


static func get_string(obj: Dictionary, key: String, fallback: String = "") -> String:
	var v: Variant = obj.get(key, fallback)
	return v if v is String else fallback


## Tableau d'entiers ; ignore les éléments qui ne sont pas des nombres.
static func int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			if item is int or item is float:
				result.append(int(item))
	return result


static func string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			if item is String:
				result.append(item)
	return result


## Dictionary racine ou null si le texte n'est pas un objet JSON valide.
static func parse_object(text: String) -> Variant:
	var json := JSON.new()  # JSON.new().parse ne journalise pas d'erreur, contrairement à JSON.parse_string
	if json.parse(text) != OK:
		return null
	return json.data if json.data is Dictionary else null
