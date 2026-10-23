class_name TrophyToast
extends Control
## Bandeau « Trophée débloqué » : tombe en rebondissant sous le haut de l'écran, reste un instant puis remonte. Les
## déblocages sont mis en file : un seul bandeau à la fois, dans l'ordre.

const SHOW_SECONDS := 2.8
const START_DELAY := 0.9
const TOP_OFFSET := 64.0

var _queue: Array[String] = []
var _busy := false
var _pill: PanelContainer
var _icon: TextureRect
var _kicker: Label
var _name: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.visible = false
	add_child(_pill)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_pill.add_child(row)
	_icon = UiKit.icon("ic_trophy", 46.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_kicker = Wg.label("", 12.0, Wg.Weight.BLACK, Wg.INK_MUTED)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_kicker)
	_name = Wg.label("", 17.0, Wg.Weight.BLACK, Wg.INK)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.custom_minimum_size.x = 150.0
	texts.add_child(_name)
	row.add_child(texts)


func _ready() -> void:
	App.trophy_unlocked.connect(announce)


## Met un trophée dans la file d'annonce.
func announce(trophy_id: String) -> void:
	if TrophyCatalog.by_id(trophy_id) == null:
		return
	_queue.append(trophy_id)
	if not _busy:
		_run()


func _run() -> void:
	_busy = true
	await get_tree().create_timer(START_DELAY).timeout
	while not _queue.is_empty():
		var trophy := TrophyCatalog.by_id(_queue.pop_front())
		if trophy != null:
			await _present(trophy)
	_busy = false


func _present(trophy: Trophy) -> void:
	var tier_color := TrophyStyle.tier_color(trophy.tier)
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.SURFACE
	box.set_corner_radius_all(26)
	box.corner_detail = 12
	box.anti_aliasing = true
	box.border_color = tier_color
	box.set_border_width_all(3)
	box.shadow_color = Wg.SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0.0, 4.0)
	box.content_margin_left = 12.0
	box.content_margin_right = 20.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	_pill.add_theme_stylebox_override("panel", box)
	_icon.texture = Icons.get_icon(trophy.icon_name())
	_kicker.text = Strings.t("trophy_unlocked_toast").to_upper()
	_kicker.add_theme_color_override("font_color", Color(tier_color.r * 0.85, tier_color.g * 0.85, tier_color.b * 0.85))
	_name.text = TrophyStyle.title(trophy)
	_pill.visible = true
	_layout()
	await get_tree().process_frame
	_layout()
	Feedback.play(Sound.GIFT)
	Feedback.perform(HapticEffect.SUCCESS)
	var insets := App.safe_area_insets
	var rest_y := insets.y + TOP_OFFSET
	var from_y := -_pill.size.y * 2.0 - rest_y
	if _tween != null:
		_tween.kill()
	if Wg.reduce_motion:
		UiKit.jelly(_pill, 1.0, 1.0, 0.0)
	else:
		var omega := sqrt(420.0)
		var duration := Motion.spring_settle_seconds(omega, 0.55, 0.003)
		_tween = create_tween()
		_tween.tween_method(func(t: float) -> void:
			var p := Motion.spring(t, omega, 0.55)
			UiKit.jelly(_pill, 1.0, 1.0, from_y * (1.0 - p)), 0.0, duration, duration)
	await get_tree().create_timer(SHOW_SECONDS).timeout
	if _tween != null:
		_tween.kill()
	if not Wg.reduce_motion:
		_tween = create_tween()
		_tween.tween_method(func(v: float) -> void: UiKit.jelly(_pill, 1.0, 1.0, v), 0.0, from_y, Wg.QUICK)
		await _tween.finished
	_pill.visible = false
	await get_tree().create_timer(0.25).timeout


func _layout() -> void:
	var insets := App.safe_area_insets
	_pill.reset_size()
	_pill.position = Vector2((size.x - _pill.size.x) * 0.5, insets.y + TOP_OFFSET)
