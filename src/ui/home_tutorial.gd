class_name HomeTutorial
extends Control
## Tutoriel d'accueil, à la toute première ouverture du jeu : après un micro-délai, le gant tape en boucle sur « Jouer » de la bulle du
## chapitre 1, cerclé d'un anneau qui bat. Aucun texte, aucun voile : le joueur reste libre de tout. Le gant s'écarte quand le
## carrousel bouge ou quand une autre bulle est affichée, et revient ensuite. Le tutoriel se poursuit sur le niveau 1 (MoveTutorial).

const START_DELAY := 0.9
const RESUME_DELAY := 0.6
const GLOVE_WIDTH := 96.0

var _pager: ChapterPager
var _target_getter: Callable  ## () -> Control : le bouton Jouer de la bulle du chapitre 1
var _wait := START_DELAY
var _time := 0.0
var _visible_now := false
var _fx := Control.new()
var _ring := StyleBoxFlat.new()


static func open(parent: Control, pager: ChapterPager, target_getter: Callable) -> HomeTutorial:
	var tutorial := HomeTutorial.new()
	tutorial._pager = pager
	tutorial._target_getter = target_getter
	tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(tutorial)
	return tutorial


func _ready() -> void:
	_ring.bg_color = Color(0, 0, 0, 0)
	_ring.border_color = Wg.YELLOW
	_ring.set_border_width_all(4)
	_ring.anti_aliasing = true
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _target() -> Control:
	var node: Variant = _target_getter.call() if _target_getter.is_valid() else null
	return node if node is Control and is_instance_valid(node) else null


func _process(delta: float) -> void:
	var target := _target()
	if target == null or not is_instance_valid(_pager):
		queue_free()
		return
	if _pager.is_moving() or _pager.current_page() != 0 or not target.is_visible_in_tree():
		_visible_now = false
		_time = 0.0
		_wait = maxf(_wait, RESUME_DELAY)
	elif _wait > 0.0:
		_wait -= delta
		_visible_now = false
	else:
		_visible_now = true
		_time += delta
	_fx.queue_redraw()


func _draw_fx() -> void:
	var target := _target()
	if target == null or not _visible_now:
		return
	var rect := Rect2(target.global_position - global_position, target.size)
	var pulse := 0.0 if Wg.reduce_motion else 0.5 + 0.5 * sin(_time * TAU / 1.1)
	_ring.set_corner_radius_all(int(rect.size.y * 0.5))
	_fx.draw_style_box(_ring, rect.grow(1.0 + 3.0 * pulse))
	var rest_tip := Vector2(rect.position.x + rect.size.x * 0.30, rect.position.y + rect.size.y * 0.42)
	if Wg.reduce_motion:
		TutorialHand.draw(_fx, rest_tip, 0.0, GLOVE_WIDTH)  # animations réduites : le gant reste posé sur le bouton
		return
	var pose := TutorialHand.tap_pose(_time, rest_tip)
	if pose["shown"]:
		TutorialHand.draw_touch(_fx, pose["tip"], float(pose["press"]), 30.0)
		TutorialHand.draw(_fx, pose["tip"], float(pose["press"]), GLOVE_WIDTH)
