extends ShotBase
## Défi du jour : bannière d'accueil, page du défi, partie, victoire (détail des récompenses), page « terminé ».


func run() -> void:
	App.startup_minimum_ms = 800
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(2.0)
	await save("daily_home")
	App.open_daily()
	await wait(1.2)
	await save("daily_page_top")
	var scroll: ScrollContainer = main._screen._scroll
	scroll.scroll_vertical = 520
	await wait(0.3)
	await save("daily_page_mid")
	scroll.scroll_vertical = 100000
	await wait(0.3)
	await save("daily_page_end")
	App.play_daily()
	await wait(1.3)
	await save("daily_game")
	var controller: GameController = App.active_game
	for word in controller.level.variant(App.language).words:
		controller.on_selection_start(word.cells[0])
		controller.on_selection_change(word.cells)
		controller.on_selection_end()
		await frames(4)
	await wait(3.5)
	await save("daily_result")
	App.go_daily()
	await wait(1.2)
	await save("daily_done")
	App.go_home()
	await wait(1.0)
	await save("daily_home_done")
