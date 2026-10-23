extends ShotBase


func run() -> void:
	var r := root()
	white_background(r)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0
	column.offset_right = -24.0
	column.offset_top = 40.0
	column.add_theme_constant_override("separation", 14)
	r.add_child(column)
	column.add_child(WgButton.create("Jouer", WgButton.Kind.PRIMARY, "ic_play"))
	column.add_child(WgButton.create("Réglages", WgButton.Kind.SECONDARY))
	column.add_child(WgButton.create("Supprimer", WgButton.Kind.DANGER))
	column.add_child(WgButton.create("Plus tard", WgButton.Kind.GHOST))
	var disabled := WgButton.create("Verrouillé", WgButton.Kind.PRIMARY)
	disabled.enabled = false
	column.add_child(disabled)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	row.add_child(RingButton.create("ic_back", "Retour"))
	row.add_child(RingButton.create("ic_settings", "Réglages", Wg.TEAL, Wg.TEAL_DARK))
	row.add_child(RingButton.create("ic_close", "Fermer", Wg.PINK, Wg.PINK_DARK))
	row.add_child(RingButton.create("ic_home", "Accueil"))
	row.add_child(RingButton.create("ic_play", "Suivant", Wg.GREEN, Wg.GREEN_DARK))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	column.add_child(icons)
	for n in ["ic_bulb", "ic_trophy", "ic_star", "ic_star_off", "ic_crown", "ic_clock", "ic_check_green", "ic_ad_badge"]:
		icons.add_child(UiKit.icon(n, 34.0))
	column.add_child(Wg.label("Mots Mêlés — 1:23", 22.0, Wg.Weight.BLACK, Wg.INK))
	await save("buttons")
