class_name HintIntro
extends Control
## Cinématique de l'indice (la toute première fois que le joueur arrive au niveau 4 du chapitre 1) : l'écran s'assombrit
## autour du bouton « Indice », le gant l'invite à le toucher et une petite carte explique à quoi il sert. Le bouton reste
## cliquable à travers le « trou » ; toucher ailleurs ne fait rien. « Plus tard » ou l'indice utilisé referme la cinématique.

signal finished()

const DIM := Color(0.10, 0.09, 0.25, 0.70)
const HOLE_PAD := 8.0
const CARD_MAX_WIDTH := 330.0
const CARD_GAP := 34.0  ## entre la carte et le bouton (la place du gant)
const OPEN_SECONDS := 0.5
const CLOSE_SECONDS := 0.28

var _target: Control
var _dims: Array[ColorRect] = []  ## quatre bandes invisibles qui bloquent le toucher autour du bouton
var _veil: ColorRect  ## le voile sombre visible, avec un trou arrondi autour du bouton (shader)
var _veil_material: ShaderMaterial
var _fx := Control.new()  ## anneau et gant, dessinés au-dessus du voile
var _stack := MarginContainer.new()
var _card_column := VBoxContainer.new()
var _ring := StyleBoxFlat.new()
var _hole := Rect2()
var _time := 0.0
var _closing := false
var _open := 0.0  ## 0 = projecteur grand ouvert (écran entier), 1 = refermé sur le bouton ; animé à l'ouverture et à la fermeture
var _open_t := 0.0


static func open(parent: Control, target: Control) -> HintIntro:
	var intro := HintIntro.new()
	intro._target = target
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE  # le « trou » laisse passer le toucher vers le bouton
	intro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(intro)
	return intro


const _VEIL_SHADER := """
shader_type canvas_item;
uniform vec4 dim_color : source_color = vec4(0.1, 0.09, 0.25, 0.7);
uniform vec2 area_size = vec2(100.0, 100.0);
uniform vec4 hole = vec4(0.0);
uniform float radius = 30.0;
void fragment() {
	vec2 p = UV * area_size;
	vec2 half_size = hole.zw * 0.5;
	vec2 q = abs(p - (hole.xy + half_size)) - half_size + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(dim_color.rgb, dim_color.a * smoothstep(0.0, 1.5, d));
}
"""


func _ready() -> void:
	var shader := Shader.new()
	shader.code = _VEIL_SHADER
	_veil_material = ShaderMaterial.new()
	_veil_material.shader = shader
	_veil_material.set_shader_parameter("dim_color", DIM)
	_veil = ColorRect.new()
	_veil.color = Color.WHITE
	_veil.material = _veil_material
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	for i in range(4):
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0)  # invisible : le voile est dessiné par le shader, ces bandes ne font que bloquer le toucher
		dim.mouse_filter = Control.MOUSE_FILTER_STOP  # tout le reste de l'écran est bloqué
		add_child(dim)
		_dims.append(dim)
	_ring.bg_color = Color(0, 0, 0, 0)
	_ring.border_color = Wg.YELLOW
	_ring.set_border_width_all(4)
	_ring.set_corner_radius_all(40)
	_ring.anti_aliasing = true
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stack)
	_card_column.alignment = BoxContainer.ALIGNMENT_END
	_card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_card_column)
	_card_column.add_child(_build_card())
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	set_process(true)
	_layout()


func _build_card() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Wg.SURFACE
	box.set_corner_radius_all(26)
	box.corner_detail = 12
	box.anti_aliasing = true
	box.shadow_color = Wg.SHADOW
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 5)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(UiKit.icon("ic_bulb", 30.0))
	title_row.add_child(Wg.label(Strings.t("tutorial_hint_title"), 21.0, Wg.Weight.BLACK, Wg.INK))
	column.add_child(title_row)
	var body := Wg.label(Strings.t("tutorial_hint_body"), 16.0, Wg.Weight.BOLD, Wg.INK_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_FILL
	column.add_child(body)
	var skip := WgButton.create(Strings.t("tutorial_hint_skip"), WgButton.Kind.GHOST)
	skip.activated.connect(close)
	column.add_child(skip)
	return panel


## Referme la cinématique (indice utilisé, « Plus tard » ou écran quitté) : le projecteur s'élargit jusqu'à l'écran entier et la
## carte redescend. Aucun fondu.
func close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
	for dim in _dims:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE  # le joueur reprend la main tout de suite
	if Wg.reduce_motion or not is_inside_tree():
		queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		close()
		return
	_time += delta
	if _closing:
		_open_t = maxf(_open_t - delta / CLOSE_SECONDS, 0.0)
		_open = Motion.ease_in_cubic(_open_t)
		if _open_t <= 0.0:
			queue_free()
			return
	else:
		_open_t = 1.0 if Wg.reduce_motion else minf(_open_t + delta / OPEN_SECONDS, 1.0)
		_open = Motion.ease_out_cubic(_open_t)
	_layout()
	_fx.queue_redraw()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	var target_hole := Rect2(_target.global_position - global_position, _target.size).grow(HOLE_PAD).intersection(bounds)
	# Le projecteur s'ouvre depuis l'écran entier (il grossit de `(1 - _open)` écrans autour du bouton) : jamais de fondu.
	_hole = target_hole.grow((1.0 - _open) * maxf(size.x, size.y))
	var left_w := _hole.position.x
	var right_w := size.x - _hole.end.x
	_set_rect(_dims[0], Rect2(0.0, 0.0, size.x, _hole.position.y))
	_set_rect(_dims[1], Rect2(0.0, _hole.end.y, size.x, size.y - _hole.end.y))
	_set_rect(_dims[2], Rect2(0.0, _hole.position.y, left_w, _hole.size.y))
	_set_rect(_dims[3], Rect2(_hole.end.x, _hole.position.y, right_w, _hole.size.y))
	# La carte est posée juste au-dessus du bouton, jamais sur la zone sûre d'Android.
	var insets := App.safe_area_insets
	var side := maxf(UiKit.edge(0.0) + maxf(insets.x, insets.z), (size.x - CARD_MAX_WIDTH) * 0.5)
	_stack.add_theme_constant_override("margin_left", int(side))
	_stack.add_theme_constant_override("margin_right", int(side))
	_stack.add_theme_constant_override("margin_top", int(insets.y) + UiKit.edge(0.0))
	_stack.add_theme_constant_override("margin_bottom", int(maxf(size.y - target_hole.position.y + CARD_GAP, 0.0)))
	UiKit.transform_visual(_card_column, Vector2(0.0, (1.0 - _open) * 150.0), Vector2.ONE)  # la carte monte depuis le bas
	var radius := minf(_hole.size.y * 0.5, 40.0 + (1.0 - _open) * 200.0)
	_ring.set_corner_radius_all(int(radius))
	_veil_material.set_shader_parameter("area_size", size)
	_veil_material.set_shader_parameter("hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y))
	_veil_material.set_shader_parameter("radius", radius)


static func _set_rect(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = Vector2(maxf(rect.size.x, 0.0), maxf(rect.size.y, 0.0))


func _draw_fx() -> void:
	if _hole.size.x <= 0.0:
		return
	var pulse := 0.0 if Wg.reduce_motion else 0.5 + 0.5 * sin(_time * TAU / 1.1)
	_fx.draw_style_box(_ring, _hole.grow(2.0 + 4.0 * pulse))  # l'anneau est le bord du projecteur
	if _open < 0.999 or _closing:
		return  # le gant n'apparaît qu'une fois le projecteur refermé sur le bouton
	var rest_tip := Vector2(_hole.position.x + _hole.size.x * 0.34, _hole.position.y + _hole.size.y * 0.36)
	if Wg.reduce_motion:
		TutorialHand.draw(_fx, rest_tip, 0.0, 92.0)
		return
	var pose := TutorialHand.tap_pose(_time - OPEN_SECONDS, rest_tip)
	if pose["shown"]:
		TutorialHand.draw_touch(_fx, pose["tip"], float(pose["press"]), 30.0)
		TutorialHand.draw(_fx, pose["tip"], float(pose["press"]), 92.0)
