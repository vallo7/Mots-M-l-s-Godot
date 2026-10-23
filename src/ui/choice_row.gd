class_name ChoiceRow
extends JuicyPressable
## Ligne de réglage qui ouvre une liste : icône jaune, libellé, valeur courante et chevron. Toute la ligne est cliquable.

var _value_label: Label


static func create(icon_name: String, title: String, value_text: String) -> ChoiceRow:
	var row := ChoiceRow.new()
	row.squash = 0.45
	row.sound = Sound.MENU_CHANGE
	row.haptic = HapticEffect.SELECTION
	row.description = "%s, %s" % [title, value_text]
	custom_minimum_size_for(row)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 0)
	UiKit.full_rect(line)
	line.offset_top = 4.0
	line.offset_bottom = -4.0
	row.add_child(line)
	var icon := UiKit.icon(icon_name, 26.0, Wg.YELLOW_DARK)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := Wg.label(title, 18.0, Wg.Weight.EXTRABOLD, Wg.INK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(title_label)
	line.add_child(margin)
	row._value_label = Wg.label(value_text, 17.0, Wg.Weight.EXTRABOLD, Wg.PURPLE if not Wg.dark else Color8(0xB8, 0xA6, 0xFF))
	row._value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(row._value_label)
	var chevron := UiKit.icon("ic_chevron", 16.0, Wg.INK_MUTED)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chevron_margin := MarginContainer.new()
	chevron_margin.add_theme_constant_override("margin_left", 6)
	chevron_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron_margin.add_child(chevron)
	line.add_child(chevron_margin)
	return row


static func custom_minimum_size_for(row: ChoiceRow) -> void:
	row.custom_minimum_size = Vector2(0.0, 52.0)


func set_value_text(text: String) -> void:
	_value_label.text = text
