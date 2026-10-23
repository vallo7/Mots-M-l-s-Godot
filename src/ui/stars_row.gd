class_name StarsRow
extends HBoxContainer
## Étoiles obtenues (dorées) et manquantes (lavande).


static func create(stars: int, p_size: float) -> StarsRow:
	var row := StarsRow.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 1)
	row.set("accessibility_name", Strings.n("stars_count", stars))
	for i in range(3):
		row.add_child(UiKit.icon("ic_star" if i < stars else "ic_star_off", p_size))
	return row
