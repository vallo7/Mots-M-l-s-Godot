class_name PageTransition
extends RefCounted
## Chorégraphie d'un changement de page. Quatre styles, aucun ne fait jamais de fondu :
##   SLIDE   : « push » horizontal avec parallaxe (menus, aide, défi) ;
##   RISE    : la page d'arrivée monte du bas (entrée en jeu, victoire) pendant que la précédente recule ;
##   DROP    : l'inverse, la page du dessus redescend et révèle celle d'en dessous (sortie du jeu) ;
##   CURTAIN : la page de départ se lève comme un rideau (chargement -> accueil) ;
##   IRIS    : disque qui s'ouvre depuis le doigt (désactivé : voir USE_IRIS).
## En plus du mouvement de la page, chaque écran déclare des « groupes » (`transition_groups()`, liste de [Control, côté]) :
## à l'arrivée ils entrent l'un après l'autre en glissant, au départ ils repartent en sens inverse, plus vite. Mouvements en
## courbes douces (décélération en quart de puissance), sans rebond et sans aucun fondu.
## Piloté à la main par `step(dt)` : le temps avance d'au plus 1/30 s par image, lissé sur les 3 dernières images pour effacer
## les à-coups, et la toute première image (celle où l'écran vient d'être construit) ne compte que pour 1/60 s : une image lente
## fait attendre l'animation au lieu de lui faire sauter des étapes.

enum Style { SLIDE, IRIS, RISE, CURTAIN, DROP }

## Le disque d'iris masque toute la page à chaque image (découpe hors écran) : coûteux sur mobile. Remplacé par RISE / DROP, bien plus
## fluides ; remettre `true` pour retrouver l'iris.
const USE_IRIS := false

const SLIDE_SECONDS := 0.44
const IRIS_SECONDS := 0.56
const RISE_SECONDS := 0.5
const DROP_SECONDS := 0.42
const CURTAIN_SECONDS := 0.55
const PARALLAX := 0.28
const ENTER_SECONDS := 0.42
const EXIT_SECONDS := 0.24
const STAGGER := 0.045

var style: int = Style.SLIDE
var forward := true
var incoming: Control
var outgoing: Control
var duration := 0.5
var iris_origin := Vector2.ZERO

var _host: Control
var _pages: Control
var _t := 0.0
var _recent_dts: Array[float] = []
var _first_step := true
var _main_seconds := 0.5
var _enter_start := 0.05
var _items_in: Array[_Item] = []
var _items_out: Array[_Item] = []
var _wrap: IrisWrap
var _ring: _Ring
var _edge: _Edge


class _Item:
	var node: Control
	var side: String
	var order: int
	var delay := 0.0


## Anneau coloré au bord du disque (de plus en plus fin à mesure qu'il grandit).
class _Ring extends Control:
	var center := Vector2.ZERO
	var radius := 0.0
	var width := 0.0
	var color := Wg.PURPLE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if radius > 1.0 and width > 0.4:
			draw_arc(center, radius, 0.0, TAU, 96, color, width, true)


## Ombre douce le long du bord de la page du dessus.
class _Edge extends Control:
	enum Side { LEFT, TOP, BOTTOM }
	var side: int = Side.LEFT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dark := Color(Wg.SHADOW, Wg.SHADOW.a * 1.1)
		var clear := Color(Wg.SHADOW, 0.0)
		var r := Rect2(Vector2.ZERO, size)
		match side:
			Side.LEFT:
				draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0.0), r.end, Vector2(0.0, r.end.y)]), PackedColorArray([clear, dark, dark, clear]))
			Side.TOP:
				draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0.0), r.end, Vector2(0.0, r.end.y)]), PackedColorArray([clear, clear, dark, dark]))
			_:
				draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0.0), r.end, Vector2(0.0, r.end.y)]), PackedColorArray([dark, dark, clear, clear]))


## Style choisi selon la page de départ, la page d'arrivée et le sens (`from_kind` : -1 = chargement).
static func style_for(from_kind: int, to_kind: int, is_forward: bool) -> int:
	if from_kind < 0:
		return Style.CURTAIN
	var K := ScreenRoute.Kind
	if from_kind == K.GAME and to_kind == K.RESULT:
		return Style.RISE
	if to_kind == K.GAME:
		return Style.IRIS if USE_IRIS else Style.RISE
	if from_kind == K.GAME and not is_forward:
		return Style.IRIS if USE_IRIS else Style.DROP
	return Style.SLIDE


## Prépare la transition : `pages` contient déjà `next` et `previous`. Les groupes d'entrée sont mis dans leur état de départ.
func begin(host: Control, pages: Control, next: Control, previous: Control, is_forward: bool, p_style: int, origin: Vector2) -> void:
	_host = host
	_pages = pages
	incoming = next
	outgoing = previous
	forward = is_forward
	style = p_style
	iris_origin = origin
	match style:
		Style.IRIS:
			_main_seconds = IRIS_SECONDS
			_enter_start = 0.24
		Style.RISE:
			_main_seconds = RISE_SECONDS
			_enter_start = 0.14
		Style.DROP:
			_main_seconds = DROP_SECONDS
			_enter_start = 0.12
		Style.CURTAIN:
			_main_seconds = CURTAIN_SECONDS
			_enter_start = 0.16
		_:
			_main_seconds = SLIDE_SECONDS
			_enter_start = 0.05
	_items_in = _collect(next, true)
	_items_out = _collect(previous, false)
	var end := _main_seconds
	for item in _items_in:
		end = maxf(end, item.delay + ENTER_SECONDS)
	duration = end
	_setup_style()
	_t = 0.0
	_apply(0.0)


func _collect(page: Control, entering: bool) -> Array[_Item]:
	var result: Array[_Item] = []
	if not page.has_method("transition_groups"):
		return result
	var groups: Array = page.call("transition_groups")
	for i in groups.size():
		var item := _Item.new()
		item.node = groups[i][0]
		item.side = groups[i][1]
		item.order = i
		if entering:
			item.delay = _enter_start + i * STAGGER
		else:
			item.delay = (groups.size() - 1 - i) * 0.03
		result.append(item)
	return result


func _setup_style() -> void:
	var size := _host.size
	match style:
		Style.IRIS:
			var mover := incoming if forward else outgoing
			_wrap = IrisWrap.new(size)
			_pages.add_child(_wrap)
			mover.reparent(_wrap.content, false)
			UiKit.full_rect(mover)
			_ring = _Ring.new()
			_ring.size = size
			_pages.add_child(_ring)
			# Ordre : la page du dessous, puis le disque (page qui bouge), puis l'anneau.
			_pages.move_child(_wrap, _pages.get_child_count() - 2)
		Style.SLIDE:
			_edge = _Edge.new()
			_edge.side = _Edge.Side.LEFT
			var top := incoming if forward else outgoing
			top.add_child(_edge)
			_edge.position = Vector2(-30.0, 0.0)
			_edge.size = Vector2(30.0, size.y)
			_pages.move_child(top, _pages.get_child_count() - 1)
			_pages.move_child(outgoing if forward else incoming, 0)
		Style.RISE:
			_edge = _Edge.new()
			_edge.side = _Edge.Side.TOP
			incoming.add_child(_edge)
			_edge.position = Vector2(0.0, -34.0)
			_edge.size = Vector2(size.x, 34.0)
			_pages.move_child(outgoing, 0)
			_pages.move_child(incoming, _pages.get_child_count() - 1)
		Style.DROP:
			_edge = _Edge.new()
			_edge.side = _Edge.Side.TOP
			outgoing.add_child(_edge)
			_edge.position = Vector2(0.0, -34.0)
			_edge.size = Vector2(size.x, 34.0)
			_pages.move_child(incoming, 0)
			_pages.move_child(outgoing, _pages.get_child_count() - 1)
		Style.CURTAIN:
			_edge = _Edge.new()
			_edge.side = _Edge.Side.BOTTOM
			outgoing.add_child(_edge)
			_edge.position = Vector2(0.0, size.y)
			_edge.size = Vector2(size.x, 34.0)
			_pages.move_child(incoming, 0)
			_pages.move_child(outgoing, _pages.get_child_count() - 1)


## Avance de `dt` secondes ; renvoie vrai quand la transition est terminée.
func step(dt: float) -> bool:
	_t = minf(duration, _t + _smoothed(dt))
	_apply(_t)
	return _t >= duration


## Durée d'image lissée : la première image (écran à peine construit) vaut 1/60 s ; ensuite chaque durée est bornée à 1/30 s puis
## moyennée avec les deux précédentes. Les pics isolés (ramasse-miettes, décodage d'une image) deviennent trois images régulières.
func _smoothed(dt: float) -> float:
	var d := 1.0 / 60.0 if _first_step else minf(dt, 1.0 / 30.0)
	_first_step = false
	_recent_dts.append(d)
	if _recent_dts.size() > 3:
		_recent_dts.remove_at(0)
	var total := 0.0
	for value in _recent_dts:
		total += value
	return total / float(_recent_dts.size())


func _apply(t: float) -> void:
	var m := clampf(t / _main_seconds, 0.0, 1.0)
	var size := _host.size
	match style:
		Style.SLIDE:
			var e := 1.0 - pow(1.0 - m, 4.0)
			if forward:
				incoming.position.x = size.x * (1.0 - e)
				outgoing.position.x = -size.x * PARALLAX * e
			else:
				outgoing.position.x = size.x * e
				incoming.position.x = -size.x * PARALLAX * (1.0 - e)
		Style.IRIS:
			var e := Motion.ease_in_out_cubic(m)
			var full := IrisWrap.cover_radius(iris_origin, size)
			var radius := lerpf(14.0, full, e) if forward else lerpf(full, 0.0, e)
			_wrap.set_circle(iris_origin, radius)
			_ring.center = iris_origin
			_ring.radius = radius
			_ring.width = lerpf(14.0, 1.0, e) if m < 1.0 else 0.0
			_ring.color = Wg.PURPLE if forward else Wg.PINK
			_ring.queue_redraw()
			var under := outgoing if forward else incoming
			var s := 1.0 - 0.05 * e if forward else 0.95 + 0.05 * e
			UiKit.transform_visual(under, Vector2.ZERO, Vector2(s, s))
		Style.RISE:
			var e := 1.0 - pow(1.0 - m, 4.0)
			incoming.position.y = size.y * (1.0 - e)
			var s := 1.0 - 0.07 * e
			UiKit.transform_visual(outgoing, Vector2(0.0, -34.0 * e), Vector2(s, s))
		Style.DROP:
			var e := Motion.ease_in_out_cubic(m)
			outgoing.position.y = size.y * e
			var s := 0.93 + 0.07 * e
			UiKit.transform_visual(incoming, Vector2(0.0, -34.0 * (1.0 - e)), Vector2(s, s))
		Style.CURTAIN:
			var e := Motion.ease_in_out_cubic(m)
			outgoing.position.y = -size.y * e
			var s := 0.94 + 0.06 * e
			UiKit.transform_visual(incoming, Vector2.ZERO, Vector2(s, s))
	for item in _items_in:
		var p := clampf((t - item.delay) / ENTER_SECONDS, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - p, 4.0)  # décélération douce, sans rebond
		var from := _enter_from(item.side)
		var scale := lerpf(0.94, 1.0, e)
		UiKit.transform_visual(item.node, from * (1.0 - e), Vector2(scale, scale))
	for item in _items_out:
		var p := clampf((t - item.delay) / EXIT_SECONDS, 0.0, 1.0)
		var e := Motion.ease_in_cubic(p)
		var to := _exit_to(item.side)
		var scale := lerpf(1.0, 0.94, e)
		UiKit.transform_visual(item.node, to * e, Vector2(scale, scale))


func _enter_from(side: String) -> Vector2:
	match side:
		"top":
			return Vector2(0.0, -34.0)
		"bottom":
			return Vector2(0.0, 46.0)
		_:
			if style == Style.SLIDE:
				return Vector2(46.0 if forward else -46.0, 0.0)
			return Vector2(0.0, 34.0)


func _exit_to(side: String) -> Vector2:
	match side:
		"top":
			return Vector2(0.0, -26.0)
		"bottom":
			return Vector2(0.0, 34.0)
		_:
			if style == Style.SLIDE:
				return Vector2(-34.0 if forward else 34.0, 0.0)
			return Vector2(0.0, -20.0)


## Rend les pages à leur état normal : positions, transformations, parents. `outgoing` n'est pas libéré ici.
func finish(pages: Control) -> void:
	if _wrap != null:
		var mover := incoming if forward else outgoing
		if is_instance_valid(mover) and mover.get_parent() == _wrap.content:
			mover.reparent(pages, false)
			UiKit.full_rect(mover)
		_wrap.queue_free()
		_wrap = null
	if _ring != null:
		_ring.queue_free()
		_ring = null
	if _edge != null:
		_edge.queue_free()
		_edge = null
	for page in [incoming, outgoing]:
		if is_instance_valid(page):
			page.position = Vector2.ZERO
			UiKit.transform_visual(page, Vector2.ZERO, Vector2.ONE)
	for item in _items_in + _items_out:
		if is_instance_valid(item.node):
			UiKit.transform_visual(item.node, Vector2.ZERO, Vector2.ONE)
