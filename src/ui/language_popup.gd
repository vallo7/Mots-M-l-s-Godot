class_name LanguagePopup
extends PopupHost
## Liste dédiée au choix de la langue : « Automatique » (langue du téléphone), Français, English. La ligne choisie
## porte une coche ; après le choix on revient aux réglages. Le contenu du jeu existe dans chaque langue.

var _rows: Array[_LanguageRow] = []


## Une ligne de la liste : pastille de code, nom dans sa propre langue, coche si choisie.
class _LanguageRow extends JuicyPressable:
	var choice: int
	var selected := false
	var badge_text: String
	var badge_color: Color
	var badge_dark: Color

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var face: Color = Color(Wg.PURPLE, 0.16) if selected else Wg.TRACK
		Wg.rrect(self, r, face, 22.0)
		if selected:
			Wg.outline(self, r, Wg.PURPLE, 22.0, 3.0)
		var c := Vector2(34.0, size.y * 0.5)
		draw_circle(c + Vector2(0.0, 2.5), 22.0, badge_dark, true, -1.0, true)
		draw_circle(c, 22.0, badge_color, true, -1.0, true)
		_draw_focus_ring(r, 22.0)


static func open_list(parent: Node) -> LanguagePopup:
	var host := LanguagePopup.new()
	var card := PopupCard.create(Strings.t("language_title"), "blue", true, Strings.t("cd_close"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	card.body.add_child(list)
	var options: Array = [
		[AppSettings.NONE, "AUTO", Strings.t("language_auto_name"), Strings.t("language_auto_hint"), Wg.TEAL, Wg.TEAL_DARK],
		[Language.FR, "FR", Strings.t("language_fr_name"), "", Wg.BLUE, Wg.BLUE_DARK],
		[Language.EN, "EN", Strings.t("language_en_name"), "", Wg.PINK, Wg.PINK_DARK],
	]
	for option in options:
		var row := _make_row(option)
		host._rows.append(row)
		list.add_child(row)
	PopupHost.open(parent, card, true, host)
	card.close_pressed.connect(App.on_back)
	host.dismissed.connect(App.on_back)
	return host


static func _make_row(option: Array) -> _LanguageRow:
	var row := _LanguageRow.new()
	row.choice = option[0]
	row.badge_text = option[1]
	row.badge_color = option[4]
	row.badge_dark = option[5]
	row.squash = 0.5
	row.sound = Sound.MENU_CHANGE
	row.custom_minimum_size = Vector2(0.0, 68.0)
	row.selected = App.settings.language == row.choice
	row.description = option[2]
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 0)
	UiKit.full_rect(line)
	line.offset_left = 12.0
	line.offset_right = -14.0
	row.add_child(line)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(44.0, 44.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var code_label := Wg.label(option[1], 13.0 if String(option[1]).length() > 2 else 16.0, Wg.Weight.BLACK, Wg.WHITE)
	UiKit.full_rect(code_label)
	badge.add_child(code_label)
	line.add_child(badge)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Wg.label(option[2], 20.0, Wg.Weight.EXTRABOLD, Wg.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(name_label)
	if not String(option[3]).is_empty():
		var hint := Wg.label(option[3], 12.0, Wg.Weight.BOLD, Wg.INK_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(hint)
	margin.add_child(texts)
	line.add_child(margin)
	var check := UiKit.icon("ic_check_green", 30.0)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.visible = row.selected
	line.add_child(check)
	row.activated.connect(func() -> void:
		App.set_language_choice(row.choice)
		await row.get_tree().create_timer(0.28).timeout
		if App.current_route().kind == ScreenRoute.Kind.LANGUAGE:
			App.on_back())
	return row
