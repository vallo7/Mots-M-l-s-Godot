class_name HintChip
extends Pill
## Solde d'indices : ampoule + nombre, dans une pastille blanche cerclée de lavande ; le nombre rebondit quand il change.

var _count_label: Label
var _count := -1


static func create_with(count: int) -> HintChip:
	var chip := HintChip.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.SURFACE
	box.set_corner_radius_all(999)
	box.corner_detail = 12
	box.anti_aliasing = true
	box.border_color = Wg.OUTLINE
	box.set_border_width_all(2)
	box.content_margin_left = 6.0
	box.content_margin_right = 14.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", box)
	chip.row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.row.add_theme_constant_override("separation", 4)
	chip.add_child(chip.row)
	chip.row.add_child(UiKit.icon("ic_bulb", 26.0))
	chip._count_label = Wg.label("0", 18.0, Wg.Weight.EXTRABOLD, Wg.INK)
	chip._count_label.custom_minimum_size.x = 14.0
	chip.row.add_child(chip._count_label)
	chip.set_count(count, false)
	return chip


func set_count(count: int, animate: bool = true) -> void:
	if count == _count:
		return
	var first := _count < 0
	_count = count
	_count_label.text = str(count)
	set("accessibility_name", Strings.n("hints_count", count))
	if animate and not first:
		UiFx.bounce(_count_label)
