class_name TutorialHand
extends RefCounted
## Le gant blanc des tutoriels (même image que l'écran de chargement : assets/ui/tutorial-hand.png). Dessin partagé :
## `TutorialHand.draw(canvas, bout_du_doigt, appui, largeur)` depuis le `_draw` d'un contrôle. Le bout du doigt est le point
## visé ; en appuyant, le gant rétrécit autour de ce point, avec une ombre portée.

const TEXTURE_PATH := "res://assets/ui/tutorial-hand.png"
## Point de contact du doigt dans l'image (pixels de l'image de 512 × 409).
const TIP := Vector2(66.0, 30.0)
const TEXTURE_SIZE := Vector2(512.0, 409.0)

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null and ResourceLoader.exists(TEXTURE_PATH):
		_texture = load(TEXTURE_PATH)
	return _texture


## `press` : 0 = gant levé, 1 = doigt posé (le gant rétrécit de 14 %).
static func draw(canvas: CanvasItem, tip: Vector2, press: float = 0.0, width: float = 96.0) -> void:
	var tex := texture()
	if tex == null:
		return
	var k := width / TEXTURE_SIZE.x
	var scale := 1.0 - 0.14 * clampf(press, 0.0, 1.0)
	var rect := Rect2(-TIP * k, TEXTURE_SIZE * k)
	canvas.draw_set_transform(tip + Vector2(7.0, 10.0) * scale, 0.0, Vector2(scale, scale))
	canvas.draw_texture_rect(tex, rect, false, Color(Wg.SHADOW, Wg.SHADOW.a * 0.9))
	canvas.draw_set_transform(tip, 0.0, Vector2(scale, scale))
	canvas.draw_texture_rect(tex, rect, false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Anneau de contact sous le doigt (visible pendant l'appui).
static func draw_touch(canvas: CanvasItem, tip: Vector2, press: float, radius: float) -> void:
	if press <= 0.01:
		return
	canvas.draw_arc(tip, radius * (1.0 + 0.35 * (1.0 - press)), 0.0, TAU, 40, Color(1, 1, 1, 0.85 * press), 3.0, true)
