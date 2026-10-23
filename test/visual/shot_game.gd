extends ShotBase
## Écran de jeu réel (données réelles) : repos, tracé en cours, mot trouvé (effets), erreur.


func run() -> void:
	App.startup_minimum_ms = 0
	await App.start()
	# On avance dans le chapitre 1 pour obtenir une grille plus grande.
	var upto := int(OS.get_environment("WG_UPTO")) if OS.get_environment("WG_UPTO") != "" else 5
	for n in range(1, upto + 1):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.play_current()
	var controller := App.active_game
	var screen := GameScreen.create(controller)
	root().add_child(screen)
	await frames(6)
	await save("game_idle")

	var words := controller.level.variant(controller.language).words
	var w := words[0]
	# Tracé en cours : début + deux cases
	controller.on_selection_start(w.cells[0])
	await wait(0.1)
	var path: Array[Vector2i] = []
	for i in range(mini(w.cells.size(), 3)):
		path.append(w.cells[i])
	controller.on_selection_change(path)
	await wait(0.35)
	await save("game_tracing")
	var full: Array[Vector2i] = w.cells.duplicate()
	controller.on_selection_change(full)
	await wait(0.3)
	controller.on_selection_end()
	await wait(0.18)
	await save("game_found_fx")
	await wait(1.2)
	# Un mauvais tracé
	controller.on_selection_start(Vector2i(0, 0))
	var wrong: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	controller.on_selection_change(wrong)
	await wait(0.2)
	controller.on_selection_end()
	await wait(0.12)
	await save("game_wrong")
	await wait(1.0)
	controller.on_hint_requested()
	await wait(0.25)
	await save("game_hint")
