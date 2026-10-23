class_name Decoded
extends RefCounted
## Résultat d'une lecture : GDScript n'a pas d'exceptions, on renvoie donc `ok` + valeur ou message d'erreur.

var ok: bool
var value: Variant
var error: String


static func success(p_value: Variant) -> Decoded:
	var d := Decoded.new()
	d.ok = true
	d.value = p_value
	return d


static func failure(p_error: String) -> Decoded:
	var d := Decoded.new()
	d.ok = false
	d.error = p_error
	return d
