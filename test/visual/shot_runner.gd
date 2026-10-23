extends SceneTree
## Lanceur de captures d'écran. Ce script ne référence aucune classe du projet (il est compilé avant la
## création des autoloads) : la capture elle-même est chargée dynamiquement.
##   godot --path . -s res://test/visual/shot_runner.gd -- shot_buttons


func _initialize() -> void:
	root.content_scale_size = Vector2i(360, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot_name: String = args[0] if args.size() > 0 else "shot_buttons"
	var script: GDScript = load("res://test/visual/%s.gd" % shot_name)
	var shot = script.new()
	shot.tree = self
	await shot.run()
	quit()
