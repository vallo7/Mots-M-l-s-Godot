extends ShotBase
## Transitions en plein mouvement : rideau (chargement -> accueil), glissement (monument, aide), iris (jeu), montée (victoire).


func run() -> void:
	App.startup_minimum_ms = 600
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(1)
	await wait(0.22)
	await save("tr_curtain_a")
	await wait(0.14)
	await save("tr_curtain_b")
	await wait(1.4)
	App.open_help()
	await wait(0.2)
	await save("tr_slide_a")
	await wait(0.12)
	await save("tr_slide_b")
	await wait(1.2)
	App.on_back()
	await wait(1.0)
	App.open_level("c1-l01")
	await wait(0.26)
	await save("tr_iris_a")
	await wait(0.16)
	await save("tr_iris_b")
	await wait(1.5)
	var controller: GameController = App.active_game
	for word in controller.level.variant(App.language).words:
		controller.on_selection_start(word.cells[0])
		controller.on_selection_change(word.cells)
		controller.on_selection_end()
		await frames(3)
	await wait(0.9)
	await save("tr_rise_a")
	await wait(0.12)
	await save("tr_rise_b")
