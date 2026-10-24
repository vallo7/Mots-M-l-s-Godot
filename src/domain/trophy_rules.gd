class_name TrophyRules
extends RefCounted
## Règles des trophées : fonctions pures (l'état reçu n'est jamais modifié ; l'horloge est un paramètre).
##
## Deux familles de compteurs :
##  - dérivés de la progression (niveaux, étoiles, chapitres, cadeaux, séries du défi du jour) : toujours
##    exacts, donc un joueur existant reçoit ses trophées rétroactivement ;
##  - mémorisés dans `ProgressState.stats` (indices utilisés, niveaux sans faute, éclairs, défis du jour, meilleure série
##    de 3 étoiles, défis finaux sans indice) : ils comptent à partir de la mise à jour qui les introduit.

const LEVELS := "levels"
const THREE_STAR_LEVELS := "three_star_levels"
const STARS := "stars"
const CHAPTERS := "chapters"
const GIFTS := "gifts"
const FINAL_NO_HINT := "final_no_hint"
const DAILY_BEST_STREAK := "daily_best_streak"
const DAILY_DONE := "daily_done"
const BEST_PERFECT_STREAK := "best_perfect_streak"
const HINTS_USED := "hint_uses"
const FLAWLESS_LEVELS := "flawless_levels"
const LIGHTNING_LEVELS := "lightning_levels"

## « Éclair » : une grille d'au moins `LIGHTNING_MIN_GRID` cases de côté résolue en moins de `LIGHTNING_BELOW_MS`.
const LIGHTNING_MIN_GRID := 8
const LIGHTNING_BELOW_MS := 30_000



## Valeur courante d'un compteur.
static func metric_value(metric: String, catalog: LevelCatalog, state: ProgressState) -> int:
	match metric:
		LEVELS:
			return state.completed.size()
		THREE_STAR_LEVELS:
			var three := 0
			for id in state.completed:
				if (state.completed[id] as LevelResult).stars >= 3:
					three += 1
			return three
		STARS:
			var stars := 0
			for id in state.completed:
				stars += (state.completed[id] as LevelResult).stars
			return stars
		CHAPTERS:
			var chapters := 0
			if catalog != null:
				for chapter in catalog.chapters:
					if ProgressRules.is_chapter_complete(catalog, state, chapter.index):
						chapters += 1
			return chapters
		GIFTS:
			return state.claimed_gift_chapters.size()
		DAILY_BEST_STREAK:
			return maxi(state.daily_best_streak, state.daily_streak)
		DAILY_DONE:
			return maxi(_stat(state, DAILY_DONE), state.daily_results.size())
		BEST_PERFECT_STREAK:
			return maxi(_stat(state, BEST_PERFECT_STREAK), state.perfect_streak)
		HINTS_USED, FLAWLESS_LEVELS, LIGHTNING_LEVELS, FINAL_NO_HINT:
			return _stat(state, metric)
	return 0


## Avancement affiché : la valeur du compteur, plafonnée à l'objectif.
static func progress_of(trophy: Trophy, catalog: LevelCatalog, state: ProgressState) -> int:
	return mini(metric_value(trophy.metric, catalog, state), trophy.target)


static func is_unlocked(state: ProgressState, trophy_id: String) -> bool:
	return state.trophies.has(trophy_id)


static func unlocked_count(state: ProgressState) -> int:
	var count := 0
	for trophy in TrophyCatalog.all():
		if state.trophies.has(trophy.id):
			count += 1
	return count


## Trophées débloqués mais pas encore vus dans le menu (pastille de l'accueil, étiquettes « Nouveau »).
static func unseen_ids(state: ProgressState) -> Array[String]:
	var ids: Array[String] = []
	for trophy in TrophyCatalog.all():
		if state.trophies.has(trophy.id) and not state.trophies_seen.has(trophy.id):
			ids.append(trophy.id)
	return ids


## Débloque (à l'heure `now`, en secondes Unix) tous les trophées dont l'objectif est atteint. Renvoie l'état reçu
## lui-même si rien ne change (pour que l'appelant puisse éviter une écriture).
static func evaluate(catalog: LevelCatalog, state: ProgressState, now: int) -> ProgressState:
	var next: ProgressState = null
	for trophy in TrophyCatalog.all():
		if state.trophies.has(trophy.id):
			continue
		if metric_value(trophy.metric, catalog, state) >= trophy.target:
			if next == null:
				next = state.copy()
			next.trophies[trophy.id] = now
	return next if next != null else state


## Identifiants débloqués par la transition `before` -> `after`, dans l'ordre du catalogue.
static func newly_unlocked(before: ProgressState, after: ProgressState) -> Array[String]:
	var ids: Array[String] = []
	for trophy in TrophyCatalog.all():
		if after.trophies.has(trophy.id) and not before.trophies.has(trophy.id):
			ids.append(trophy.id)
	return ids


## Marque tous les trophées débloqués comme vus.
static func mark_all_seen(state: ProgressState) -> ProgressState:
	var unseen := unseen_ids(state)
	if unseen.is_empty():
		return state
	var next := state.copy()
	for id in unseen:
		next.trophies_seen.append(id)
	return next


## Enregistre une victoire (niveau ordinaire ou défi du jour) dans les compteurs mémorisés.
## `grid_size` : côté de la grille ; `hints_used` / `wrong_selections` : issus de la partie ; `is_final` : défi final du chapitre.
static func record_level(state: ProgressState, grid_size: int, elapsed_millis: int, hints_used: int, wrong_selections: int, is_final: bool = false) -> ProgressState:
	var next := state.copy()
	if is_final and hints_used == 0:
		_add(next, FINAL_NO_HINT, 1)
	if hints_used == 0 and wrong_selections == 0:
		_add(next, FLAWLESS_LEVELS, 1)
	if grid_size >= LIGHTNING_MIN_GRID and elapsed_millis < LIGHTNING_BELOW_MS:
		_add(next, LIGHTNING_LEVELS, 1)
	# La meilleure série de 3 étoiles est mémorisée : la série courante retombe à 0 à la première partie moins rapide.
	next.stats[BEST_PERFECT_STREAK] = maxi(_stat(state, BEST_PERFECT_STREAK), next.perfect_streak)
	return next


## Enregistre une victoire au défi du jour.
static func record_daily(state: ProgressState) -> ProgressState:
	var next := state.copy()
	next.stats[DAILY_DONE] = metric_value(DAILY_DONE, null, state) + 1
	return next


## Enregistre l'utilisation d'un indice.
static func record_hint(state: ProgressState) -> ProgressState:
	var next := state.copy()
	_add(next, HINTS_USED, 1)
	return next


static func _stat(state: ProgressState, key: String) -> int:
	return maxi(0, int(state.stats.get(key, 0)))


static func _add(state: ProgressState, key: String, amount: int) -> void:
	state.stats[key] = _stat(state, key) + amount
