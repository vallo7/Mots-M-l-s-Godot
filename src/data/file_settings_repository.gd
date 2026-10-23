class_name FileSettingsRepository
extends SettingsRepository
## Réglages : fichier JSON (écritures atomiques). Un fichier illisible est remplacé par les valeurs par défaut.

var _path: String
var _settings: AppSettings
var _last_text: String = ""


func _init(path: String) -> void:
	_path = path
	_settings = _load()
	_last_text = SettingsJson.encode(_settings)


func read() -> AppSettings:
	return _settings


## Renvoie les nouveaux réglages, ou null si l'écriture a échoué (réglages en mémoire inchangés).
func update(transform: Callable) -> AppSettings:
	var next: AppSettings = transform.call(_settings)
	var text := SettingsJson.encode(next)
	if text != _last_text:
		if not AtomicFile.write_text(_path, text):
			push_warning("Écriture des réglages impossible : %s" % _path)
			return null
		_last_text = text
	_settings = next
	return next


func _load() -> AppSettings:
	if not FileAccess.file_exists(_path):
		return AppSettings.new()
	var decoded := SettingsJson.decode(AtomicFile.read_text(_path))
	return decoded.value if decoded.ok else AppSettings.new()
