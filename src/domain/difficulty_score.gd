class_name DifficultyScore
extends RefCounted
## Score de difficulté éditorial : combine taille de grille, nombre et longueur des mots, palier de
## directions, ambiguïté (proportion de lettres leurres) et leurres plantés (débuts de mots cachés dans la grille). Formule identique dans
## scripts/level_tools.py (vérifiée en CI).


static func compute_raw(grid_size: int, word_count: float, average_length: float, tier: int, ambiguity: float, decoys: int = 0) -> int:
	var value := grid_size * 2.0 + word_count * 3.0 + average_length * 1.5 + tier * 6.0 + ambiguity * 20.0 + decoys * 1.5
	return int(floorf(value + 0.5))  # Math.round : arrondi « demi vers le haut »


static func compute(level: Level) -> int:
	var count_sum := 0.0
	var variant_count := 0
	var length_sum := 0.0
	var word_total := 0
	for language in level.variants:
		var variant: LevelVariant = level.variants[language]
		count_sum += variant.words.size()
		variant_count += 1
		for word in variant.words:
			length_sum += word.length()
			word_total += 1
	var word_count := count_sum / variant_count if variant_count > 0 else 0.0
	var average_length := length_sum / word_total if word_total > 0 else 0.0
	return compute_raw(level.grid_size, word_count, average_length, level.difficulty.tier, level.difficulty.ambiguity, level.difficulty.decoys)
