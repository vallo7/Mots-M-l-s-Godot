class_name PercentBadge
extends Control
## Pastille ronde de résolution d'un chapitre : un anneau qui se remplit (étoiles gagnées / étoiles possibles) et le
## pourcentage au centre. Grisée si le chapitre est verrouillé. L'anneau se remplit à l'arrivée (rebond léger).

const DIAMETER := 60.0
const FILL_SECONDS := 0.9

var percent := 0
var color := Wg.GREEN
var locked := false

var _shown := 0.0
var _age := 0.0
var _instant := false


static func create(p_percent: int, p_color: Color, p_locked: bool) -> PercentBadge:
	var badge := PercentBadge.new()
	badge.percent = clampi(p_percent, 0, 100)
	badge.color = p_color
	badge.locked = p_locked
	return badge


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set("accessibility_name", Strings.t("home_chapter_percent_description", [percent]))
	_instant = Wg.reduce_motion or Wg.suppress_intro or percent == 0
	if _instant:
		_shown = percent / 100.0
	else:
		set_process(true)


func _process(delta: float) -> void:
	_age += delta
	var u := clampf((_age - 0.35) / FILL_SECONDS, 0.0, 1.0)
	_shown = percent / 100.0 * Motion.ease_out_back(u, 1.0) if u > 0.0 else 0.0
	queue_redraw()
	if u >= 1.0:
		_shown = percent / 100.0
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0.0, 3.0), r - 1.0, Color(Wg.SHADOW, Wg.SHADOW.a * 1.4), true, -1.0, true)
	draw_circle(c, r - 1.0, Wg.SURFACE, true, -1.0, true)
	var ring := 6.0
	var radius := r - 1.0 - ring * 0.5 - 3.0
	var track := Wg.LOCKED if locked else Wg.TRACK
	draw_arc(c, radius, 0.0, TAU, 48, track, ring, true)
	var fraction := clampf(_shown, 0.0, 1.0)
	if fraction > 0.004 and not locked:
		draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, maxi(int(48.0 * fraction), 3), color, ring, true)
		# Bouts arrondis
		var end_angle := -PI * 0.5 + TAU * fraction
		draw_circle(c + Vector2(cos(-PI * 0.5), sin(-PI * 0.5)) * radius, ring * 0.5, color, true, -1.0, true)
		draw_circle(c + Vector2(cos(end_angle), sin(end_angle)) * radius, ring * 0.5, color, true, -1.0, true)
	var font := Wg.font(Wg.Weight.BLACK)
	var text := Strings.t("home_chapter_percent", [percent])
	var font_size := 17 if text.length() <= 4 else 15
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(c.x - width * 0.5, c.y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Wg.LOCKED_INK if locked else Wg.INK)
