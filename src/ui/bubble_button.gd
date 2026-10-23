class_name BubbleButton
extends JuicyPressable
## Bouton « bulle » : face colorée plate + lèvre foncée qui s'écrase à l'appui. Aucun reflet.
## Avec `ringed`, la bulle est cerclée de blanc (anneau + ombre douce), comme les boutons de l'écran de victoire :
## c'est le style de tous les boutons d'action (retour, recommencer, réglages, fermer, niveaux, indice, jouer…).
## `content()` est le conteneur des éléments posés sur la face : il suit l'écrasement de la lèvre.

## Épaisseur de l'anneau blanc (dp).
const RING := 4.0

var face_color: Color = Wg.PURPLE:
	set(value):
		face_color = value
		queue_redraw()
var dark_color: Color = Wg.PURPLE_DARK:
	set(value):
		dark_color = value
		queue_redraw()
var corner_radius: float = Wg.R_MD:
	set(value):
		corner_radius = value
		queue_redraw()
## Anneau blanc autour de la bulle.
var ringed := false:
	set(value):
		ringed = value
		_update_content()
		update_minimum_size()
		queue_redraw()
## Taille visuelle (lèvre comprise) centrée dans le contrôle ; ZERO : le contrôle entier.
var visual_size := Vector2.ZERO:
	set(value):
		visual_size = value
		_update_content()
		queue_redraw()

var _content := Control.new()


func _init() -> void:
	super._init()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.clip_contents = false
	add_child(_content)
	resized.connect(_update_content)


func content() -> Control:
	return _content


## Rectangle de l'objet entier (anneau compris).
func _outer_rect() -> Rect2:
	if visual_size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, size)
	return Rect2((size - visual_size) * 0.5, visual_size)


## Rectangle de la bulle colorée, lèvre comprise (à l'intérieur de l'anneau s'il y en a un).
func _visual_rect() -> Rect2:
	var outer := _outer_rect()
	return outer.grow(-RING) if ringed else outer


func _lip_rect() -> Rect2:
	var base := _visual_rect()
	return Rect2(base.position + Vector2(0.0, Wg.LIP), Vector2(base.size.x, base.size.y - Wg.LIP))


func _face_rect() -> Rect2:
	var base := _visual_rect()
	var shift := maxf(press(), 0.0) * Wg.LIP
	return Rect2(base.position + Vector2(0.0, shift), Vector2(base.size.x, base.size.y - Wg.LIP))


func _update_content() -> void:
	var face := _face_rect()
	_content.position = face.position
	_content.size = face.size


func _on_press_changed() -> void:
	_update_content()


## Anneau blanc et ombre douce portée (élévation d'environ 5 dp).
func _draw_ring() -> void:
	var outer := _outer_rect()
	var radius := minf(outer.size.x, outer.size.y) * 0.5 if corner_radius >= Wg.R_PILL else corner_radius + RING
	for i in range(5):
		var spread := 6.0 - i * 1.2
		var shadow := Rect2(outer.position + Vector2(0.0, 3.0 + i * 0.4), outer.size).grow(spread * 0.5)
		Wg.rrect(self, shadow, Color(Wg.SHADOW, Wg.SHADOW.a * 0.175), radius + spread * 0.5)
	Wg.rrect(self, outer, Wg.SURFACE, radius)


func _draw() -> void:
	if ringed:
		_draw_ring()
	Wg.rrect(self, _lip_rect(), dark_color, corner_radius)
	Wg.rrect(self, _face_rect(), face_color, corner_radius)
	_draw_focus_ring(_outer_rect(), minf(_outer_rect().size.y * 0.5, corner_radius + (RING if ringed else 0.0)))
