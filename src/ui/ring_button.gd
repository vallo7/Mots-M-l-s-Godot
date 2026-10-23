class_name RingButton
extends BubbleButton
## Bouton rond cerclé de blanc : disque blanc + bulle colorée parfaitement ronde (lèvre foncée en dessous).
## Même design pour tous les boutons ronds : retour, recommencer, réglages, fermer, niveaux, accueil, suivant…
## `diameter` : diamètre total, anneau compris (48 dp par défaut = zone tactile minimale ; 60 à 76 sur l'écran de victoire).


static func create(
	icon_name: String, description_text: String, face: Color = Wg.PURPLE, dark: Color = Wg.PURPLE_DARK,
	diameter: float = Wg.MIN_TOUCH, tint: Color = Wg.WHITE
) -> RingButton:
	var button := RingButton.new()
	button.ringed = true
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.corner_radius = Wg.R_PILL
	button.face_color = face
	button.dark_color = dark
	button.description = description_text
	button.haptic = HapticEffect.CONFIRM if diameter >= 56.0 else HapticEffect.SELECTION
	var face_diameter := diameter - RING * 2.0 - Wg.LIP
	button.content().add_child(UiKit.centered(UiKit.icon(icon_name, face_diameter * 0.52, tint)))
	return button


## Face ronde : son diamètre laisse la place de la lèvre dans l'anneau.
func _face_rect() -> Rect2:
	var base := _visual_rect()
	var diameter := minf(base.size.x, base.size.y - Wg.LIP)
	var shift := maxf(press(), 0.0) * Wg.LIP
	return Rect2(Vector2(base.position.x + (base.size.x - diameter) * 0.5, base.position.y + shift), Vector2(diameter, diameter))


func _lip_rect() -> Rect2:
	var face := _face_rect()
	var shift := maxf(press(), 0.0) * Wg.LIP
	return Rect2(face.position + Vector2(0.0, Wg.LIP - shift), face.size)
