class_name PraiseSelector
extends RefCounted
## Praise pseudo-aléatoire contrôlé : le niveau maximal dépend de la performance (0..7 points),
## le tirage est déterministe (graine) et évite de répéter le praise précédent.

const FAST_BELOW_MS := 90_000


static func points(ctx: PraiseContext) -> int:
	var p := clampi(ctx.stars, 1, 3) - 1
	if ctx.hints_used == 0:
		p += 1
	if ctx.wrong_selections == 0:
		p += 1
	if ctx.elapsed_millis < FAST_BELOW_MS:
		p += 1
	if ctx.is_final_challenge and ctx.stars >= 2:
		p += 1
	if ctx.stars == 3 and ctx.perfect_streak_before >= 2:
		p += 1
	return clampi(p, 0, Praise.KEYS.size() - 1)


## `previous` : dernier praise (Praise.NONE s'il n'y en a pas).
static func select(ctx: PraiseContext, previous: int, seed_value: int) -> int:
	var cap := points(ctx)
	var candidates: Array[int] = []
	for i in range(maxi(0, cap - 1), cap + 1):
		candidates.append(i)
	if previous != Praise.NONE and candidates.size() > 1:
		candidates = candidates.filter(func(p: int) -> bool: return p != previous)
	var index := posmod(_mix(seed_value), candidates.size())
	return candidates[index]


## SplitMix64. GDScript : entiers 64 bits signés (débordement cyclique) ; `>>` est arithmétique,
## on masque donc pour obtenir le décalage logique (`ushr`) du code d'origine.
static func _mix(x: int) -> int:
	var z := x + -7046029254386353131
	z = (z ^ _ushr(z, 30)) * -4658895280553007687
	z = (z ^ _ushr(z, 27)) * -7723592293110705685
	return z ^ _ushr(z, 31)


static func _ushr(value: int, bits: int) -> int:
	return (value >> bits) & ((1 << (64 - bits)) - 1)


## Équivalent de String.hashCode() de Kotlin/Java (entier 32 bits signé).
static func string_hash(text: String) -> int:
	var h := 0
	for i in text.length():
		h = (h * 31 + text.unicode_at(i)) & 0xFFFFFFFF
	return h - 0x100000000 if h >= 0x80000000 else h
