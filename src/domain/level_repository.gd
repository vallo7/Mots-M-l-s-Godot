class_name LevelRepository
extends RefCounted
## Contenu des niveaux (ressources embarquées, aucun réseau). Interface : surchargée par les implémentations.


func load_catalog() -> LevelCatalog:
	push_error("LevelRepository.load_catalog non implémenté")
	return null
