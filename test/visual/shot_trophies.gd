extends ShotBase
## Trophées : bouton de l'accueil, bandeau de déblocage, grille à trois colonnes, fiches (verrouillé / débloqué), mode sombre.


func run() -> void:
	App.startup_minimum_ms = 800
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(1.2)
	await save("tr_home_empty")
	# Progression : douze niveaux (la plupart en 3 étoiles) + quelques compteurs
	for n in range(1, 13):
		var id := "c1-l%02d" % n if n <= 10 else "c2-l%02d" % (n - 10)
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, id, 3 if n % 3 != 0 else 2, 40000, Praise.NICE))
	App.progress_repository.update(func(s: ProgressState) -> ProgressState:
		return TrophyRules.record_hint(s))
	App.progress_repository.update(func(s: ProgressState) -> ProgressState:
		var n := s.copy()
		n.stats[TrophyRules.FLAWLESS_LEVELS] = 3
		return n)
	App._use_cases.sync_trophies()
	App._refresh_progress()
	await wait(1.9)
	await save("tr_toast")
	await wait(9.0)
	await save("tr_home_progress")
	App.open_trophies()
	await wait(1.4)
	await save("tr_screen")
	var screen := _find_screen(main)
	if screen != null:
		screen._scroll.scroll_vertical = 2000
		await wait(0.4)
		await save("tr_screen_bottom")
		screen._scroll.scroll_vertical = 0
		screen._open_detail("flawless_five")
		await wait(0.9)
		await save("tr_detail_locked")
		for host in screen.get_children():
			if host is PopupHost:
				(host as PopupHost).close_now()
		screen._open_detail("first_steps")
		await wait(0.9)
		await save("tr_detail_unlocked")
		for host in screen.get_children():
			if host is PopupHost:
				(host as PopupHost).close_now()
	App.update_settings(func(s: AppSettings) -> AppSettings:
		var n := s.copy()
		n.dark_mode = true
		return n)
	await wait(1.4)
	await save("tr_screen_dark")


func _find_screen(node: Node) -> TrophiesScreen:
	if node is TrophiesScreen:
		return node
	for child in node.get_children():
		var found := _find_screen(child)
		if found != null:
			return found
	return null
