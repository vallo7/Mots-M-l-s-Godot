class_name AssetLevelRepository
extends LevelRepository
## Niveaux embarqués : res://data/levels (aucun accès réseau).

const DIRECTORY := "res://data/levels/"


func load_catalog() -> LevelCatalog:
	var decoded := LevelJsonParser.parse_catalog(func(file_name: String) -> String:
		var path := DIRECTORY + file_name
		return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	if not decoded.ok:
		push_error("Niveaux illisibles : %s" % decoded.error)
		return null
	return decoded.value
