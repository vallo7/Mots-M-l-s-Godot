class_name MessageHost
extends Control
## Message bref en haut de l'écran : tombe en rebondissant puis remonte en glissant (jamais de fondu).

var _pill: PanelContainer
var _label: Label
var _tween: Tween
var _visible_message := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.PURPLE_DEEP
	box.set_corner_radius_all(999)
	box.corner_detail = 12
	box.anti_aliasing = true
	box.content_margin_left = Wg.SP_LG
	box.content_margin_right = Wg.SP_LG
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	_pill.add_theme_stylebox_override("panel", box)
	_label = Wg.label("", 16.0, Wg.Weight.BOLD, Wg.WHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 120.0
	_pill.add_child(_label)
	_pill.visible = false
	add_child(_pill)


func _ready() -> void:
	App.message_changed.connect(_on_message_changed)


func _on_message_changed() -> void:
	if App.message_text.is_empty():
		_hide()
	else:
		_show(App.message_text)


func _layout() -> void:
	var insets := App.safe_area_insets
	var max_width := size.x - 2.0 * Wg.SP_MD - insets.x - insets.z
	_label.custom_minimum_size.x = minf(max_width - 2.0 * Wg.SP_LG, 300.0)
	_pill.reset_size()
	_pill.position = Vector2((size.x - _pill.size.x) * 0.5, insets.y + Wg.SP_SM)


func _show(text: String) -> void:
	_label.text = text
	_pill.visible = true
	_layout()
	await get_tree().process_frame
	_layout()
	if _tween != null:
		_tween.kill()
	_visible_message = true
	var from_y := -_pill.size.y * 2.0 - _pill.position.y
	if Wg.reduce_motion:
		UiKit.jelly(_pill, 1.0, 1.0, 0.0)
		return
	var omega := sqrt(420.0)
	var duration := Motion.spring_settle_seconds(omega, 0.55, 0.003)
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		var p := Motion.spring(t, omega, 0.55)
		UiKit.jelly(_pill, 1.0, 1.0, from_y * (1.0 - p)), 0.0, duration, duration)


func _hide() -> void:
	if not _visible_message:
		return
	_visible_message = false
	if _tween != null:
		_tween.kill()
	var to_y := -_pill.size.y * 2.0 - _pill.position.y
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: UiKit.jelly(_pill, 1.0, 1.0, v), 0.0, to_y, Wg.QUICK)
	_tween.tween_callback(func() -> void: _pill.visible = false)
