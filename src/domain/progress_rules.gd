class_name ProgressRules
extends RefCounted
## Règles de progression : fonctions pures, idempotentes quand c'est nécessaire.
## Chaque transformation renvoie un nouvel état (l'état reçu n'est jamais modifié).

const INITIAL_FREE_HINTS := 2
const REWARDED_MIN := 1
const REWARDED_MAX := 1
const GIFT_MIN := 1
const GIFT_MAX := 3
const REMEMBERED_REWARD_IDS := 32


## Premier lancement : exactement 2 indices gratuits, une seule fois.
static func initialize(state: ProgressState) -> ProgressState:
	if state.initial_hints_granted:
		return state
	var next := state.copy()
	next.initial_hints_granted = true
	next.hint_balance += INITIAL_FREE_HINTS
	return next


## Un niveau gagné est verrouillé : rappeler cette fonction ne change rien (idempotent).
static func complete_level(state: ProgressState, level_id: String, stars: int, elapsed_millis: int, praise: int) -> ProgressState:
	if state.completed.has(level_id):
		return state
	var next := state.copy()
	next.completed[level_id] = LevelResult.new(clampi(stars, 1, 3), maxi(0, elapsed_millis))
	next.perfect_streak = state.perfect_streak + 1 if stars >= 3 else 0
	if praise != Praise.NONE:
		next.last_praise = praise
	next.in_progress = _without_level_snapshots(state.in_progress, level_id)
	return next


## Victoire au défi du jour `day`. Un seul défi compte par jour (rappeler la fonction ne change rien). Récompenses :
## 1 indice, +1 avec 3 étoiles, + bonus quand la série de jours consécutifs atteint un palier (une fois par série).
## Terminer un jour passé (horloge modifiée, partie commencée avant minuit) donne les indices mais ne touche pas la série.
static func complete_daily(state: ProgressState, day: int, stars: int, elapsed_millis: int) -> DailyCompletion:
	if state.daily_results.has(day):
		var done := DailyCompletion.new(state)
		done.already_done = true
		done.streak = state.daily_streak
		done.best_streak = state.daily_best_streak
		return done
	var next := state.copy()
	var clamped_stars := clampi(stars, 1, 3)
	next.daily_results[day] = LevelResult.new(clamped_stars, maxi(0, elapsed_millis))
	var oldest := day - DailyChallenge.HISTORY_DAYS
	for key in next.daily_results.keys():
		if int(key) < oldest:
			next.daily_results.erase(key)
	var completion := DailyCompletion.new(next)
	if day > state.daily_last_day:
		var continues := state.daily_last_day == day - 1
		next.daily_streak = state.daily_streak + 1 if continues else 1
		if not continues:
			next.daily_claimed_milestones = []
		next.daily_last_day = day
		if next.daily_streak > next.daily_best_streak:
			next.daily_best_streak = next.daily_streak
			completion.new_best = next.daily_streak > 1
	completion.streak = next.daily_streak
	completion.best_streak = next.daily_best_streak
	var claimed := next.daily_claimed_milestones.has(next.daily_streak)
	var rewards := DailyChallenge.rewards_for(clamped_stars, next.daily_streak, claimed)
	completion.base_hints = rewards[0]
	completion.star_bonus_hints = rewards[1]
	completion.milestone_hints = rewards[2]
	if rewards[2] > 0 and day >= state.daily_last_day:
		next.daily_claimed_milestones.append(next.daily_streak)
		completion.milestone_days = next.daily_streak
	elif day < state.daily_last_day:
		completion.milestone_hints = 0
	next.hint_balance = state.hint_balance + completion.total_hints()
	next.in_progress = _without_level_snapshots(state.in_progress, "daily-%d" % day)
	return completion


static func snapshot_key(level_id: String, language: int) -> String:
	return "%s:%s" % [level_id, Language.code(language)]


## Sauvegarde la partie en cours ; sans effet sur un niveau déjà terminé.
static func save_snapshot(state: ProgressState, level_id: String, language: int, snapshot: GameSnapshot) -> ProgressState:
	if state.completed.has(level_id):
		return state
	var next := state.copy()
	next.in_progress[snapshot_key(level_id, language)] = snapshot
	return next


static func clear_snapshots(state: ProgressState, level_id: String) -> ProgressState:
	var next := state.copy()
	next.in_progress = _without_level_snapshots(state.in_progress, level_id)
	return next


static func _without_level_snapshots(in_progress: Dictionary, level_id: String) -> Dictionary:
	var prefix := level_id + ":"
	var result := {}
	for key in in_progress:
		if not String(key).begins_with(prefix):
			result[key] = in_progress[key]
	return result


## Premier niveau non terminé dans l'ordre du catalogue, ou null si tout est terminé.
static func current_level(catalog: LevelCatalog, state: ProgressState) -> Level:
	for level in catalog.levels:
		if not state.completed.has(level.id):
			return level
	return null


static func status_of(catalog: LevelCatalog, state: ProgressState, level_id: String) -> int:
	if state.completed.has(level_id):
		return LevelStatus.COMPLETED
	var current := current_level(catalog, state)
	if current != null and current.id == level_id:
		return LevelStatus.AVAILABLE
	return LevelStatus.LOCKED


static func chapter_completed_count(catalog: LevelCatalog, state: ProgressState, chapter_index: int) -> int:
	var count := 0
	for level in catalog.levels:
		if level.chapter_index == chapter_index and state.completed.has(level.id):
			count += 1
	return count


static func chapter_level_count(catalog: LevelCatalog, chapter_index: int) -> int:
	var count := 0
	for level in catalog.levels:
		if level.chapter_index == chapter_index:
			count += 1
	return count


static func is_chapter_complete(catalog: LevelCatalog, state: ProgressState, chapter_index: int) -> bool:
	var total := chapter_level_count(catalog, chapter_index)
	return total > 0 and chapter_completed_count(catalog, state, chapter_index) == total


static func is_gift_claimable(catalog: LevelCatalog, state: ProgressState, chapter_index: int) -> bool:
	return not state.claimed_gift_chapters.has(chapter_index) and is_chapter_complete(catalog, state, chapter_index)


## Cadeau de chapitre : 1 à 3 indices, une seule fois par chapitre (idempotent). `random` : Callable
## (from, until_exclusive) -> int. Renvoie null si rien à réclamer.
static func claim_gift(catalog: LevelCatalog, state: ProgressState, chapter_index: int, random: Callable) -> GiftClaim:
	if not is_gift_claimable(catalog, state, chapter_index):
		return null
	var amount: int = random.call(GIFT_MIN, GIFT_MAX + 1)
	var next := state.copy()
	next.hint_balance += amount
	next.claimed_gift_chapters.append(chapter_index)
	return GiftClaim.new(next, amount)


## Retire un indice. À appeler seulement quand l'indice a pu être exécuté. Null si le solde est vide.
static func spend_hint(state: ProgressState) -> ProgressState:
	if state.hint_balance <= 0:
		return null
	var next := state.copy()
	next.hint_balance -= 1
	return next


## Récompense publicitaire confirmée par le SDK. `reward_id` identifie *cette* diffusion : un
## rappel multiple ou une reprise d'appli avec le même identifiant n'accorde rien de plus.
## L'aléa n'est tiré qu'ici, après confirmation. Null si identifiant vide ou déjà accordé.
static func grant_rewarded_hints(state: ProgressState, reward_id: String, random: Callable) -> RewardGrant:
	if reward_id.strip_edges().is_empty() or state.granted_reward_ids.has(reward_id):
		return null
	var amount: int = random.call(REWARDED_MIN, REWARDED_MAX + 1)
	var next := state.copy()
	next.hint_balance += amount
	next.granted_reward_ids.append(reward_id)
	while next.granted_reward_ids.size() > REMEMBERED_REWARD_IDS:
		next.granted_reward_ids.remove_at(0)
	return RewardGrant.new(next, amount)
