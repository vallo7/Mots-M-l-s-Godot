class_name DailyText
extends RefCounted
## Textes du défi du jour (dates, durées, difficulté), dans la langue courante.


static func date_label(day: int) -> String:
	var date := DailyChallenge.date_of(day)
	return Strings.t("daily_date", [
		Strings.t("daily_weekday_long_%d" % int(date["weekday"])),
		Strings.t("daily_month_%d" % int(date["month"])),
		int(date["day"]),
	])


## Met seulement la première lettre en majuscule (« Mercredi 21 octobre »).
static func capitalized(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func month_label(year: int, month: int) -> String:
	return "%s %d" % [Strings.t("daily_month_%d" % month).capitalize(), year]


static func weekday_short(weekday: int) -> String:
	return Strings.t("daily_weekday_short_%d" % weekday)


## « 05:12:33 » : temps restant avant minuit.
static func countdown(seconds: int) -> String:
	var s := maxi(seconds, 0)
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


## « 2:13 » : durée d'une partie.
static func duration(millis: int) -> String:
	return TimeFormat.mmss(millis)


static func band_name(band: int) -> String:
	match band:
		DifficultyBand.MEDIUM:
			return Strings.t("band_medium")
		DifficultyBand.HARD:
			return Strings.t("band_hard")
		DifficultyBand.FINAL:
			return Strings.t("band_final")
		_:
			return Strings.t("band_easy")


## Couleur (face, lèvre) de la carte du défi selon la difficulté.
static func band_colors(band: int) -> Array[Color]:
	match band:
		DifficultyBand.MEDIUM:
			return [Wg.BLUE, Wg.BLUE_DARK]
		DifficultyBand.HARD:
			return [Wg.PINK, Wg.PINK_DARK]
		DifficultyBand.FINAL:
			return [Wg.PURPLE, Wg.PURPLE_DARK]
		_:
			return [Wg.TEAL, Wg.TEAL_DARK]
