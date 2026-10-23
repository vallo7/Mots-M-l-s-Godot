class_name HomeModelBuilder
extends RefCounted


static func build(catalog: LevelCatalog, progress: ProgressState, language: int) -> HomeModel:
	var current := ProgressRules.current_level(catalog, progress)
	var current_chapter: Chapter = catalog.chapter_of(current) if current != null else null
	var ordered := catalog.chapters_sorted()
	var claimable: Chapter = null
	for chapter in ordered:
		if ProgressRules.is_gift_claimable(catalog, progress, chapter.index):
			claimable = chapter
			break
	var gift_chapter: Chapter = claimable
	if gift_chapter == null:
		gift_chapter = current_chapter
	if gift_chapter == null and not ordered.is_empty():
		gift_chapter = ordered[ordered.size() - 1]

	var model := HomeModel.new()
	for chapter in ordered:
		var card := ChapterCard.new()
		var is_current := current != null and current.chapter_index == chapter.index
		var complete := ProgressRules.is_chapter_complete(catalog, progress, chapter.index)
		card.index = chapter.index
		card.theme = chapter.theme
		card.palette_key = chapter.palette_key
		if is_current:
			card.status = ChapterStatus.CURRENT
		elif complete:
			card.status = ChapterStatus.COMPLETED
		else:
			card.status = ChapterStatus.LOCKED
		card.completed_count = ProgressRules.chapter_completed_count(catalog, progress, chapter.index)
		card.total = chapter.levels.size()
		var stars := 0
		for level in chapter.levels:
			var done: LevelResult = progress.completed.get(level.id, null)
			stars += done.stars if done != null else 0
		card.stars_earned = stars
		card.stars_max = chapter.levels.size() * 3
		card.current_level = current if is_current else null
		card.has_snapshot = is_current and progress.in_progress.has(ProgressRules.snapshot_key(current.id, language))
		card.trophy_claimable = ProgressRules.is_gift_claimable(catalog, progress, chapter.index)
		card.trophy_claimed = progress.claimed_gift_chapters.has(chapter.index)
		model.chapters.append(card)

	var start_page := -1
	for i in model.chapters.size():
		if model.chapters[i].status == ChapterStatus.CURRENT:
			start_page = i
			break
	if start_page < 0:
		start_page = maxi(model.chapters.size() - 1, 0)
	model.start_page = start_page
	model.current_level = current
	model.current_chapter = current_chapter
	model.gift_chapter = gift_chapter
	model.gift_chapter_completed = ProgressRules.chapter_completed_count(catalog, progress, gift_chapter.index) if gift_chapter != null else 0
	model.gift_chapter_total = gift_chapter.levels.size() if gift_chapter != null else 0
	model.gift_claimable = claimable != null
	model.hint_balance = progress.hint_balance
	model.all_completed = current == null
	model.has_snapshot = current != null and progress.in_progress.has(ProgressRules.snapshot_key(current.id, language))
	return model
