class_name ShotV130
extends ShotBase
## Captures de la 1.3.0 : tutoriel du niveau 1 (gant), cinématique de l'indice (niveau 4), bannières rouge / jaune / bleue.


func run() -> void:
	App.startup_minimum_ms = 0
	await App.start()
	root().content_scale_size = Vector2i(360, 800)
	# --- Niveau 1 : le gant montre le premier tracé
	App.play_current()
	var screen := GameScreen.create(App.active_game)
	root().add_child(screen)
	await frames(6)
	screen.on_entered()
	await wait(1.15)
	await save("v130_tuto_1_approach")
	await wait(0.55)
	await save("v130_tuto_2_press")
	await wait(0.9)
	await save("v130_tuto_3_drag")
	await wait(0.9)
	await save("v130_tuto_4_release")
	# Le joueur trouve le premier mot : le gant passe au tracé suivant
	var controller := App.active_game
	var words := controller.level.variant(controller.language).words
	controller.on_selection_start(words[0].cells[0])
	controller.on_selection_change(words[0].cells.duplicate())
	controller.on_selection_end()
	await wait(2.6)
	await save("v130_tuto_5_next_word")
	screen.queue_free()
	await frames(2)
	# --- Niveau 4 du chapitre 1 : cinématique de l'indice
	for n in range(1, 4):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.play_current()
	var screen4 := GameScreen.create(App.active_game)
	root().add_child(screen4)
	await frames(6)
	screen4.on_entered()
	await wait(1.3)
	await save("v130_hint_intro_a")
	await wait(0.32)
	await save("v130_hint_intro_b")
	await wait(0.2)
	await save("v130_hint_intro_c")
	print("balance after intro: ", App.progress_repository.read().hint_balance)
	screen4.queue_free()
	await frames(2)
	# --- Bannières jaune et rouge
	var bg := white_background(root())
	var card := PopupCard.create("Trophy title", "yellow", true, "Close")
	card.add_body_text("Yellow banner (trophies).")
	PopupHost.open(root(), card, true)
	await wait(0.6)
	await save("v130_banner_yellow")
	bg.queue_free()
