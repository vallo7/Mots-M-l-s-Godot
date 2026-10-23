extends ShotBase
## Publicités de test simulées : bannière dans le jeu, annonce récompensée (compte à rebours, récupération), solde d'indices.


func run() -> void:
	App.startup_minimum_ms = 800
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	await wait(1.5)
	print("fournisseur : ", App.ads.get_class(), " ", App.ads.get_script().get_global_name(), " ads_enabled=", App.ads_enabled)
	App.progress_repository.update(func(s: ProgressState) -> ProgressState:
		var n := s.copy()
		n.hint_balance = 0
		return n)
	App.progress = App.progress_repository.read()
	App.open_level("c1-l01")
	await wait(1.4)
	await save("ads_game_banner")
	var controller: GameController = App.active_game
	controller.on_hint_requested()
	await wait(1.6)
	await save("ads_rewarded_counting")
	await wait(5.0)
	await save("ads_rewarded_done")
	var balance_before := App.progress.hint_balance
	# Appui sur « Récupérer » : on simule le bouton
	var layer: CanvasLayer = null
	for child in root().get_children():
		if child is CanvasLayer and child.layer == 100:
			layer = child
	if layer != null:
		var overlay = layer.get_child(0)
		overlay._claim.activated.emit()
	await wait(1.0)
	App.progress = App.progress_repository.read()
	print("indices avant=", balance_before, " après=", App.progress.hint_balance)
	await save("ads_after_reward")
