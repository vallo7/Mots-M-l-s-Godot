extends ShotBase
## Les cinq cartes de chapitre sur l'accueil (clair), l'accueil en sombre, et l'écran des niveaux de chaque chapitre.


func run() -> void:
	App.startup_minimum_ms = 600
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(1)
	await wait(1.6)
	# Chapitres 1 et 2 presque terminés, pour voir des pourcentages
	for n in range(1, 11):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3 if n % 2 == 1 else 2, 40000, Praise.NICE))
	for n in range(1, 5):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c2-l%02d" % n, 3, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.progress_changed.emit()
	await wait(1.0)
	var pager: ChapterPager = main._screen._pager
	for page in range(10):
		pager.go_to(page)
		await wait(0.9)
		await save("ch_card_%d" % page)
	App.update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.dark_mode = true
		return n)
	await wait(1.2)
	pager = main._screen._pager  # l'accueil a été reconstruit : on reprend le nouveau carrousel
	pager.go_to(2)
	await wait(0.9)
	await save("ch_card_dark")
