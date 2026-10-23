class_name Icons
extends RefCounted
## Icônes et illustrations : images PNG détourées (étoile, trophées, cadeau, pièce-couronne) et SVG importés à haute
## résolution (le reste). Jamais teintées sauf demande explicite.

const _FOLDERS: Array[String] = ["res://assets/icons", "res://assets/illustrations"]
const _EXTENSIONS: Array[String] = ["png", "svg"]

static var _cache: Dictionary = {}


static func get_icon(icon_name: String) -> Texture2D:
	if not _cache.has(icon_name):
		_cache[icon_name] = load(_path_of(icon_name))
	return _cache[icon_name]


## Chemin de la ressource `icon_name` (PNG d'abord, puis SVG ; icônes avant illustrations).
static func _path_of(icon_name: String) -> String:
	for folder in _FOLDERS:
		for extension in _EXTENSIONS:
			var path := "%s/%s.%s" % [folder, icon_name, extension]
			if ResourceLoader.exists(path):
				return path
	return "%s/%s.svg" % [_FOLDERS[0], icon_name]


static func clear_cache() -> void:
	_cache.clear()


## Précharge toutes les icônes (étape de l'écran de chargement).
static func preload_all() -> void:
	for dir_path in _FOLDERS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if file_name.ends_with(".svg") or file_name.ends_with(".png"):
				get_icon(file_name.get_basename())
