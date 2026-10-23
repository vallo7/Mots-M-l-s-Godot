class_name WatermarkBackground
extends Control
## Fond blanc avec filigrane animé en boucle : une très grande grille de lettres presque invisible qui dérive
## lentement, et un tracé qui se dessine puis se retire. Dessiné une seule fois : seule la transformation
## (translation, rotation, échelle) est animée par le GPU. Statique si animations réduites.

## Dézoomé : beaucoup plus de lettres, plus petites (avant : une grille 5×5 de lettres de 150), pour un fond fin
## qui se lit comme une vraie grille de mots mêlés.
const ALPHABET := "EAIRSNTOLUDCMPVGBFHQJXYZKW"
const FONT_SIZE := 62
const GRID := 12
const LAYER_SIZE := 960.0

var _layer := _Letters.new()
var _sweep := _Sweep.new()
var _time := 0.0


class _Letters extends Control:
	func _draw() -> void:
		var letters := ALPHABET
		var font := Wg.font(Wg.Weight.BLACK)
		var color := Wg.WATERMARK
		var font_size := FONT_SIZE
		for r in range(GRID):
			for c in range(GRID):
				# Une lettre « hasardeuse » mais stable : le motif ne dépend que de la case.
				var ch := letters[(r * 7 + c * 3 + (r * c) % 5) % letters.length()]
				var width := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var cx := size.x * (c + 0.5) / GRID
				var cy := size.y * (r + 0.5) / GRID
				draw_string(font, Vector2(cx - width * 0.5, cy + font_size * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


class _Sweep extends Control:
	func _draw() -> void:
		Wg.rrect(self, Rect2(Vector2.ZERO, size), Color(Wg.WATERMARK, Wg.WATERMARK.a * 1.3), size.y * 0.5)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.custom_minimum_size = Vector2(LAYER_SIZE, LAYER_SIZE)
	_layer.size = Vector2(LAYER_SIZE, LAYER_SIZE)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.size = Vector2(LAYER_SIZE, LAYER_SIZE / GRID * 0.82)
	_sweep.position = Vector2(0.0, LAYER_SIZE / GRID * 5.5 - LAYER_SIZE / GRID * 0.41)
	_layer.add_child(_sweep)
	add_child(_layer)
	resized.connect(_place)


func _ready() -> void:
	_place()
	_apply(0.5, 1.0)
	set_process(not Wg.reduce_motion)


func _place() -> void:
	_layer.position = (size - _layer.size) * 0.5


func _process(delta: float) -> void:
	_time += delta
	# Dérive : va-et-vient sur 22 s ; tracé : 9 s (dessin, pause, retrait).
	var drift := fposmod(_time / 22.0, 2.0)
	drift = drift if drift <= 1.0 else 2.0 - drift
	var t := fposmod(_time, 9.0)
	var sweep := 0.0
	if t < 3.4:
		sweep = Motion.ease_in_out_cubic(t / 3.4)
	elif t < 6.8:
		sweep = 1.0
	else:
		sweep = 1.0 - Motion.ease_in_out_cubic((t - 6.8) / 2.2)
	_apply(drift, sweep)


func _apply(drift: float, sweep: float) -> void:
	_layer.offset_transform_enabled = true
	_layer.offset_transform_visual_only = true
	_layer.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_layer.offset_transform_position = Vector2((drift - 0.5) * 110.0, (0.5 - drift) * 80.0)
	_layer.offset_transform_rotation = deg_to_rad(-10.0)
	_sweep.offset_transform_enabled = true
	_sweep.offset_transform_visual_only = true
	_sweep.offset_transform_pivot_ratio = Vector2(0.0, 0.5)
	_sweep.offset_transform_scale = Vector2(maxf(sweep, 0.0001), 1.0)
