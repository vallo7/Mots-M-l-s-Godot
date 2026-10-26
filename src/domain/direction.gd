class_name Direction
extends RefCounted
## Les 8 directions de lecture d'une grille. Une case est un Vector2i : x = colonne, y = ligne.

enum { E, S, SE, W, N, SW, NW, NE }

const NAMES: Array[String] = ["E", "S", "SE", "W", "N", "SW", "NW", "NE"]
const VECTORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0),
	Vector2i(0, -1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]
const ALL: Array[int] = [E, S, SE, W, N, SW, NW, NE]


static func vector(direction: int) -> Vector2i:
	return VECTORS[direction]


## -1 si le nom est inconnu.
static func from_name(name_value: String) -> int:
	return NAMES.find(name_value)


## Direction obtenue en tournant `direction` de `turns` quarts de tour dans le sens horaire (négatif = antihoraire).
## À l'écran (y vers le bas) un quart de tour horaire envoie E -> S -> W -> N -> E.
static func rotate(direction: int, turns: int) -> int:
	var v := VECTORS[direction]
	for _i in range(posmod(turns, 4)):
		v = Vector2i(-v.y, v.x)
	return VECTORS.find(v)


## Direction du pas unitaire de `from` vers `to`, ou -1 si ce n'est pas un pas voisin.
static func step_between(from: Vector2i, to: Vector2i) -> int:
	return VECTORS.find(to - from)


## Directions autorisées pour *placer* les mots selon le palier de difficulté (1..4).
static func for_tier(tier: int) -> Array[int]:
	if tier <= 1:
		return [E, S]
	if tier == 2:
		return [E, S, SE]
	if tier == 3:
		return [E, S, SE, W, N]
	return ALL.duplicate()
