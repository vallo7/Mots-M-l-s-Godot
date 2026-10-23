class_name GameTimer
extends RefCounted
## Chronomètre de partie. Démarre à la première interaction avec la grille (`start_if_needed`),
## se suspend en arrière-plan (`pause`) et reprend (`resume`) uniquement si la partie a démarré.
## L'horloge est injectée (Callable -> ms monotones), jamais l'heure civile.

var _clock: Callable
var _accumulated_ms: int = 0
var _running_since: int = -1
var _started := false
var _stopped := false


func _init(clock: Callable) -> void:
	_clock = clock


func has_started() -> bool:
	return _started


func is_running() -> bool:
	return _running_since >= 0


func start_if_needed() -> void:
	if _started or _stopped:
		return
	_started = true
	_running_since = _clock.call()


func pause() -> void:
	if _running_since < 0:
		return
	_accumulated_ms += maxi(0, int(_clock.call()) - _running_since)
	_running_since = -1


func resume() -> void:
	if not _started or _stopped or _running_since >= 0:
		return
	_running_since = _clock.call()


## Fige le temps final (victoire). Idempotent.
func stop() -> int:
	pause()
	_stopped = true
	return _accumulated_ms


## Restaure un temps déjà écoulé (reprise) : reste en pause jusqu'à `resume`.
func restore_elapsed(millis: int) -> void:
	_accumulated_ms = maxi(0, millis)
	_running_since = -1
	_started = true
	_stopped = false


func reset() -> void:
	_accumulated_ms = 0
	_running_since = -1
	_started = false
	_stopped = false


func elapsed_millis() -> int:
	if _running_since < 0:
		return _accumulated_ms
	return _accumulated_ms + maxi(0, int(_clock.call()) - _running_since)
