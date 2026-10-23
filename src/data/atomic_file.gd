class_name AtomicFile
extends RefCounted
## Écriture atomique : on écrit un fichier temporaire complet, puis on le renomme sur la cible.
## Un arrêt brutal ne laisse jamais la cible à moitié écrite.


static func write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(tmp)
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		# Certaines plateformes refusent de renommer par-dessus un fichier existant.
		DirAccess.remove_absolute(path)
		if DirAccess.rename_absolute(tmp, path) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	return true


static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func copy_file(from: String, to: String) -> bool:
	if not FileAccess.file_exists(from):
		return false
	return write_text(to, FileAccess.get_file_as_string(from))
