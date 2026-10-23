class_name ChunkyProgressBar
extends Control
## Barre continue (pas de segments). Avec `animate_from`, la barre part de cette valeur et se remplit jusqu'à
## `fraction` avec une courbe d'accélération douce, puis « souffle » (petit rebond d'épaisseur) en arrivant.
## Un reflet diagonal balaie le remplissage en boucle (animations réduites : barre statique).

signal finished()

var fill_color: Color = Wg.GREEN
var dark_color: Color = Wg.GREEN_DARK
var bar_height := 22.0

var _progress := 0.0
var _squash := SpringValue.new(380.0, 0.3, 0.0)
var _sweep := 0.0
var _tween: Tween


static func create(fraction: float, color: Color = Wg.GREEN, dark: Color = Wg.GREEN_DARK, height: float = 22.0) -> ChunkyProgressBar:
	var bar := ChunkyProgressBar.new()
	bar.fill_color = color
	bar.dark_color = dark
	bar.bar_height = height
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar._progress = clampf(fraction, 0.0, 1.0)
	return bar


## Remplit la barre de `from` à `to` (0..1) après `start_delay` secondes.
func animate(from: float, to: float, duration: float = 1.2, start_delay: float = 0.0) -> void:
	var target := clampf(to, 0.0, 1.0)
	if Wg.reduce_motion:
		_progress = target
		queue_redraw()
		finished.emit()
		return
	_progress = clampf(from, 0.0, 1.0)
	queue_redraw()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(start_delay)
	if absf(_progress - target) > 0.0001:
		_tween.tween_method(func(v: float) -> void:
			_progress = v
			queue_redraw(), _progress, target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(func() -> void:
			_squash.value = 1.0
			_squash.target = 0.0)
	_tween.tween_callback(func() -> void: finished.emit())


func set_fraction(fraction: float) -> void:
	_progress = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not Wg.reduce_motion:
		_sweep += delta / 1.8
		if _sweep > 1.3:
			_sweep = -0.3
	_squash.step(delta)
	UiKit.jelly(self, 1.0, 1.0 + 0.22 * _squash.value)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var radius := h * 0.5
	Wg.rrect(self, Rect2(0.0, 0.0, w, h), Wg.TRACK, radius)
	if _progress <= 0.001:
		return
	var fill_w := maxf(w * _progress, h)
	Wg.rrect(self, Rect2(0.0, h * 0.08, fill_w, h * 0.92), dark_color, radius)
	Wg.rrect(self, Rect2(0.0, 0.0, fill_w, h * 0.92), fill_color, radius)
	Wg.rrect(self, Rect2(h * 0.35, h * 0.12, maxf(fill_w - h * 0.7, 0.0), h * 0.24), Color(1, 1, 1, 0.30), h * 0.12)
	if not Wg.reduce_motion:
		var cx := fill_w * _sweep
		var band := h * 1.1
		var stripe := PackedVector2Array([
			Vector2(cx - band, h * 0.92), Vector2(cx - band * 0.4, 0.0), Vector2(cx + band * 0.4, 0.0), Vector2(cx - band * 0.2, h * 0.92)
		])
		# Le reflet est rogné à l'intérieur du remplissage.
		var clipped := Geometry2D.intersect_polygons(stripe, PackedVector2Array([
			Vector2(h * 0.4, 0.0), Vector2(fill_w - h * 0.4, 0.0), Vector2(fill_w - h * 0.4, h * 0.92), Vector2(h * 0.4, h * 0.92)
		]))
		for poly in clipped:
			if poly.size() >= 3:
				draw_colored_polygon(poly, Color(1, 1, 1, 0.30))
	draw_circle(Vector2(fill_w - h * 0.4, h * 0.34), h * 0.12, Color(1, 1, 1, 0.55))
