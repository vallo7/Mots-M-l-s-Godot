class_name FileProgressRepository
extends ProgressRepository
## Progression : fichier JSON (écritures atomiques) + copie de secours `.bak` du dernier état valide.
## Un fichier corrompu est conservé en `.corrupt` puis remplacé par la copie de secours (ou l'état initial).
## L'état est gardé en mémoire : chaque `update` est lecture-transformation-écriture, sans relecture disque.

var _path: String
var _state: ProgressState
var _last_text: String = ""


func _init(path: String) -> void:
	_path = path
	_state = _load()
	_last_text = ProgressJson.encode(_state)


func read() -> ProgressState:
	return _state


## Renvoie le nouvel état, ou null si l'écriture a échoué (l'état en mémoire est alors inchangé).
func update(transform: Callable) -> ProgressState:
	var next: ProgressState = transform.call(_state)
	var text := ProgressJson.encode(next)
	if text == _last_text:
		_state = next
		return next
	if not AtomicFile.write_text(_path, text):
		push_warning("Écriture de la progression impossible : %s" % _path)
		return null
	AtomicFile.write_text(_path + ".bak", text)  # échec toléré : la copie de secours est un bonus
	_state = next
	_last_text = text
	return next


func _load() -> ProgressState:
	if not FileAccess.file_exists(_path):
		return ProgressState.new()
	var decoded := ProgressJson.decode(AtomicFile.read_text(_path))
	if decoded.ok:
		return decoded.value
	push_warning("Progression illisible (%s) : %s" % [_path, decoded.error])
	AtomicFile.copy_file(_path, _path + ".corrupt")
	var backup := ProgressJson.decode(AtomicFile.read_text(_path + ".bak"))
	return backup.value if backup.ok else ProgressState.new()
