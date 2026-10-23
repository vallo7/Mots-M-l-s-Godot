extends ShotBase
## Vérifications de mise en page : français, texte agrandi, popups, transition de page capturée en cours de route.
## Usage : shot_runner.gd -- shot_checks   (tailles d'écran variées via --resolution).


func run() -> void:
	App.startup_minimum_ms = 300
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(0.8)
	var suffix := "%dx%d" % [root().size.x, root().size.y]
	# Français + texte agrandi
	App.update_settings(func(x: AppSettings) -> AppSettings:
		var n := x.copy()
		n.large_text = true
		return n)
	App.update_settings(func(x: AppSettings) -> AppSettings:
		var n := x.copy()
		n.language = Language.FR
		return n)
	await wait(0.8)
	await save("chk_home_fr_large_" + suffix)
	App.open_settings()
	await wait(0.9)
	await save("chk_settings_fr_large_" + suffix)
	App.on_back()
	await wait(0.6)
	# Transition capturée à mi-course (accueil → niveaux)
	App.open_monument()
	await wait(0.25)
	await save("chk_transition_" + suffix)
	await wait(0.9)
	await save("chk_monument_fr_large_" + suffix)
	App.on_back()
	await wait(1.0)
	# Retour à la normale, partie, popup « quitter »
	App.update_settings(func(x: AppSettings) -> AppSettings:
		var n := x.copy()
		n.large_text = false
		return n)
	await wait(0.6)
	App.play_current()  # niveau en cours (la progression de test persiste entre les captures)
	await wait(3.5)  # rendu logiciel lent : la transition (bornée à 1/30 s par image) dure plus longtemps qu'à 60 fps
	await save("chk_game_fr_" + suffix)
	# Une première interaction démarre la partie : « retour » demande alors confirmation.
	App.active_game.on_selection_start(Vector2i(0, 0))
	App.active_game.on_selection_end()
	await wait(0.3)
	App.on_back()
	await wait(1.5)
	await save("chk_quit_fr_" + suffix)
	# Indice sans solde : la publicité (simulée) se lance directement, sans popup.
	App.on_back()
	await wait(0.4)
	App.active_game.on_hint_requested()
	await wait(0.2)
	await save("chk_ad_launch_" + suffix)
	# Indice sans solde : la publicité se lance directement (aucun popup)
