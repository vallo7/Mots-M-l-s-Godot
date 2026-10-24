class_name GameUseCases
extends RefCounted
## Cas d'utilisation de la partie. Chaque modification de progression passe par
## ProgressRepository.update (atomique) ; rien n'est accordé ni retiré avant que l'action soit réussie.

var _catalog: LevelCatalog
var _progress: ProgressRepository
var _ads: AdProvider
var _random: Callable  ## (from, until_exclusive) -> int
var _clock: Callable  ## () -> secondes Unix (date de déblocage des trophées) ; horloge système par défaut
var _pacing: AdPacing  ## espacement des annonces plein écran (optionnel : les tests s'en passent)


func _init(catalog: LevelCatalog, progress: ProgressRepository, ads: AdProvider, random: Callable, clock: Callable = Callable(), pacing: AdPacing = null) -> void:
	_catalog = catalog
	_progress = progress
	_ads = ads
	_random = random
	_clock = clock
	_pacing = pacing


func _now() -> int:
	return _clock.call() if _clock.is_valid() else int(Time.get_unix_time_from_system())


## Débloque les trophées que la progression a déjà mérités (démarrage, nouveaux trophées après une mise à jour).
func sync_trophies() -> void:
	_progress.update(func(s: ProgressState) -> ProgressState: return TrophyRules.evaluate(_catalog, s, _now()))


## Le menu des trophées a été ouvert : tout ce qui est débloqué est « vu ».
func mark_trophies_seen() -> void:
	_progress.update(func(s: ProgressState) -> ProgressState: return TrophyRules.mark_all_seen(s))


## null si aucune partie n'est sauvegardée pour ce niveau et cette langue.
func load_snapshot(level: Level, language: int) -> GameSnapshot:
	return _progress.read().in_progress.get(ProgressRules.snapshot_key(level.id, language), null)


func save_snapshot(session: GameSession) -> void:
	if session.is_solved():
		return
	save_snapshot_of(session.level, session.language, session.snapshot())


func save_snapshot_of(level: Level, language: int, snapshot: GameSnapshot) -> void:
	_progress.update(func(s: ProgressState) -> ProgressState: return ProgressRules.save_snapshot(s, level.id, language, snapshot))


func clear_snapshots(level: Level) -> void:
	_progress.update(func(s: ProgressState) -> ProgressState: return ProgressRules.clear_snapshots(s, level.id))


## Victoire : vérifiée par le moteur, enregistrée de façon atomique et idempotente.
## Renvoie null (et journalise une erreur) si le moteur ne considère pas le niveau comme résolu.
func complete_level(session: GameSession) -> VictoryResult:
	if not session.is_solved():
		push_error("complete_level : le moteur ne considère pas le niveau comme résolu")
		return null
	var level := session.level
	var elapsed := session.finish()
	var stars := StarRating.stars_for(elapsed)
	var before := _progress.read()
	if level.is_daily():
		return _complete_daily(level, before, stars, elapsed, session.state.hints_used(), session.state.wrong_selections)
	var already_done := before.completed.has(level.id)
	var context := PraiseContext.new(
		stars, session.state.hints_used(), session.state.wrong_selections, elapsed,
		level.is_final_challenge(), before.perfect_streak
	)
	var seed_value := PraiseSelector.string_hash(level.id) * 31 + before.completed.size()
	var praise := PraiseSelector.select(context, before.last_praise, seed_value)
	var count_before := ProgressRules.chapter_completed_count(_catalog, before, level.chapter_index)
	var hints_used := session.state.hints_used()
	var wrong_selections := session.state.wrong_selections
	var transform := func(s: ProgressState) -> ProgressState:
		var done := ProgressRules.complete_level(s, level.id, stars, elapsed, praise)
		if done == s:  # déjà terminé : rien n'est recompté
			return s
		done = TrophyRules.record_level(done, level.grid_size, elapsed, hints_used, wrong_selections, level.is_final_challenge())
		return TrophyRules.evaluate(_catalog, done, _now())
	var after := _progress.update(transform)
	if after == null:
		# Écriture impossible : la victoire reste affichée (jamais de blocage du joueur), mais non persistée.
		push_warning("Victoire non persistée : %s" % level.id)
		after = transform.call(before)
	var stored: LevelResult = after.completed[level.id]
	var chapter := _catalog.chapter_by_index(level.chapter_index)
	var next := _catalog.level_after(level.id)

	var result := VictoryResult.new()
	result.level_id = level.id
	result.chapter_index = level.chapter_index
	result.stars = stored.stars
	result.elapsed_millis = stored.elapsed_millis
	if already_done:
		result.praise = after.last_praise if after.last_praise != Praise.NONE else Praise.NICE
	else:
		result.praise = praise
	result.chapter_completed = ProgressRules.is_chapter_complete(_catalog, after, level.chapter_index)
	result.gift_claimable = ProgressRules.is_gift_claimable(_catalog, after, level.chapter_index)
	result.next_level_id = next.id if next != null else ""
	result.chapter_completed_before = count_before
	result.chapter_completed_after = ProgressRules.chapter_completed_count(_catalog, after, level.chapter_index)
	result.chapter_total = chapter.levels.size() if chapter != null else Level.LEVELS_PER_CHAPTER
	return result


## Victoire au défi du jour : étoiles, indices, série (voir ProgressRules.complete_daily).
func _complete_daily(level: Level, before: ProgressState, stars: int, elapsed: int, hints_used: int, wrong_selections: int) -> VictoryResult:
	var day := level.daily_day()
	var captured: Array = [null]
	var transform := func(s: ProgressState) -> ProgressState:
		var completion := ProgressRules.complete_daily(s, day, stars, elapsed)
		if not completion.already_done:
			var recorded := TrophyRules.record_level(TrophyRules.record_daily(completion.state), level.grid_size, elapsed, hints_used, wrong_selections)
			completion.state = TrophyRules.evaluate(_catalog, recorded, _now())
		captured[0] = completion
		return completion.state
	var after := _progress.update(transform)
	var completion: DailyCompletion = captured[0]
	if after == null:
		push_warning("Victoire non persistée : %s" % level.id)
		transform.call(before)
		completion = captured[0]
		after = completion.state
	var context := PraiseContext.new(stars, 0, 0, elapsed, level.is_final_challenge(), before.perfect_streak)
	var praise := PraiseSelector.select(context, before.last_praise, PraiseSelector.string_hash(level.id) * 31 + before.daily_results.size())
	var stored: LevelResult = after.daily_results[day]
	var result := VictoryResult.new()
	result.level_id = level.id
	result.chapter_index = 0
	result.stars = stored.stars
	result.elapsed_millis = stored.elapsed_millis
	result.praise = praise if praise != Praise.NONE else Praise.NICE
	result.is_daily = true
	result.daily_day = day
	result.daily = completion
	result.next_level_id = ""
	return result


## Ne retire l'indice qu'une fois le solde persisté ; ne révèle rien si la sauvegarde échoue.
func use_hint(session: GameSession) -> HintUseResult:
	var balance := _progress.read().hint_balance
	var outcome := HintService.use_hint(session.state, balance)
	match outcome.kind:
		HintOutcome.Kind.REVEALED:
			var after := _progress.update(func(s: ProgressState) -> ProgressState:
				var spent := ProgressRules.spend_hint(s)
				if spent == null:
					return s
				return TrophyRules.evaluate(_catalog, TrophyRules.record_hint(spent), _now()))
			if after == null:
				return HintUseResult.new(HintUseResult.Kind.FAILED)
			if after.hint_balance >= balance:
				return HintUseResult.new(HintUseResult.Kind.NO_BALANCE)
			session.apply_hint(outcome)
			return HintUseResult.new(HintUseResult.Kind.USED, outcome.hint, after.hint_balance)
		HintOutcome.Kind.NO_BALANCE:
			return HintUseResult.new(HintUseResult.Kind.NO_BALANCE)
		HintOutcome.Kind.LIMIT_REACHED:
			return HintUseResult.new(HintUseResult.Kind.LIMIT_REACHED)
		_:
			return HintUseResult.new(HintUseResult.Kind.NOTHING_TO_REVEAL)


## Trophée de chapitre : 1 à 3 indices, une seule fois. Renvoie le gain, ou 0 si rien n'est réclamable
## (ou si la sauvegarde a échoué : rien n'est alors accordé).
func claim_gift(chapter_index: int) -> int:
	var amount := [0]  # conteneur mutable : une lambda capture les variables simples par valeur
	var after := _progress.update(func(s: ProgressState) -> ProgressState:
		var claim := ProgressRules.claim_gift(_catalog, s, chapter_index, _random)
		amount[0] = claim.amount if claim != null else 0
		return TrophyRules.evaluate(_catalog, claim.state, _now()) if claim != null else s)
	return amount[0] if after != null else 0


## Cinématique de l'indice (niveau 4 du chapitre 1) : la toute première fois, offre 1 indice et mémorise que la cinématique a
## été vue, dans la même écriture atomique. Renvoie true si la cinématique doit se lancer (sauvegarde réussie).
func begin_hint_intro(level: Level) -> bool:
	var due := [false]
	var after := _progress.update(func(s: ProgressState) -> ProgressState:
		if not TutorialRules.hint_intro_due(s, level):
			return s
		due[0] = true
		return TutorialRules.begin_hint_intro(s))
	return due[0] and after != null


## Publicité récompensée : la récompense (1 indice) n'est accordée qu'après confirmation du SDK.
## Asynchrone : à appeler avec `await`.
func watch_rewarded_ad() -> RewardOutcome:
	var grant_one := func(s: ProgressState, reward_id: String) -> RewardGrant:
		return ProgressRules.grant_rewarded_hints(s, reward_id, _random)
	return await _watch_rewarded(grant_one)


## « Doubler la récompense » : une publicité récompensée donne `amount` indices de plus (cadeau de chapitre, défi du jour).
func watch_rewarded_bonus(amount: int) -> RewardOutcome:
	var grant_bonus := func(s: ProgressState, reward_id: String) -> RewardGrant:
		return ProgressRules.grant_bonus_hints(s, reward_id, amount)
	return await _watch_rewarded(grant_bonus)


func _watch_rewarded(grant_fn: Callable) -> RewardOutcome:
	var reason := _ads.rewarded_unavailable_reason()
	if reason != UnavailableReason.NONE:
		return RewardOutcome.new(RewardOutcome.Kind.UNAVAILABLE, 0, reason)
	@warning_ignore("redundant_await")  # AdProvider est l'interface : l'implémentation AdMob est asynchrone
	var result: RewardedAdResult = await _ads.show_rewarded()
	if _pacing != null and result.kind != RewardedAdResult.Kind.UNAVAILABLE:
		_pacing.record(AdPacing.Kind.REWARDED, Time.get_ticks_msec())  # espace les interstitielles qui suivent
	match result.kind:
		RewardedAdResult.Kind.REWARDED:
			var granted := [0]
			var after := _progress.update(func(s: ProgressState) -> ProgressState:
				var grant: RewardGrant = grant_fn.call(s, result.reward_id)
				granted[0] = grant.amount if grant != null else 0
				return grant.state if grant != null else s)
			if after == null:
				return RewardOutcome.new(RewardOutcome.Kind.UNAVAILABLE, 0, UnavailableReason.ERROR)
			if granted[0] > 0:
				return RewardOutcome.new(RewardOutcome.Kind.GRANTED, granted[0])
			return RewardOutcome.new(RewardOutcome.Kind.DUPLICATE)
		RewardedAdResult.Kind.DISMISSED:
			return RewardOutcome.new(RewardOutcome.Kind.DISMISSED)
		_:
			return RewardOutcome.new(RewardOutcome.Kind.UNAVAILABLE, 0, result.reason)
