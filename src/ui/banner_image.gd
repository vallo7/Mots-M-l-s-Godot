class_name BannerImage
extends Control
## Bannière de titre des popups : image 3D (rouge, jaune ou bleue) avec le titre posé sur la bande centrale.
## L'image garde ses proportions (centrée dans la place disponible) ; le titre rétrécit pour tenir sur la bande, jamais d'ellipse.
## Couleurs : bleu = réglages, langue, crédits ; jaune = trophées ; rouge = victoire et confirmations.

const TEXTURES := {
	"red": "res://assets/ui/banners/banner_red.png",
	"yellow": "res://assets/ui/banners/banner_yellow.png",
	"blue": "res://assets/ui/banners/banner_blue.png",
}
## Anciens noms de rubans -> bannière la plus proche.
const ALIASES := {"pink": "red", "purple": "blue", "green": "blue", "orange": "yellow"}
## Zone de lecture (la bande de face), en fractions de l'image : gauche, haut, largeur, hauteur.
const FACE := Rect2(0.14, 0.10, 0.72, 0.56)
const MIN_FONT := 13

var _texture: Texture2D
var _label: Label
var _base_size := 22


static func resolve(ribbon: String) -> String:
	var name: String = ALIASES.get(ribbon, ribbon)
	return name if TEXTURES.has(name) else "blue"


static func create(text: String, ribbon: String, height: float = 58.0) -> BannerImage:
	var banner := BannerImage.new()
	var color := resolve(ribbon)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.custom_minimum_size = Vector2(0.0, height)
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var path: String = TEXTURES[color]
	banner._texture = load(path) if ResourceLoader.exists(path) else null
	var dark_text := color == "yellow"
	var label := Wg.label(text, 22.0, Wg.Weight.BLACK, Color8(0x5A, 0x32, 0x00) if dark_text else Wg.WHITE)
	var shadow: Color = Color(1.0, 0.94, 0.62, 0.8) if dark_text else (Color8(0x9A, 0x14, 0x14) if color == "red" else Color8(0x0B, 0x5C, 0xA8))
	label.add_theme_color_override("font_shadow_color", shadow)
	label.add_theme_constant_override("shadow_offset_y", 2 if dark_text else 3)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner._label = label
	banner._base_size = int(round(22.0 * Wg.text_scale))
	banner.add_child(label)
	banner.resized.connect(banner._layout)
	return banner


func get_title() -> String:
	return _label.text if _label != null else ""


## Rectangle occupé par l'image : proportions conservées, centrée en largeur, calée en haut.
func image_rect() -> Rect2:
	if _texture == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var texture_size := _texture.get_size()
	var scale := minf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn := texture_size * scale
	return Rect2(Vector2((size.x - drawn.x) * 0.5, 0.0), drawn)


func _layout() -> void:
	if _label == null:
		return
	var image := image_rect()
	_label.position = image.position + Vector2(image.size.x * FACE.position.x, image.size.y * FACE.position.y)
	_label.size = Vector2(image.size.x * FACE.size.x, image.size.y * FACE.size.y)
	_fit_text()
	queue_redraw()


func _fit_text() -> void:
	if _label == null or _label.size.x <= 0.0:
		return
	var font := _label.get_theme_font("font")
	var chosen := _base_size
	while chosen > MIN_FONT and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > _label.size.x:
		chosen -= 1
	_label.add_theme_font_size_override("font_size", chosen)


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, image_rect(), false)
