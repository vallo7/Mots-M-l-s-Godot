class_name ResultScreen
extends Control
## Écran de victoire (maquette violette) : ruban « Victoire », rayons qui tournent derrière trois étoiles qui retombent
## en rebondissant avec une onde de choc, mot de félicitations qui saute (texte + voix), temps, puis barre de progression
## CONTINUE du chapitre qui se remplit en douceur jusqu'au trophée. Boutons ronds cerclés de blanc : accueil, niveaux,
## suivant. Sans effet de fondu ni particules. La séquence d'entrée (étoiles, mot, barre, boutons) ne démarre qu'une
## fois la page arrivée (`on_entered`, appelé par Main) : on n'anime pas des éléments pendant que la page glisse.

const STAR_FIRST_DELAY := 0.42
const STAR_STEP := 0.33
const PRAISE_KEYS := ["praise_nice", "praise_great", "praise_awesome", "praise_amazing", "praise_insane", "praise_unreal", "praise_divine", "praise_legendary"]

var result: VictoryResult

var _praise_label: Label
var _praise_t := -1.0
var _bar_delay := 0.0
var _stars_area: Control
var _card_wrap: Control
var _buttons: Control
var _stars: Array[VictoryStar] = []
var _bar: ChunkyProgressBar
var _pop_holders: Array = []  ## [conteneur, délai] des boutons qui entrent en « pop »
var _started := false


static func create(p_result: VictoryResult) -> ResultScreen:
	var screen := ResultScreen.new()
	screen.result = p_result
	return screen


class _Card extends MarginContainer:
	func _draw() -> void:
		var top := 30.0
		var rect := Rect2(0.0, top, size.x, size.y - top)
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Wg.PURPLE_DEEP
		shadow.set_corner_radius_all(32)
		shadow.shadow_color = Color(0.16, 0.15, 0.31, 0.25)
		shadow.shadow_size = 16
		shadow.shadow_offset = Vector2(0, 6)
		draw_style_box(shadow, rect)
		Wg.rrect(self, Rect2(rect.position, Vector2(rect.size.x, rect.size.y - 6.0)), Wg.PURPLE, 32.0)


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var catalog := App.catalog
	var language := App.language
	var level := catalog.level_by_id(result.level_id)
	var trophy_ready := not result.is_daily and ProgressRules.is_gift_claimable(catalog, App.progress, result.chapter_index)
	_bar_delay = STAR_FIRST_DELAY + 3 * STAR_STEP + 0.65

	var watermark := WatermarkBackground.new()
	UiKit.full_rect(watermark)
	add_child(watermark)

	var insets := App.safe_area_insets
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", int(insets.x + 22))
	margin.add_theme_constant_override("margin_top", int(insets.y))
	margin.add_theme_constant_override("margin_right", int(insets.z + 22))
	margin.add_theme_constant_override("margin_bottom", int(insets.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_expander())
	var card := _Card.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("margin_left", 18)
	card.add_theme_constant_override("margin_right", 18)
	card.add_theme_constant_override("margin_top", 30 + 52)
	card.add_theme_constant_override("margin_bottom", 18 + 6)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	var card_holder := _HolderMin.new()
	card_holder.target = card
	card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_holder.add_child(card)
	UiKit.full_rect(card)
	column.add_child(card_holder)

	if result.is_daily:
		var daily_subtitle := Wg.label(Strings.t("daily_result_subtitle", [DailyText.date_label(result.daily_day)]), 16.0, Wg.Weight.BOLD, Color(1, 1, 1, 0.85))
		daily_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(daily_subtitle)
	elif level != null:
		var subtitle := Wg.label(Strings.t("result_level_subtitle", [level.chapter_index, level.number, Language.pick(level.theme, language)]), 16.0, Wg.Weight.BOLD, Color(1, 1, 1, 0.85))
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(subtitle)
	body.add_child(_gap(10.0))

	# Étoiles sur des rayons qui tournent
	var stars_area := Control.new()
	stars_area.custom_minimum_size = Vector2(0.0, 180.0)
	_stars_area = stars_area
	stars_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_area.set("accessibility_name", Strings.n("stars_count", result.stars))
	var rays := RotatingRays.new()
	rays.set_anchors_preset(Control.PRESET_CENTER)
	rays.anchor_left = 0.5
	rays.anchor_right = 0.5
	rays.anchor_top = 0.5
	rays.anchor_bottom = 0.5
	rays.offset_left = -150.0
	rays.offset_right = 150.0
	rays.offset_top = -150.0
	rays.offset_bottom = 150.0
	rays.custom_minimum_size = Vector2.ZERO
	stars_area.add_child(rays)
	stars_area.resized.connect(func() -> void:
		var d := minf(300.0, stars_area.size.y + 40.0)
		rays.offset_left = -d * 0.5
		rays.offset_right = d * 0.5
		rays.offset_top = -d * 0.5
		rays.offset_bottom = d * 0.5)
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 6)
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(stars_row)
	for index in range(3):
		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_theme_constant_override("separation", 0)
		if index != 1:
			holder.add_child(_gap(14.0))
		var star := VictoryStar.create(index < result.stars, 96.0 if index == 1 else 76.0, STAR_FIRST_DELAY + index * STAR_STEP)
		_stars.append(star)
		holder.add_child(star)
		stars_row.add_child(holder)
	stars_area.add_child(stars_row)
	body.add_child(stars_area)
	body.add_child(_gap(6.0))

	_praise_label = Wg.label(Strings.t(PRAISE_KEYS[result.praise]), 46.0, Wg.Weight.BLACK, Wg.WHITE)
	UiKit.fit_label(_praise_label, int(round(46.0 * Wg.text_scale)), 22)
	_praise_label.custom_minimum_size.y = 46.0 * Wg.text_scale * 1.25
	_praise_label.add_theme_color_override("font_shadow_color", Wg.PURPLE_DEEP)
	_praise_label.add_theme_constant_override("shadow_offset_y", 8)
	_praise_label.offset_transform_enabled = true
	_praise_label.offset_transform_visual_only = true
	_praise_label.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	body.add_child(_praise_label)
	body.add_child(_gap(10.0))

	var time_holder := CenterContainer.new()
	time_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var time_pill := Pill.create(Wg.SURFACE, Vector4(8, 3, 18, 3), Color(0, 0, 0, 0), 0.0, 8.0)
	time_pill.row.add_child(UiKit.icon("ic_clock", 34.0))
	time_pill.row.add_child(Wg.label(TimeFormat.mmss(result.elapsed_millis), 30.0, Wg.Weight.BLACK, Wg.INK))
	time_holder.add_child(time_pill)
	body.add_child(time_holder)
	body.add_child(_gap(16.0))

	body.add_child(_build_daily_rewards() if result.is_daily else _build_chapter_progress(trophy_ready))
	if trophy_ready:
		body.add_child(_gap(14.0))
		var gift := WgButton.create(Strings.t("result_gift_open"), WgButton.Kind.PRIMARY, "", true)
		gift.sound = Sound.GIFT
		gift.haptic = HapticEffect.SUCCESS
		gift.activated.connect(func() -> void:
			var amount := App.claim_gift(result.chapter_index)
			if amount > 0 and App.double_reward_available() and is_instance_valid(gift):
				# Le cadeau est ouvert : le bouton laisse place à l'offre « doubler », au choix du joueur.
				var offer := _make_double_button(amount)
				gift.get_parent().add_child(offer)
				gift.get_parent().move_child(offer, gift.get_index() + 1)
				gift.visible = false)
		body.add_child(gift)

	# Ruban de titre à cheval sur le bord haut de la carte
	_card_wrap = card_holder
	var ribbon := BannerImage.create(Strings.t("result_title"), "red", 64.0)
	ribbon.anchor_left = 0.05
	ribbon.anchor_right = 0.95
	ribbon.offset_bottom = 64.0
	card_holder.add_child(ribbon)

	column.add_child(_expander())
	_buttons = _build_buttons()
	column.add_child(_buttons)
	column.add_child(_gap(18.0))
	resized.connect(_fit_stars)
	_fit_stars.call_deferred()
	if _animated():
		_apply_praise(0.0)
		# Filet de sécurité : si la page n'est jamais annoncée « en place », la séquence démarre quand même.
		get_tree().create_timer(2.0).timeout.connect(_begin)
	else:
		_begin()


## Pour la chorégraphie de transition : la carte de victoire, puis les boutons du bas.
func transition_groups() -> Array:
	return [[_card_wrap, "center"], [_buttons, "bottom"]]


func _animated() -> bool:
	return not (Wg.reduce_motion or Wg.suppress_intro)


## La page est arrivée en place : on lance la séquence d'entrée.
func on_entered() -> void:
	_begin()


func _begin() -> void:
	if _started or not is_inside_tree():
		return
	_started = true
	set_process(true)
	for star in _stars:
		star.play()
	if _animated():
		if _bar != null:
			_bar.animate(float(result.chapter_completed_before) / maxi(result.chapter_total, 1), float(result.chapter_completed_after) / maxi(result.chapter_total, 1), 1.3, _bar_delay)
		for entry in _pop_holders:
			UiFx.pop_in(entry[0], maxf(entry[1], 0.0))
	elif _bar != null:
		_bar.set_fraction(float(result.chapter_completed_after) / maxi(result.chapter_total, 1))
	if Wg.suppress_intro and not Wg.reduce_motion:
		# Reconstruction sur place (changement de langue…) : état final, sans rejouer sons ni animations.
		_praise_t = 99.0
		_apply_praise(1.0)
		set_process(false)
	else:
		_play_sequence()


class _HolderMin extends Control:
	var target: Control

	func _get_minimum_size() -> Vector2:
		return target.get_combined_minimum_size() if target != null else Vector2.ZERO


## La zone d'étoiles (rayons compris) prend la place disponible : 300 dp sur un grand écran, moins sur un petit.
func _fit_stars() -> void:
	if _stars_area == null or size.y <= 0.0:
		return
	_stars_area.custom_minimum_size.y = 0.0
	var insets := App.safe_area_insets
	var rest := _card_wrap.get_combined_minimum_size().y
	var buttons := _buttons.get_combined_minimum_size().y + 18.0
	var free := size.y - insets.y - insets.w - rest - buttons - 12.0
	_stars_area.custom_minimum_size.y = clampf(free, 170.0, 300.0)


func _expander() -> Control:
	var e := Control.new()
	e.size_flags_vertical = Control.SIZE_EXPAND_FILL
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _build_chapter_progress(trophy_ready: bool) -> Control:
	var total := maxi(result.chapter_total, 1)
	var before := float(result.chapter_completed_before) / total
	var after := float(result.chapter_completed_after) / total
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set("accessibility_name", Strings.t("home_gift_description", [result.chapter_completed_after, total]))
	column.add_child(Wg.label(Strings.t("result_chapter_progress", [result.chapter_index]), 15.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
	column.add_child(_gap(6.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ChunkyProgressBar.create(before, Wg.GREEN, Wg.GREEN_DARK, 24.0)
	_bar = bar
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(GiftBadge.create(trophy_ready, 52.0))
	column.add_child(row)
	column.add_child(_gap(4.0))
	var text := Strings.t("result_chapter_done") if result.chapter_completed else Strings.t("home_gift_progress", [result.chapter_completed_after, total])
	column.add_child(Wg.label(text, 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
	return column


## Défi du jour : indices gagnés (détail) et série de jours.
func _build_daily_rewards() -> Control:
	var completion := result.daily
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(Wg.label(Strings.t("daily_result_rewards"), 15.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
	column.add_child(_gap(2.0))
	if completion == null or completion.already_done:
		column.add_child(Wg.label(Strings.t("daily_result_already"), 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
	else:
		var total_row := HBoxContainer.new()
		total_row.alignment = BoxContainer.ALIGNMENT_CENTER
		total_row.add_theme_constant_override("separation", 8)
		total_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		total_row.add_child(UiKit.icon("ic_bulb", 34.0))
		total_row.add_child(Wg.label(Strings.n("daily_result_total", completion.total_hints()), 24.0, Wg.Weight.BLACK, Wg.WHITE))
		column.add_child(total_row)
		var lines: Array[String] = [Strings.t("daily_result_base") + "  +%d" % completion.base_hints]
		if completion.star_bonus_hints > 0:
			lines.append(Strings.t("daily_result_stars") + "  +%d" % completion.star_bonus_hints)
		if completion.milestone_hints > 0:
			lines.append(Strings.t("daily_result_milestone", [completion.milestone_days]) + "  +%d" % completion.milestone_hints)
		for line in lines:
			column.add_child(Wg.label(line, 14.0, Wg.Weight.BOLD, Color(1, 1, 1, 0.9)))
		if completion.total_hints() > 0 and App.double_reward_available():
			column.add_child(_gap(8.0))
			column.add_child(_make_double_button(completion.total_hints()))
	if completion != null and completion.streak > 0:
		column.add_child(_gap(4.0))
		var streak_row := HBoxContainer.new()
		streak_row.alignment = BoxContainer.ALIGNMENT_CENTER
		streak_row.add_theme_constant_override("separation", 6)
		streak_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak_row.add_child(UiKit.icon("ic_coin_crown", 28.0))
		var streak_text := Strings.n("daily_result_streak", completion.streak)
		if completion.new_best:
			streak_text += " · " + Strings.t("daily_result_new_best")
		streak_row.add_child(Wg.label(streak_text, 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE))
		column.add_child(streak_row)
	return column


## « Doubler » : une publicité récompensée (choisie par le joueur) donne `amount` indices de plus. Le bouton disparaît une fois la
## récompense reçue ; si la pub est fermée trop tôt, il reste pour un nouvel essai.
func _make_double_button(amount: int) -> WgButton:
	var button := WgButton.create(Strings.t("result_double", [amount]), WgButton.Kind.PRIMARY, "ic_play", true)
	button.activated.connect(func() -> void:
		var granted: bool = await App.double_reward(amount)
		if granted and is_instance_valid(button):
			button.queue_free())
	return button


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var home := RingButton.create("ic_home", Strings.t("result_home"), Wg.PURPLE, Wg.PURPLE_DARK, 60.0)
	home.sound = Sound.MENU_CHANGE
	home.activated.connect(App.go_home)
	row.add_child(_popped(home, _bar_delay - 0.2))
	var levels := RingButton.create("ic_calendar" if result.is_daily else "ic_levels", Strings.t("daily_result_back") if result.is_daily else Strings.t("cd_monument"), Wg.PURPLE, Wg.PURPLE_DARK, 60.0)
	levels.sound = Sound.MENU_CHANGE
	levels.activated.connect(App.go_daily if result.is_daily else App.open_monument)
	row.add_child(_popped(levels, _bar_delay - 0.12))
	if not result.next_level_id.is_empty():
		var next := RingButton.create("ic_play", Strings.t("result_next"), Wg.BLUE, Wg.BLUE_DARK, 76.0)
		next.activated.connect(func() -> void: App.play_next_after(result))
		row.add_child(_popped(next, _bar_delay - 0.04))
	return row


## Enveloppe un bouton pour lui donner une entrée « pop » sans toucher à sa pression « gelée ».
func _popped(button: Control, delay: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = button.custom_minimum_size
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.full_rect(button)
	holder.add_child(button)
	if _animated():
		UiKit.jelly(holder, 0.0, 0.0)
		_pop_holders.append([holder, delay])
	return holder


func _play_sequence() -> void:
	Feedback.play(Sound.VICTORY)
	Feedback.perform(HapticEffect.SUCCESS)
	if Wg.reduce_motion:
		_praise_t = 99.0
		Feedback.play_praise(result.praise, App.language)
		return
	await get_tree().create_timer(STAR_FIRST_DELAY).timeout
	for i in range(result.stars):
		if not is_inside_tree():
			return
		Feedback.play(Sound.SELECT_CELL)
		Feedback.perform(HapticEffect.SELECTION)
		await get_tree().create_timer(STAR_STEP).timeout
	if not is_inside_tree():
		return
	_praise_t = 0.0
	Feedback.play_praise(result.praise, App.language)
	if result.chapter_completed_after != result.chapter_completed_before:
		var wait := maxf(_bar_delay - STAR_FIRST_DELAY - result.stars * STAR_STEP, 0.0)
		await get_tree().create_timer(wait).timeout
		if is_inside_tree():
			Feedback.play(Sound.PROGRESS_UP)
			Feedback.perform(HapticEffect.CONFIRM)


func _process(delta: float) -> void:
	if _praise_t < 0.0:
		return
	_praise_t += delta
	var omega := sqrt(260.0)
	_apply_praise(Motion.spring(_praise_t, omega, 0.34))
	if _praise_t > Motion.spring_settle_seconds(omega, 0.34, 0.003):
		_apply_praise(1.0)
		set_process(false)


func _apply_praise(s: float) -> void:
	_praise_label.offset_transform_scale = Vector2(s, s)
	_praise_label.offset_transform_rotation = deg_to_rad((1.0 - s) * -14.0)
