class_name ConfirmPopup
extends RefCounted
## Popup de confirmation : ruban en titre, texte, deux boutons bulles.


## Renvoie l'hôte ; `on_confirm` / `on_dismiss` sont des Callables sans argument.
static func open(
	parent: Node, title: String, body: String, confirm_text: String, dismiss_text: String,
	on_confirm: Callable, on_dismiss: Callable, ribbon: String = "red"
) -> PopupHost:
	var card := PopupCard.create(title, ribbon)
	card.add_body_text(body)
	card.add_gap(18.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(Wg.SP_SM))
	var dismiss := WgButton.create(dismiss_text, WgButton.Kind.SECONDARY)
	dismiss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm := WgButton.create(confirm_text, WgButton.Kind.DANGER)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dismiss)
	row.add_child(confirm)
	card.body.add_child(row)
	var host := PopupHost.open(parent, card)
	dismiss.activated.connect(on_dismiss)
	confirm.activated.connect(on_confirm)
	card.close_pressed.connect(on_dismiss)
	host.dismissed.connect(on_dismiss)
	return host
