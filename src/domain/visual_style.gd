class_name VisualStyle
extends RefCounted
## 4 styles visuels : trois varient selon le chapitre, FINAL est réservé au niveau 10.

enum { STYLE_1, STYLE_2, STYLE_3, FINAL }

const NAMES: Array[String] = ["STYLE_1", "STYLE_2", "STYLE_3", "FINAL"]


static func from_name(name_value: String) -> int:
	return NAMES.find(name_value)


static func for_level(chapter_index: int, number: int) -> int:
	if number == Level.FINAL_NUMBER:
		return FINAL
	@warning_ignore("integer_division")
	var band := (number - 1) / 3
	match (band + chapter_index - 1) % 3:
		0:
			return STYLE_1
		1:
			return STYLE_2
		_:
			return STYLE_3
