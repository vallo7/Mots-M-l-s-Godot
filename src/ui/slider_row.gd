class_name SliderRow
extends HBoxContainer
## Ligne de réglage à curseur : icône jaune, libellé et pourcentage, curseur dessous. Le volume est entendu en direct
## pendant le geste ; il n'est enregistré qu'au relâchement.

signal previewed(value: float)
signal committed(value: float)

var _slider: WgSlider
var _percent: Label
var _icon: TextureRect


static func create(icon_name: String, title: String, initial: float) -> SliderRow:
	var row := SliderRow.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = 64.0
	row._icon = UiKit.icon(icon_name, 26.0, Wg.YELLOW_DARK)
	row._icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(row._icon)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Wg.label(title, 18.0, Wg.Weight.EXTRABOLD, Wg.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	row._percent = Wg.label("", 16.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED)
	row._percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(row._percent)
	column.add_child(head)
	row._slider = WgSlider.create(initial, title)
	row._slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(row._slider)
	margin.add_child(column)
	row.add_child(margin)
	row._slider.value_changed.connect(func(v: float) -> void:
		row._refresh_text(v)
		row.previewed.emit(v))
	row._slider.drag_ended.connect(func(v: float) -> void: row.committed.emit(v))
	row._refresh_text(initial)
	return row


func _refresh_text(v: float) -> void:
	_percent.text = "%d %%" % int(round(v * 100.0))
	_icon.self_modulate = Wg.YELLOW_DARK if v > 0.001 else Wg.LOCKED_INK
	_slider.set("accessibility_description", _percent.text)


## Rafraîchit sans signal (ignoré pendant un geste en cours).
func set_value(v: float) -> void:
	if _slider.is_dragging():
		return
	_slider.set_value_silently(v)
	_refresh_text(v)
