class_name HelpScreen
extends Control
## Page d'aide : une démonstration animée du gant, puis des cartes qui expliquent comment jouer, comment les étoiles
## sont attribuées, comment fonctionnent les indices et toutes les façons d'en gagner (récompenses).

var _top: Control
var _scroll: SmoothScroll


static func create() -> HelpScreen:
	return HelpScreen.new()


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Wg.BACKGROUND
	UiKit.full_rect(background)
	add_child(background)
	var insets := App.safe_area_insets
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", int(insets.x))
	margin.add_theme_constant_override("margin_top", int(insets.y))
	margin.add_theme_constant_override("margin_right", int(insets.z))
	margin.add_theme_constant_override("margin_bottom", int(insets.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var bar := ScreenTopBar.create(Strings.t("help_title"))
	bar.back_pressed.connect(App.on_back)
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", UiKit.edge(8))
	bar_margin.add_theme_constant_override("margin_right", UiKit.edge(8))
	bar_margin.add_theme_constant_override("margin_top", UiKit.edge(4))
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_child(bar)
	_top = bar_margin
	column.add_child(bar_margin)

	_scroll = SmoothScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_scroll)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("margin_left", 16)
	holder.add_theme_constant_override("margin_right", 16)
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_theme_constant_override("margin_bottom", 28)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(holder)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(list)

	list.add_child(_demo_card())
	list.add_child(_howto_card())
	list.add_child(_stars_card())
	list.add_child(_hints_card())
	list.add_child(_rewards_card())
	list.add_child(_progress_card())


## Pour la chorégraphie de transition : barre du haut, puis le contenu.
func transition_groups() -> Array:
	return [[_top, "top"], [_scroll, "center"]]


func _card(title: String, accent: Color, accent_dark: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.SURFACE
	box.set_corner_radius_all(int(Wg.R_LG))
	box.set_border_width_all(2)
	box.border_color = Wg.OUTLINE
	box.shadow_color = Color(Wg.SHADOW, Wg.SHADOW.a * 0.5)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0.0, 3.0)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", box)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(body)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	var chip := _Dot.new()
	chip.custom_minimum_size = Vector2(12.0, 28.0)
	chip.face = accent
	chip.lip = accent_dark
	head.add_child(chip)
	var label := Wg.label(title, 20.0, Wg.Weight.BLACK, Wg.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	body.add_child(head)
	# Le conteneur retourné est le corps ; la carte se trouve au-dessus.
	body.set_meta("card", panel)
	return body


## Petite barre de couleur à gauche des titres.
class _Dot extends Control:
	var face: Color
	var lip: Color

	func _draw() -> void:
		Wg.rrect(self, Rect2(0.0, 3.0, size.x, size.y - 3.0), lip, 6.0)
		Wg.rrect(self, Rect2(0.0, 0.0, size.x, size.y - 3.0), face, 6.0)


## Ajoute le corps `body` (renvoyé par `_card`) à une carte et renvoie la carte (le nœud à poser dans la liste).
func _finish(body: VBoxContainer) -> Control:
	return body.get_meta("card") as Control


func _text(text: String, size_px: float = 16.0, color: Color = Wg.INK_MUTED) -> Label:
	var label := Wg.label(text, size_px, Wg.Weight.BOLD, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _demo_card() -> Control:
	var body := _card(Strings.t("help_demo_title"), Wg.PINK, Wg.PINK_DARK)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var demo := LoadingDemo.create(0, App.language)
	demo.cycle_scenarios = true
	center.add_child(demo)
	body.add_child(center)
	return _finish(body)


func _howto_card() -> Control:
	var body := _card(Strings.t("help_howto_title"), Wg.GREEN, Wg.GREEN_DARK)
	var colors: Array = [[Wg.PURPLE, Wg.PURPLE_DARK], [Wg.PINK, Wg.PINK_DARK], [Wg.BLUE, Wg.BLUE_DARK], [Wg.GREEN, Wg.GREEN_DARK]]
	for i in range(4):
		body.add_child(_numbered(i + 1, Strings.t("help_step_%d" % (i + 1)), colors[i][0], colors[i][1]))
	return _finish(body)


func _numbered(number: int, text: String, face: Color, lip: Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var badge := _NumberBadge.new()
	badge.face = face
	badge.lip = lip
	badge.custom_minimum_size = Vector2(34.0, 36.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var n := Wg.label(str(number), 18.0, Wg.Weight.BLACK, Wg.WHITE)
	UiKit.full_rect(n)
	n.offset_bottom = -3.0
	badge.add_child(n)
	row.add_child(badge)
	row.add_child(_text(text, 16.0, Wg.INK))
	return row


class _NumberBadge extends Control:
	var face: Color
	var lip: Color

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 - 1.0)
		draw_circle(c + Vector2(0.0, 3.0), 16.0, lip, true, -1.0, true)
		draw_circle(c, 16.0, face, true, -1.0, true)


func _stars_card() -> Control:
	var body := _card(Strings.t("help_stars_title"), Wg.YELLOW, Wg.YELLOW_DARK)
	body.add_child(_text(Strings.t("help_stars_intro")))
	for count in [3, 2, 1]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		for i in range(3):
			var star := UiKit.icon("ic_star" if i < count else "ic_star_off", 30.0)
			row.add_child(star)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Wg.label(Strings.t("help_stars_%d" % count), 17.0, Wg.Weight.EXTRABOLD, Wg.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		margin.add_child(label)
		row.add_child(margin)
		body.add_child(row)
	return _finish(body)


func _hints_card() -> Control:
	var body := _card(Strings.t("help_hints_title"), Wg.PURPLE, Wg.PURPLE_DARK)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var icon := UiKit.icon("ic_bulb", 44.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	row.add_child(_text(Strings.t("help_hints_body"), 16.0, Wg.INK))
	body.add_child(row)
	return _finish(body)


func _rewards_card() -> Control:
	var body := _card(Strings.t("help_rewards_title"), Wg.ORANGE, Wg.ORANGE_DARK)
	body.add_child(_text(Strings.t("help_rewards_intro")))
	var items: Array = [
		["ic_gift", "help_reward_gift"],
		["ic_video", "help_reward_ad"],
		["ic_calendar_color", "help_reward_daily"],
		["ic_coin_crown", "help_reward_streak"],
	]
	for item in items:
		body.add_child(_reward_row(item[0], Strings.t(item[1] + "_title"), Strings.t(item[1] + "_body")))
	return _finish(body)


func _reward_row(icon_name: String, title: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var tile := _IconTile.new()
	tile.custom_minimum_size = Vector2(52.0, 52.0)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon := UiKit.icon(icon_name, 34.0)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -17.0
	icon.offset_right = 17.0
	icon.offset_top = -17.0
	icon.offset_bottom = 17.0
	tile.add_child(icon)
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Wg.label(title, 17.0, Wg.Weight.EXTRABOLD, Wg.INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(head)
	texts.add_child(_text(text, 14.5))
	row.add_child(texts)
	return row


class _IconTile extends Control:
	func _draw() -> void:
		Wg.rrect(self, Rect2(Vector2.ZERO, size), Wg.TRACK, 18.0)


func _progress_card() -> Control:
	var body := _card(Strings.t("help_progress_title"), Wg.TEAL, Wg.TEAL_DARK)
	body.add_child(_text(Strings.t("help_progress_body"), 16.0, Wg.INK))
	return _finish(body)
