class_name PraiseMap
extends RefCounted
## Lecture de assets/audio/praise/praise_map.json. `resolve` renvoie null quand aucun fichier n'est
## déclaré pour la langue : l'appelant joue alors le son de réussite générique.

const DIRECTORY := "res://assets/audio/praise"
const FILE := DIRECTORY + "/praise_map.json"

var _voices: Dictionary = {}  ## langue (int) -> { praise (int) -> PraiseVoice }


## Table vide : toute voix manquante retombe sur le son de réussite générique.
static func empty() -> PraiseMap:
	return PraiseMap.new()


## null si le JSON est invalide.
static func parse(json_text: String) -> PraiseMap:
	var root: Variant = JsonUtil.parse_object(json_text)
	if root == null or not (root.get("voices") is Dictionary):
		return null
	var map := PraiseMap.new()
	for language in Language.ALL:
		var entries := {}
		var block: Variant = root["voices"].get(Language.code(language))
		if block is Dictionary:
			for key in block:
				var praise := Praise.from_key(String(key))
				var entry: Variant = block[key]
				if praise == Praise.NONE or not (entry is Dictionary):
					continue
				entries[praise] = PraiseVoice.new(
					"%s/%s" % [DIRECTORY, JsonUtil.get_string(entry, "file")],
					clampf(float(entry.get("volume", 1.0)), 0.0, 1.0)
				)
		map._voices[language] = entries
	return map


func resolve(praise: int, language: int) -> PraiseVoice:
	var entries: Dictionary = _voices.get(language, {})
	return entries.get(praise, null)


## Chemins de ressources attendus, utiles au préchargement et aux vérifications.
func all_asset_paths() -> Array[String]:
	var result: Array[String] = []
	for language in _voices:
		for praise in _voices[language]:
			var path: String = _voices[language][praise].asset_path
			if not result.has(path):
				result.append(path)
	return result
