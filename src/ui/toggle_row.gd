class_name ToggleRow
extends JuicyPressable
## Ligne de réglage : icône jaune, libellé (+ sous-titre), interrupteur. Toute la ligne est cliquable.

var _switch: WgSwitch
var _row := HBoxContainer.new()
var _checked := false


static func create(icon_name: String, title: String, subtitle: String, checked: bool, on_change: Callable) -> ToggleRow:
	var row := ToggleRow.new()
	row.squash = 0.45
	row.sound = Sound.CLICK
	row.haptic = -1
	row._checked = checked
	row.description = title
	row._row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row._row.add_theme_constant_override("separation", 0)
	UiKit.full_rect(row._row)
	row._row.offset_top = 4.0
	row._row.offset_bottom = -4.0
	row.add_child(row._row)
	var icon := UiKit.icon(icon_name, 26.0, Wg.YELLOW_DARK)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row._row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := Wg.label(title, 18.0, Wg.Weight.EXTRABOLD, Wg.INK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(title_label)
	if not subtitle.is_empty():
		var sub := Wg.label(subtitle, 12.0, Wg.Weight.BOLD, Wg.INK_MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(sub)
	margin.add_child(texts)
	row._row.add_child(margin)
	row._switch = WgSwitch.create(checked)
	row._switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row._row.add_child(row._switch)
	row.activated.connect(func() -> void: on_change.call(not row._checked))
	return row


func _get_minimum_size() -> Vector2:
	return Vector2(0.0, maxf(52.0, _row.get_combined_minimum_size().y + 8.0))


func set_checked(checked: bool) -> void:
	if checked == _checked:
		return
	_checked = checked
	_switch.set_checked(checked)
	set("accessibility_description", Strings.t("settings_state_on" if checked else "settings_state_off"))
