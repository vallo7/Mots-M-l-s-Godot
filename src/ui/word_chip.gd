class_name WordChip
extends PanelContainer
## Pastille d'un mot à trouver. Un mot trouvé se remplit de sa couleur, se barre, et rebondit.

var _found := false
var _color: Color
var _label: Label
var _check: TextureRect
var _strike: ColorRect
var _box := StyleBoxFlat.new()


static func create(text: String, color: Color, compact: bool) -> WordChip:
	var chip := WordChip.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip._color = color
	chip.custom_minimum_size.y = 28.0 if compact else 32.0
	chip._box.set_corner_radius_all(999)
	chip._box.corner_detail = 12
	chip._box.anti_aliasing = true
	chip._box.content_margin_left = 10.0 if compact else 12.0
	chip._box.content_margin_right = chip._box.content_margin_left
	chip.add_theme_stylebox_override("panel", chip._box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	chip.add_child(row)
	chip._check = UiKit.icon("ic_check", 14.0, Wg.WHITE)
	chip._check.visible = false
	row.add_child(chip._check)
	chip._label = Wg.label(text, 12.0 if compact else 14.0, Wg.Weight.EXTRABOLD, Wg.INK)
	row.add_child(chip._label)
	chip._strike = ColorRect.new()
	chip._strike.color = Wg.WHITE
	chip._strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip._strike.anchor_right = 1.0
	chip._strike.anchor_top = 0.5
	chip._strike.anchor_bottom = 0.5
	chip._strike.offset_top = -0.8
	chip._strike.offset_bottom = 0.8
	chip._strike.visible = false
	chip._label.add_child(chip._strike)
	chip.set_found(false, false)
	chip.set("accessibility_name", text)
	return chip


func set_found(found: bool, animate: bool = true) -> void:
	var became_found := found and not _found
	_found = found
	_box.bg_color = _color if found else Wg.TRACK
	_label.add_theme_color_override("font_color", Wg.WHITE if found else Wg.INK)
	_check.visible = found
	_strike.visible = found
	if became_found and animate:
		UiFx.bounce(self, 1.32, 0.34, 460.0)
