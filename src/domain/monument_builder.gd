class_name MonumentBuilder
extends RefCounted


static func build(catalog: LevelCatalog, progress: ProgressState) -> Array[MonumentChapter]:
	var result: Array[MonumentChapter] = []
	for chapter in catalog.chapters_sorted():
		var m := MonumentChapter.new()
		m.index = chapter.index
		m.theme = chapter.theme
		m.palette_key = chapter.palette_key
		var levels: Array[Level] = chapter.levels.duplicate()
		levels.sort_custom(func(a: Level, b: Level) -> bool: return a.number < b.number)
		for level in levels:
			var ml := MonumentLevel.new()
			ml.level_id = level.id
			ml.number = level.number
			ml.theme = level.theme
			ml.grid_size = level.grid_size
			ml.style = level.visual_style
			ml.band = DifficultyBand.of(level.number)
			ml.status = ProgressRules.status_of(catalog, progress, level.id)
			var done: LevelResult = progress.completed.get(level.id, null)
			ml.stars = done.stars if done != null else 0
			ml.is_final = level.is_final_challenge()
			m.levels.append(ml)
		m.completed_count = ProgressRules.chapter_completed_count(catalog, progress, chapter.index)
		m.gift_claimed = progress.claimed_gift_chapters.has(chapter.index)
		m.gift_claimable = ProgressRules.is_gift_claimable(catalog, progress, chapter.index)
		result.append(m)
	return result
