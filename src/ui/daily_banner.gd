class_name DailyBanner
extends JuicyPressable
## Bannière « Défi du jour » en bas de l'accueil : flamme de la série, état du défi (nouvelle grille, en cours, terminé
## + compte à rebours) et pastille d'action. Un appui ouvre la page du défi.

const HEIGHT := 78.0

var _model: DailyModel
var _title: Label
var _subtitle: Label
var _icon: TextureRect
var _streak_label: Label
var _action: Label
var _tick := 0.0


static func create(model: DailyModel) -> DailyBanner:
	var banner := DailyBanner.new()
	banner._model = model
	banner._build()
	return banner


func _build() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	squash = 0.35
	sound = Sound.MENU_CHANGE
	haptic = HapticEffect.SELECTION
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	UiKit.full_rect(row)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.offset_top = 4.0
	row.offset_bottom = -6.0
	add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(52.0, 52.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UiKit.icon("ic_coin_crown", 38.0)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_icon.offset_left = -19.0
	_icon.offset_right = 19.0
	_icon.offset_top = -22.0
	_icon.offset_bottom = 16.0
	badge.add_child(_icon)
	_streak_label = Wg.label("", 14.0, Wg.Weight.BLACK, Wg.INK_FIXED)
	_streak_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_streak_label.offset_left = -24.0
	_streak_label.offset_right = 24.0
	_streak_label.offset_top = -15.0
	_streak_label.offset_bottom = 3.0
	badge.add_child(_streak_label)
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Wg.label(Strings.t("daily_title"), 19.0, Wg.Weight.BLACK, Wg.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_title)
	_subtitle = Wg.label("", 13.0, Wg.Weight.BOLD, Wg.INK_MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_subtitle)
	row.add_child(texts)
	_action = Wg.label("", 15.0, Wg.Weight.BLACK, Wg.WHITE)
	_action.custom_minimum_size = Vector2(90.0, 40.0)
	_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_action)
	apply(_model)
	set_process(true)


## Met la bannière à jour sans la reconstruire.
func apply(model: DailyModel) -> void:
	_model = model
	var streak := model.streak
	_icon.texture = Icons.get_icon("ic_coin_crown" if streak > 0 else "ic_calendar_color")
	_streak_label.text = str(streak) if streak > 0 else ""
	match model.status:
		DailyModel.Status.DONE:
			_subtitle.text = Strings.t("daily_banner_done", [DailyText.countdown(model.seconds_left)])
			_action.text = Strings.t("daily_done")
		DailyModel.Status.IN_PROGRESS:
			_subtitle.text = Strings.t("daily_banner_resume", [model.grid_size])
			_action.text = Strings.t("daily_resume")
		DailyModel.Status.AVAILABLE:
			_subtitle.text = Strings.t("daily_banner_new", [model.grid_size, DailyText.band_name(model.band)])
			_action.text = Strings.t("daily_play")
		_:
			_subtitle.text = Strings.t("daily_banner_loading")
			_action.text = ""
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description = "%s. %s" % [Strings.t("daily_title"), _subtitle.text]
	queue_redraw()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		App.check_day_rollover()
		if _model != null and _model.status == DailyModel.Status.DONE:
			apply(App.daily_model())


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size - Vector2(0.0, 4.0))
	var ready := _model != null and (_model.status == DailyModel.Status.AVAILABLE or _model.status == DailyModel.Status.IN_PROGRESS)
	var accent := Wg.GREEN if ready else Wg.TRACK
	var accent_dark := Wg.GREEN_DARK if ready else Wg.LOCKED
	Wg.rrect(self, Rect2(r.position + Vector2(0.0, 4.0), r.size), Color(Wg.SHADOW, Wg.SHADOW.a * 0.8), 26.0)
	Wg.rrect(self, r, Wg.SURFACE, 26.0)
	Wg.outline(self, r, Wg.OUTLINE, 26.0, 2.0)
	# Pastille d'action à droite
	var pill := Rect2(size.x - 14.0 - 90.0, (size.y - 4.0 - 40.0) * 0.5 + 2.0, 90.0, 38.0)
	if _model != null and _model.status != DailyModel.Status.LOADING:
		var done := _model.status == DailyModel.Status.DONE
		Wg.rrect(self, Rect2(pill.position + Vector2(0.0, 3.0), pill.size), Wg.YELLOW_DARK if done else accent_dark, 19.0)
		Wg.rrect(self, pill, Wg.YELLOW if done else accent, 19.0)
	# Pastille de la flamme
	var circle := Vector2(14.0 + 26.0, (size.y - 4.0) * 0.5)
	draw_circle(circle, 27.0, Wg.TRACK, true, -1.0, true)
	if _model != null and _model.streak > 0:
		draw_circle(circle, 27.0, Color(Wg.ORANGE, 0.22), true, -1.0, true)
	_draw_focus_ring(r, 26.0)
