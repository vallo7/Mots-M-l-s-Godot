class_name LevelCatalog
extends RefCounted
## Tous les chapitres ; `levels` est la liste aplatie dans l'ordre de jeu.

var chapters: Array[Chapter]
var levels: Array[Level] = []


func _init(p_chapters: Array[Chapter]) -> void:
	chapters = p_chapters
	var ordered: Array[Chapter] = chapters.duplicate()
	ordered.sort_custom(func(a: Chapter, b: Chapter) -> bool: return a.index < b.index)
	for chapter in ordered:
		var sorted_levels: Array[Level] = chapter.levels.duplicate()
		sorted_levels.sort_custom(func(a: Level, b: Level) -> bool: return a.number < b.number)
		levels.append_array(sorted_levels)


func chapters_sorted() -> Array[Chapter]:
	var ordered: Array[Chapter] = chapters.duplicate()
	ordered.sort_custom(func(a: Chapter, b: Chapter) -> bool: return a.index < b.index)
	return ordered


func level_by_id(level_id: String) -> Level:
	for level in levels:
		if level.id == level_id:
			return level
	return null


func chapter_of(level: Level) -> Chapter:
	for chapter in chapters:
		if chapter.index == level.chapter_index:
			return chapter
	return null


func chapter_by_index(chapter_index: int) -> Chapter:
	for chapter in chapters:
		if chapter.index == chapter_index:
			return chapter
	return null


func level_after(level_id: String) -> Level:
	for i in levels.size():
		if levels[i].id == level_id:
			return levels[i + 1] if i < levels.size() - 1 else null
	return null
