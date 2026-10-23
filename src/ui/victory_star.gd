class_name VictoryStar
extends Control
## Étoile de victoire : tombe de haut en grossissant avec un fort rebond, onde de choc blanche à l'impact,
## visage souriant sur les étoiles gagnées.

var _earned: bool
var _size: float
var _delay: float
var _t := -1.0
var _ring := 0.0
var _pending := false
var _star: TextureRect
var _face := _Face.new()


class _Face extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var ink := Wg.INK_FIXED
		draw_circle(Vector2(s * 0.41, s * 0.54), s * 0.045, ink, true, -1.0, true)
		draw_circle(Vector2(s * 0.59, s * 0.54), s * 0.045, ink, true, -1.0, true)
		var points := PackedVector2Array()
		var a := Vector2(s * 0.44, s * 0.62)
		var c := Vector2(s * 0.5, s * 0.70)
		var b := Vector2(s * 0.56, s * 0.62)
		for i in range(13):
			var u := i / 12.0
			points.append(a * (1 - u) * (1 - u) + c * 2.0 * u * (1 - u) + b * u * u)
		var w := s * 0.032
		draw_polyline(points, ink, w, true)
		draw_circle(a, w * 0.5, ink, true, -1.0, true)
		draw_circle(b, w * 0.5, ink, true, -1.0, true)


static func create(earned: bool, p_size: float, delay: float) -> VictoryStar:
	var star := VictoryStar.new()
	star._earned = earned
	star._size = p_size
	star._delay = delay
	star.custom_minimum_size = Vector2(p_size, p_size)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star._star = UiKit.icon("ic_star" if earned else "ic_star_off", p_size)
	UiKit.full_rect(star._star)
	star.add_child(star._star)
	if earned:
		UiKit.full_rect(star._face)
		star._face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star._star.add_child(star._face)
	return star


func _ready() -> void:
	set_process(false)
	if not _earned or Wg.reduce_motion or Wg.suppress_intro:
		_t = 99.0
		_apply(1.0)
		return
	_apply(0.0)
	_pending = true


## Lance la chute (après le délai propre à cette étoile). Appelé par l'écran de victoire une fois la page en place.
func play() -> void:
	if not _pending:
		return
	_pending = false
	await get_tree().create_timer(_delay).timeout
	if not is_inside_tree():
		return
	_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var omega := sqrt(280.0)
	var s := Motion.spring(_t, omega, 0.3)
	_ring = clampf(_t / 0.56, 0.0, 1.0)
	_apply(s)
	queue_redraw()
	if _t > Motion.spring_settle_seconds(omega, 0.3, 0.003) and _ring >= 1.0:
		_apply(1.0)
		set_process(false)


func _apply(s: float) -> void:
	_star.offset_transform_enabled = true
	_star.offset_transform_visual_only = true
	_star.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_star.offset_transform_scale = Vector2(s, s)
	_star.offset_transform_rotation = deg_to_rad((1.0 - s) * -45.0)


func _draw() -> void:
	if _earned and _ring > 0.001 and _ring < 0.999:
		var p := Motion.ease_in_out_cubic(_ring)
		draw_arc(size * 0.5, minf(size.x, size.y) * (0.35 + 0.85 * p), 0.0, TAU, 48, Color.WHITE, 12.0 * (1.0 - p), true)
