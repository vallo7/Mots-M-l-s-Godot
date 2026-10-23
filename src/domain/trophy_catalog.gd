class_name TrophyCatalog
extends RefCounted
## Les 20 trophées, du plus simple au plus rare : deux faciles pour démarrer, puis une difficulté et une rareté
## croissantes. L'ordre de la liste est l'ordre d'affichage. Pour en ajouter : une ligne ici + deux textes dans le CSV
## (un identifiant déjà débloqué n'est jamais retiré ni renommé : il est mémorisé dans la sauvegarde).

static var _all: Array[Trophy] = []


static func all() -> Array[Trophy]:
	if _all.is_empty():
		_all = _build()
	return _all


static func by_id(trophy_id: String) -> Trophy:
	for trophy in all():
		if trophy.id == trophy_id:
			return trophy
	return null


static func _build() -> Array[Trophy]:
	var list: Array[Trophy] = []
	# Bronze : prise en main
	list.append(Trophy.new("first_steps", TrophyRules.LEVELS, 1, Trophy.Tier.BRONZE))
	list.append(Trophy.new("rising_star", TrophyRules.THREE_STAR_LEVELS, 1, Trophy.Tier.BRONZE))
	# Argent : quelques parties
	list.append(Trophy.new("five_levels", TrophyRules.LEVELS, 5, Trophy.Tier.SILVER))
	list.append(Trophy.new("helping_hand", TrophyRules.HINTS_USED, 1, Trophy.Tier.SILVER))
	list.append(Trophy.new("chapter_one", TrophyRules.CHAPTERS, 1, Trophy.Tier.SILVER))
	# Or : on s'implique
	list.append(Trophy.new("daily_first", TrophyRules.DAILY_DONE, 1, Trophy.Tier.GOLD))
	list.append(Trophy.new("gift_opener", TrophyRules.GIFTS, 3, Trophy.Tier.GOLD))
	list.append(Trophy.new("fifty_stars", TrophyRules.STARS, 50, Trophy.Tier.GOLD))
	list.append(Trophy.new("flawless_five", TrophyRules.FLAWLESS_LEVELS, 5, Trophy.Tier.GOLD))
	# Émeraude : du métier
	list.append(Trophy.new("final_challenge", TrophyRules.FINAL_NO_HINT, 1, Trophy.Tier.EMERALD))
	list.append(Trophy.new("daily_week", TrophyRules.DAILY_BEST_STREAK, 7, Trophy.Tier.EMERALD))
	list.append(Trophy.new("perfect_five", TrophyRules.BEST_PERFECT_STREAK, 5, Trophy.Tier.EMERALD))
	list.append(Trophy.new("hundred_stars", TrophyRules.STARS, 100, Trophy.Tier.EMERALD))
	# Saphir : rare
	list.append(Trophy.new("five_chapters", TrophyRules.CHAPTERS, 5, Trophy.Tier.SAPPHIRE))
	list.append(Trophy.new("lightning", TrophyRules.LIGHTNING_LEVELS, 1, Trophy.Tier.SAPPHIRE))
	list.append(Trophy.new("daily_fortnight", TrophyRules.DAILY_BEST_STREAK, 14, Trophy.Tier.SAPPHIRE))
	list.append(Trophy.new("flawless_many", TrophyRules.FLAWLESS_LEVELS, 25, Trophy.Tier.SAPPHIRE))
	# Améthyste : légendaire
	list.append(Trophy.new("perfect_fifteen", TrophyRules.BEST_PERFECT_STREAK, 15, Trophy.Tier.AMETHYST))
	list.append(Trophy.new("ten_chapters", TrophyRules.CHAPTERS, 10, Trophy.Tier.AMETHYST))
	list.append(Trophy.new("daily_month", TrophyRules.DAILY_BEST_STREAK, 30, Trophy.Tier.AMETHYST))
	return list
