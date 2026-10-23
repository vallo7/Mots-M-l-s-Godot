extends SceneTree
## Charge tous les scripts GDScript du projet (src/, scenes/, test/) et échoue si l'un d'eux ne compile pas.
## Usage : godot --headless --path . -s res://scripts/check_scripts.gd


func _initialize() -> void:
	var failures := 0
	var total := 0
	for root in ["res://src", "res://scenes", "res://test"]:
		for path in _gd_files(root):
			if _skip(path):
				continue
			total += 1
			var script: Resource = load(path)
			if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
				printerr("ÉCHEC  ", path)
				failures += 1
	print("%d scripts vérifiés, %d en échec" % [total, failures])
	quit.call_deferred(1 if failures > 0 else 0)


func _gd_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for sub in dir.get_directories():
		result.append_array(_gd_files(dir_path.path_join(sub)))
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			result.append(dir_path.path_join(file_name))
	return result


func _skip(path: String) -> bool:
	# Les fichiers admob_* de src/ads dépendent du plugin AdMob (addons/admob) : vérifiés seulement s'il est installé
	# (la CI l'installe : scripts/ci/install_admob.sh). Le fournisseur simulé, lui, est toujours vérifié.
	return path.begins_with("res://src/ads/admob_") and not FileAccess.file_exists("res://addons/admob/plugin.cfg")
