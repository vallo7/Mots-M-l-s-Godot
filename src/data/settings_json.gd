class_name SettingsJson
extends RefCounted
## Sérialisation des réglages.

const SCHEMA := 1


static func encode(s: AppSettings) -> String:
	var json := {
		"schemaVersion": SCHEMA,
		"sound": s.sound_enabled,
		"sfxVolume": snappedf(s.sfx_volume, 0.01),
		"music": s.music_enabled,
		"musicVolume": snappedf(s.music_volume, 0.01),
		"haptics": s.haptics_enabled,
		"reduceMotion": s.reduce_motion,
		"largeText": s.large_text,
		"darkMode": s.dark_mode,
	}
	if s.language != AppSettings.NONE:
		json["language"] = Language.code(s.language)
	return JSON.stringify(json, "", true)


## Renvoie un Decoded dont `value` est un AppSettings.
static func decode(text: String) -> Decoded:
	var parsed: Variant = JsonUtil.parse_object(text)
	if parsed == null:
		return Decoded.failure("JSON de réglages invalide")
	var json: Dictionary = parsed
	var version := JsonUtil.get_int(json, "schemaVersion", -1)
	if version != SCHEMA:
		return Decoded.failure("réglages : schemaVersion %d non supporté" % version)
	var s := AppSettings.new()
	var code := JsonUtil.get_string(json, "language")
	s.language = AppSettings.NONE if code.is_empty() else Language.from_code(code)
	# Ancien format : un simple interrupteur « sound ». Le volume prime quand il est présent.
	if json.has("sfxVolume") and (json["sfxVolume"] is float or json["sfxVolume"] is int):
		s.sfx_volume = clampf(float(json["sfxVolume"]), 0.0, 1.0)
	else:
		s.sound_enabled = JsonUtil.get_bool(json, "sound", true)
	# Ancien format : un simple interrupteur « music ». Le volume prime quand il est présent.
	if json.has("musicVolume"):
		s.music_volume = clampf(float(json["musicVolume"]) if (json["musicVolume"] is float or json["musicVolume"] is int) else AppSettings.DEFAULT_MUSIC_VOLUME, 0.0, 1.0)
	else:
		s.music_enabled = JsonUtil.get_bool(json, "music", true)
	s.haptics_enabled = JsonUtil.get_bool(json, "haptics", true)
	s.reduce_motion = JsonUtil.get_bool(json, "reduceMotion", false)
	s.large_text = JsonUtil.get_bool(json, "largeText", false)
	s.dark_mode = JsonUtil.get_bool(json, "darkMode", false)
	return Decoded.success(s)
