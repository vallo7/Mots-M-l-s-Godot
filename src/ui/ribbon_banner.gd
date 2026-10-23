class_name RibbonBanner
extends Control
## Ruban à deux queues fendues, plis et bande courbée ; le titre est posé sur la bande.

const COLORS := {
	"pink": [Color8(0xFF, 0x3D, 0x8B), Color8(0xD6, 0x2A, 0x73), Color8(0xA8, 0x1A, 0x57)],
	"blue": [Color8(0x2E, 0xB8, 0xFF), Color8(0x1F, 0x9A, 0xE0), Color8(0x15, 0x73, 0xB0)],
	"purple": [Color8(0x7B, 0x5C, 0xFF), Color8(0x63, 0x42, 0xE6), Color8(0x46, 0x30, 0xB5)],
	"yellow": [Color8(0xFF, 0xC8, 0x1E), Color8(0xF2, 0xA1, 0x00), Color8(0xC2, 0x7E, 0x00)],
	"green": [Color8(0x5C, 0xD6, 0x2F), Color8(0x3F, 0xB4, 0x1B), Color8(0x2A, 0x8A, 0x10)],
	"red": [Color8(0xFF, 0x4B, 0x55), Color8(0xDB, 0x2F, 0x3A), Color8(0xA8, 0x20, 0x2A)],
}

var _color: Color
var _dark: Color
var _deep: Color
var _label: Label


static func create(text: String, ribbon: String, height: float = 58.0, text_color: Color = Wg.WHITE) -> RibbonBanner:
	var banner := RibbonBanner.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette: Array = COLORS[ribbon]
	banner._color = palette[0]
	banner._dark = palette[1]
	banner._deep = palette[2]
	banner.custom_minimum_size = Vector2(0.0, height)
	var label := Wg.label(text, 22.0, Wg.Weight.BLACK, text_color)
	label.add_theme_color_override("font_shadow_color", banner._deep)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.clip_text = true
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = height * 0.66
	label.offset_right = -height * 0.66
	label.offset_top = 0.0
	label.offset_bottom = height * 0.74
	banner._label = label
	banner._base_size = int(round(22.0 * Wg.text_scale))
	banner.add_child(label)
	label.resized.connect(banner._fit_text)
	return banner


var _base_size := 22


## Réduit la taille du titre jusqu'à ce qu'il tienne sur la bande (jamais d'ellipse sur un titre).
func _fit_text() -> void:
	if _label == null or _label.size.x <= 0.0:
		return
	var font := _label.get_theme_font("font")
	var chosen := _base_size
	while chosen > 13 and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > _label.size.x:
		chosen -= 1
	_label.add_theme_font_size_override("font_size", chosen)


## Palette personnalisée (ruban verrouillé).
func set_palette(color: Color, dark: Color, deep: Color) -> void:
	_color = color
	_dark = dark
	_deep = deep
	if _label != null:
		_label.add_theme_color_override("font_shadow_color", deep)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var tail := h * 0.62
	var band_l := tail * 0.80
	var band_r := w - band_l
	var over := tail * 0.35
	var curve := h * 0.06
	var top := curve
	var band_h := h * 0.70
	var ty0 := h * 0.22
	var ty1 := h * 0.97
	var notch := tail * 0.38
	var mid_y := (ty0 + ty1) / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(band_l + over, ty0), Vector2(0, ty0), Vector2(notch, mid_y), Vector2(0, ty1), Vector2(band_l + over, ty1)]), _dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(band_r - over, ty0), Vector2(w, ty0), Vector2(w - notch, mid_y), Vector2(w, ty1), Vector2(band_r - over, ty1)]), _dark)
	draw_colored_polygon(PackedVector2Array([Vector2(band_l, top + band_h), Vector2(band_l + over, top + band_h), Vector2(band_l + over, ty1)]), _deep)
	draw_colored_polygon(PackedVector2Array([Vector2(band_r, top + band_h), Vector2(band_r - over, top + band_h), Vector2(band_r - over, ty1)]), _deep)
	draw_colored_polygon(_band(h * 0.05, band_l, band_r, top, curve, band_h), _deep)
	var face := _band(0.0, band_l, band_r, top, curve, band_h)
	draw_colored_polygon(face, _color)
	# Reflet : dégradé blanc -> transparent du haut de la bande jusqu'à 34 % de la hauteur, rogné à la bande.
	var steps := 24
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(steps + 1):
		var x := band_l + (band_r - band_l) * i / steps
		points.append(Vector2(x, top - curve * sin(PI * i / steps)))
		colors.append(Color(1, 1, 1, 0.34))
	for i in range(steps, -1, -1):
		var x := band_l + (band_r - band_l) * i / steps
		points.append(Vector2(x, h * 0.34))
		colors.append(Color(1, 1, 1, 0.0))
	draw_polygon(points, colors)


static func _band(dy: float, band_l: float, band_r: float, top: float, curve: float, band_h: float) -> PackedVector2Array:
	var steps := 24
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var x := band_l + (band_r - band_l) * i / steps
		points.append(Vector2(x, top - curve * sin(PI * i / steps) + dy))
	for i in range(steps, -1, -1):
		var x := band_l + (band_r - band_l) * i / steps
		points.append(Vector2(x, top + band_h - curve * 0.8 * sin(PI * i / steps) + dy))
	return points
