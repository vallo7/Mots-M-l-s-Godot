class_name TimeFormat
extends RefCounted


## 83 s -> « 1:23 ». Indépendant de la langue du téléphone.
static func mmss(millis: int) -> String:
	@warning_ignore("integer_division")
	var total := maxi(0, millis) / 1000
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]
