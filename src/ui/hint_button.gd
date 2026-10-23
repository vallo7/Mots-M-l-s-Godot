class_name HintButton
extends BubbleButton
## Bouton Indice sous la grille, à droite (pastille cerclée de blanc). Le solde est toujours visible ; à zéro, la
## pastille de nombre laisse place à un badge « pub » (triangle de lecture vert) sur l'ampoule, qui se balance
## régulièrement : un appui lance directement une publicité récompensée (aucune fenêtre de confirmation).

var _row := HBoxContainer.new()
var _bulb_box := Control.new()
var _ad_badge: TextureRect
var _label: Label
var _count_circle: Control
var _count_label: Label
var _balance := -1
var _wobble: Tween


static func create() -> HintButton:
	var b := HintButton.new()
	b.ringed = true
	b.custom_minimum_size = Vector2(0.0, Wg.BUTTON + Wg.LIP + RING * 2.0)
	b.corner_radius = Wg.R_PILL
	b.haptic = HapticEffect.SELECTION
	b._row.alignment = BoxContainer.ALIGNMENT_CENTER
	b._row.add_theme_constant_override("separation", 6)
	b._row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b._row.offset_left = 10.0
	b._row.offset_right = -14.0
	b.content().add_child(b._row)
	b.content().resized.connect(func() -> void:
		b._row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b._row.offset_left = 10.0
		b._row.offset_right = -14.0)

	b._bulb_box.custom_minimum_size = Vector2(38.0, 38.0)
	b._bulb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._bulb_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bulb := UiKit.icon("ic_bulb", 34.0)
	bulb.position = Vector2(2.0, 2.0)
	b._bulb_box.add_child(bulb)
	b._ad_badge = UiKit.icon("ic_ad_badge", 20.0)
	b._ad_badge.position = Vector2(38.0 - 20.0 + 4.0, -2.0)
	b._bulb_box.add_child(b._ad_badge)
	b._row.add_child(b._bulb_box)

	b._label = Wg.label("", 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE)
	b._row.add_child(b._label)

	b._count_circle = Control.new()
	b._count_circle.custom_minimum_size = Vector2(28.0, 28.0)
	b._count_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._count_circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b._count_circle.pivot_offset = Vector2(14.0, 14.0)
	b._count_circle.draw.connect(func() -> void: Wg.rrect(b._count_circle, Rect2(Vector2.ZERO, Vector2(28.0, 28.0)), Wg.WHITE, 14.0))
	b._count_label = Wg.label("0", 16.0, Wg.Weight.EXTRABOLD, Wg.PURPLE_DARK)
	b._count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b._count_circle.add_child(b._count_label)
	b._row.add_child(b._count_circle)
	b.set_balance(0, true, false)
	return b


func _get_minimum_size() -> Vector2:
	return Vector2(_row.get_combined_minimum_size().x + 24.0 + RING * 2.0, Wg.BUTTON + Wg.LIP + RING * 2.0)


## Animation de lancement de la publicité : l'ampoule et son badge rebondissent pendant le micro-délai qui précède
## l'annonce (le bouton lui-même s'écrase déjà sous le doigt).
func play_ad_launch() -> void:
	UiFx.bounce(_bulb_box, 1.35, 0.4, 420.0)
	UiFx.bounce(_ad_badge, 1.6, 0.4, 420.0)


func set_balance(balance: int, is_enabled: bool, animate: bool = true) -> void:
	var no_hints := balance <= 0
	var changed := balance != _balance
	_balance = balance
	enabled = is_enabled
	face_color = Wg.GREEN if no_hints else Wg.PURPLE
	dark_color = Wg.GREEN_DARK if no_hints else Wg.PURPLE_DARK
	_label.text = Strings.t("game_hint_more" if no_hints else "game_hint")
	_ad_badge.visible = no_hints
	_count_circle.visible = not no_hints
	_count_label.text = str(balance)
	description = Strings.t("game_hint_description", [_label.text, Strings.n("hints_count", balance)])
	update_minimum_size()
	if _wobble != null:
		_wobble.kill()
		_wobble = null
		UiKit.jelly(_bulb_box, 1.0, 1.0)
	if no_hints and is_enabled:
		_wobble = UiFx.wobble(_bulb_box)
	if changed and animate and not no_hints:
		UiFx.bounce(_count_circle)
