class_name DifficultyBand
extends RefCounted
## Badge de difficulté affiché sur les niveaux.

enum { EASY, MEDIUM, HARD, FINAL }


static func of(number: int) -> int:
	if number >= Level.FINAL_NUMBER:
		return FINAL
	if number >= 7:
		return HARD
	if number >= 4:
		return MEDIUM
	return EASY
