class_name LoadingDemo
extends Control
## Démonstration en boucle du gant sur une mini-grille 5×5, pour l'écran de chargement. Trois scénarios (un tiré au
## hasard à chaque ouverture) montrent les mécaniques : 0 = glisser le doigt sur les lettres d'un mot, 1 = les mots se
## lisent dans tous les sens (diagonale, à l'envers), 2 = un indice (l'ampoule) puis les étoiles gagnées au temps.
## Tout est dessiné par `_draw` à partir d'un temps bouclé : aucune ressource, aucun nœud par lettre. Aucun fondu.

const SCENARIO_COUNT := 3
const GRID_N := 5
const CELL := 44.0
const PAD := 12.0
const HEADER_H := 40.0
const FOOTER_H := 56.0
const GAP := 8.0
const HAND_W := 96.0
## Point de contact du doigt dans l'image du gant (pixels de l'image de 512 de large).
const TIP := Vector2(66.0, 30.0)
const TEX_W := 512.0
const HAND_TEXTURE := "res://assets/ui/tutorial-hand.png"

const GRIDS := {
	"fr": [
		["PLUME", "MOTSA", "RIDEN", "VALOR", "CHATS"],
		["LASOT", "PUCIB", "ORNAD", "KTVEY", "REMSZ"],
		["MARID", "SOVEL", "BUETS", "KANYR", "HITAC"],
	],
	"en": [
		["BLAKE", "WORDS", "TIMER", "HAPPY", "CLUES"],
		["MASKT", "POCIB", "OROAD", "KTVNY", "AESLZ"],
		["MARID", "FOBSE", "BUETS", "KANAY", "HITRC"],
	],
}
const WORDS := {
	"fr": [["MOTS"], ["LUNE", "MER"], ["VENT"]],
	"en": [["WORD"], ["MOON", "SEA"], ["STAR"]],
}
## Étapes : [type, colonne départ, ligne départ, colonne fin, ligne fin, couleur]. « hint » : appui sur l'ampoule
## (colonne / ligne = case révélée).
const STEPS := [
	[["swipe", 0, 1, 3, 1, 0]],
	[["swipe", 0, 0, 3, 3, 0], ["swipe", 2, 4, 0, 4, 1]],
	[["hint", 2, 1, 2, 1, 0], ["swipe", 2, 1, 2, 4, 0]],
]
const EN_STEPS_OVERRIDE := {2: [["hint", 3, 1, 3, 1, 0], ["swipe", 3, 1, 3, 4, 0]]}
const WORD_COLORS: Array[Color] = [Wg.PINK, Wg.BLUE, Wg.GREEN]

var scenario := 0
var language := Language.EN
## Enchaîne les trois scénarios l'un après l'autre (page d'aide) au lieu de répéter toujours le même.
var cycle_scenarios := false

var _time := 0.0
var _period := 4.0
var _steps: Array[Dictionary] = []
var _grid: Array = []
var _words: Array = []
var _hand: TextureRect
var _hand_scale := 1.0
var _hand_pos := Vector2.ZERO
var _hand_visible := true
var _exit_start := 0.0
var _enter_pos := Vector2.ZERO
var _exit_pos := Vector2.ZERO
var _texture: Texture2D


static func create(p_scenario: int, p_language: int) -> LoadingDemo:
	var demo := LoadingDemo.new()
	demo.scenario = clampi(p_scenario, 0, SCENARIO_COUNT - 1)
	demo.language = p_language
	return demo


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PAD * 2.0 + CELL * GRID_N, HEADER_H + GAP + PAD * 2.0 + CELL * GRID_N + GAP + FOOTER_H)


func _ready() -> void:
	_texture = load(HAND_TEXTURE)
	_hand = TextureRect.new()
	_hand.texture = _texture
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var k := HAND_W / TEX_W
	_hand.size = Vector2(HAND_W, HAND_W * 409.0 / 512.0)
	_hand.pivot_offset = TIP * k
	add_child(_hand)
	_load_scenario()
	# Animations réduites : image fixe, mots trouvés, gant au repos.
	if Wg.reduce_motion:
		_time = _exit_start - 0.2
		_apply_hand()
		queue_redraw()
	else:
		set_process(true)


func _load_scenario() -> void:
	var code := Language.code(language)
	_grid = GRIDS[code][scenario]
	_words = WORDS[code][scenario]
	_compile()


func _grid_origin() -> Vector2:
	return Vector2(PAD, HEADER_H + GAP + PAD)


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_origin() + Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func _hint_button_rect() -> Rect2:
	var y := HEADER_H + GAP + PAD * 2.0 + CELL * GRID_N + GAP
	return Rect2(size_for_layout().x - 132.0, y, 132.0, 44.0)


func size_for_layout() -> Vector2:
	return custom_minimum_size


## Construit la ligne de temps : approche, appui, glissé, relâchement pour chaque étape, puis sortie du gant.
func _compile() -> void:
	_steps.clear()
	var raw: Array = STEPS[scenario]
	if language == Language.EN and EN_STEPS_OVERRIDE.has(scenario):
		raw = EN_STEPS_OVERRIDE[scenario]
	_enter_pos = Vector2(custom_minimum_size.x + 40.0, custom_minimum_size.y + 30.0)
	_exit_pos = _enter_pos
	var pos := _enter_pos
	var t := 0.3
	var word_index := 0
	for r in raw:
		var step := {"type": r[0], "t_approach": t, "from": pos, "word": -1}
		var is_hint: bool = r[0] == "hint"
		var start := Vector2i(r[1], r[2])
		var finish := Vector2i(r[3], r[4])
		var target := _hint_button_rect().get_center() + Vector2(2.0, 6.0) if is_hint else _cell_center(start)
		step["to"] = target
		step["start_cell"] = start
		step["end_cell"] = finish
		t += 0.5
		step["t_press"] = t
		t += 0.14
		if is_hint:
			step["t_pulse"] = t
			t += 1.0
			step["end_pos"] = target
		else:
			step["t_drag"] = t
			var cells := maxi(absi(finish.x - start.x), absi(finish.y - start.y))
			t += maxf(0.55, cells * 0.2)
			step["t_release"] = t
			step["end_pos"] = _cell_center(finish)
			step["word"] = word_index
			step["color"] = WORD_COLORS[word_index % WORD_COLORS.size()]
			word_index += 1
			t += 0.36
		t += 0.1
		step["t_end"] = t
		pos = step["end_pos"]
		_steps.append(step)
	_exit_start = t + 0.35
	_period = _exit_start + 0.5 + 0.55
	_exit_pos = Vector2(custom_minimum_size.x + 50.0, custom_minimum_size.y + 40.0)


func _process(delta: float) -> void:
	_time += delta
	if cycle_scenarios and _time >= _period:
		_time = 0.0
		scenario = (scenario + 1) % SCENARIO_COUNT
		_load_scenario()
	_apply_hand()
	queue_redraw()


func _loop_time() -> float:
	return fposmod(_time, _period)


## Position et échelle du gant à l'instant courant.
func _apply_hand() -> void:
	var tt := _loop_time()
	var pos := _enter_pos
	var press := 0.0
	var shown := false
	for step in _steps:
		if tt < step["t_approach"]:
			break
		shown = true
		var from: Vector2 = step["from"]
		if tt < step["t_press"]:
			var u := Motion.ease_out_cubic((tt - step["t_approach"]) / (step["t_press"] - step["t_approach"]))
			pos = from.lerp(step["to"], u) + Vector2(0.0, -14.0 * Motion.bump(u))  # petit arc
		elif step["type"] == "hint":
			pos = step["to"]
			var u := clampf((tt - step["t_press"]) / 0.3, 0.0, 1.0)
			press = Motion.bump(u)
		else:
			var start_pos: Vector2 = step["to"]
			if tt < step["t_drag"]:
				pos = start_pos
				press = Motion.ease_out_cubic((tt - step["t_press"]) / (step["t_drag"] - step["t_press"]))
			elif tt < step["t_release"]:
				var u := Motion.ease_in_out_cubic((tt - step["t_drag"]) / (step["t_release"] - step["t_drag"]))
				pos = start_pos.lerp(step["end_pos"], u)
				press = 1.0
			else:
				pos = step["end_pos"]
				press = 1.0 - Motion.ease_out_cubic(clampf((tt - step["t_release"]) / 0.22, 0.0, 1.0))
		if tt >= step["t_end"] and step == _steps[_steps.size() - 1]:
			pos = step["end_pos"]
	if tt >= _exit_start and not _steps.is_empty():
		var last: Dictionary = _steps[_steps.size() - 1]
		var u := Motion.ease_in_out_cubic(clampf((tt - _exit_start) / 0.5, 0.0, 1.0))
		pos = (last["end_pos"] as Vector2).lerp(_exit_pos, u)
		press = 0.0
		shown = tt < _exit_start + 0.55
	_hand_pos = pos
	_hand_scale = 1.0 - 0.14 * press
	_hand_visible = shown
	_hand.visible = shown
	var k := HAND_W / TEX_W
	_hand.position = pos - TIP * k
	_hand.scale = Vector2(_hand_scale, _hand_scale)


func _draw() -> void:
	var tt := _loop_time()
	var shrink := 1.0 - Motion.ease_in_out_cubic(clampf((tt - (_period - 0.45)) / 0.4, 0.0, 1.0))
	var found_words := {}
	var found_times := {}
	for step in _steps:
		if step["type"] == "swipe" and tt >= step["t_release"] and shrink > 0.5:
			found_words[step["word"]] = step
			found_times[step["word"]] = tt - step["t_release"]
	_draw_header(found_words, found_times, tt, shrink)
	_draw_board(tt, shrink, found_times)
	_draw_footer(tt)
	_draw_hand_shadow()


func _draw_header(found_words: Dictionary, found_times: Dictionary, tt: float, shrink: float) -> void:
	var font := Wg.font(Wg.Weight.EXTRABOLD)
	var x := 2.0
	for i in _words.size():
		var text: String = _words[i]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30.0
		var found := found_words.has(i)
		var pop := 1.0
		if found:
			pop = 1.0 + 0.16 * Motion.bump(clampf(found_times[i] / 0.35, 0.0, 1.0))
		var rect := Rect2(Vector2(x, 4.0), Vector2(w, 32.0))
		var c := rect.get_center()
		draw_set_transform(c, 0.0, Vector2(pop, pop))
		var local := Rect2(-rect.size * 0.5, rect.size)
		Wg.rrect(self, local, WORD_COLORS[i % WORD_COLORS.size()] if found else Wg.TRACK, 16.0)
		draw_string(font, Vector2(local.position.x + (w - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) * 0.5 + (6.0 if found else 0.0), 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Wg.WHITE if found else Wg.INK)
		if found:
			draw_texture_rect(Icons.get_icon("ic_check"), Rect2(local.position + Vector2(7.0, 9.0), Vector2(14.0, 14.0)), false, Wg.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w + 8.0
	# Étoiles gagnées (dernier scénario) : retombent une à une après le dernier mot.
	if scenario == 2 and not _steps.is_empty():
		var last: Dictionary = _steps[_steps.size() - 1]
		if tt >= last["t_release"] + 0.25 and shrink > 0.5:
			var star_tex := Icons.get_icon("ic_star")
			for k in range(3):
				var u := clampf((tt - last["t_release"] - 0.25 - k * 0.16) / 0.45, 0.0, 1.0)
				var s := Motion.spring(u * 0.45, 16.0, 0.42)
				var center := Vector2(custom_minimum_size.x - 22.0 - (2 - k) * 34.0, 20.0)
				draw_set_transform(center, 0.0, Vector2(s, s))
				draw_texture_rect(star_tex, Rect2(Vector2(-15.0, -15.0), Vector2(30.0, 30.0)), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_board(tt: float, shrink: float, found_times: Dictionary) -> void:
	var origin := _grid_origin() - Vector2(PAD, PAD)
	var side := CELL * GRID_N + PAD * 2.0
	# Ombre et fond de la grille
	Wg.rrect(self, Rect2(origin + Vector2(0.0, 4.0), Vector2(side, side)), Color(Wg.SHADOW, Wg.SHADOW.a * 0.6), 30.0)
	Wg.rrect(self, Rect2(origin, Vector2(side, side)), Wg.GRID_BUBBLE, 30.0)
	# Capsules des mots trouvés puis du tracé en cours
	for step in _steps:
		if step["type"] != "swipe" or tt < step["t_drag"] or shrink <= 0.02:
			continue
		var a := _cell_center(step["start_cell"])
		var b := _cell_center(step["end_cell"])
		var end := b
		var pop := 1.0
		if tt < step["t_release"]:
			end = a.lerp(b, Motion.ease_in_out_cubic((tt - step["t_drag"]) / (step["t_release"] - step["t_drag"])))
		else:
			pop = 1.0 + 0.12 * Motion.bump(clampf((tt - step["t_release"]) / 0.3, 0.0, 1.0))
		_draw_capsule(a, end, Wg.trace_tint(step["color"]), pop * shrink)
	# Lettre d'indice (ampoule utilisée) : halo doré tant que le mot n'est pas trouvé
	for step in _steps:
		if step["type"] != "hint" or tt < step["t_pulse"]:
			continue
		var cell: Vector2i = step["start_cell"]
		var solved := false
		for other in _steps:
			if other["type"] == "swipe" and other["start_cell"] == cell and tt >= other["t_release"]:
				solved = true
		if solved:
			continue
		var c := _cell_center(cell)
		var beat := 1.0 + 0.1 * sin((tt - step["t_pulse"]) * 7.0)
		draw_circle(c, CELL * 0.44 * beat, Color(Wg.YELLOW, 0.34), true, -1.0, true)
		var u := clampf((tt - step["t_pulse"]) / 0.7, 0.0, 1.0)
		if u < 1.0:
			draw_arc(c, CELL * (0.3 + 0.55 * u), 0.0, TAU, 40, Wg.YELLOW_DARK, lerpf(5.0, 1.0, u), true)
	# Lettres
	var font := Wg.font(Wg.Weight.BLACK)
	var font_size := int(CELL * 0.56)
	for r in GRID_N:
		for c in GRID_N:
			var ch: String = _grid[r][c]
			var center := _cell_center(Vector2i(c, r))
			var bounce := 1.0
			for step in _steps:
				if step["type"] != "swipe" or tt < step["t_release"] or shrink < 0.5:
					continue
				var index := _index_in_path(step, Vector2i(c, r))
				if index >= 0:
					bounce = 1.0 + 0.3 * Motion.bump(clampf((tt - step["t_release"] - index * 0.06) / 0.32, 0.0, 1.0))
			var width := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_set_transform(center, 0.0, Vector2(bounce, bounce))
			draw_string(font, Vector2(-width * 0.5, font_size * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Wg.INK)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Onde au point d'appui
	for step in _steps:
		if step["type"] == "swipe":
			var u := clampf((tt - step["t_press"]) / 0.4, 0.0, 1.0)
			if u > 0.0 and u < 1.0:
				draw_arc(_cell_center(step["start_cell"]), CELL * (0.2 + 0.5 * u), 0.0, TAU, 32, Wg.PURPLE, lerpf(5.0, 0.8, u), true)


func _index_in_path(step: Dictionary, cell: Vector2i) -> int:
	var a: Vector2i = step["start_cell"]
	var b: Vector2i = step["end_cell"]
	var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(n + 1):
		if a + d * k == cell:
			return k
	return -1


func _draw_capsule(a: Vector2, b: Vector2, color: Color, scale_factor: float) -> void:
	var thickness := CELL * 0.8 * scale_factor
	var length := a.distance_to(b) + thickness
	var angle := (b - a).angle() if a.distance_to(b) > 0.5 else 0.0
	draw_set_transform((a + b) * 0.5, angle, Vector2.ONE)
	Wg.rrect(self, Rect2(Vector2(-length * 0.5, -thickness * 0.5), Vector2(length, thickness)), color, thickness * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pied de la démo : chronomètre à gauche, bouton d'indice à droite (le gant l'appuie dans le scénario 3).
func _draw_footer(tt: float) -> void:
	var font := Wg.font(Wg.Weight.BLACK)
	var y := HEADER_H + GAP + PAD * 2.0 + CELL * GRID_N + GAP
	var seconds := int(tt * 1.4) + 4
	var text := "0:%02d" % seconds
	Wg.rrect(self, Rect2(Vector2(2.0, y + 2.0), Vector2(112.0, 40.0)), Wg.TRACK, 20.0)
	draw_texture_rect(Icons.get_icon("ic_clock"), Rect2(Vector2(8.0, y + 5.0), Vector2(34.0, 34.0)), false)
	draw_string(font, Vector2(50.0, y + 32.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Wg.INK)
	# Bouton d'indice
	var rect := _hint_button_rect()
	var press := 0.0
	var balance := 2
	for step in _steps:
		if step["type"] == "hint":
			press = Motion.bump(clampf((tt - step["t_press"]) / 0.3, 0.0, 1.0))
			if tt >= step["t_pulse"]:
				balance = 1
	var lift := press * 3.0
	Wg.rrect(self, Rect2(rect.position + Vector2(0.0, 4.0), rect.size - Vector2(0.0, 4.0)), Wg.PURPLE_DARK, 22.0)
	Wg.rrect(self, Rect2(rect.position + Vector2(0.0, lift), rect.size - Vector2(0.0, 4.0)), Wg.PURPLE, 22.0)
	draw_texture_rect(Icons.get_icon("ic_bulb"), Rect2(rect.position + Vector2(8.0, 3.0 + lift), Vector2(34.0, 34.0)), false)
	var label := Strings.t("game_hint")
	var small := Wg.font(Wg.Weight.EXTRABOLD)
	draw_string(small, Vector2(rect.position.x + 46.0, rect.position.y + 26.0 + lift), label, HORIZONTAL_ALIGNMENT_LEFT, 56, 15, Wg.WHITE)
	var c := Vector2(rect.end.x - 20.0, rect.position.y + 18.0 + lift)
	draw_circle(c, 14.0, Wg.WHITE, true, -1.0, true)
	draw_string(small, c + Vector2(-5.0, 6.0), str(balance), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Wg.PURPLE_DARK)


func _draw_hand_shadow() -> void:
	if not _hand_visible or _texture == null:
		return
	var k := HAND_W / TEX_W
	draw_set_transform(_hand_pos + Vector2(7.0, 10.0), 0.0, Vector2(_hand_scale, _hand_scale))
	draw_texture_rect(_texture, Rect2(-TIP * k, Vector2(HAND_W, HAND_W * 409.0 / 512.0)), false, Color(Wg.SHADOW, Wg.SHADOW.a * 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
