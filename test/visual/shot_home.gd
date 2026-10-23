extends ShotBase
## Accueil, réglages, liste de langues et monument, en clair puis en sombre (scène principale réelle).


func run() -> void:
	App.startup_minimum_ms = 800
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(1.2)
	# Progression : chapitre 1 presque fini
	for n in range(1, 8):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3 if n % 2 == 1 else 2, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.progress_changed.emit()
	await wait(1.5)
	await save("home_light")
	App.open_settings()
	await wait(0.9)
	await save("settings_light")
	App.update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.dark_mode = true
		return n)
	await wait(0.35)
	await save("theme_reveal_mid")
	await wait(0.9)
	await save("settings_dark")
	App.open_language()
	await wait(0.8)
	await save("language_dark")
	App.on_back()
	await wait(0.5)
	App.on_back()
	await wait(0.8)
	await save("home_dark")
	App.open_monument()
	await wait(0.6)
	await save("monument_start_dark")
	await wait(2.2)
	await save("monument_unrolled_dark")
