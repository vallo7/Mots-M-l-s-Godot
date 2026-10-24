class_name TrophyCatalog
extends RefCounted
## Les 20 trophées, du plus simple au plus rare. L'ordre de la liste est l'ordre d'affichage. Pour en ajouter : une ligne
## ici + deux textes dans le CSV (un identifiant déjà débloqué n'est jamais retiré ni renommé : il est mémorisé dans la
## sauvegarde).
##
## Difficulté : chaque ligne donne l'objectif d'origine puis son multiplicateur. Les trophées qui étaient les plus faciles
## sont triplés (×3), les plus rares doublés (×2) : l'échelle reste progressive, sans qu'aucun objectif ne devienne
## inatteignable (le jeu compte 10 chapitres de 10 niveaux, soit 100 niveaux et 300 étoiles au plus ; « Maître des mots »
## garde donc 10 chapitres, déjà le maximum, et « Grand voyageur » est plafonné à 8 pour rester sous lui).

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
	# Bronze : prise en main (×3)
	list.append(Trophy.new("first_steps", TrophyRules.LEVELS, 1, Trophy.Tier.BRONZE, 3))
	list.append(Trophy.new("rising_star", TrophyRules.THREE_STAR_LEVELS, 1, Trophy.Tier.BRONZE, 3))
	# Argent : quelques parties
	list.append(Trophy.new("five_levels", TrophyRules.LEVELS, 5, Trophy.Tier.SILVER, 3))
	list.append(Trophy.new("helping_hand", TrophyRules.HINTS_USED, 1, Trophy.Tier.SILVER, 3))
	list.append(Trophy.new("chapter_one", TrophyRules.CHAPTERS, 1, Trophy.Tier.SILVER, 2))
	# Or : on s'implique
	list.append(Trophy.new("daily_first", TrophyRules.DAILY_DONE, 1, Trophy.Tier.GOLD, 3))
	list.append(Trophy.new("gift_opener", TrophyRules.GIFTS, 3, Trophy.Tier.GOLD, 2))
	list.append(Trophy.new("fifty_stars", TrophyRules.STARS, 50, Trophy.Tier.GOLD, 3))
	list.append(Trophy.new("flawless_five", TrophyRules.FLAWLESS_LEVELS, 5, Trophy.Tier.GOLD, 3))
	# Émeraude : du métier
	list.append(Trophy.new("final_challenge", TrophyRules.FINAL_NO_HINT, 1, Trophy.Tier.EMERALD, 3))
	list.append(Trophy.new("daily_week", TrophyRules.DAILY_BEST_STREAK, 7, Trophy.Tier.EMERALD, 2))
	list.append(Trophy.new("perfect_five", TrophyRules.BEST_PERFECT_STREAK, 5, Trophy.Tier.EMERALD, 2))
	list.append(Trophy.new("hundred_stars", TrophyRules.STARS, 100, Trophy.Tier.EMERALD, 2))
	# Saphir : rare (×2 ; « Grand voyageur » plafonné à 8 chapitres, « Éclair » : 2 grilles, en moins de 30 s)
	list.append(Trophy.new("five_chapters", TrophyRules.CHAPTERS, 5, Trophy.Tier.SAPPHIRE, 2, 8))
	list.append(Trophy.new("lightning", TrophyRules.LIGHTNING_LEVELS, 1, Trophy.Tier.SAPPHIRE, 2))
	list.append(Trophy.new("daily_fortnight", TrophyRules.DAILY_BEST_STREAK, 14, Trophy.Tier.SAPPHIRE, 2))
	list.append(Trophy.new("flawless_many", TrophyRules.FLAWLESS_LEVELS, 25, Trophy.Tier.SAPPHIRE, 2))
	# Améthyste : légendaire (« Maître des mots » : les 10 chapitres du jeu, déjà le maximum)
	list.append(Trophy.new("perfect_fifteen", TrophyRules.BEST_PERFECT_STREAK, 15, Trophy.Tier.AMETHYST, 2))
	list.append(Trophy.new("ten_chapters", TrophyRules.CHAPTERS, 10, Trophy.Tier.AMETHYST))
	list.append(Trophy.new("daily_month", TrophyRules.DAILY_BEST_STREAK, 30, Trophy.Tier.AMETHYST, 2))
	return list
