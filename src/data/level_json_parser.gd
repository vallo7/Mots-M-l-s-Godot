class_name LevelJsonParser
extends RefCounted
## Lecture des fichiers JSON du dossier data/levels (schéma versionné). Les fichiers sont fournis
## par `read_file` (Callable : nom relatif -> contenu texte, "" si introuvable).

const SUPPORTED_SCHEMA := 1


## Renvoie un Decoded dont `value` est un LevelCatalog.
static func parse_catalog(read_file: Callable) -> Decoded:
	var index_text: String = read_file.call("index.json")
	var index: Variant = JsonUtil.parse_object(index_text)
	if index == null:
		return Decoded.failure("index.json invalide ou introuvable")
	var schema_error := _check_schema(index, "index.json")
	if not schema_error.is_empty():
		return Decoded.failure(schema_error)
	var files: Variant = index.get("chapters", null)
	if not (files is Array) or (files as Array).is_empty():
		return Decoded.failure("index.json : liste de chapitres absente")
	var chapters: Array[Chapter] = []
	for file_name in files:
		var text: String = read_file.call(String(file_name))
		var obj: Variant = JsonUtil.parse_object(text)
		if obj == null:
			return Decoded.failure("%s invalide ou introuvable" % file_name)
		var chapter := _parse_chapter(obj, String(file_name))
		if not chapter.ok:
			return chapter
		chapters.append(chapter.value)
	return Decoded.success(LevelCatalog.new(chapters))


static func _check_schema(obj: Dictionary, file_name: String) -> String:
	var version := JsonUtil.get_int(obj, "schemaVersion", -1)
	if version != SUPPORTED_SCHEMA:
		return "%s : schemaVersion %d non supporté (attendu %d)" % [file_name, version, SUPPORTED_SCHEMA]
	return ""


static func _parse_chapter(obj: Dictionary, file_name: String) -> Decoded:
	var schema_error := _check_schema(obj, file_name)
	if not schema_error.is_empty():
		return Decoded.failure(schema_error)
	if not (obj.get("levels") is Array) or not (obj.get("theme") is Dictionary):
		return Decoded.failure("%s : chapitre incomplet" % file_name)
	var index := JsonUtil.get_int(obj, "index")
	var levels: Array[Level] = []
	for raw in obj["levels"]:
		var level := _parse_level(raw, index, file_name)
		if not level.ok:
			return level
		levels.append(level.value)
	return Decoded.success(Chapter.new(
		JsonUtil.get_string(obj, "id"), index, _text(obj["theme"]),
		JsonUtil.get_string(obj, "paletteKey"), levels
	))


static func _parse_level(obj: Variant, chapter_index: int, file_name: String) -> Decoded:
	if not (obj is Dictionary):
		return Decoded.failure("%s : niveau invalide" % file_name)
	var diff: Variant = obj.get("difficulty")
	var hints: Variant = obj.get("hints")
	var variants_raw: Variant = obj.get("variants")
	if not (diff is Dictionary) or not (hints is Dictionary) or not (variants_raw is Dictionary) or not (obj.get("theme") is Dictionary):
		return Decoded.failure("%s : niveau %s incomplet" % [file_name, JsonUtil.get_string(obj, "id", "?")])
	var style := VisualStyle.from_name(JsonUtil.get_string(obj, "visualStyle"))
	if style < 0:
		return Decoded.failure("%s : visualStyle inconnu" % file_name)
	var variants := {}
	for language in Language.ALL:
		var block: Variant = variants_raw.get(Language.code(language))
		if not (block is Dictionary):
			return Decoded.failure("%s : variante %s absente" % [file_name, Language.code(language)])
		var parsed := _parse_variant(language, block, file_name)
		if not parsed.ok:
			return parsed
		variants[language] = parsed.value
	var profile := DifficultyProfile.new(
		JsonUtil.get_int(diff, "tier"), float(diff.get("ambiguity", 0.0)), JsonUtil.get_int(diff, "score"), JsonUtil.get_int(diff, "decoys")
	)
	return Decoded.success(Level.new(
		JsonUtil.get_string(obj, "id"), chapter_index, JsonUtil.get_int(obj, "number"), _text(obj["theme"]),
		style, JsonUtil.get_int(obj, "gridSize"), profile, JsonUtil.get_int(hints, "maxPerLevel"), variants
	))


static func _parse_variant(language: int, obj: Dictionary, file_name: String) -> Decoded:
	if not (obj.get("grid") is Array) or not (obj.get("words") is Array):
		return Decoded.failure("%s : variante incomplète" % file_name)
	var grid := PackedStringArray(JsonUtil.string_array(obj["grid"]))
	var words: Array[TargetWord] = []
	for raw in obj["words"]:
		if not (raw is Dictionary):
			return Decoded.failure("%s : mot invalide" % file_name)
		var direction := Direction.from_name(JsonUtil.get_string(raw, "direction"))
		if direction < 0:
			return Decoded.failure("%s : direction inconnue" % file_name)
		words.append(TargetWord.new(
			JsonUtil.get_string(raw, "display"), JsonUtil.get_string(raw, "letters"),
			Vector2i(JsonUtil.get_int(raw, "col"), JsonUtil.get_int(raw, "row")), direction
		))
	return Decoded.success(LevelVariant.new(language, grid, words))


static func _text(obj: Dictionary) -> Dictionary:
	return {"fr": JsonUtil.get_string(obj, "fr"), "en": JsonUtil.get_string(obj, "en")}
