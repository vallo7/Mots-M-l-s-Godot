class_name ShotV140
extends ShotBase
## Captures de la 1.4.0 : tutoriel d'accueil (gant sur Jouer), liste des niveaux (titre en bas de l'illustration), redémarrage
## (rotation de la grille), bouton Indice au-dessus de la bannière, transition d'entrée en jeu.


func run() -> void:
	App.startup_minimum_ms = 600
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(3.2)  # le rendu logiciel est lent : on laisse finir le rideau d'ouverture
	# --- Première ouverture : le gant invite à toucher Jouer
	await save("v140_home_tuto_0")
	await wait(0.3)
	await save("v140_home_tuto_1")
	await wait(0.3)
	await save("v140_home_tuto_2")
	# --- Liste des niveaux
	App.progress_repository.update(func(s: ProgressState) -> ProgressState:
		return ProgressRules.complete_level(s, "c1-l01", 3, 30000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.progress_changed.emit()
	App.open_monument()
	await wait(1.6)
	await save("v140_monument")
	App.on_back()
	await wait(1.0)
	# --- Entrée en jeu : milieu de la transition (la page monte)
	App.open_chapter(1)
	await wait(0.28)
	await save("v140_enter_game_mid")
	await wait(3.2)
	await save("v140_game")
	var game: GameScreen = main._screen
	var controller := game.controller
	# --- Redémarrage : la grille tourne (droite)
	controller.turn_picker = func() -> int: return 1
	controller.on_restart_requested()
	await wait(0.12)
	await save("v140_restart_a")
	await wait(0.16)
	await save("v140_restart_b")
	await wait(0.2)
	await save("v140_restart_c")
	await wait(0.9)
	await save("v140_restart_done")
