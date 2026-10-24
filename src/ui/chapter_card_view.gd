class_name ChapterCardView
extends JuicyPressable
## Carte d'un chapitre du carrousel : lèvre 3D, bandeau illustré (parallaxe, sans bannière) et corps (thème, niveau en cours,
## étoiles, progression vers le trophée, action). La carte entière est le bouton : un seul geste, aucun faux bouton.

signal claim_pressed()

const FACE_RADIUS := 34.0
const LIP_DEPTH := 8.0

var _card: ChapterCard
var _language: int
var _locked := false
var _theme: Dictionary
var _face := Control.new()
var _illustration: TextureRect
var _gift: GiftBadge


static func create(card: ChapterCard, language: int) -> ChapterCardView:
	var view := ChapterCardView.new()
	view._card = card
	view._language = language
	view._build()
	return view


func _build() -> void:
	_locked = _card.status == ChapterStatus.LOCKED
	_theme = Wg.chapter_theme(_card.palette_key)
	squash = 0.35
	sound = Sound.WRONG if _locked else Sound.MENU_CHANGE
	haptic = HapticEffect.ERROR if _locked else HapticEffect.CONFIRM
	description = "%s, %s" % [Strings.t("home_chapter_title", [_card.index]), Language.pick(_card.theme, _language)]

	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	# Ombre portée (sous la face)
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_box := StyleBoxFlat.new()
	shadow_box.bg_color = Color(0, 0, 0, 0)
	shadow_box.set_corner_radius_all(int(FACE_RADIUS))
	shadow_box.shadow_color = Wg.SHADOW
	shadow_box.shadow_size = 10
	shadow_box.shadow_offset = Vector2(0, 4)
	shadow.add_theme_stylebox_override("panel", shadow_box)
	UiKit.full_rect(shadow)
	_face.add_child(shadow)
	# Face blanche : son masque arrondi rogne les enfants (illustration, bandeau)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.SURFACE
	box.set_corner_radius_all(int(FACE_RADIUS))
	box.corner_detail = 16
	box.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", box)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	UiKit.full_rect(panel)
	_face.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(column)
	panel.add_child(column)
	column.add_child(_build_band())
	column.add_child(_build_body())
	resized.connect(_layout_face)


func _layout_face() -> void:
	var shift := maxf(press(), 0.0) * LIP_DEPTH
	_face.position = Vector2(0.0, shift)
	_face.size = Vector2(size.x, size.y - LIP_DEPTH)


func _on_press_changed() -> void:
	_layout_face()


func _draw() -> void:
	var lip := Wg.LOCKED_DARK if _locked else (_theme["dark"] as Color)
	Wg.rrect(self, Rect2(0.0, LIP_DEPTH, size.x, size.y - LIP_DEPTH), lip, FACE_RADIUS)
	_draw_focus_ring(Rect2(Vector2.ZERO, size), FACE_RADIUS)


## Parallaxe : l'illustration glisse un peu plus vite que la carte (appelé par le carrousel).
func set_pager_offset(offset: float) -> void:
	if _illustration != null:
		_illustration.offset_transform_position = Vector2(offset * 70.0, 0.0)


func _build_band() -> Control:
	var band := Control.new()
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	band.size_flags_stretch_ratio = 0.34
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := ColorRect.new()
	sky.color = Wg.LOCKED if _locked else (_theme["sky"] as Color)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(sky)
	band.add_child(sky)
	_illustration = TextureRect.new()
	_illustration.texture = Icons.get_icon(_theme["illustration"])
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illustration.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_illustration)
	_illustration.modulate = Color(1, 1, 1, 0.35 if _locked else 1.0)
	_illustration.offset_transform_enabled = true
	_illustration.offset_transform_visual_only = true
	_illustration.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_illustration.offset_transform_scale = Vector2(1.25, 1.25)
	band.add_child(_illustration)

	# Plus de bannière sur l'illustration : « Chapitre N » est écrit en simple texte sur la bulle (voir _build_body).
	# Résolution du chapitre (étoiles gagnées / possibles), en haut à droite de l'illustration
	var badge := PercentBadge.create(_card.percent(), _theme["color"], _locked)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -PercentBadge.DIAMETER - 12.0
	badge.offset_right = -12.0
	badge.offset_top = 12.0
	badge.offset_bottom = 12.0 + PercentBadge.DIAMETER
	band.add_child(badge)
	if _locked:
		var lock := UiKit.icon("ic_lock", 54.0, Wg.WHITE)
		lock.set_anchors_preset(Control.PRESET_CENTER)
		lock.anchor_left = 0.5
		lock.anchor_right = 0.5
		lock.anchor_top = 0.5
		lock.anchor_bottom = 0.5
		lock.offset_left = -27.0
		lock.offset_right = 27.0
		lock.offset_top = -27.0 - 14.0
		lock.offset_bottom = 27.0 - 14.0
		band.add_child(lock)
	return band


func _build_body() -> Control:
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_stretch_ratio = 0.66
	body.add_theme_constant_override("margin_left", 18)
	body.add_theme_constant_override("margin_right", 18)
	body.add_theme_constant_override("margin_top", 12)
	body.add_theme_constant_override("margin_bottom", 12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(column)

	# Titre : thème du chapitre (+ niveau en cours)
	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 2)
	title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chapter_name := Wg.label(Strings.t("home_chapter_title", [_card.index]), 15.0, Wg.Weight.EXTRABOLD, Wg.LOCKED_INK if _locked else (_theme["dark"] as Color))
	title_block.add_child(chapter_name)
	var title := Wg.label(Language.pick(_card.theme, _language), 28.0, Wg.Weight.BLACK, Wg.LOCKED_INK if _locked else Wg.INK)
	title_block.add_child(title)
	var level := _card.current_level
	if level != null:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(Wg.label(Strings.t("home_level_n", [level.number]), 18.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED))
		line.add_child(DifficultyBadge.create_for(DifficultyBand.of(level.number)))
		title_block.add_child(line)
		title_block.add_child(Wg.label(Language.pick(level.theme, _language), 16.0, Wg.Weight.BOLD, Wg.INK_MUTED))
	elif _card.status == ChapterStatus.COMPLETED:
		var done := HBoxContainer.new()
		done.alignment = BoxContainer.ALIGNMENT_CENTER
		done.add_theme_constant_override("separation", 6)
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.add_child(UiKit.icon("ic_check_green", 24.0))
		done.add_child(Wg.label(Strings.t("home_chapter_done"), 18.0, Wg.Weight.EXTRABOLD, Wg.GREEN_DARK))
		title_block.add_child(done)
	else:
		var hint := Wg.label(Strings.t("home_chapter_locked_hint"), 16.0, Wg.Weight.BOLD, Wg.LOCKED_INK)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_block.add_child(hint)
	column.add_child(title_block)
	column.add_child(_spacer())

	# Étoiles du chapitre
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(UiKit.icon("ic_star_off" if _locked else "ic_star", 24.0))
	stars.add_child(Wg.label(Strings.t("home_chapter_stars", [_card.stars_earned, _card.stars_max]), 15.0, Wg.Weight.EXTRABOLD, Wg.LOCKED_INK if _locked else Wg.INK))
	column.add_child(stars)
	column.add_child(_spacer())

	# Progression continue vers le trophée
	var progress_block := VBoxContainer.new()
	progress_block.add_theme_constant_override("separation", 0)
	progress_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_block.set("accessibility_name", Strings.t("home_gift_description", [_card.completed_count, _card.total]))
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ChunkyProgressBar.create(
		_card.fraction(), Wg.LOCKED_INK if _locked else (_theme["color"] as Color),
		Wg.LOCKED_DARK if _locked else (_theme["dark"] as Color), 20.0
	)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	_gift = GiftBadge.create(_card.trophy_claimable, 46.0)
	bar_row.add_child(_gift)
	progress_block.add_child(bar_row)
	progress_block.add_child(Wg.label(Strings.t("home_gift_progress", [_card.completed_count, _card.total]), 13.0, Wg.Weight.EXTRABOLD, Wg.INK_MUTED))
	column.add_child(progress_block)
	column.add_child(_spacer())

	# Action
	if _card.trophy_claimable:
		var claim := WgButton.create(Strings.t("home_gift_claim"), WgButton.Kind.PRIMARY, "", true)
		claim.sound = Sound.GIFT
		claim.haptic = HapticEffect.SUCCESS
		claim.activated.connect(func() -> void: claim_pressed.emit())
		column.add_child(claim)
	elif _card.status == ChapterStatus.CURRENT:
		column.add_child(_play_pill(Strings.t("home_resume" if _card.has_snapshot else "home_play")))
	else:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0.0, Wg.BUTTON + Wg.LIP + BubbleButton.RING * 2.0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(gap)
	return body


## Pastille « Jouer » de la carte courante : cerclée de blanc comme les autres boutons d'action. Purement visuelle :
## la carte entière est le bouton.
func _play_pill(text: String) -> Control:
	var pill := BubbleButton.new()
	pill.ringed = true
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.focus_mode = Control.FOCUS_NONE
	pill.corner_radius = Wg.R_PILL
	pill.face_color = Wg.GREEN
	pill.dark_color = Wg.GREEN_DARK
	pill.custom_minimum_size = Vector2(0.0, Wg.BUTTON + Wg.LIP + BubbleButton.RING * 2.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(row)
	row.add_child(UiKit.icon("ic_play", 22.0, Wg.WHITE))
	row.add_child(Wg.label(text, 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE, Wg.GREEN_DARK))
	pill.content().add_child(row)
	return pill


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
