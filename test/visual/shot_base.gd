class_name ShotBase
extends RefCounted
## Base des captures d'écran (vérification visuelle hors appareil, Xvfb + Vulkan logiciel).
## Chaque capture construit une interface dans `run()`, attend quelques images puis enregistre un PNG.

var tree: SceneTree
var out_dir := "/home/claude/shots"


func run() -> void:
	pass


func root() -> Window:
	return tree.root


func frames(count: int = 3) -> void:
	for i in range(count):
		await tree.process_frame


func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func save(file_name: String) -> void:
	await frames(2)
	var image := tree.root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, file_name])
	print("capture : %s (%s)" % [file_name, image.get_size()])


func white_background(parent: Node) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Wg.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg
