class_name DailyScreen
extends Control
## Page du défi du jour : la grille du jour (thème, taille, difficulté, bouton jouer ou résultat + compte à rebours),
## la série (flamme, 7 derniers jours), le calendrier du mois et l'échelle des récompenses.

var _top: Control
var _scroll: ScrollContainer
var _content: VBoxContainer
var _countdown: Label
var _shown_day := -1
var _tick := 0.0


static func create() -> DailyScreen:
	return DailyScreen.new()


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
	var bar := ScreenTopBar.create(Strings.t("daily_title"))
	bar.back_pressed.connect(App.on_back)
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", UiKit.edge(8))
	bar_margin.add_theme_constant_override("margin_right", UiKit.edge(8))
	bar_margin.add_theme_constant_override("margin_top", UiKit.edge(4))
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_child(bar)
	_top = bar_margin
	column.add_child(bar_margin)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(_content)
	App.daily_changed.connect(_rebuild)
	App.progress_changed.connect(_rebuild)
	App.daily_prepare()
	_rebuild()
	set_process(true)


## Pour la chorégraphie de transition : barre du haut, puis le contenu.
func transition_groups() -> Array:
	return [[_top, "top"], [_scroll, "center"]]


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	App.check_day_rollover()
	if DailyChallenge.today_index() != _shown_day:
		_rebuild()
	elif is_instance_valid(_countdown):
		_countdown.text = Strings.t("daily_next_in", [DailyText.countdown(DailyChallenge.seconds_until_tomorrow())])


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var model := App.daily_model()
	_shown_day = model.today
	_countdown = null
	_content.add_child(_hero(model))
	_content.add_child(_streak_card(model))
	_content.add_child(_calendar_card(model))
	_content.add_child(_rewards_card(model))


# ---- Cartes
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
	var bar := _Bar.new()
	bar.custom_minimum_size = Vector2(12.0, 28.0)
	bar.face = accent
	bar.lip = accent_dark
	head.add_child(bar)
	var label := Wg.label(title, 20.0, Wg.Weight.BLACK, Wg.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	body.add_child(head)
	body.set_meta("card", panel)
	return body


class _Bar extends Control:
	var face: Color
	var lip: Color

	func _draw() -> void:
		Wg.rrect(self, Rect2(0.0, 3.0, size.x, size.y - 3.0), lip, 6.0)
		Wg.rrect(self, Rect2(0.0, 0.0, size.x, size.y - 3.0), face, 6.0)


func _text(text: String, size_px: float = 15.0, color: Color = Wg.INK_MUTED, weight: int = Wg.Weight.BOLD) -> Label:
	var label := Wg.label(text, size_px, weight, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## Carte du défi : couleur selon la difficulté, thème en grand, puis bouton jouer ou résultat.
func _hero(model: DailyModel) -> Control:
	var colors := DailyText.band_colors(model.band)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = colors[0]
	box.set_corner_radius_all(int(Wg.R_LG))
	box.border_width_bottom = 8
	box.border_color = colors[1]
	box.shadow_color = Wg.SHADOW
	box.shadow_size = 8
	box.shadow_offset = Vector2(0.0, 4.0)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", box)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(body)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	var date := _text(DailyText.capitalized(DailyText.date_label(model.today)), 15.0, Color(Wg.WHITE, 0.92), Wg.Weight.EXTRABOLD)
	top.add_child(date)
	top.add_child(DifficultyBadge.create_for(model.band))
	body.add_child(top)
	var theme_name := Language.pick(model.theme, App.language) if not model.theme.is_empty() else "…"
	var title := Wg.label(theme_name, 32.0, Wg.Weight.BLACK, Wg.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	body.add_child(_text(Strings.t("daily_size_band", [model.grid_size, DailyText.band_name(model.band)]), 16.0, Color(Wg.WHITE, 0.9), Wg.Weight.EXTRABOLD))
	var space := Control.new()
	space.custom_minimum_size.y = 6.0
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(space)
	match model.status:
		DailyModel.Status.DONE:
			var stars_holder := CenterContainer.new()
			stars_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stars_holder.add_child(StarsRow.create(model.stars, 40.0))
			body.add_child(stars_holder)
			var done := Wg.label(Strings.t("daily_done_stars", [model.stars, DailyText.duration(model.elapsed_millis)]), 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE)
			body.add_child(done)
			_countdown = Wg.label(Strings.t("daily_next_in", [DailyText.countdown(model.seconds_left)]), 15.0, Wg.Weight.BOLD, Color(Wg.WHITE, 0.9))
			body.add_child(_countdown)
		DailyModel.Status.LOADING:
			body.add_child(Wg.label(Strings.t("daily_loading"), 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
		_:
			var label := "daily_resume" if model.status == DailyModel.Status.IN_PROGRESS else "daily_play"
			var play := WgButton.create(Strings.t(label), WgButton.Kind.PRIMARY, "ic_play", true)
			play.activated.connect(App.play_daily)
			body.add_child(play)
	return panel


func _streak_card(model: DailyModel) -> Control:
	var body := _card(Strings.t("daily_streak_title"), Wg.ORANGE, Wg.ORANGE_DARK)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var flame := UiKit.icon("ic_coin_crown" if model.streak > 0 else "ic_calendar_color", 54.0)
	flame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flame)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if model.streak > 0:
		texts.add_child(_text(Strings.n("daily_streak_days", model.streak), 26.0, Wg.INK, Wg.Weight.BLACK))
		texts.add_child(_text(Strings.t("daily_best", [model.best_streak]), 14.0))
	else:
		texts.add_child(_text(Strings.t("daily_streak_none"), 16.0, Wg.INK, Wg.Weight.EXTRABOLD))
		if model.best_streak > 0:
			texts.add_child(_text(Strings.t("daily_best", [model.best_streak]), 14.0))
	row.add_child(texts)
	body.add_child(row)
	var strip := _WeekStrip.new()
	strip.week = model.week
	strip.custom_minimum_size = Vector2(0.0, 62.0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(strip)
	return body.get_meta("card")


## Les 7 derniers jours : initiale du jour, puis un rond (réussi, aujourd'hui, manqué).
class _WeekStrip extends Control:
	var week: Array[Dictionary] = []

	func _draw() -> void:
		var count := week.size()
		if count == 0:
			return
		var font := Wg.font(Wg.Weight.EXTRABOLD)
		var cell := size.x / count
		for i in count:
			var entry: Dictionary = week[i]
			var cx := cell * (i + 0.5)
			var letter := DailyText.weekday_short(int(entry["weekday"]))
			var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(cx - width * 0.5, 13.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Wg.INK_MUTED)
			var c := Vector2(cx, 40.0)
			match String(entry["state"]):
				"done":
					draw_circle(c + Vector2(0.0, 2.5), 17.0, Wg.GREEN_DARK, true, -1.0, true)
					draw_circle(c, 17.0, Wg.GREEN, true, -1.0, true)
					draw_texture_rect(Icons.get_icon("ic_check"), Rect2(c - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), false, Wg.WHITE)
				"today":
					draw_circle(c, 17.0, Wg.TRACK, true, -1.0, true)
					draw_arc(c, 16.0, 0.0, TAU, 32, Wg.YELLOW, 4.0, true)
				_:
					draw_circle(c, 17.0, Wg.TRACK, true, -1.0, true)
					draw_circle(c, 4.0, Wg.LOCKED_DARK, true, -1.0, true)


func _calendar_card(model: DailyModel) -> Control:
	var body := _card(DailyText.month_label(model.month["year"], model.month["month"]), Wg.BLUE, Wg.BLUE_DARK)
	var grid := _MonthGrid.new()
	grid.month = model.month
	var rows := int(ceil((int(model.month["first_weekday"]) + (model.month["days"] as Array).size()) / 7.0))
	grid.custom_minimum_size = Vector2(0.0, 22.0 + rows * 42.0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(grid)
	return body.get_meta("card")


class _MonthGrid extends Control:
	var month: Dictionary = {}

	func _draw() -> void:
		var font := Wg.font(Wg.Weight.EXTRABOLD)
		var cell := size.x / 7.0
		for d in range(7):
			var letter := DailyText.weekday_short(d)
			var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(cell * (d + 0.5) - width * 0.5, 13.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Wg.INK_MUTED)
		var first := int(month["first_weekday"])
		var number_font := Wg.font(Wg.Weight.BLACK)
		for entry in month["days"]:
			var slot: int = first + int(entry["number"]) - 1
			var c := Vector2(cell * ((slot % 7) + 0.5), 22.0 + (slot / 7) * 42.0 + 20.0)
			var text := str(entry["number"])
			var tw := number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var ink := Wg.INK_MUTED
			match String(entry["state"]):
				"done":
					draw_circle(c, 17.0, Wg.GREEN, true, -1.0, true)
					ink = Wg.WHITE
				"today":
					draw_circle(c, 17.0, Wg.TRACK, true, -1.0, true)
					draw_arc(c, 16.0, 0.0, TAU, 32, Wg.PURPLE, 3.0, true)
					ink = Wg.INK
				"missed":
					ink = Wg.LOCKED_INK
				_:
					ink = Wg.LOCKED_DARK
			draw_string(number_font, Vector2(c.x - tw * 0.5, c.y + 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)


func _rewards_card(model: DailyModel) -> Control:
	var body := _card(Strings.t("daily_rewards_title"), Wg.YELLOW, Wg.YELLOW_DARK)
	body.add_child(_text(Strings.t("daily_rewards_base")))
	for entry in model.milestones:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var reached: bool = entry["reached"]
		var icon := UiKit.icon("ic_check_green" if reached else "ic_coin_crown", 28.0)
		if not reached:
			icon.self_modulate = Color(Wg.WHITE, 0.55)
		row.add_child(icon)
		var label := _text(Strings.t("daily_milestone_row", [entry["days"]]), 16.0, Wg.INK if reached else Wg.INK_MUTED, Wg.Weight.EXTRABOLD)
		row.add_child(label)
		var hints := Wg.label(Strings.n("daily_milestone_hints", entry["hints"]), 16.0, Wg.Weight.BLACK, Wg.GREEN_DARK if reached else Wg.INK_MUTED)
		hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(hints)
		body.add_child(row)
	if model.next_milestone != Vector2i.ZERO:
		body.add_child(_text(Strings.t("daily_next_milestone", [model.next_milestone.x - model.streak]), 14.0))
	return body.get_meta("card")
