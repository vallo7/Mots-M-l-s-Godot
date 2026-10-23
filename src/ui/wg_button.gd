class_name WgButton
extends BubbleButton
## Bouton large avec libellé (et icône optionnelle). 46 dp de face, zone tactile conservée.

enum Kind { PRIMARY, SECONDARY, DANGER, GHOST }

const MAX_NATURAL_WIDTH := 150.0
const MIN_FONT_SIZE := 11

var _kind: int = Kind.PRIMARY
var _row := HBoxContainer.new()
var _label: Label
var _icon: TextureRect


## `with_ring` : cerclé de blanc (boutons d'action posés sur une carte), comme les boutons ronds.
static func create(text: String, kind: int = Kind.PRIMARY, icon_name: String = "", with_ring: bool = false) -> WgButton:
	var button := WgButton.new()
	button.ringed = with_ring
	button._build(text, kind, icon_name)
	return button


func _ring_extra() -> float:
	return RING * 2.0 if ringed else 0.0


func _build(text: String, kind: int, icon_name: String) -> void:
	_kind = kind
	custom_minimum_size = Vector2(0.0, Wg.BUTTON + Wg.LIP + _ring_extra())
	sound = Sound.CLICK
	haptic = HapticEffect.CONFIRM
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_left = 20.0
	_row.offset_right = -20.0
	content().add_child(_row)
	if not icon_name.is_empty():
		_icon = UiKit.icon(icon_name, 20.0, Wg.WHITE)
		_row.add_child(_icon)
	_label = Wg.label(text, 16.0, Wg.Weight.EXTRABOLD, Wg.WHITE, Wg.PURPLE_DARK)
	_row.add_child(_label)
	content().resized.connect(func() -> void:
		_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_row.offset_left = 20.0
		_row.offset_right = -20.0
		_fit_label())
	_state_changed()


func set_text(text: String) -> void:
	_label.text = text
	update_minimum_size()
	_fit_label()


## Largeur du libellé à sa taille normale, icône comprise.
func _natural_row_width() -> float:
	var width := _label.get_theme_font("font").get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _base_font_size()).x
	if _icon != null:
		width += _icon.custom_minimum_size.x + 8.0
	return width


func _base_font_size() -> int:
	return int(round(16.0 * Wg.text_scale))


## Largeur minimale : plafonnée, pour qu'un libellé long ne force jamais son conteneur à déborder de l'écran ; le
## libellé rétrécit alors pour tenir (jamais d'ellipse sur un bouton).
func _get_minimum_size() -> Vector2:
	return Vector2(minf(_natural_row_width(), MAX_NATURAL_WIDTH) + 40.0 + _ring_extra(), Wg.BUTTON + Wg.LIP + _ring_extra())


func _fit_label() -> void:
	if _label == null or content().size.x <= 0.0:
		return
	var available := content().size.x - 40.0 - (_icon.custom_minimum_size.x + 8.0 if _icon != null else 0.0)
	var font := _label.get_theme_font("font")
	var chosen := _base_font_size()
	while chosen > MIN_FONT_SIZE and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > available:
		chosen -= 1
	_label.add_theme_font_size_override("font_size", chosen)


func _state_changed() -> void:
	if _label == null:
		return
	var face := Wg.LOCKED
	var dark := Wg.LOCKED_DARK
	var ink := Wg.LOCKED_INK
	if enabled:
		match _kind:
			Kind.PRIMARY:
				face = Wg.GREEN
				dark = Wg.GREEN_DARK
				ink = Wg.WHITE
			Kind.SECONDARY:
				face = Wg.PURPLE
				dark = Wg.PURPLE_DARK
				ink = Wg.WHITE
			Kind.DANGER:
				face = Wg.RED
				dark = Wg.RED_DARK
				ink = Wg.WHITE
			_:
				face = Wg.SURFACE
				dark = Wg.OUTLINE
				ink = Wg.INK
	face_color = face
	dark_color = dark
	_label.add_theme_color_override("font_color", ink)
	if enabled and _kind != Kind.GHOST:
		_label.add_theme_color_override("font_shadow_color", dark)
		_label.add_theme_constant_override("shadow_offset_y", 3)
	else:
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if _icon != null:
		_icon.self_modulate = ink
