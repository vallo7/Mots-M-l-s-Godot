class_name LevelPill
extends JuicyPressable
## Une pilule de niveau : pastille numérotée cerclée de blanc, titre « chapitre-niveau THÈME », étoiles, action à droite.
## Niveau terminé : étoiles + coche. Disponible : lecture. Verrouillé : cadenas. Le défi final est doré.

const HEIGHT := 70.0
const LIP := 5.0

var _level: MonumentLevel
var _locked: bool
var _face_color: Color
var _lip_color: Color
var _content := Control.new()


static func create(chapter: MonumentChapter, level: MonumentLevel, language: int) -> LevelPill:
	var pill := LevelPill.new()
	pill._level = level
	pill._locked = level.status == LevelStatus.LOCKED
	pill._build(chapter, language)
	return pill


func _build(chapter: MonumentChapter, language: int) -> void:
	var completed := _level.status == LevelStatus.COMPLETED
	var style := Wg.style_palette(_level.style)
	custom_minimum_size = Vector2(0.0, HEIGHT)
	squash = 0.5
	sound = Sound.WRONG if _locked else Sound.MENU_CHANGE
	haptic = HapticEffect.ERROR if _locked else HapticEffect.CONFIRM
	if _locked:
		_face_color = Wg.LOCKED
		_lip_color = Wg.LOCKED_DARK
	elif _level.is_final:
		_face_color = Wg.YELLOW
		_lip_color = Wg.YELLOW_DARK
	else:
		_face_color = Wg.PURPLE
		_lip_color = Wg.PURPLE_DARK
	var text_color: Color = Wg.LOCKED_INK if _locked else (Wg.INK_FIXED if _level.is_final else Wg.WHITE)
	var status_keys: Array[String] = ["monument_status_locked", "monument_status_available", "monument_status_completed"]
	var status_key: String = status_keys[_level.status]
	description = Strings.t("monument_level_a11y", [chapter.index, _level.number, Language.pick(_level.theme, language), Strings.t(status_key)])

	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(row)
	row.offset_left = 8.0
	row.offset_right = -10.0
	_content.add_child(row)
	row.add_child(_number_badge(style["accent"]))

	var text_block := VBoxContainer.new()
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.alignment = BoxContainer.ALIGNMENT_CENTER
	text_block.add_theme_constant_override("separation", 2)
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Wg.label(Strings.t("monument_level_title", [chapter.index, _level.number, Language.pick(_level.theme, language).to_upper()]), 15.0, Wg.Weight.EXTRABOLD, text_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 10.0
	text_block.add_child(title)
	if _locked:
		var grid := Wg.label(Strings.t("monument_grid_size", [_level.grid_size]), 13.0, Wg.Weight.EXTRABOLD, text_color)
		grid.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_block.add_child(grid)
	else:
		var stars := StarsRow.create(_level.stars, 20.0)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text_block.add_child(stars)
	margin.add_child(text_block)
	row.add_child(margin)

	var action: Control
	if completed:
		action = UiKit.icon("ic_check_green", 34.0)
	elif _locked:
		action = UiKit.icon("ic_lock", 26.0, text_color)
	else:
		action = _PlayDisc.new()
		(action as _PlayDisc).tint = text_color
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	resized.connect(_layout)


class _PlayDisc extends Control:
	var tint: Color = Wg.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(42.0, 42.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph := UiKit.icon("ic_play", 24.0, Wg.WHITE)
		add_child(UiKit.centered(glyph))

	func _draw() -> void:
		Wg.rrect(self, Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22), 21.0)


func _number_badge(accent: Color) -> Control:
	var badge := _Badge.new()
	badge.custom_minimum_size = Vector2(54.0, 54.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.inner = Wg.LOCKED_DARK if _locked else (Wg.PURPLE if _level.is_final else accent)
	var glyph: Control
	if _locked:
		glyph = UiKit.icon("ic_lock", 22.0, Wg.WHITE)
	elif _level.is_final:
		glyph = UiKit.icon("ic_crown", 28.0)
	else:
		var ink: Color = Wg.INK_FIXED if accent == Wg.YELLOW else Wg.WHITE
		glyph = Wg.label(str(_level.number), 18.0, Wg.Weight.EXTRABOLD, ink)
	badge.add_child(UiKit.centered(glyph))
	return badge


class _Badge extends Control:
	var inner: Color

	func _draw() -> void:
		Wg.rrect(self, Rect2(Vector2.ZERO, size), Wg.SURFACE, 27.0)
		Wg.rrect(self, Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)), inner, 23.0)


func _face_rect() -> Rect2:
	var shift := maxf(press(), 0.0) * LIP
	return Rect2(Vector2(0.0, shift), Vector2(size.x, size.y - LIP))


func _layout() -> void:
	var face := _face_rect()
	_content.position = face.position
	_content.size = face.size


func _on_press_changed() -> void:
	_layout()


func _draw() -> void:
	Wg.rrect(self, Rect2(0.0, LIP, size.x, size.y - LIP), _lip_color, Wg.R_PILL)
	Wg.rrect(self, _face_rect(), _face_color, Wg.R_PILL)
	_draw_focus_ring(Rect2(Vector2.ZERO, size), size.y * 0.5)
