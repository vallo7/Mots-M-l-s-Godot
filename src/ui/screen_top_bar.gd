class_name ScreenTopBar
extends HBoxContainer
## Barre de titre des écrans secondaires : retour à gauche, titre centré.

signal back_pressed()


static func create(title: String) -> ScreenTopBar:
	var bar := ScreenTopBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 0)
	var back := RingButton.create("ic_back", Strings.t("cd_back"))
	back.sound = Sound.MENU_CHANGE
	back.activated.connect(func() -> void: bar.back_pressed.emit())
	bar.add_child(back)
	var label := Wg.label(title, 22.0, Wg.Weight.BLACK, Wg.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(Wg.MIN_TOUCH, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	return bar
