class_name RotatingRays
extends Control
## Rayons de lumière qui tournent lentement derrière les étoiles (violet clair, opacité fixe : aucun fondu).


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 300.0)
	offset_transform_enabled = true
	offset_transform_visual_only = true
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)


func _ready() -> void:
	set_process(not Wg.reduce_motion)


func _process(delta: float) -> void:
	offset_transform_rotation = fposmod(offset_transform_rotation + delta * TAU / 36.0, TAU)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var rays := 12
	for i in range(rays):
		var a0 := (i * 360.0 / rays) * PI / 180.0
		var a1 := ((i + 0.5) * 360.0 / rays) * PI / 180.0
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]), Color(1, 1, 1, 0.13))
