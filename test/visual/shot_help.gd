extends ShotBase
## Page d'aide : haut de page, puis défilement jusqu'en bas ; en clair et en sombre.


func run() -> void:
	for dark in [false, true]:
		Wg.apply_theme(dark)
		var bg := white_background(root())
		var screen := HelpScreen.create()
		root().add_child(screen)
		await wait(0.9)
		await save("help_%s_top" % ("dark" if dark else "light"))
		var scroll: ScrollContainer = screen._scroll
		scroll.scroll_vertical = 700
		await wait(0.3)
		await save("help_%s_mid" % ("dark" if dark else "light"))
		scroll.scroll_vertical = 100000
		await wait(0.3)
		await save("help_%s_end" % ("dark" if dark else "light"))
		screen.queue_free()
		bg.queue_free()
		await frames(2)
