class_name Pill
extends PanelContainer
## Pastille arrondie (fond, contour optionnel, marges) contenant une rangée d'éléments.

var row := HBoxContainer.new()


static func create(
	background: Color, padding: Vector4 = Vector4(10, 3, 10, 3), border_color: Color = Color(0, 0, 0, 0),
	border_width: float = 0.0, spacing: float = 4.0
) -> Pill:
	var pill := Pill.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(999)
	box.corner_detail = 12
	box.anti_aliasing = true
	if border_width > 0.0:
		box.border_color = border_color
		box.set_border_width_all(int(border_width))
	box.content_margin_left = padding.x
	box.content_margin_top = padding.y
	box.content_margin_right = padding.z
	box.content_margin_bottom = padding.w
	pill.add_theme_stylebox_override("panel", box)
	pill.row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.row.add_theme_constant_override("separation", int(spacing))
	pill.row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(pill.row)
	return pill
