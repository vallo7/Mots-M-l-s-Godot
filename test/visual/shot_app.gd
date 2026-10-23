extends ShotBase
## Parcours complet de l'application (scène principale réelle) : chargement, accueil, monument, réglages, crédits, victoire.


func run() -> void:
	App.startup_minimum_ms = 1500
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	await wait(0.6)
	await save("app_loading")
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(1.0)
	await save("app_home")
	App.open_monument()
	await wait(0.9)
	await save("app_monument")
	App.on_back()
	await wait(0.9)
	App.open_settings()
	await wait(0.8)
	await save("app_settings")
	App.open_credits()
	await wait(0.8)
	await save("app_credits")
	App.on_back()
	await wait(0.4)
	App.on_back()
	await wait(0.6)
	# Victoire (niveau 10 du chapitre 1 terminé)
	for n in range(1, 11):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	var result := VictoryResult.new()
	result.level_id = "c1-l10"
	result.chapter_index = 1
	result.stars = 3
	result.elapsed_millis = 52000
	result.praise = Praise.LEGENDARY
	result.chapter_completed = true
	result.gift_claimable = true
	result.next_level_id = "c2-l01"
	result.chapter_completed_before = 9
	result.chapter_completed_after = 10
	result.chapter_total = 10
	App._on_victory(result)
	await wait(1.4)
	await save("app_result_mid")
	await wait(4.0)
	await save("app_result_end")
	App.go_home()
	await wait(1.0)
	await save("app_home_gift")
