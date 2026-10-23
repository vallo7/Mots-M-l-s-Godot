class_name DifficultyBadge
extends Pill


static func create_for(band: int) -> Pill:
	var background := Wg.TEAL
	var foreground := Wg.WHITE
	var key := "band_easy"
	match band:
		DifficultyBand.MEDIUM:
			background = Wg.YELLOW
			foreground = Wg.INK_FIXED
			key = "band_medium"
		DifficultyBand.HARD:
			background = Wg.PINK
			key = "band_hard"
		DifficultyBand.FINAL:
			background = Wg.PURPLE
			key = "band_final"
	var pill := Pill.create(background)
	if band == DifficultyBand.FINAL:
		pill.row.add_child(UiKit.icon("ic_crown", 14.0))
	pill.row.add_child(Wg.label(Strings.t(key), 11.0, Wg.Weight.EXTRABOLD, foreground))
	return pill
