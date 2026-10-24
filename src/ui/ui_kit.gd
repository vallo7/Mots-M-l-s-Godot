class_name UiKit
extends RefCounted
## Petits constructeurs de nœuds d'interface partagés par tous les écrans.


## Icône vectorielle à la taille donnée. `tint` : teinte appliquée aux glyphes monochromes (blancs) ;
## les icônes multicolores ne sont jamais teintées (laisser `tint` à null).
static func icon(icon_name: String, size: float, tint: Variant = null) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Icons.get_icon(icon_name)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tint != null:
		rect.self_modulate = tint
	return rect


## Libellé qui rétrécit pour tenir sur une ligne dans la largeur qu'il reçoit (jamais d'ellipse ni de débordement) :
## sa largeur minimale est nulle, donc il ne force jamais son conteneur à s'élargir. `base_size` : taille normale.
static func fit_label(label: Label, base_size: int, min_size: int = 12) -> void:
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var refit := func() -> void:
		if label.size.x <= 0.0:
			return
		var font := label.get_theme_font("font")
		var chosen := base_size
		while chosen > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > label.size.x:
			chosen -= 1
		label.add_theme_font_size_override("font_size", chosen)
	label.resized.connect(refit)
	label.item_rect_changed.connect(refit)


## Enveloppe `node` dans un conteneur qui remplit son parent et le centre.
static func centered(node: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(node)
	return holder


## Contrôle de mise en page qui remplit son parent.
static func full_rect(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Transformation visuelle d'un contrôle sans toucher à la mise en page ni à la zone tactile
## (Control « offset transform » de Godot 4.7) : échelle autour du centre, décalage, rotation en degrés.
static func jelly(node: Control, scale_x: float, scale_y: float, translate_y: float = 0.0, rotation_degrees: float = 0.0) -> void:
	if not node.offset_transform_enabled:
		node.offset_transform_enabled = true
		node.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		node.offset_transform_visual_only = true
	node.offset_transform_scale = Vector2(scale_x, scale_y)
	node.offset_transform_position = Vector2(0.0, translate_y)
	node.offset_transform_rotation = deg_to_rad(rotation_degrees)


## Transformation visuelle complète (décalage x/y, échelle, rotation en degrés) autour du centre : sert aux
## chorégraphies de transition de page.
static func transform_visual(node: Control, offset: Vector2, scale: Vector2, rotation_degrees: float = 0.0) -> void:
	if not node.offset_transform_enabled:
		node.offset_transform_enabled = true
		node.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		node.offset_transform_visual_only = true
	node.offset_transform_scale = scale
	node.offset_transform_position = offset
	node.offset_transform_rotation = deg_to_rad(rotation_degrees)


## Comme `jelly`, mais autour du bas-centre du contrôle (carrousel : les cartes voisines reculent en s'inclinant).
static func tilt_from_bottom(node: Control, scale_factor: float, rotation_degrees: float, translate_y: float) -> void:
	if not node.offset_transform_enabled:
		node.offset_transform_enabled = true
		node.offset_transform_pivot_ratio = Vector2(0.5, 1.0)
		node.offset_transform_visual_only = true
	node.offset_transform_scale = Vector2(scale_factor, scale_factor)
	node.offset_transform_position = Vector2(0.0, translate_y)
	node.offset_transform_rotation = deg_to_rad(rotation_degrees)


## Marge d'un bouton avec la zone sûre : la marge actuelle de l'écran, relevée à Wg.EDGE_GAP si elle était plus petite.
static func edge(current: float) -> int:
	return int(ceilf(maxf(current, Wg.EDGE_GAP)))


## Calcule la hauteur sûre en haut/bas (encoches, barres système) en unités de la fenêtre de référence.
static func safe_insets(viewport: Viewport) -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var visible := viewport.get_visible_rect().size
	var factor := Vector2(visible.x / window_size.x, visible.y / window_size.y)
	var screen := Vector2(DisplayServer.screen_get_size())
	var left := maxf(0.0, float(safe.position.x)) * factor.x
	var top := maxf(0.0, float(safe.position.y)) * factor.y
	var right := maxf(0.0, screen.x - float(safe.end.x)) * factor.x
	var bottom := maxf(0.0, screen.y - float(safe.end.y)) * factor.y
	return Vector4(left, top, right, bottom)
