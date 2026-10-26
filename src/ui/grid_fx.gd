class_name GridFx
extends RefCounted
## Moteur d'effets de la grille. Tout est évalué à partir d'un temps écoulé (ressorts analytiques de Motion) :
## aucune animation par case, un seul passage de dessin, une seule boucle d'images qui s'arrête quand plus
## rien ne bouge.
##
## Règles de style : AUCUN fondu et AUCUNE particule. Les effets grandissent, rebondissent, tournent, glissent et
## rétrécissent ; ils ne changent jamais d'opacité dans le temps. Les tracés sont des capsules plates, claires et
## translucides (une seule forme par tracé : pas de reflet, pas de lèvre) posées sous des lettres toujours foncées.
## Les coordonnées sont en « unités de case » (colonne + 0,5 ; ligne + 0,5), indépendantes de la taille en pixels.

## Émis quand un nouvel effet démarre : la vue relance sa boucle d'images.
signal woke()

## Effet créé mais pas encore horodaté (la boucle d'images lui donnera son temps de départ).
const UNSET := -4611686018427387904
## Aucun effet en attente.
const NONE := -4611686018427387903
const POP_MS := 600
const WAVE_MS := 420
const WAVE_STAGGER_MS := 42
const LEAVE_MS := 260
const FOUND_GROW_MS := 700
const WRONG_WIGGLE_MS := 520
## Redémarrage : chaque lettre tourne autour du centre de la grille jusqu'à sa nouvelle case (retard maximal par lettre, puis
## ressort amorti qui se pose avec un léger dépassement).
const SPIN_MAX_DELAY_MS := 190
const SPIN_SETTLE_FREQUENCY := 11.0
const SPIN_SETTLE_DAMPING := 0.62
## Durée maximale de l'animation (le ressort est à moins de 1 % de sa cible) : verrou de saisie pendant ce temps.
const SHUFFLE_TOTAL_MS := SPIN_MAX_DELAY_MS + 720
## Épaisseur d'une capsule, en fraction de la case.
const CAPSULE_THICKNESS := 0.80


class Pop:
	var col: int
	var row: int
	var strength: float
	var start_ms: int = GridFx.UNSET


class WordWave:
	var cells: Array[Vector2i]
	var color: Color
	var start_ms: int = GridFx.UNSET


class Leaving:
	var a: Vector2
	var b: Vector2
	var color: Color
	var wrong: bool
	var start_ms: int = GridFx.UNSET


class Shuffle:
	var turns: int  ## quarts de tour horaires de la grille (+1 droite, -1 gauche)
	var delays: PackedInt32Array
	var start_ms: int = GridFx.UNSET


var n: int
var reduce_motion: bool
## Verrou de saisie pendant le mélange (horodatage Time.get_ticks_msec, posé par l'écran).
var input_locked_until: int = 0
var clock_ms: int = 0

var _pops: Array[Pop] = []
var _waves: Array[WordWave] = []
var _leaving: Array[Leaving] = []
var _shuffle: Shuffle = null
var _found_start := {}  ## clé de mot -> ms
var _known_found := {}
var _found_initialised := false
var _known_hints := {}
var _previous_selection: Array[Vector2i] = []
var _last_path: Array[Vector2i] = []
var _pending_release: int = NONE
var _pending_release_at: int = 0
var _wrong_since: int = NONE
var _wrong_cells: Array[Vector2i] = []
var _tip := Vector2.ZERO
## Couleur (déjà adoucie) du tracé en cours : sert aussi à la capsule qui se rétracte au relâchement.
var _trace_color := Wg.trace_tint(Wg.PURPLE)
var _tracing := false
var _last_tick: int = 0
# Modifications par case recalculées à chaque image (échelle, décalage, rotation) : O(effets) et non O(cases × effets).
var _scale := PackedFloat32Array()
var _off := PackedVector2Array()
var _rot := PackedFloat32Array()
var _touched := PackedByteArray()
var _glyph_widths := {}


func _init(p_n: int, p_reduce_motion: bool) -> void:
	n = p_n
	reduce_motion = p_reduce_motion
	_scale.resize(n * n)
	_off.resize(n * n)
	_rot.resize(n * n)
	_touched.resize(n * n)


func is_shuffling() -> bool:
	return _shuffle != null


func _bump() -> void:
	woke.emit()


# =========================================================================== événements
## Compare l'ensemble des mots trouvés au précédent : un nouveau mot déclenche l'effet de victoire, un mot retiré se rétracte.
func on_found_changed(found: Array[FoundHighlight]) -> void:
	var current := {}
	for h in found:
		current[_key(h.cells)] = h
	if not _found_initialised:
		_found_initialised = true
		_known_found.clear()
		for k in current:
			_known_found[k] = true
		return
	for k in current:
		if _known_found.has(k):
			continue
		_known_found[k] = true
		if reduce_motion:
			continue
		_found_start[k] = UNSET
		_pending_release = NONE
		_spawn_found(current[k])
	var gone: Array = []
	for k in _known_found:
		if not current.has(k):
			gone.append(k)
	for k in gone:
		_known_found.erase(k)
		_found_start.erase(k)
	if not gone.is_empty() and not reduce_motion:
		_bump()


## Mots retirés d'un coup (redémarrage) : on garde leurs capsules pour les rétracter.
func on_found_cleared(previous: Array[FoundHighlight]) -> void:
	if reduce_motion:
		return
	for h in previous:
		_leaving.append(_make_leaving(h.cells[0], h.cells[h.cells.size() - 1], h.color, false))
	if not previous.is_empty():
		_bump()


func on_selection_changed(selection: Array[Vector2i]) -> void:
	if reduce_motion:
		_previous_selection = selection
		if not selection.is_empty():
			_last_path = selection
		_tracing = not selection.is_empty()
		if _tracing:
			_tip = _center(selection[selection.size() - 1])
		_bump()
		return
	if not selection.is_empty():
		if _previous_selection.is_empty():
			_tip = _center(selection[0])
			_pending_release = NONE
		# Chaque case nouvellement atteinte « pop » ; la première rebondit plus fort.
		var fresh: Array[Vector2i] = []
		for c in selection:
			if not _previous_selection.has(c):
				fresh.append(c)
		for i in fresh.size():
			var pop := Pop.new()
			pop.col = fresh[i].x
			pop.row = fresh[i].y
			pop.strength = 1.25 if (_previous_selection.is_empty() and i == 0) else 1.0
			_pops.append(pop)
		_last_path = selection
		_tracing = true
	elif not _previous_selection.is_empty():
		_tracing = false
		_pending_release = UNSET  # attend le verdict (trouvé / faux) quelques images avant de rétracter
	_previous_selection = selection
	_bump()


## Mauvais mot : la capsule rouge se rétracte en tremblant.
func on_wrong() -> void:
	if reduce_motion:
		return
	_pending_release = NONE
	if _last_path.size() >= 2:
		_leaving.append(_make_leaving(_last_path[0], _last_path[_last_path.size() - 1], Wg.trace_tint(Wg.RED), true))
		_wrong_cells = _last_path
		_wrong_since = UNSET
	_bump()


## Indices déjà présents à l'ouverture (partie reprise) : pas d'effet de révélation.
func prime_hints(cells: Array[Vector2i]) -> void:
	_known_hints.clear()
	for c in cells:
		_known_hints[c] = true


func on_hint_cells(cells: Array[Vector2i]) -> void:
	_known_hints.clear()
	for c in cells:
		_known_hints[c] = true
	# L'indice est un halo qui bat (dessiné tant que la case est indicée) : aucun effet ponctuel à lancer.
	_bump()


## Position d'une lettre sur sa « couronne » : la grille est faite de carrés concentriques et un quart de tour fait avancer chaque
## lettre de `quarter_turns` quarts de la couronne qui l'entoure (dans le sens horaire), comme une courroie : les lettres gardent
## leur espacement, ne se chevauchent jamais et ne sortent jamais de la grille, même dans les coins. `v` : position de la lettre
## relative au centre (en cases), `quarter_turns` : quarts de tour horaires restant à parcourir (fractionnaire, négatif = antihoraire).
static func _ring_move(v: Vector2, quarter_turns: float) -> Vector2:
	var rho := maxf(absf(v.x), absf(v.y))
	if rho < 0.001:
		return v  # la case centrale (grille impaire) ne bouge pas
	var s := _ring_param(v, rho) + quarter_turns * 2.0 * rho  # un quart de tour = un quart du périmètre (8·rho)
	return _ring_point(rho, fposmod(s, 8.0 * rho))


## Abscisse curviligne d'un point de la couronne de demi-côté `rho` : 0 au coin haut-gauche, dans le sens horaire (0..8·rho).
static func _ring_param(v: Vector2, rho: float) -> float:
	if absf(v.y + rho) < 0.001:
		return v.x + rho
	if absf(v.x - rho) < 0.001:
		return 2.0 * rho + (v.y + rho)
	if absf(v.y - rho) < 0.001:
		return 4.0 * rho + (rho - v.x)
	return 6.0 * rho + (rho - v.y)


static func _ring_point(rho: float, s: float) -> Vector2:
	if s < 2.0 * rho:
		return Vector2(-rho + s, -rho)
	if s < 4.0 * rho:
		return Vector2(rho, -rho + (s - 2.0 * rho))
	if s < 6.0 * rho:
		return Vector2(rho - (s - 4.0 * rho), rho)
	return Vector2(-rho, rho - (s - 6.0 * rho))


## Redémarrage : les lettres se mélangent en tournant autour du centre jusqu'à leur nouvelle case (`turns` quarts de tour
## horaires : +1 vers la droite, -1 vers la gauche). La grille affichée est déjà la nouvelle : chaque lettre part de l'ancienne
## position de sa case (la rotation inverse) et y revient en tournant, les plus proches du centre en premier, avec un léger
## dépassement à l'arrivée. Aucun fondu, aucune particule.
func on_restart(turns: int, _token: int) -> void:
	if reduce_motion or turns == 0:
		return
	var total := n * n
	var max_ring := n / 2.0
	var s := Shuffle.new()
	s.turns = signi(turns)
	s.delays.resize(total)
	for i in total:
		var dx := (i % n + 0.5) - n / 2.0
		@warning_ignore("integer_division")
		var dy := (i / n + 0.5) - n / 2.0
		# Même retard pour toutes les lettres d'une couronne (elles gardent leur espacement), les couronnes du centre partent
		# les premières : le mouvement se propage vers l'extérieur sans qu'aucune lettre n'en chevauche une autre.
		s.delays[i] = int(maxf(absf(dx), absf(dy)) / max_ring * float(SPIN_MAX_DELAY_MS))
	s.start_ms = Time.get_ticks_msec()  # tout de suite : la nouvelle grille ne doit pas apparaître une image à sa place finale
	_shuffle = s
	_pending_release = NONE
	_bump()


# =========================================================================== boucle d'images
func tick(now: int) -> void:
	# Horodatage des effets créés alors que la boucle était à l'arrêt.
	for p in _pops:
		if p.start_ms == UNSET:
			p.start_ms = now
	for w in _waves:
		if w.start_ms == UNSET:
			w.start_ms = now
	for l in _leaving:
		if l.start_ms == UNSET:
			l.start_ms = now
	if _shuffle != null and _shuffle.start_ms == UNSET:
		_shuffle.start_ms = now
	for k in _found_start:
		if _found_start[k] == UNSET:
			_found_start[k] = now
	if _wrong_since == UNSET:
		_wrong_since = now
	if _pending_release == UNSET:
		_pending_release = now
		_pending_release_at = now
	# Verdict absent au bout de ~2 images : simple relâchement, la capsule se rétracte sans bruit.
	if _pending_release >= 0 and now - _pending_release_at >= 40:
		_pending_release = NONE
		if _last_path.size() >= 2:
			var leaving := _make_leaving(_last_path[0], _last_path[_last_path.size() - 1], _trace_color, false)
			leaving.start_ms = now
			_leaving.append(leaving)
	# Pointe de la capsule : suit le doigt avec un amortissement critique (jamais de saut de case en case).
	var dt := 0.0 if _last_tick == 0 else clampf((now - _last_tick) / 1000.0, 0.0, 0.05)
	_last_tick = now
	if _tracing and not _last_path.is_empty():
		var target := _center(_previous_selection[_previous_selection.size() - 1] if not _previous_selection.is_empty() else _last_path[_last_path.size() - 1])
		var k := 1.0 - exp(-30.0 * dt)
		_tip += (target - _tip) * k
	# Nettoyage des effets terminés.
	_pops = _pops.filter(func(p: Pop) -> bool: return p.start_ms == UNSET or now - p.start_ms <= POP_MS)
	_waves = _waves.filter(func(w: WordWave) -> bool: return w.start_ms == UNSET or now - w.start_ms <= WAVE_MS + w.cells.size() * WAVE_STAGGER_MS)
	_leaving = _leaving.filter(func(l: Leaving) -> bool: return l.start_ms == UNSET or now - l.start_ms <= LEAVE_MS)
	if _shuffle != null and _shuffle.start_ms != UNSET and now - _shuffle.start_ms > SHUFFLE_TOTAL_MS:
		_shuffle = null
	if _wrong_since >= 0 and now - _wrong_since > WRONG_WIGGLE_MS:
		_wrong_since = NONE
		_wrong_cells = []
	clock_ms = now


## Vrai tant qu'il reste quelque chose à animer (la boucle d'images s'arrête sinon).
func has_work(now: int) -> bool:
	if not (_pops.is_empty() and _waves.is_empty() and _leaving.is_empty()):
		return true
	if _shuffle != null or _tracing or _pending_release != NONE or _wrong_since != NONE:
		return true
	for k in _found_start:
		var start: int = _found_start[k]
		if start == UNSET or now - start < FOUND_GROW_MS:
			return true
	return false


# =========================================================================== fabrication d'effets
func _make_leaving(a: Vector2i, b: Vector2i, color: Color, wrong: bool) -> Leaving:
	var l := Leaving.new()
	l.a = _center(a)
	l.b = _center(b)
	l.color = color
	l.wrong = wrong
	return l


func _spawn_found(h: FoundHighlight) -> void:
	var wave := WordWave.new()
	wave.cells = h.cells
	wave.color = h.color
	_waves.append(wave)
	_bump()


func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5)


func _key(cells: Array[Vector2i]) -> String:
	var a := cells[0]
	var b := cells[cells.size() - 1]
	return "%d,%d-%d,%d" % [a.y, a.x, b.y, b.x]


func _slot(i: int) -> Vector2:
	@warning_ignore("integer_division")
	return Vector2(i % n + 0.5, i / n + 0.5)


# =========================================================================== dessin
## Couleur (déjà adoucie) de la capsule du tracé en direct.
func set_trace_color(color: Color) -> void:
	_trace_color = color


## Dessine la couche dynamique : capsules, indices, lettres animées.
## Le fond de la grille (la bulle) est dessiné à part, une seule fois, par la vue.
func draw(
	canvas: CanvasItem, grid: PackedStringArray, found: Array[FoundHighlight], selection: Array[Vector2i],
	selection_color: Color, hint_cells: Array[Vector2i], font: Font, font_px: float, ink: Color, cell_size: float
) -> void:
	var now := clock_ms
	var cs := cell_size
	_trace_color = selection_color
	# 1) Capsules qui se rétractent (mot retiré, tracé relâché ou faux)
	for l in _leaving:
		_draw_leaving(canvas, l, now, cs)
	# 2) Capsules des mots trouvés (elles « poussent » avec un rebond à leur création)
	for h in found:
		var start: int = _found_start.get(_key(h.cells), -1)
		var t := 99.0 if (start == -1 or start == UNSET) else (now - start) / 1000.0
		var grow := 0.0 if start == UNSET else minf(1.08, Motion.spring(t, 15.0, 0.55))
		var pulse := 1.0 + 0.24 * Motion.bump(t / 0.36)
		_draw_capsule(canvas, _center(h.cells[0]), _center(h.cells[h.cells.size() - 1]), h.color, cs, grow, pulse, 0.0)
	# 3) Capsule du tracé en direct : serpent élastique, léger « souffle » de l'épaisseur
	if not selection.is_empty():
		var a := _center(selection[0])
		var b := _center(selection[selection.size() - 1]) if reduce_motion else _tip
		var breathe := 1.0 + 0.04 * sin(now / 105.0)
		_draw_capsule(canvas, a, b, selection_color, cs, 1.0, breathe, 0.04)
	# 4) Cases d'indice : anneau qui bat + halo
	for c in hint_cells:
		var beat := 1.0 + 0.12 * sin(now / 170.0 + c.x)
		var center := Vector2((c.x + 0.5) * cs, (c.y + 0.5) * cs)
		canvas.draw_circle(center, cs * 0.44 * beat, Color(Wg.YELLOW, 0.28), true, -1.0, true)
		canvas.draw_arc(center, cs * 0.46 * beat, 0.0, TAU, 40, Wg.YELLOW_DARK, cs * 0.09, true)
	# 5) Lettres : pop à la sélection, vague à la victoire, secousse à l'erreur, mélange au redémarrage.
	#    Les lettres sont toujours foncées : les capsules, claires et translucides, restent dessous.
	_compute_letter_effects(now)
	var font_size := int(roundf(font_px))
	var baseline := font_px * 0.36
	for r in n:
		var row_text := grid[r]
		for c in n:
			var idx := r * n + c
			var ch := row_text[c]
			var width: float = _glyph_widths.get(ch, -1.0)
			if width < 0.0:
				width = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				_glyph_widths[ch] = width
			if _touched[idx] == 0:
				canvas.draw_string(font, Vector2((c + 0.5) * cs - width * 0.5, (r + 0.5) * cs + baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
			else:
				var pos := (Vector2(c + 0.5, r + 0.5) + _off[idx]) * cs
				canvas.draw_set_transform(pos, deg_to_rad(_rot[idx]), Vector2(_scale[idx], _scale[idx]))
				canvas.draw_string(font, Vector2(-width * 0.5, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
				# Indispensable : la transformation reste active jusqu'au prochain appel. Sans cette remise à zéro, toutes
				# les lettres dessinées ensuite (ordre ligne par ligne) héritaient du décalage et de l'échelle de la
				# lettre animée et partaient hors de leur case dès le début d'un tracé.
				canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _compute_letter_effects(now: int) -> void:
	var total := n * n
	var any := not _pops.is_empty() or not _waves.is_empty() or _wrong_since >= 0 or _shuffle != null
	_touched.fill(0)
	if not any:
		return
	for i in total:
		_scale[i] = 1.0
		_off[i] = Vector2.ZERO
		_rot[i] = 0.0
	for p in _pops:
		if p.start_ms == UNSET:
			continue
		var idx := p.row * n + p.col
		var t := (now - p.start_ms) / 1000.0
		_scale[idx] *= 1.0 + 0.5 * p.strength * (1.0 - Motion.spring(t, 20.0, 0.4))
		_touched[idx] = 1
	for w in _waves:
		if w.start_ms == UNSET:
			continue
		for i in w.cells.size():
			var t := (now - w.start_ms - i * WAVE_STAGGER_MS) / 1000.0 / 0.32
			if t >= 0.0 and t <= 1.0:
				var b := Motion.bump(t)
				var idx := w.cells[i].y * n + w.cells[i].x
				_off[idx].y -= 0.34 * b
				_scale[idx] *= 1.0 + 0.38 * b
				_touched[idx] = 1
	if _wrong_since >= 0:
		var t := (now - _wrong_since) / 1000.0
		for c in _wrong_cells:
			var idx := c.y * n + c.x
			_rot[idx] += 11.0 * sin(t * 46.0) * exp(-t * 7.0)
			_touched[idx] = 1
	if _shuffle != null and _shuffle.start_ms != UNSET:
		var s := _shuffle
		var center := Vector2(n / 2.0, n / 2.0)
		for idx in total:
			# Avant son retard, la lettre attend à son ancienne position (angle de départ) : jamais de saut.
			var t := maxf(float(now - s.start_ms - s.delays[idx]), 0.0) / 1000.0
			var settle := Motion.spring(t, SPIN_SETTLE_FREQUENCY, SPIN_SETTLE_DAMPING)  # 0 -> 1, léger dépassement
			var remaining := -float(s.turns) * (1.0 - settle)  # quarts de tour horaires encore à parcourir (0 = arrivée)
			var pull := Motion.bump(minf(t / 0.5, 1.0))
			var home := _slot(idx)
			var spun := center + _ring_move(home - center, remaining)
			_off[idx] = spun - home
			_rot[idx] = remaining * 90.0 * 0.12  # une légère inclinaison dans le sens du mouvement
			_scale[idx] *= 1.0 + 0.1 * pull
			_touched[idx] = 1


## Capsule : UNE seule forme plate (rectangle à coins en demi-cercle, pivoté), donc aucun recouvrement interne quand
## la couleur est translucide. Pas de lèvre foncée, pas de reflet. `grow` ∈ [0, ~1,1] : longueur visible.
func _draw_capsule(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, cs: float, grow: float, thickness: float, extra: float) -> void:
	var pa := a * cs
	var pb := pa + (b * cs - pa) * grow
	_capsule(canvas, pa, pb, color, cs * (CAPSULE_THICKNESS + extra) * thickness)


func _capsule(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	if width <= 0.5:
		return
	var radius := width * 0.5
	var delta := to - from
	canvas.draw_set_transform(from, delta.angle(), Vector2.ONE)
	Wg.rrect(canvas, Rect2(Vector2(-radius, -radius), Vector2(delta.length() + width, width)), color, radius)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_leaving(canvas: CanvasItem, l: Leaving, now: int, cs: float) -> void:
	if l.start_ms == UNSET:
		return
	var u := clampf((now - l.start_ms) / float(LEAVE_MS), 0.0, 1.0)
	var e := Motion.ease_in_out_cubic(u)
	var pa := l.a * cs
	var pb := pa + (l.b * cs - pa) * (1.0 - e)
	var shake := 0.18 * cs * sin(u * 50.0) * (1.0 - u) if l.wrong else 0.0
	var w := cs * CAPSULE_THICKNESS * (1.0 - e * 0.85)
	var dx := Vector2(shake, 0)
	_capsule(canvas, pa + dx, pb + dx, l.color, w)
