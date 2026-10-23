class_name IrisWrap
extends Panel
## Masque circulaire : tout ce qui est posé dans `content` n'est visible qu'à l'intérieur d'un disque que l'on agrandit
## ou rétrécit (`set_circle`). `content` garde toujours la taille de l'écran et reste fixe par rapport à lui : le
## contenu ne bouge ni ne se redimensionne pendant que le disque change, seul le masque évolue. Aucun fondu.

var content := Control.new()
var _host_size: Vector2


func _init(host_size: Vector2) -> void:
	_host_size = host_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(4096)
	box.corner_detail = 32
	box.anti_aliasing = true
	add_theme_stylebox_override("panel", box)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = host_size
	add_child(content)


## Disque de centre `center` (coordonnées de l'écran) et de rayon `radius`.
func set_circle(center: Vector2, radius: float) -> void:
	var r := maxf(radius, 0.5)
	position = center - Vector2(r, r)
	size = Vector2(r, r) * 2.0
	content.position = -position
	content.size = _host_size


## Rayon qui couvre tout l'écran depuis `center`.
static func cover_radius(center: Vector2, host_size: Vector2) -> float:
	var far := Vector2(maxf(center.x, host_size.x - center.x), maxf(center.y, host_size.y - center.y))
	return far.length() + 4.0
