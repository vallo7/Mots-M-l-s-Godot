class_name GameController
extends Node
## Pilote une partie : gestes -> moteur -> sons/haptique -> sauvegarde. Un contrôleur par partie.
## L'écran de jeu lit ses champs et réagit à ses signaux ; les règles vivent dans src/domain.

enum Dialog { NONE, CONFIRM_QUIT }

const TICK_SECONDS := 0.25
const WIN_PAUSE_SECONDS := 0.45
const MAX_SAVE_ATTEMPTS := 3
const RETRY_DELAY_SECONDS := 0.8
## Durée du verrou après un redémarrage (≈ durée de l'animation de mélange).
const RESTART_LOCK_MS := 900
## Micro-délai entre l'appui sur « Indice » (solde à zéro) et l'ouverture de la publicité : laisse jouer l'animation du bouton.
const AD_LAUNCH_DELAY_SECONDS := 0.38

signal changed()
signal found(word_index: int)
signal wrong()
signal hint_revealed(cell: Vector2i)
## Solde à zéro : la publicité récompensée va se lancer (l'écran joue l'animation du bouton pendant le micro-délai).
signal ad_launching()
signal restarted()
signal victory(result: VictoryResult)
signal leave_requested()
signal message_requested(key: String, quantity: int, plural: bool)
signal progress_changed()

var level: Level
var language: int
var ready_to_play := false
var found_word_indices: Array[int] = []
## Cases d'indice encore utiles (mot non trouvé).
var hint_cells: Array[Vector2i] = []
var selection: Array[Vector2i] = []
var elapsed_millis: int = 0
var hint_balance: int = 0
var hints_left_on_level: int = 0
var solved := false
var dialog: int = Dialog.NONE

var _use_cases: GameUseCases
var _read_hint_balance: Callable
var _session: GameSession
var _resumed := false
var _closed := false
var _hint_busy := false
var _ad_busy := false
var _victory_failed := false
var _last_restart_at: int = -1_000_000
var _tick := 0.0


func _init(p_level: Level, p_language: int, use_cases: GameUseCases, read_hint_balance: Callable) -> void:
	level = p_level
	language = p_language
	_use_cases = use_cases
	_read_hint_balance = read_hint_balance
	hints_left_on_level = level.hints_max_per_level
	_session = GameSession.new(level, language, func() -> int: return Time.get_ticks_msec())


func _ready() -> void:
	var snapshot := _use_cases.load_snapshot(level, language)
	if snapshot != null:
		_session.restore(snapshot)
	hint_balance = _read_hint_balance.call()
	_sync_from_session()
	ready_to_play = true
	changed.emit()
	if _resumed and not _session.is_solved():
		_session.resume()
	if _session.is_solved():
		_win()  # sauvegarde interrompue juste après le dernier mot


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= TICK_SECONDS:
		_tick = 0.0
		if _session.is_running():
			elapsed_millis = _session.elapsed_millis()
			changed.emit()


func session() -> GameSession:
	return _session


func state() -> GameState:
	return _session.state


func _sync_from_session() -> void:
	var s := _session.state
	found_word_indices = s.found_word_indices.duplicate()
	hint_cells.clear()
	for hint in s.revealed_hints:
		if not s.has_found(hint.word_index):
			hint_cells.append(hint.cell)
	elapsed_millis = _session.elapsed_millis()
	solved = _session.is_solved()
	hints_left_on_level = maxi(level.hints_max_per_level - s.hints_used(), 0)


func can_interact() -> bool:
	return ready_to_play and not solved and not _session.is_solved() and dialog == Dialog.NONE and not _closed


# ---- Tracé
func on_selection_start(cell: Vector2i) -> void:
	if not can_interact():
		return
	_session.begin_interaction()
	Feedback.play(Sound.SELECT_CELL)
	Feedback.perform(HapticEffect.SELECTION)
	selection = [cell] as Array[Vector2i]
	changed.emit()


func on_selection_change(path: Array[Vector2i]) -> void:
	if not can_interact():
		return
	if path.size() > selection.size():
		Feedback.play(Sound.SELECT_CELL)
		Feedback.perform(HapticEffect.SELECTION)
	selection = path
	changed.emit()


func on_selection_end() -> void:
	var path := selection
	selection = [] as Array[Vector2i]
	if not can_interact() or path.size() < 2:
		changed.emit()
		return
	var event := _session.submit(path)
	match event.kind:
		SessionEvent.Kind.FOUND:
			Feedback.play(Sound.CORRECT)
			Feedback.perform(HapticEffect.CONFIRM)
			_sync_from_session()
			changed.emit()
			found.emit(event.word_index)
			_persist_snapshot()
			if event.solved:
				_win()
		SessionEvent.Kind.WRONG:
			Feedback.play(Sound.WRONG)
			Feedback.perform(HapticEffect.ERROR)
			_sync_from_session()
			changed.emit()
			wrong.emit()
		_:
			changed.emit()


## Vrai pendant qu'un doigt trace sur la grille : aucune publicité ne doit s'afficher à ce moment.
func is_grid_being_touched() -> bool:
	return not selection.is_empty()


# ---- Victoire : vérifiée par le moteur, enregistrée de façon atomique (avec reprises en cas d'échec)
func _win() -> void:
	solved = true
	changed.emit()
	await get_tree().create_timer(WIN_PAUSE_SECONDS).timeout
	for attempt in range(MAX_SAVE_ATTEMPTS):
		if _closed:
			return
		var result := _use_cases.complete_level(_session)
		if result != null:
			victory.emit(result)
			return
		await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
	_victory_failed = true
	message_requested.emit("msg_error_generic", 0, false)


# ---- Indices
func on_hint_requested() -> void:
	if not can_interact() or _hint_busy:
		return
	_hint_busy = true
	var result := _use_cases.use_hint(_session)
	match result.kind:
		HintUseResult.Kind.USED:
			Feedback.play(Sound.HINT)
			Feedback.perform(HapticEffect.CONFIRM)
			_sync_from_session()
			hint_balance = result.new_balance
			changed.emit()
			hint_revealed.emit(result.hint.cell)
			_persist_snapshot()
			progress_changed.emit()
		HintUseResult.Kind.NO_BALANCE:
			# Aucune fenêtre de confirmation : l'appui lance directement la publicité, après un micro-délai et l'animation du bouton.
			await _launch_rewarded_ad()
		HintUseResult.Kind.LIMIT_REACHED:
			message_requested.emit("msg_hint_limit", 0, false)
		HintUseResult.Kind.NOTHING_TO_REVEAL:
			message_requested.emit("msg_hint_nothing", 0, false)
		_:
			message_requested.emit("msg_hint_failed", 0, false)
	_hint_busy = false


## Micro-délai (animation du bouton) puis publicité récompensée.
func _launch_rewarded_ad() -> void:
	if _ad_busy or _closed:
		return
	ad_launching.emit()
	await get_tree().create_timer(AD_LAUNCH_DELAY_SECONDS).timeout
	if _closed:
		return
	await on_watch_ad()


func on_watch_ad() -> void:
	if _ad_busy:
		return
	_ad_busy = true
	var outcome: RewardOutcome = await _use_cases.watch_rewarded_ad()
	match outcome.kind:
		RewardOutcome.Kind.GRANTED:
			Feedback.play(Sound.PROGRESS_UP)
			Feedback.perform(HapticEffect.SUCCESS)
			hint_balance = _read_hint_balance.call()
			changed.emit()
			message_requested.emit("msg_hints_earned", outcome.amount, true)
			progress_changed.emit()
		RewardOutcome.Kind.DISMISSED:
			message_requested.emit("msg_ad_dismissed", 0, false)
		RewardOutcome.Kind.DUPLICATE:
			message_requested.emit("msg_ad_duplicate", 0, false)
		_:
			var key := "msg_ad_offline" if outcome.reason == UnavailableReason.OFFLINE else "msg_ad_unavailable"
			message_requested.emit(key, 0, false)
	_ad_busy = false


# ---- Redémarrage, sortie, dialogues
## Redémarrage immédiat, sans fenêtre de confirmation : la grille rejoue un mélange animé de ses lettres.
## Un court verrou évite les doubles déclenchements pendant l'animation.
func on_restart_requested() -> void:
	var now := Time.get_ticks_msec()
	if not can_interact() or now - _last_restart_at < RESTART_LOCK_MS:
		return
	_last_restart_at = now
	_session.restart()
	Feedback.play(Sound.SHUFFLE)
	Feedback.perform(HapticEffect.CONFIRM)
	_sync_from_session()
	selection = [] as Array[Vector2i]
	elapsed_millis = 0
	changed.emit()
	restarted.emit()
	_use_cases.clear_snapshots(level)


func on_back_requested() -> void:
	if dialog != Dialog.NONE:
		_set_dialog(Dialog.NONE)
	elif solved and not _victory_failed:
		pass
	elif _session.has_started() and not _session.is_solved():
		_set_dialog(Dialog.CONFIRM_QUIT)
	else:
		_leave()


func confirm_quit() -> void:
	_set_dialog(Dialog.NONE)
	_leave()


func dismiss_dialog() -> void:
	_set_dialog(Dialog.NONE)


func _leave() -> void:
	_persist_snapshot()
	leave_requested.emit()


func _set_dialog(value: int) -> void:
	dialog = value
	if dialog == Dialog.NONE:
		if _resumed and not _session.is_solved():
			_session.resume()
	else:
		_session.pause()
	changed.emit()


# ---- Cycle de vie : le chronomètre est suspendu en arrière-plan (appel, verrouillage, annonce plein écran…)
func on_resume() -> void:
	_resumed = true
	if ready_to_play and dialog == Dialog.NONE and not _session.is_solved():
		_session.resume()


func on_pause() -> void:
	_resumed = false
	_session.pause()
	_persist_snapshot()


func _persist_snapshot() -> void:
	if not _session.has_started() and _session.state.revealed_hints.is_empty():
		return
	_use_cases.save_snapshot_of(level, language, _session.snapshot())


func close() -> void:
	_closed = true
	queue_free()
