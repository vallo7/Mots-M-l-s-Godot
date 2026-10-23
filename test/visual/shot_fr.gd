extends ShotBase
## Textes français les plus longs : accueil, réglages, liste de langues, défi du jour, aide, chargement.


func run() -> void:
	App.startup_minimum_ms = 600
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(1)
	await wait(1.2)
	App.set_language_choice(Language.FR)
	await wait(1.4)
	await save("fr_home")
	App.open_settings()
	await wait(1.0)
	await save("fr_settings")
	App.open_language()
	await wait(0.8)
	await save("fr_language")
	App.on_back()
	await wait(0.4)
	App.on_back()
	await wait(0.6)
	App.open_daily()
	await wait(1.2)
	await save("fr_daily")
	App.on_back()
	await wait(0.8)
	App.open_help()
	await wait(1.2)
	await save("fr_help")
