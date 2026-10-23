extends ShotBase
## Mesure de charge de la grille 12×12 pendant le pire moment visuel (mélange + mot trouvé + particules).
## Affiche, par image : temps de traitement des scripts (ms) et nombre d'appels de dessin. Le rendu logiciel de la
## machine de test n'est pas représentatif du GPU d'un téléphone ; les temps de SCRIPT et le nombre d'appels le sont.


func run() -> void:
	App.startup_minimum_ms = 0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root().add_child(main)
	while App.phase == App.Phase.LOADING:
		await frames(2)
	for n in range(1, 10):
		App.progress_repository.update(func(s: ProgressState) -> ProgressState:
			return ProgressRules.complete_level(s, "c1-l%02d" % n, 3, 40000, Praise.NICE))
	App.progress = App.progress_repository.read()
	App.play_current()  # niveau 10 : 12×12
	await wait(1.0)
	var controller := App.active_game
	var level := controller.level
	print("niveau %s, grille %dx%d" % [level.id, level.grid_size, level.grid_size])
	var words := level.variant(controller.language).words
	controller.on_restart_requested()
	var samples: Array[float] = []
	var draws: Array[int] = []
	for i in range(45):
		await tree.process_frame
		samples.append(_paint_ms())
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("mélange   : dessin script moyen %.2f ms, max %.2f ms ; appels de dessin moyen %d, max %d" % [_avg(samples), samples.max(), _avg_i(draws), draws.max()])
	await wait(1.2)
	samples.clear()
	draws.clear()
	var w := words[0]
	controller.on_selection_start(w.cells[0])
	controller.on_selection_change(w.cells.duplicate())
	controller.on_selection_end()
	for i in range(45):
		await tree.process_frame
		samples.append(_paint_ms())
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("mot trouvé: dessin script moyen %.2f ms, max %.2f ms ; appels de dessin moyen %d, max %d" % [_avg(samples), samples.max(), _avg_i(draws), draws.max()])
	await wait(2.0)
	samples.clear()
	draws.clear()
	for i in range(30):
		await tree.process_frame
		samples.append(_paint_ms())
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("repos     : dessin script moyen %.2f ms ; appels de dessin moyen %d" % [_avg(samples), _avg_i(draws)])


func _paint_ms() -> float:
	var grid := _find_grid(App.get_tree().root)
	return grid.last_paint_usec / 1000.0 if grid != null else 0.0


func _find_grid(node: Node) -> LetterGridView:
	if node is LetterGridView:
		return node
	for child in node.get_children():
		var found := _find_grid(child)
		if found != null:
			return found
	return null


func _avg(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(a.size(), 1)


func _avg_i(a: Array[int]) -> int:
	var t := 0
	for v in a:
		t += v
	return t / maxi(a.size(), 1)
