extends ShotBase
## Écran de chargement : les trois démonstrations du gant à plusieurs instants de la boucle, en français puis en anglais.


func run() -> void:
	for lang in [Language.FR, Language.EN]:
		App.settings.language = lang
		for scenario in range(LoadingDemo.SCENARIO_COUNT):
			var bg := white_background(root())
			var screen := LoadingScreen.create(scenario)
			root().add_child(screen)
			var elapsed := 0.0
			for stamp in [0.9, 1.7, 2.6, 3.3]:
				await wait(stamp - elapsed)
				elapsed = stamp
				await save("load_%s_%d_%02d" % [Language.code(lang), scenario, int(stamp * 10)])
			screen.queue_free()
			bg.queue_free()
			await frames(2)
