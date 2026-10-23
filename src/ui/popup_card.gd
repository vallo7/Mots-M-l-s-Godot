class_name PopupCard
extends Control
## Carte de popup : ruban en titre à cheval sur le bord haut, bouton fermer rose dans le coin, contenu en colonne
## (`body`). Positionnée, dimensionnée et animée par PopupHost. `container_color` blanc par défaut (violet pour la victoire).
## Hauteur fixe autour du corps (marges + ruban) : voir CHROME_HEIGHT.

## Hauteur de la carte hors contenu du corps : marge du ruban (30) + marge haute (44) + marge basse (20).
const CHROME_HEIGHT := 94.0

signal close_pressed()

var body := VBoxContainer.new()
var _margin := MarginContainer.new()


static func create(title: String, ribbon: String, closable: bool = true, close_description: String = "", container_color: Color = Color(0, 0, 0, 0)) -> PopupCard:
	var card := PopupCard.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP  # un tap sur la carte ne ferme pas le popup
	card._margin.add_theme_constant_override("margin_top", 30)
	card._margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card._margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card._margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = container_color if container_color.a > 0.0 else Wg.SURFACE
	box.set_corner_radius_all(30)
	box.corner_detail = 14
	box.anti_aliasing = true
	box.shadow_color = Wg.SHADOW
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 6)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 44.0
	box.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", box)
	card._margin.add_child(panel)

	card.body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.body.add_theme_constant_override("separation", 0)
	panel.add_child(card.body)

	var ribbon_node := RibbonBanner.create(title, ribbon)
	ribbon_node.anchor_left = 0.07
	ribbon_node.anchor_right = 0.93
	ribbon_node.offset_bottom = 58.0
	card.add_child(ribbon_node)

	if closable:
		var close := RingButton.create("ic_close", close_description if not close_description.is_empty() else Strings.t("dialog_cancel"), Wg.PINK, Wg.PINK_DARK)
		close.sound = Sound.MENU_CHANGE
		close.anchor_left = 1.0
		close.anchor_right = 1.0
		close.offset_left = -48.0 + 10.0
		close.offset_right = 10.0
		close.offset_top = 16.0
		close.offset_bottom = 16.0 + 48.0
		close.activated.connect(func() -> void: card.close_pressed.emit())
		card.add_child(close)
	card._margin.minimum_size_changed.connect(card.update_minimum_size)
	return card


func _get_minimum_size() -> Vector2:
	return _margin.get_combined_minimum_size()


## Texte du corps (centré, 16 dp gras, encre).
func add_body_text(text: String) -> Label:
	var label := Wg.label(text, 16.0, Wg.Weight.BOLD, Wg.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	body.add_child(label)
	return label


func add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gap)
